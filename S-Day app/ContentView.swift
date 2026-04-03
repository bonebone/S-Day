import SwiftUI
import SwiftData
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @Query private var allPatients: [Patient]

    /// Post-op patients with "需追踪" tag.
    private var postOpTrackingCount: Int {
        allPatients.filter { $0.isPostOp && $0.tags.contains("需追踪") }.count
    }

    /// Pre-op patients with "需追踪" tag.
    private var preOpTrackingCount: Int {
        allPatients.filter { !$0.isPostOp && $0.tags.contains("需追踪") }.count
    }
    
    // Privacy Lock properties
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("requireBiometrics") private var requireBiometrics: Bool = false
    @State private var isUnlocked: Bool = false

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            OverviewView()
                .tag(AppTab.overview)
                .tabItem {
                    Label("概览", systemImage: "chart.bar.doc.horizontal")
                }

            PreOpView()
                .tag(AppTab.preOp)
                .tabItem {
                    Label("术前", systemImage: "list.bullet.clipboard")
                }
                .badge(preOpTrackingCount > 0 ? preOpTrackingCount : 0)

            PostOpView()
                .tag(AppTab.postOp)
                .tabItem {
                    Label("术后", systemImage: "checkmark.circle")
                }
                .badge(postOpTrackingCount > 0 ? postOpTrackingCount : 0)

            SettingsView()
                .tag(AppTab.settings)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        // Apply privacy lock overlay and behavior
        .overlay {
            if requireBiometrics && !isUnlocked {
                ZStack {
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                        Text("S-Day 已锁定")
                            .font(.title2)
                            .bold()
                        Text("需要进行身份认证以保护病患隐私数据。")
                            .foregroundColor(.secondary)
                        
                        Button("点击解锁") {
                            authenticate()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onAppear {
            if requireBiometrics && !isUnlocked {
                authenticate()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                // Lock when app goes to background
                if requireBiometrics {
                    isUnlocked = false
                }
            } else if phase == .active {
                // Keep trying to auth when active
                if requireBiometrics && !isUnlocked {
                    authenticate()
                }
            }
        }
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // check whether biometric authentication is possible
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "我们需要验证您的身份以展示医疗数据。"
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation {
                            self.isUnlocked = true
                        }
                    } else {
                        // there was a problem
                    }
                }
            }
        } else {
            // no biometrics or passcode
            // Allow access or warn? Usually, deviceOwnerAuthentication works with Passcode too.
        }
    }
}

#Preview {
    ContentView()
}
