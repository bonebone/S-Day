import SwiftUI
import SwiftData

struct OverviewView: View {
    @Query var allPatients: [Patient]
    
    var preOpCount: Int {
        allPatients.filter { !$0.isPostOp }.count
    }
    
    var postOpCount: Int {
        allPatients.filter { $0.isPostOp }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Large Title for maximum space control
                HStack {
                    Text("概览")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4) // Minimal distance to the top safe area!
                .padding(.bottom, 4) // Minimal distance to the list!
                
                List {
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    OverviewView()
}
