import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var allPatients: [Patient]

    /// Post-op patients with "需追踪" tag.
    private var postOpTrackingCount: Int {
        allPatients.filter { $0.isPostOp && $0.tags.contains("需追踪") }.count
    }

    /// Pre-op patients with "需追踪" tag.
    private var preOpTrackingCount: Int {
        allPatients.filter { !$0.isPostOp && $0.tags.contains("需追踪") }.count
    }

    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("概览", systemImage: "chart.bar.doc.horizontal")
                }

            PreOpView()
                .tabItem {
                    Label("术前", systemImage: "list.bullet.clipboard")
                }
                .badge(preOpTrackingCount > 0 ? preOpTrackingCount : 0)

            PostOpView()
                .tabItem {
                    Label("术后", systemImage: "checkmark.circle")
                }
                .badge(postOpTrackingCount > 0 ? postOpTrackingCount : 0)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
