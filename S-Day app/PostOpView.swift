import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PostOpView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [Patient]
    
    @State private var collapsedDates: Set<Date> = []
    @State private var searchText = ""
    
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
                (key: key, value: value.sorted { $0.order > $1.order })
            }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Large Title for maximum space control
                HStack(alignment: .center) {
                    Text("术后")
                        .font(.largeTitle)
                        .bold()
                        .layoutPriority(1)
                    
                    Spacer(minLength: 16)
                    
                    NativeSearchBar(text: $searchText, placeholder: "搜索术后...")
                }
                .padding(.horizontal)
                .padding(.top, 4) // Minimal distance to the top safe area!
                .padding(.bottom, 8) // Minimal distance to the list!
                List {
                if groupedPostOpPatients.isEmpty {
                    Text("暂无术后病人")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(groupedPostOpPatients, id: \.key) { group in
                        Section(header: 
                            HStack {
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
                                    PatientRow(patient: patient)
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
                .environment(\.defaultMinListRowHeight, 44)
                .environment(\.defaultMinListHeaderHeight, 28)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private func deletePatients(in group: [Patient], offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(group[index])
            }
        }
    }
    
    private func movePatients(in group: [Patient], from source: IndexSet, to destination: Int) {
        var revisedItems = group
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.order = revisedItems.count - index
        }
    }
    
    private func handleDrop(items: [String], targetDate: Date, groupItems: [Patient]) {
        for uuidString in items {
            guard let id = UUID(uuidString: uuidString) else { continue }
            if let patient = patients.first(where: { $0.id == id }) {
                let currentStart = patient.surgeryDate.map { Calendar.current.startOfDay(for: $0) }
                let targetStart = Calendar.current.startOfDay(for: targetDate)
                
                if currentStart != targetStart {
                    patient.surgeryDate = targetDate
                    
                    var newGroup = groupItems.filter { $0.id != patient.id }
                    newGroup.append(patient)
                    
                    for (i, p) in newGroup.enumerated() {
                        p.order = newGroup.count - i
                    }
                    
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

