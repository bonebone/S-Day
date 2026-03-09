import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PreOpView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [Patient]
    
    @State private var collapsedDates: Set<Date?> = []
    @State private var searchText = ""
    
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
            VStack(spacing: 0) {
                // Custom Large Title for maximum space control
                HStack(alignment: .center) {
                    Text("术前")
                        .font(.largeTitle)
                        .bold()
                        .layoutPriority(1)
                    
                    Spacer(minLength: 16)
                    
                    NativeSearchBar(text: $searchText, placeholder: "搜索术前...")
                }
                .padding(.horizontal)
                .padding(.top, 4) // Minimal distance to the top safe area!
                .padding(.bottom, 8) // Minimal distance to the list!
                List {
                    // Always place the ghost row at the very top conceptually creating a new unassigned patient
                    GhostPatientRow { newName, newTags in
                        addPatient(name: newName, tags: newTags)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    
                    ForEach(groupedPreOpPatients, id: \.key) { group in
                        Section(header: 
                            HStack {
                                Text(headerText(for: group.key))
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
                                    PatientRow(patient: patient)
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
                // Removed the negative padding as we now have full control natively
                .environment(\.defaultMinListRowHeight, 44)
                .environment(\.defaultMinListHeaderHeight, 28)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private func headerText(for date: Date?) -> String {
        guard let date = date else { return "未安排手术" }
        return dateFormatter.string(from: date)
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
                    patient.surgeryDate = targetDate
                    
                    var newGroup = groupItems.filter { $0.id != patient.id }
                    newGroup.append(patient)
                    
                    for (i, p) in newGroup.enumerated() {
                        p.order = i
                    }
                    
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                }
            }
        }
    }
    }


private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
}()
