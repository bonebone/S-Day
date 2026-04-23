import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PreOpView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationState: AppNavigationState
    @Query private var patients: [Patient]
    @ObservedObject private var colorStore = TagColorStore.shared
    @ObservedObject private var tagFilterStore = TagFilterStore.shared
    private let sectionSelectionIndicatorSize: CGFloat = 20
    private let sectionSelectionIndicatorSpacing: CGFloat = 4
    private let listInsertionAnimation = Animation.snappy(duration: 0.32, extraBounce: 0.02)
    
    @State private var collapsedDates: Set<Date?> = []
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
    @State private var handledComposerFocusToken = 0
    @State private var isAwaitingBatchDeleteConfirmation = false

    private var visiblePatients: [Patient] {
        activePatients(from: patients)
    }
    
    private var preOpPatients: [Patient] {
        visiblePatients.filter { !$0.isPostOp }
    }

    private var tagFilterSnapshot: TagFilterSnapshot {
        tagFilterStore.snapshot(
            for: .preOp,
            patients: visiblePatients,
            selectedTag: selectedTag
        )
    }

    private var filteredPreOpPatients: [Patient] {
        preOpPatients.filter { patient in
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

    // Group patients by their surgery date (ignoring time)
    var groupedPreOpPatients: [(key: Date?, value: [Patient])] {
        let dict = Dictionary(grouping: filteredPreOpPatients) { patient -> Date? in
            guard let date = patient.surgeryDate else { return nil }
            return Calendar.current.startOfDay(for: date)
        }
        
        return dict.sorted { (kv1, kv2) in
            // nil (unassigned) comes first
            if kv1.key == nil { return true }
            if kv2.key == nil { return false }
            return kv1.key! < kv2.key!
        }.map { (key, value) in
            (key: key, value: value.sorted { $0.order < $1.order })
        }
    }

    private var preOpListAnimationKey: [String] {
        groupedPreOpPatients.flatMap { group in
            let groupKey = group.key?.formatted(date: .abbreviated, time: .omitted) ?? "nil"
            return ["section:\(groupKey)"] + group.value.map { "patient:\($0.id.uuidString)" }
        }
    }

    private var shouldShowEmptyState: Bool {
        groupedPreOpPatients.isEmpty && (!preOpPatients.isEmpty || !searchText.isEmpty || selectedTag != nil)
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
                                    title: "术前",
                                    searchText: $searchText,
                                    placeholder: "搜索术前..."
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
                                            let allIds = groupedPreOpPatients.flatMap { $0.value }.map { $0.id }
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

                        // Keep the row height in selection mode so the first patient does not shift upward.
                        GhostPatientRow(
                            onCommit: { newName, newTags in
                            addPatient(name: newName, tags: newTags)
                            },
                            focusTrigger: navigationState.preOpComposerFocusToken
                        )
                        .id("preOpGhostPatientRow")
                        .opacity(isSelectionMode ? 0 : 1)
                        .allowsHitTesting(!isSelectionMode)
                        .accessibilityHidden(isSelectionMode)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))

                        if shouldShowEmptyState {
                            Text(searchText.isEmpty && selectedTag == nil ? "暂无术前病人" : "暂无匹配结果")
                                .foregroundColor(.secondary)
                                .italic()
                                .listRowSeparator(.hidden)
                        }
                    
                        ForEach(groupedPreOpPatients, id: \.key) { group in
                            let groupIds = group.value.map { $0.id }
                            let isAllSelected = !groupIds.isEmpty && groupIds.allSatisfy { selectedPatients.contains($0) }
                            Section(header: 
                                HStack {
                                    Text(formatPreOpDate(group.key))
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
                                .id(sectionScrollID(for: group.key))
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
                                                   },
                                                   onDelete: {
                                                       movePatientsToTrash([patient])
                                                       UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                       showToast("已删除")
                                                   })
                                            .animation(.easeInOut(duration: 0.2), value: patient.tags)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    }
                                    // Native move within the SAME section
                                    .onMove { source, destination in
                                        movePatients(in: group.value, from: source, to: destination)
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
                    .animation(listInsertionAnimation, value: preOpListAnimationKey)
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
                        syncFromNavigationState(proxy: proxy)
                        syncComposerFocusRequest(proxy: proxy)
                        syncSelectedTag()
                    }
                    .onChange(of: searchText) { _, newValue in
                        if navigationState.preOpSearchText != newValue {
                            navigationState.preOpSearchText = newValue
                        }
                        if !newValue.isEmpty, navigationState.preOpJumpTarget != nil {
                            navigationState.preOpJumpTarget = nil
                        }
                    }
                    .onChange(of: navigationState.preOpSearchText) { _, _ in
                        syncFromNavigationState(proxy: proxy)
                    }
                    .onChange(of: navigationState.preOpJumpTarget) { _, _ in
                        syncFromNavigationState(proxy: proxy)
                    }
                    .onChange(of: navigationState.preOpComposerFocusToken) { _, _ in
                        syncComposerFocusRequest(proxy: proxy)
                    }
                    .onChange(of: tagFilterSnapshot.availableTags) { _, _ in
                        syncSelectedTag()
                    }
                    .sheet(isPresented: $showTagFilterSheet) {
                        TagFilterSheet(
                            scopeTitle: "术前",
                            allCount: tagFilterSnapshot.totalPatientCount,
                            tags: tagFilterSnapshot.sheetTags,
                            counts: tagFilterSnapshot.counts,
                            selectedTag: selectedTag,
                            isPinned: { tag in
                                tagFilterStore.isPinned(tag, in: .preOp)
                            },
                            onSelect: { tag in
                                selectedTag = tag
                            },
                            onTogglePinned: { tag in
                                withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                                    tagFilterStore.togglePinned(tag, in: .preOp)
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
                                let toUpdate = visiblePatients.filter { selectedPatients.contains($0.id) }
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
                        let toUpdate = visiblePatients.filter { selectedPatients.contains($0.id) }
                        movePatientsToEndOfSurgeryGroup(toUpdate, surgeryDate: batchSurgeryDate, allPatients: visiblePatients)
                        showBatchDatePicker = false
                        withAnimation { isSelectionMode = false; selectedPatients.removeAll() }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    })
                }
                .presentationDetents([.fraction(0.75), .large])
            }
            .sheet(isPresented: $showBatchTagSheet) {
                let toUpdate = visiblePatients.filter { selectedPatients.contains($0.id) }
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
                                    movePatientsToEndOfSurgeryGroup([patient], surgeryDate: nil, allPatients: visiblePatients)
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
                        movePatientsToEndOfSurgeryGroup([patient], surgeryDate: singlePatientSurgeryDate, allPatients: visiblePatients)
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

    private func syncFromNavigationState(proxy: ScrollViewProxy) {
        if searchText != navigationState.preOpSearchText {
            searchText = navigationState.preOpSearchText
        }

        guard let jumpTarget = navigationState.preOpJumpTarget else { return }

        switch jumpTarget {
        case .unscheduled:
            searchText = ""
            collapsedDates.remove(nil)
            withAnimation {
                proxy.scrollTo(sectionScrollID(for: nil), anchor: .top)
            }
        case .surgeryDate(let date):
            searchText = ""
            collapsedDates.remove(date)
            withAnimation {
                proxy.scrollTo(sectionScrollID(for: date), anchor: .top)
            }
        }

        if navigationState.preOpJumpTarget != nil {
            navigationState.preOpJumpTarget = nil
        }
    }

    private func syncSelectedTag() {
        guard let selectedTag, !tagFilterSnapshot.availableTags.contains(selectedTag) else { return }
        self.selectedTag = nil
    }

    private func syncComposerFocusRequest(proxy: ScrollViewProxy) {
        let focusToken = navigationState.preOpComposerFocusToken
        guard focusToken > handledComposerFocusToken else { return }

        handledComposerFocusToken = focusToken
        searchText = ""
        selectedTag = nil

        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo("preOpGhostPatientRow", anchor: .top)
            }
        }
    }

    private func sectionScrollID(for date: Date?) -> String {
        if let date {
            return "preop-section-\(date.timeIntervalSinceReferenceDate)"
        }
        return "preop-section-unscheduled"
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
        let selected = visiblePatients.filter { selectedPatients.contains($0.id) }
        let text = exportText(for: selected, sortDatesDescending: false, titleStyle: .preOp)
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
        let toDelete = visiblePatients.filter { selectedPatients.contains($0.id) }
        movePatientsToTrash(toDelete)
        selectedPatients.removeAll()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation {
            isSelectionMode = false
        }
        showToast("已删除所选条目")
    }
    

    private func addPatient(name: String, tags: [String]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !tags.isEmpty else { return }
        
        let minOrder = visiblePatients.min(by: { $0.order < $1.order })?.order ?? 0
        let newPatient = Patient(rawInput: trimmed, order: minOrder - 1)
        newPatient.tags = tags
        registerTagsIfNeeded(tags)
        withAnimation(listInsertionAnimation) {
            modelContext.insert(newPatient)
        }
        
        let impactMed = UIImpactFeedbackGenerator(style: .light)
        impactMed.impactOccurred()
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
        
        // Re-assign order based on the new array
        for (index, item) in revisedItems.enumerated() {
            item.order = index
        }
    }
    
    private func handleDrop(items: [String], targetDate: Date?, groupItems: [Patient]) {
        for uuidString in items {
            guard let id = UUID(uuidString: uuidString) else { continue }
            if let patient = visiblePatients.first(where: { $0.id == id }) {
                let currentStart = patient.surgeryDate.map { Calendar.current.startOfDay(for: $0) }
                let targetStart = targetDate.map { Calendar.current.startOfDay(for: $0) }
                
                if currentStart != targetStart {
                    movePatientsToEndOfSurgeryGroup([patient], surgeryDate: targetDate, allPatients: visiblePatients)
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                }
            }
        }
    }
}
