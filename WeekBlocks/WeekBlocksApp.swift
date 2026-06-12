import SwiftUI
import SwiftData

@main
struct WeekBlocksApp: App {
    let container: ModelContainer = {
        let schema = Schema([Routine.self, PlanBlock.self, BacklogItem.self, RoutineOccurrence.self, BacklogCategory.self, QuotaPlacement.self])
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
        // 단일 창 앱: Window 씬을 쓰면 창을 닫아도
        // "윈도우" 메뉴(및 Dock 아이콘 클릭)로 다시 열 수 있다. (App Store 심사 Guideline 4 대응)
        Window("무지개 공방", id: "main") {
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
