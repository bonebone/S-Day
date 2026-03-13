import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PostOpView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [Patient]
    
    @State private var collapsedDates: Set<Date> = []
    @State private var searchText = ""
    
    // Multiple selection states
    @State private var isSelectionMode = false
    @State private var selectedPatients: Set<UUID> = []
    @State private var showBatchDatePicker = false
    @State private var showBatchTagSheet = false
    @State private var batchSurgeryDate: Date = Date()
    @State private var selectedPatientForDate: Patient?
    @State private var selectedPatientForTag: Patient?
    @State private var singlePatientSurgeryDate: Date = Date()
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    // Group post-op patients by their surgery date
    var groupedPostOpPatients: [(key: Date, value: [Patient])] {
        let unsortedPostOp = patients.filter { patient in 
            if !patient.isPostOp { return false }
            if searchText.isEmpty { return true }
            let matchesText = patient.rawInput.localizedCaseInsensitiveContains(searchText) || (patient.parsedName?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesTag = patient.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesText || matchesTag
        }
        
        let dict = Dictionary(grouping: unsortedPostOp) { patient -> Date in
            // Post op patients should always have a date, but default to distant past just in case
            return Calendar.current.startOfDay(for: patient.surgeryDate ?? Date.distantPast)
        }
        
        return dict.sorted { $0.key > $1.key } // Most recent dates first
            .map { (key, value) in
                (key: key, value: value.sorted { $0.order < $1.order })
            }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Custom Large Title for maximum space control
                HStack(alignment: .center) {
                    if isSelectionMode {
                        Button("取消") {
                            withAnimation {
                                isSelectionMode = false
                                selectedPatients.removeAll()
                            }
                        }
                        Spacer()
                        Text("已选择 \(selectedPatients.count) 人")
                            .font(.headline)
                        Spacer()
                        Button("全选") {
                            withAnimation {
                                let allIds = groupedPostOpPatients.flatMap { $0.value }.map { $0.id }
                                if selectedPatients.count == allIds.count {
                                    selectedPatients.removeAll()
                                } else {
                                    selectedPatients = Set(allIds)
                                }
                            }
                        }
                    } else {
                        Text("术后")
                            .font(.largeTitle)
                            .bold()
                            .layoutPriority(1)
                        
                        Spacer(minLength: 16)
                        
                        NativeSearchBar(text: $searchText, placeholder: "搜索术后...")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 0)
                .padding(.bottom, 0)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        proxy.scrollTo("topPosition", anchor: .top)
                    }
                }
                
                List {
                    Color.clear.frame(height: 0).listRowInsets(EdgeInsets()).listRowSeparator(.hidden).id("topPosition")
                    
                    if groupedPostOpPatients.isEmpty {
                    Text("暂无术后病人")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(groupedPostOpPatients, id: \.key) { group in
                        Section(header: 
                            HStack {
                                if isSelectionMode {
                                    let groupIds = group.value.map { $0.id }
                                    let isAllSelected = !groupIds.isEmpty && groupIds.allSatisfy { selectedPatients.contains($0) }
                                    Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isAllSelected ? .blue : .gray)
                                        .font(.title3)
                                        .onTapGesture {
                                            withAnimation {
                                                if isAllSelected {
                                                    selectedPatients.subtract(groupIds)
                                                } else {
                                                    selectedPatients.formUnion(groupIds)
                                                }
                                            }
                                        }
                                        .padding(.trailing, 4)
                                }
                                Text(formatPostOpDate(group.key))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: collapsedDates.contains(group.key) ? "chevron.right" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if collapsedDates.contains(group.key) {
                                        collapsedDates.remove(group.key)
                                    } else {
                                        collapsedDates.insert(group.key)
                                    }
                                }
                            }
                        ) {
                            if !collapsedDates.contains(group.key) {
                                ForEach(group.value) { patient in
                                    let isSelected = selectedPatients.contains(patient.id)
                                    PatientRow(patient: patient,
                                               isSelectionMode: isSelectionMode,
                                               isSelected: isSelected,
                                               toggleSelection: {
                                                   withAnimation {
                                                       if isSelected {
                                                           selectedPatients.remove(patient.id)
                                                       } else {
                                                           selectedPatients.insert(patient.id)
                                                       }
                                                   }
                                               },
                                               onSwipeSelect: {
                                                   withAnimation {
                                                       isSelectionMode = true
                                                       selectedPatients.insert(patient.id)
                                                   }
                                               },
                                               onCancelSelection: {
                                                   withAnimation {
                                                       isSelectionMode = false
                                                       selectedPatients.removeAll()
                                                   }
                                               },
                                               onShowDatePicker: {
                                                   singlePatientSurgeryDate = patient.surgeryDate ?? Date()
                                                   selectedPatientForDate = patient
                                               },
                                               onShowTagSheet: {
                                                   selectedPatientForTag = patient
                                               })
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                                .onDelete { offsets in
                                    deletePatients(in: group.value, offsets: offsets)
                                }
                                .onMove { source, destination in
                                    movePatients(in: group.value, from: source, to: destination)
                                }
                            }
                        }
                    }
                }
                }
                .listStyle(.plain)
                .listSectionSpacing(0)
                .contentMargins(.top, 0, for: .scrollContent)
                // Left swipe in selection mode exits it
                .simultaneousGesture(
                    DragGesture(minimumDistance: 30, coordinateSpace: .local)
                        .onEnded { value in
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                            guard isHorizontal && isSelectionMode else { return }
                            if value.translation.width < -40 {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation {
                                    isSelectionMode = false
                                    selectedPatients.removeAll()
                                }
                            }
                        }
                )
            }
            } // ScrollViewReader
            .toolbar(.hidden, for: .navigationBar)
            .overlay(
                VStack {
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
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 16)
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showingToast)
            )
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode {
                    VStack(spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            Button(role: .destructive) {
                                guard !selectedPatients.isEmpty else { return }
                                let toDelete = patients.filter { selectedPatients.contains($0.id) }
                                for p in toDelete { modelContext.delete(p) }
                                selectedPatients.removeAll()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation {
                                    isSelectionMode = false
                                }
                            } label: {
                                Image(systemName: "trash").font(.title2)
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(selectedPatients.isEmpty)
                            
                            Button {
                                guard !selectedPatients.isEmpty else { return }
                                batchSurgeryDate = Date()
                                showBatchDatePicker = true
                            } label: {
                                Image(systemName: "calendar").font(.title2)
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(selectedPatients.isEmpty)
                            
                            Button {
                                guard !selectedPatients.isEmpty else { return }
                                showBatchTagSheet = true
                            } label: {
                                Image(systemName: "tag").font(.title2)
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(selectedPatients.isEmpty)
                            
                            Button {
                                guard !selectedPatients.isEmpty else { return }
                                let selected = patients.filter { selectedPatients.contains($0.id) }
                                let text = exportText(for: selected, sortDatesDescending: true, titleStyle: .postOp)
                                UIPasteboard.general.string = text
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                showToast("已复制到剪贴板")
                                withAnimation {
                                    isSelectionMode = false
                                    selectedPatients.removeAll()
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up").font(.title2)
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(selectedPatients.isEmpty)
                        }
                        .padding(.vertical, 12)
                        .padding(.bottom, 8)
                        .background(.regularMaterial)
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .sheet(isPresented: $showBatchDatePicker) {
                NavigationStack {
                    Form {
                        DatePicker("手术日期", selection: $batchSurgeryDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .environment(\.calendar, Calendar.autoupdatingCurrent)
                            .environment(\.locale, Locale.autoupdatingCurrent)
                        
                        Section {
                            Button(role: .destructive) {
                                let toUpdate = patients.filter { selectedPatients.contains($0.id) }
                                for p in toUpdate { p.surgeryDate = nil }
                                showBatchDatePicker = false
                                withAnimation { isSelectionMode = false; selectedPatients.removeAll() }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("清除手术日期")
                                    Spacer()
                                }
                            }
                        }
                    }
                    .navigationTitle("批量设日期")
                    .navigationBarItems(trailing: Button("完成") {
                        let toUpdate = patients.filter { selectedPatients.contains($0.id) }
                        movePatientsToEndOfSurgeryGroup(toUpdate, surgeryDate: batchSurgeryDate, allPatients: patients)
                        showBatchDatePicker = false
                        withAnimation { isSelectionMode = false; selectedPatients.removeAll() }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    })
                }
                .presentationDetents([.fraction(0.75), .large])
            }
            .sheet(isPresented: $showBatchTagSheet) {
                let toUpdate = patients.filter { selectedPatients.contains($0.id) }
                BatchTagSheetView(patients: toUpdate, existingAllTags: existingTags()) {
                    withAnimation { isSelectionMode = false; selectedPatients.removeAll() }
                }
            }
            .sheet(item: $selectedPatientForDate) { patient in
                NavigationStack {
                    Form {
                        Section {
                            DatePicker("手术日期", selection: $singlePatientSurgeryDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .environment(\.calendar, Calendar.autoupdatingCurrent)
                                .environment(\.locale, Locale.autoupdatingCurrent)
                        }

                        if patient.surgeryDate != nil {
                            Section {
                                Button(role: .destructive) {
                                    movePatientsToEndOfSurgeryGroup([patient], surgeryDate: nil, allPatients: patients)
                                    selectedPatientForDate = nil
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("清除手术日期")
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("设置手术日")
                    .navigationBarItems(trailing: Button("完成") {
                        movePatientsToEndOfSurgeryGroup([patient], surgeryDate: singlePatientSurgeryDate, allPatients: patients)
                        selectedPatientForDate = nil
                    })
                }
                .presentationDetents(patient.surgeryDate != nil ? [.fraction(0.75), .large] : [.fraction(0.6)])
            }
            .sheet(item: $selectedPatientForTag) { patient in
                TagSheetView(patient: patient, existingAllTags: existingTags())
            }
        }
    }
    
    private func deletePatients(in group: [Patient], offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(group[index])
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showingToast = false }
        }
    }
    
    private func movePatients(in group: [Patient], from source: IndexSet, to destination: Int) {
        var revisedItems = group
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.order = index
        }
    }
    
    private func handleDrop(items: [String], targetDate: Date, groupItems: [Patient]) {
        for uuidString in items {
            guard let id = UUID(uuidString: uuidString) else { continue }
            if let patient = patients.first(where: { $0.id == id }) {
                let currentStart = patient.surgeryDate.map { Calendar.current.startOfDay(for: $0) }
                let targetStart = Calendar.current.startOfDay(for: targetDate)
                
                if currentStart != targetStart {
                    movePatientsToEndOfSurgeryGroup([patient], surgeryDate: targetDate, allPatients: patients)
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                }
            }
        }
    }
}

#Preview {
    PostOpView()
}
