import SwiftUI
import SwiftData

struct OverviewView: View {
    @Query var allPatients: [Patient]
    @State private var searchText = ""
    
    var preOpCount: Int {
        allPatients.filter { !$0.isPostOp }.count
    }
    
    var postOpCount: Int {
        allPatients.filter { $0.isPostOp }.count
    }
    
    var searchResults: [Patient] {
        if searchText.isEmpty { return [] }
        return allPatients.filter { patient in
            let matchesText = patient.rawInput.localizedCaseInsensitiveContains(searchText) || (patient.parsedName?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesTag = patient.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesText || matchesTag
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Large Title for maximum space control
                HStack(alignment: .center) {
                    Text("概览")
                        .font(.largeTitle)
                        .bold()
                        .layoutPriority(1)
                    
                    Spacer(minLength: 16)
                    
                    NativeSearchBar(text: $searchText, placeholder: "全局快速定位...")
                }
                .padding(.horizontal)
                .padding(.top, 4) // Minimal distance to the top safe area!
                .padding(.bottom, 8) // Minimal distance to the list!
                List {
                    if !searchText.isEmpty {
                        if searchResults.isEmpty {
                            Text("未找到相关患者")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(searchResults, id: \.id) { patient in
                                Section(header: Text(patient.isPostOp ? "术后 · \(headerDateString(for: patient.surgeryDate))" : "术前 · \(headerDateString(for: patient.surgeryDate))")) {
                                    PatientRow(patient: patient)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                            }
                        }
                    } else {
                        Section(header: Text("今日概览")) {
                            HStack {
                                Text("待手术 (术前)")
                                Spacer()
                                Text("\(preOpCount)")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            HStack {
                                Text("已完成 (术后)")
                                Spacer()
                                Text("\(postOpCount)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private func headerDateString(for date: Date?) -> String {
        guard let d = date else { return "无排期" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: d)
    }
}

#Preview {
    OverviewView()
}
