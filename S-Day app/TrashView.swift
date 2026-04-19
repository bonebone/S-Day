import SwiftData
import SwiftUI

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [Patient]

    @State private var isSelectionMode = false
    @State private var selectedPatients: Set<UUID> = []
    @State private var isAwaitingPermanentDeleteConfirmation = false
    @State private var showingClearTrashConfirmation = false
    @State private var showingToast = false
    @State private var toastMessage = ""

    private var trashPatients: [Patient] {
        trashedPatients(from: patients).sorted {
            ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast)
        }
    }

    private var groupedTrashPatients: [(key: Date, value: [Patient])] {
        let grouped = Dictionary(grouping: trashPatients) { patient in
            Calendar.current.startOfDay(for: patient.trashedAt ?? .distantPast)
        }

        return grouped.keys.sorted(by: >).map { key in
            let value = (grouped[key] ?? []).sorted {
                ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast)
            }
            return (key, value)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabHeaderContainer {
                ZStack {
                    HStack {
                        Text("回收站")
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                        if !isSelectionMode, !trashPatients.isEmpty {
                            Button(role: .destructive) {
                                showingClearTrashConfirmation = true
                            } label: {
                                Image(systemName: "trash.slash")
                                    .font(.title3)
                            }
                        }
                    }
                    .opacity(isSelectionMode ? 0 : 1)
                    .allowsHitTesting(!isSelectionMode)

                    AdaptiveSelectionHeader(
                        selectedCount: selectedPatients.count,
                        onCancel: {
                            withAnimation {
                                isSelectionMode = false
                                selectedPatients.removeAll()
                                isAwaitingPermanentDeleteConfirmation = false
                            }
                        },
                        onToggleSelectAll: {
                            withAnimation {
                                let allIds = trashPatients.map(\.id)
                                if selectedPatients.count == allIds.count {
                                    selectedPatients.removeAll()
                                } else {
                                    selectedPatients = Set(allIds)
                                }
                            }
                        }
                    )
                    .opacity(isSelectionMode ? 1 : 0)
                    .allowsHitTesting(isSelectionMode)
                }
            }

            List {
                if groupedTrashPatients.isEmpty {
                    Text("回收站为空")
                        .foregroundColor(.secondary)
                        .italic()
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedTrashPatients, id: \.key) { group in
                        Section(header: Text(deletedSectionTitle(for: group.key))) {
                            ForEach(group.value) { patient in
                                TrashPatientRow(
                                    patient: patient,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedPatients.contains(patient.id),
                                    onToggleSelection: {
                                        toggleSelection(for: patient)
                                    },
                                    onEnterSelectionMode: {
                                        withAnimation {
                                            isSelectionMode = true
                                            selectedPatients.insert(patient.id)
                                        }
                                    },
                                    onRestore: {
                                        restore(patient: patient)
                                    },
                                    onDeletePermanently: {
                                        permanentlyDelete(patient: patient)
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                        guard isHorizontal && isSelectionMode else { return }
                        if value.translation.width < -40 {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation {
                                isSelectionMode = false
                                selectedPatients.removeAll()
                                isAwaitingPermanentDeleteConfirmation = false
                            }
                        }
                    }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode {
                VStack(spacing: 0) {
                    Divider()
                    AdaptiveActionBar {
                        Button {
                            restoreSelectedPatients()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(selectedPatients.isEmpty)

                        Button(role: .destructive) {
                            guard !selectedPatients.isEmpty else { return }
                            if isAwaitingPermanentDeleteConfirmation {
                                permanentlyDeleteSelectedPatients()
                            } else {
                                withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                                    isAwaitingPermanentDeleteConfirmation = true
                                }
                            }
                        } label: {
                            Group {
                                if isAwaitingPermanentDeleteConfirmation {
                                    Text("确认永久删除")
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                } else {
                                    Image(systemName: "trash")
                                        .font(.title2)
                                }
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(selectedPatients.isEmpty)
                    }
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
                    .background(.regularMaterial)
                }
            }
        }
        .overlay(alignment: .top) {
            if showingToast {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    Text(toastMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showingToast)
        .alert("清空回收站？", isPresented: $showingClearTrashConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                permanentlyDeletePatients(trashPatients, in: modelContext)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showToast("已清空回收站")
            }
        } message: {
            Text("回收站中的所有条目都会被永久删除，且无法恢复。")
        }
        .onAppear {
            purgeExpiredTrash(in: modelContext)
        }
        .onChange(of: selectedPatients) { _, _ in
            if selectedPatients.isEmpty {
                isAwaitingPermanentDeleteConfirmation = false
            }
        }
    }

    private func toggleSelection(for patient: Patient) {
        withAnimation {
            if selectedPatients.contains(patient.id) {
                selectedPatients.remove(patient.id)
            } else {
                selectedPatients.insert(patient.id)
            }
        }
    }

    private func restore(patient: Patient) {
        restorePatientsFromTrash([patient])
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showToast("已恢复")
    }

    private func permanentlyDelete(patient: Patient) {
        permanentlyDeletePatients([patient], in: modelContext)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showToast("已永久删除")
    }

    private func restoreSelectedPatients() {
        let selected = trashPatients.filter { selectedPatients.contains($0.id) }
        restorePatientsFromTrash(selected)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        selectedPatients.removeAll()
        withAnimation {
            isSelectionMode = false
        }
        showToast("已恢复所选条目")
    }

    private func permanentlyDeleteSelectedPatients() {
        let selected = trashPatients.filter { selectedPatients.contains($0.id) }
        permanentlyDeletePatients(selected, in: modelContext)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        selectedPatients.removeAll()
        isAwaitingPermanentDeleteConfirmation = false
        withAnimation {
            isSelectionMode = false
        }
        showToast("已永久删除所选条目")
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showingToast = false
            }
        }
    }

    private func deletedSectionTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "今天删除"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "昨天删除"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = appDisplayLocale()
        return formatter.string(from: date)
    }
}

private struct TrashPatientRow: View {
    let patient: Patient
    let isSelectionMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onEnterSelectionMode: () -> Void
    let onRestore: () -> Void
    let onDeletePermanently: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 20))
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(patientDisplayTitle)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !patient.tags.isEmpty {
                    Text(patient.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(metadataText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isSelectionMode {
                Button(role: .destructive) {
                    onDeletePermanently()
                } label: {
                    Label("永久删除", systemImage: "trash")
                }

                Button {
                    onRestore()
                } label: {
                    Label("恢复", systemImage: "arrow.uturn.backward")
                }
                .tint(.indigo)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                    guard isHorizontal, !isSelectionMode else { return }
                    if value.translation.width > 40 {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onEnterSelectionMode()
                    }
                }
        )
    }

    private var patientDisplayTitle: String {
        let trimmedParsedName = patient.parsedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedParsedName.isEmpty {
            return trimmedParsedName
        }
        return patient.rawInput
    }

    private var metadataText: String {
        let section = patient.isPostOp ? "术后" : "术前"
        let surgery = patient.surgeryDate.map { surgeryDateText(for: $0) } ?? "手术日期待定"
        let deleted = patient.trashedAt.map { deletedTimeText(for: $0) } ?? "删除时间未知"
        return "\(section) · \(surgery) · \(deleted)"
    }

    private func surgeryDateText(for date: Date) -> String {
        patient.isPostOp ? formatPostOpDate(date) : formatPreOpDate(date)
    }

    private func deletedTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = appDisplayLocale()
        return "删除于 \(formatter.string(from: date))"
    }
}
