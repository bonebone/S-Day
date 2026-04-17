import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PostOpView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: AppNavigationState
    @Query private var patients: [Patient]
    @ObservedObject private var colorStore = TagColorStore.shared
    @ObservedObject private var tagFilterStore = TagFilterStore.shared
    private let sectionSelectionIndicatorSize: CGFloat = 20
    private let sectionSelectionIndicatorSpacing: CGFloat = 4
    private let listInsertionAnimation = Animation.snappy(duration: 0.32, extraBounce: 0.02)
    
    @State private var collapsedDates: Set<Date> = []
    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var showTagFilterSheet = false
    @State private var tagFilterSheetDetent: PresentationDetent = .fraction(0.5)
    
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
    @State private var isAwaitingBatchDeleteConfirmation = false
    
    private var postOpPatients: [Patient] {
        patients.filter { $0.isPostOp }
    }

    private var tagFilterSnapshot: TagFilterSnapshot {
        tagFilterStore.snapshot(
            for: .postOp,
            patients: patients,
            selectedTag: selectedTag
        )
    }

    private var filteredPostOpPatients: [Patient] {
        postOpPatients.filter { patient in
            if !searchText.isEmpty {
                let matchesText = patient.rawInput.localizedCaseInsensitiveContains(searchText)
                    || (patient.parsedName?.localizedCaseInsensitiveContains(searchText) ?? false)
                let matchesSearchTag = patient.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
                guard matchesText || matchesSearchTag else { return false }
            }

            if let selectedTag {
                return patient.tags.contains(selectedTag)
            }

            return true
        }
    }

    // Group post-op patients by their surgery date
    var groupedPostOpPatients: [(key: Date, value: [Patient])] {
        let dict = Dictionary(grouping: filteredPostOpPatients) { patient -> Date in
            // Post op patients should always have a date, but default to distant past just in case
            return Calendar.current.startOfDay(for: patient.surgeryDate ?? Date.distantPast)
        }
        
        return dict.sorted { $0.key > $1.key } // Most recent dates first
            .map { (key, value) in
                (key: key, value: value.sorted { $0.order < $1.order })
            }
    }

    private var postOpListAnimationKey: [String] {
        groupedPostOpPatients.flatMap { group in
            let groupKey = group.key.formatted(date: .abbreviated, time: .omitted)
            return ["section:\(groupKey)"] + group.value.map { "patient:\($0.id.uuidString)" }
        }
    }

    private var emptyStateText: String {
        if postOpPatients.isEmpty && searchText.isEmpty && selectedTag == nil {
            return "暂无术后病人"
        }
        return "暂无匹配结果"
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    TabHeaderContainer(onTap: {
                        withAnimation {
                            proxy.scrollTo("topPosition", anchor: .top)
                        }
                    }) {
                        VStack(spacing: 10) {
                            ZStack {
                                AdaptiveTitleSearchHeader(
                                    title: "术后",
                                    searchText: $searchText,
                                    placeholder: "搜索术后..."
                                )
                                .opacity(isSelectionMode ? 0 : 1)
                                .allowsHitTesting(!isSelectionMode)
                                
                                AdaptiveSelectionHeader(
                                    selectedCount: selectedPatients.count,
                                    onCancel: {
                                        withAnimation {
                                            isSelectionMode = false
                                            selectedPatients.removeAll()
                                        }
                                    },
                                    onToggleSelectAll: {
                                        withAnimation {
                                            let allIds = groupedPostOpPatients.flatMap { $0.value }.map { $0.id }
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
                            
                            if !tagFilterSnapshot.barTags.isEmpty {
                                TagFilterBar(
                                    tags: tagFilterSnapshot.barTags,
                                    selectedTag: selectedTag,
                                    onSelect: { tag in
                                        selectedTag = tag
                                    },
                                    onMore: {
                                        tagFilterSheetDetent = tagFilterSheetDefaultDetent(tagCount: tagFilterSnapshot.sheetTags.count)
                                        showTagFilterSheet = true
                                    }
                                )
                                .opacity(isSelectionMode ? 0 : 1)
                                .allowsHitTesting(!isSelectionMode)
                                .accessibilityHidden(isSelectionMode)
                            }
                        }
                    }
                
                    List {
                        Color.clear.frame(height: 0).listRowInsets(EdgeInsets()).listRowSeparator(.hidden).id("topPosition")
                    
                        if groupedPostOpPatients.isEmpty {
                            Text(emptyStateText)
                                .foregroundColor(.secondary)
                                .italic()
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(groupedPostOpPatients, id: \.key) { group in
                                let groupIds = group.value.map { $0.id }
                                let isAllSelected = !groupIds.isEmpty && groupIds.allSatisfy { selectedPatients.contains($0) }
                                Section(header: 
                                    HStack {
                                        Text(formatPostOpDate(group.key))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, isSelectionMode ? sectionSelectionIndicatorSize + sectionSelectionIndicatorSpacing : 0)
                                        Spacer()
                                        Image(systemName: collapsedDates.contains(group.key) ? "chevron.right" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(alignment: .leading) {
                                        Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(isAllSelected ? .blue : .gray)
                                            .font(.system(size: sectionSelectionIndicatorSize))
                                            .frame(width: sectionSelectionIndicatorSize, height: sectionSelectionIndicatorSize)
                                            .opacity(isSelectionMode ? 1 : 0)
                                            .allowsHitTesting(isSelectionMode)
                                            .onTapGesture {
                                                guard isSelectionMode else { return }
                                                withAnimation {
                                                    if isAllSelected {
                                                        selectedPatients.subtract(groupIds)
                                                    } else {
                                                        selectedPatients.formUnion(groupIds)
                                                    }
                                                }
                                            }
                                    }
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
                                                       onShowDatePicker: {
                                                           singlePatientSurgeryDate = patient.surgeryDate ?? Date()
                                                           selectedPatientForDate = patient
                                                       },
                                                       onShowTagSheet: {
                                                           selectedPatientForTag = patient
                                                       },
                                                       onCopyExport: {
                                                           copySinglePatient(patient)
                                                       })
                                                .animation(.easeInOut(duration: 0.2), value: patient.tags)
                                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
                    .environment(\.defaultMinListRowHeight, 0)
                    .padding(.top, 4)
                    .animation(listInsertionAnimation, value: postOpListAnimationKey)
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
                    .onAppear {
                        syncFromNavigationState()
                        syncSelectedTag()
                    }
                    .onChange(of: searchText) { _, newValue in
                        if navigationState.postOpSearchText != newValue {
                            navigationState.postOpSearchText = newValue
                        }
                    }
                    .onChange(of: navigationState.postOpSearchText) { _, _ in
                        syncFromNavigationState()
                    }
                    .onChange(of: tagFilterSnapshot.availableTags) { _, _ in
                        syncSelectedTag()
                    }
                    .sheet(isPresented: $showTagFilterSheet) {
                        TagFilterSheet(
                            scopeTitle: "术后",
                            allCount: tagFilterSnapshot.totalPatientCount,
                            tags: tagFilterSnapshot.sheetTags,
                            counts: tagFilterSnapshot.counts,
                            selectedTag: selectedTag,
                            isPinned: { tag in
                                tagFilterStore.isPinned(tag, in: .postOp)
                            },
                            onSelect: { tag in
                                selectedTag = tag
                            },
                            onTogglePinned: { tag in
                                withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                                    tagFilterStore.togglePinned(tag, in: .postOp)
                                }
                            }
                        )
                        .presentationDetents(
                            [tagFilterSheetDefaultDetent(tagCount: tagFilterSnapshot.sheetTags.count), .large],
                            selection: $tagFilterSheetDetent
                        )
                    }
                    .overlay {
                        if isSelectionMode && isAwaitingBatchDeleteConfirmation {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    cancelBatchDeleteConfirmation()
                                }
                        }
                    }
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
                VStack(spacing: 0) {
                    Divider()
                    AdaptiveActionBar {
                        Button {
                            handleBatchDateTap()
                        } label: {
                            Image(systemName: "calendar").font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(selectedPatients.isEmpty || !isSelectionMode || isAwaitingBatchDeleteConfirmation)
                        .overlay {
                            if isSelectionMode && isAwaitingBatchDeleteConfirmation && !selectedPatients.isEmpty {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        cancelBatchDeleteConfirmation()
                                    }
                            }
                        }
                        
                        Button {
                            handleBatchTagTap()
                        } label: {
                            Image(systemName: "tag").font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(selectedPatients.isEmpty || !isSelectionMode || isAwaitingBatchDeleteConfirmation)
                        .overlay {
                            if isSelectionMode && isAwaitingBatchDeleteConfirmation && !selectedPatients.isEmpty {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        cancelBatchDeleteConfirmation()
                                    }
                            }
                        }
                        
                        Button {
                            handleBatchCopyTap()
                        } label: {
                            Image(systemName: "doc.on.doc").font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(selectedPatients.isEmpty || !isSelectionMode || isAwaitingBatchDeleteConfirmation)
                        .overlay {
                            if isSelectionMode && isAwaitingBatchDeleteConfirmation && !selectedPatients.isEmpty {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        cancelBatchDeleteConfirmation()
                                    }
                            }
                        }
                        
                        Button(role: .destructive) {
                            guard !selectedPatients.isEmpty else { return }
                            if isAwaitingBatchDeleteConfirmation {
                                confirmBatchDelete()
                            } else {
                                withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                                    isAwaitingBatchDeleteConfirmation = true
                                }
                            }
                        } label: {
                            Group {
                                if isAwaitingBatchDeleteConfirmation {
                                    Text("确认删除")
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                } else {
                                    Image(systemName: "trash").font(.title2)
                                }
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(selectedPatients.isEmpty || !isSelectionMode)
                    }
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
                    .background(.regularMaterial)
                }
                .opacity(isSelectionMode ? 1 : 0)
                .allowsHitTesting(isSelectionMode)
            }
            .sheet(isPresented: $showBatchDatePicker) {
                NavigationStack {
                    Form {
                        DatePicker("手术日期", selection: $batchSurgeryDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .environment(\.calendar, Calendar.autoupdatingCurrent)
                            .environment(\.locale, appDisplayLocale())
                        
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
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedPatientForDate) { patient in
                NavigationStack {
                    Form {
                        Section {
                            DatePicker("手术日期", selection: $singlePatientSurgeryDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .environment(\.calendar, Calendar.autoupdatingCurrent)
                                .environment(\.locale, appDisplayLocale())
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
            .onChange(of: isSelectionMode) { _, newValue in
                if !newValue {
                    cancelBatchDeleteConfirmation()
                }
            }
            .onChange(of: selectedPatients) { _, _ in
                cancelBatchDeleteConfirmation()
            }
        }
    }

    private func syncFromNavigationState() {
        if searchText != navigationState.postOpSearchText {
            searchText = navigationState.postOpSearchText
        }
    }

    private func syncSelectedTag() {
        guard let selectedTag, !tagFilterSnapshot.availableTags.contains(selectedTag) else { return }
        self.selectedTag = nil
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

    private func copySinglePatient(_ patient: Patient) {
        let tagsText = patient.tags.map { "#\($0)" }.joined(separator: " ")
        let text = tagsText.isEmpty ? patient.rawInput : "\(patient.rawInput) \(tagsText)"
        UIPasteboard.general.string = text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        showToast("已复制到剪贴板")
    }

    private func cancelBatchDeleteConfirmation() {
        guard isAwaitingBatchDeleteConfirmation else { return }
        withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
            isAwaitingBatchDeleteConfirmation = false
        }
    }

    private func handleBatchDateTap() {
        guard !selectedPatients.isEmpty, isSelectionMode else { return }
        batchSurgeryDate = Date()
        showBatchDatePicker = true
    }

    private func handleBatchTagTap() {
        guard !selectedPatients.isEmpty, isSelectionMode else { return }
        showBatchTagSheet = true
    }

    private func handleBatchCopyTap() {
        guard !selectedPatients.isEmpty, isSelectionMode else { return }
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
    }

    private func confirmBatchDelete() {
        isAwaitingBatchDeleteConfirmation = false
        let toDelete = patients.filter { selectedPatients.contains($0.id) }
        for patient in toDelete {
            modelContext.delete(patient)
        }
        selectedPatients.removeAll()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation {
            isSelectionMode = false
        }
    }
}

#Preview {
    PostOpView()
}
