import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PreOpView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [Patient]
    
    @State private var collapsedDates: Set<Date?> = []
    @State private var searchText = ""
    
    // Multiple selection states
    @State private var isSelectionMode = false
    @State private var selectedPatients: Set<UUID> = []
    @State private var showBatchDatePicker = false
    @State private var showBatchTagSheet = false
    @State private var batchSurgeryDate: Date = Date()
    
    // Group patients by their surgery date (ignoring time)
    var groupedPreOpPatients: [(key: Date?, value: [Patient])] {
        let unsortedPreOp = patients.filter { patient in 
            if patient.isPostOp { return false }
            if searchText.isEmpty { return true }
            let matchesText = patient.rawInput.localizedCaseInsensitiveContains(searchText) || (patient.parsedName?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesTag = patient.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesText || matchesTag
        }
        
        let dict = Dictionary(grouping: unsortedPreOp) { patient -> Date? in
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
                                let allIds = groupedPreOpPatients.flatMap { $0.value }.map { $0.id }
                                if selectedPatients.count == allIds.count {
                                    selectedPatients.removeAll()
                                } else {
                                    selectedPatients = Set(allIds)
                                }
                            }
                        }
                    } else {
                        Text("术前")
                            .font(.largeTitle)
                            .bold()
                            .layoutPriority(1)
                        
                        Spacer(minLength: 16)
                        
                        NativeSearchBar(text: $searchText, placeholder: "搜索术前...")
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

                    if !isSelectionMode {
                        // Always place the ghost row at the very top conceptually creating a new unassigned patient
                        GhostPatientRow { newName, newTags in
                            addPatient(name: newName, tags: newTags)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                    }
                    
                    ForEach(groupedPreOpPatients, id: \.key) { group in
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
                                Text(formatPreOpDate(group.key))
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
                                               })
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                                // Native move within the SAME section
                                .onMove { source, destination in
                                    movePatients(in: group.value, from: source, to: destination)
                                }
                                .onDelete { offsets in
                                    deletePatients(in: group.value, offsets: offsets)
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
                                let text = selected.map { p -> String in
                                    let tagsText = p.tags.map { "#\($0)" }.joined(separator: " ")
                                    return tagsText.isEmpty ? p.rawInput : "\(p.rawInput) \(tagsText)"
                                }.joined(separator: "\n")
                                UIPasteboard.general.string = text
                                // Quick haptic
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                // Flash mode to let user know it's copied
                                withAnimation {
                                    isSelectionMode = false
                                    selectedPatients.removeAll()
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard").font(.title2)
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
        }
    }
    

    private func addPatient(name: String, tags: [String]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !tags.isEmpty else { return }
        
        let minOrder = patients.min(by: { $0.order < $1.order })?.order ?? 0
        let newPatient = Patient(rawInput: trimmed, order: minOrder - 1)
        newPatient.tags = tags
        modelContext.insert(newPatient)
        
        let impactMed = UIImpactFeedbackGenerator(style: .light)
        impactMed.impactOccurred()
    }
    
    private func deletePatients(in group: [Patient], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(group[index])
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
            if let patient = patients.first(where: { $0.id == id }) {
                let currentStart = patient.surgeryDate.map { Calendar.current.startOfDay(for: $0) }
                let targetStart = targetDate.map { Calendar.current.startOfDay(for: $0) }
                
                if currentStart != targetStart {
                    movePatientsToEndOfSurgeryGroup([patient], surgeryDate: targetDate, allPatients: patients)
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                }
            }
        }
    }
    }

