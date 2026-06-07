import SwiftUI
import SwiftData

@main
struct WeekBlocksApp: App {
    let container: ModelContainer = {
        let schema = Schema([Routine.self, PlanBlock.self, BacklogItem.self, RoutineOccurrence.self, BacklogCategory.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.devkoan.ScheduleDensity")
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .defaultSize(width: 1080, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
