import SwiftUI
import SwiftData

@main
struct SDayApp: App {
    @StateObject private var navigationState = AppNavigationState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Patient.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("appAppearance") private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.colorScheme)
                .environmentObject(navigationState)
                .task {
                    // Bootstrap: ensure all tags already on patients exist in TagColorStore.
                    // This handles data that predates the tag manager.
                    await syncPatientTagsToStore()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func syncPatientTagsToStore() async {
        let ctx = sharedModelContainer.mainContext
        guard let patients = try? ctx.fetch(FetchDescriptor<Patient>()) else { return }
        let store = TagColorStore.shared
        for patient in patients {
            for tag in patient.tags where store.colorIndices[tag] == nil {
                store.colorIndices[tag] = TagColorStore.hashIndex(for: tag)
            }
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
