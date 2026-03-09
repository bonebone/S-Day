import SwiftUI
import SwiftData

@main
struct SDayApp: App {
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

    var body: some Scene {
        WindowGroup {
            ContentView()
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
