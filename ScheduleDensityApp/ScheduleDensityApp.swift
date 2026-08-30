//
//  ScheduleDensityApp.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI
import SwiftData
import CloudKit
import LeeoKit

// MARK: - CloudKit 공유 초대 수락 연결
// SwiftUI 라이프사이클에서는 씬 델리게이트의 userDidAcceptCloudKitShareWith로
// 초대 수락 콜백이 들어오므로, 델리게이트 클래스를 직접 지정해 연결한다.

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Self.routeShareAccept(cloudKitShareMetadata)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // 앱이 꺼진 상태에서 초대 링크로 실행된 경우.
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Self.routeShareAccept(metadata)
        }
    }

    /// 초대받은 공유의 존 이름에 따라 알맞은 스토어로 수락을 보낸다.
    /// (일정 공유와 할 일 공유가 같은 CloudKit 컨테이너를 쓰기 때문.)
    private static func routeShareAccept(_ metadata: CKShare.Metadata) {
        let zoneName = metadata.share.recordID.zoneID.zoneName
        Task {
            switch zoneName {
            case ScheduleShareStore.zoneName:
                await ScheduleShareStore.shared.accept(metadata)
            case FamilyShareStore.zoneName:
                await FamilyShareStore.shared.accept(metadata)
            default:
                await ScheduleShareStore.shared.accept(metadata)
            }
        }
    }
}

/// 여러 뷰에서 함께 쓰는 UserDefaults 키 모음. 문자열 오타로 설정이 어긋나는 것을 막는다.
enum AppSettingsKey {
    /// 공유 탭 노출 여부. 기본값은 false(숨김)이며 설정에서 켤 수 있다.
    static let showShareTab = "showShareTab"
    /// 무지개 화면 첫 진입 온보딩을 이미 봤는지. 한 번만 뜬다(설정에서 다시 볼 수 있다).
    static let hasSeenRainbowOnboarding = "hasSeenRainbowOnboarding"
    /// 할 일 쪼개는 법 안내를 이미 봤는지. 단계가 없는 할 일에 처음 들어갈 때 한 번 뜬다.
    static let hasSeenSplitOnboarding = "hasSeenSplitOnboarding"
}

/// 루트 TabView의 탭. 위젯 딥링크가 특정 탭을 열 수 있도록 태그를 붙인다.
enum AppTab: Hashable {
    case rainbow, share, todo
}

@main
struct ScheduleDensityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettingsKey.showShareTab) private var showShareTab = false
    @State private var selectedTab: AppTab = .todo
    /// 일정(무지개) 뷰모델은 앱이 들고 있는다. 할 일 화면에서 데드라인을 정하면
    /// 이 뷰모델을 통해 무지개에 줄이 그어지므로, 무지개 탭을 안 열어도 살아 있어야 한다.
    @State private var schedule = ScheduleViewModel()

    init() {
        LeeoEngagement.shared.registerLaunch()
        // 할 일 화면의 조언은 전부 TipKit으로 낸다 (→ TodoTips.swift).
        TodoTips.configure()
    }

    var sharedModelContainer: ModelContainer = {
        // 1단계: 기존 데이터베이스 로드 시도 (하위 호환성)
        // ⚠️ cloudKitDatabase: .none 을 명시한다. 앱에 CloudKit 컨테이너(WeekBlocks 연동용)가
        //    추가되면 기본값 .automatic 이 Event 스토어까지 CloudKit을 켜려다 실패한다
        //    (Event는 기본값 없는 비옵셔널 속성 보유 → CloudKit 비호환). Event는 로컬 전용 유지.
        do {
            // ⚠️ groupContainer: .none 을 반드시 명시한다.
            //    App Group entitlement(할 일 위젯용)가 붙으면 SwiftData 기본 저장 위치가
            //    앱 샌드박스 → App Group 컨테이너로 바뀐다. 그러면 이미 배포된 사용자의
            //    default.store를 못 찾고 빈 스토어를 새로 만들어 일정이 전부 사라진 것처럼 보인다.
            //    (Event는 로컬 전용이라 CloudKit에서 복구되지도 않는다.)
            let config = ModelConfiguration(schema: Schema([Event.self]),
                                            groupContainer: .none,
                                            cloudKitDatabase: .none)
            let container = try ModelContainer(for: Event.self, configurations: config)
            print("✅ [Migration] Using existing database successfully (local-only)")
            return container
        } catch {
            print("⚠️ [Migration] Failed to load existing database: \(error)")
            print("🔄 [Migration] Attempting to recover data...")

            // 2단계: 기존 데이터 복구 시도
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

            // 기존 DB 위치들
            let possibleOldLocations = [
                appSupportURL.appendingPathComponent("default.store"),
                URL.documentsDirectory.appendingPathComponent("ScheduleDensity.store"),
                URL.documentsDirectory.appendingPathComponent("default.store")
            ]

            var recoveredEvents: [Event] = []

            // 기존 DB에서 데이터 읽기 시도
            for oldLocation in possibleOldLocations {
                guard fileManager.fileExists(atPath: oldLocation.path) else { continue }

                print("🔍 [Migration] Found old database at: \(oldLocation)")

                do {
                    // 기존 DB를 읽기 전용으로 열기
                    let oldConfig = ModelConfiguration(
                        schema: Schema([Event.self]),
                        url: oldLocation,
                        cloudKitDatabase: .none
                    )
                    let oldContainer = try ModelContainer(for: Event.self, configurations: oldConfig)
                    let context = ModelContext(oldContainer)

                    let descriptor = FetchDescriptor<Event>()
                    let events = try context.fetch(descriptor)

                    if !events.isEmpty {
                        print("📚 [Migration] Found \(events.count) events in old database")
                        // 데이터 복사 (새 인스턴스 생성)
                        for event in events {
                            let newEvent = Event(
                                title: event.title,
                                startDate: event.startDate,
                                endDate: event.endDate,
                                color: event.color,
                                hoursPerDay: event.hoursPerDay,
                                selectedWeekdays: event.selectedWeekdays,
                                cloudKitRecordName: event.cloudKitRecordName,
                                importance: event.importance,
                                isInfinite: event.isInfinite
                            )
                            recoveredEvents.append(newEvent)
                        }
                        print("✅ [Migration] Recovered \(recoveredEvents.count) events with importance field")
                        break // 성공하면 중단
                    }
                } catch {
                    print("⚠️ [Migration] Could not read from \(oldLocation): \(error)")
                    continue
                }
            }

            // 3단계: 새로운 DB 생성
            do {
                let newConfig = ModelConfiguration(
                    schema: Schema([Event.self]),
                    url: appSupportURL.appendingPathComponent("ScheduleDensity_v2.store"),
                    cloudKitDatabase: .none
                )

                let newContainer = try ModelContainer(for: Event.self, configurations: newConfig)
                print("✅ [Migration] Created new database at: \(newConfig.url)")

                // 복구된 데이터 저장
                if !recoveredEvents.isEmpty {
                    let context = ModelContext(newContainer)
                    for event in recoveredEvents {
                        context.insert(event)
                    }
                    try? context.save()
                    print("💾 [Migration] Successfully migrated \(recoveredEvents.count) events to new database")
                } else {
                    print("ℹ️ [Migration] No events to migrate - starting fresh")
                }

                return newContainer

            } catch {
                print("❌ [Migration] Failed to create new database: \(error)")

                // 4단계: 최후의 수단 - 임시 위치에 새 DB
                do {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("ScheduleDensity_emergency_\(UUID().uuidString).store")

                    let emergencyConfig = ModelConfiguration(
                        schema: Schema([Event.self]),
                        url: tempURL,
                        cloudKitDatabase: .none
                    )

                    let emergencyContainer = try ModelContainer(for: Event.self, configurations: emergencyConfig)
                    print("⚠️ [Migration] Using emergency temporary database")

                    // 복구된 데이터라도 저장
                    if !recoveredEvents.isEmpty {
                        let context = ModelContext(emergencyContainer)
                        for event in recoveredEvents {
                            context.insert(event)
                        }
                        try? context.save()
                        print("💾 [Migration] Saved \(recoveredEvents.count) events to emergency database")
                    }

                    return emergencyContainer

                } catch {
                    // 5단계: 정말 최후 - 인메모리
                    do {
                        let memoryConfig = ModelConfiguration(
                            schema: Schema([Event.self]),
                            isStoredInMemoryOnly: true
                        )
                        let memoryContainer = try ModelContainer(for: Event.self, configurations: memoryConfig)
                        print("❌ [Migration] Using in-memory database (data will not persist)")

                        // 복구된 데이터라도 로드
                        if !recoveredEvents.isEmpty {
                            let context = ModelContext(memoryContainer)
                            for event in recoveredEvents {
                                context.insert(event)
                            }
                            try? context.save()
                            print("💾 [Migration] Loaded \(recoveredEvents.count) events to memory")
                        }

                        return memoryContainer
                    } catch {
                        fatalError("💥 [Migration] Complete failure - cannot create any database: \(error)")
                    }
                }
            }
        }
    }()

    /// 할 일(백로그) 전용 컨테이너 — 맥 '무지개 공방'과 같은 CloudKit 컨테이너를 써서
    /// BacklogItem/BacklogCategory가 기기 간 동기화된다.
    /// Event 스토어(sharedModelContainer)·WeekBlocksStore 미러와는 완전히 분리된 별도 store.
    var todoContainer: ModelContainer = {
        // iOS 샌드박스에는 Application Support 디렉터리가 없을 수 있어 먼저 만들어 둔다.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)

        let schema = Schema([BacklogItem.self, BacklogCategory.self])
        // groupContainer: .none — 위 Event 스토어와 같은 이유. App Group entitlement 때문에
        // 저장 위치가 옮겨가면 기존 store를 못 찾고 CloudKit에서 전부 다시 받아야 한다.
        let cloudConfig = ModelConfiguration(
            "WeekBlocksTodos",
            schema: schema,
            groupContainer: .none,
            cloudKitDatabase: .private("iCloud.com.devkoan.ScheduleDensity")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // iCloud 미로그인 등으로 실패하면 로컬 전용으로라도 동작하게 한다.
            print("⚠️ [Todo] CloudKit 컨테이너 실패, 로컬 전용으로 전환: \(error)")
            let localConfig = ModelConfiguration("WeekBlocksTodos", schema: schema,
                                                 groupContainer: .none, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [memoryConfig])
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                // 할 일이 먼저다 — 매일 여는 화면이고, 무지개는 그 일들이 언제 걸려 있는지 보는 곳이다.
                TodoView()
                    .modelContainer(todoContainer)
                    .tabItem { Label("할 일", systemImage: "checklist") }
                    .tag(AppTab.todo)
                ContentView(viewModel: schedule)
                    .tabItem { Label("무지개", systemImage: "rainbow") }
                    .tag(AppTab.rainbow)
                // 공유 탭은 설정 > 일정 > '공유 탭 표시'로 켤 때만 노출된다.
                if showShareTab {
                    ScheduleShareView()
                        .tabItem { Label("공유", systemImage: "person.2.circle") }
                        .tag(AppTab.share)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
            .leeoSatisfactionCheck(ScheduleDensityAppSpec.self)
            // 화면의 다른 데를 톡 치면 키보드가 내려간다 (→ KeyboardDismiss.swift).
            .task { KeyboardDismissOnTap.install() }
            // 할 일 ↔ 무지개를 잇는 다리에 양쪽 스토어를 넘긴다 (→ TodoEventBridge.swift).
            .task {
                schedule.setModelContext(sharedModelContainer.mainContext)
                TodoEventBridge.shared.attach(schedule: schedule)
                TodoEventBridge.shared.attach(todoContainer: todoContainer)
                TodoEventBridge.shared.attach(eventContainer: sharedModelContainer)
                // 무지개 탭을 한 번도 안 열어도 위젯은 채워져 있어야 한다.
                RainbowWidgetSync.refresh(from: schedule)
            }
            // 다른 앱에서 공유한 할 일 받기. 공유 익스텐션은 SwiftData에 직접 못 쓰고
            // App Group에 쌓아만 두므로, 앱이 켜질 때마다 그 상자를 비운다.
            .task { intakeSharedTodos() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    intakeSharedTodos()
                    // 맥에서 넘어온 변경도 위젯에 반영한다.
                    RainbowWidgetSync.refresh(from: schedule)
                }
            }
            .onOpenURL { url in
                // 홈·잠금 화면 위젯 탭 → 그 위젯이 보여주던 탭 열기.
                guard url.scheme == TodoWidgetBridge.deepLink.scheme else { return }
                switch url.host {
                case TodoWidgetBridge.deepLink.host:    selectedTab = .todo
                case RainbowWidgetBridge.deepLink.host: selectedTab = .rainbow
                default: break
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// 공유로 받아둔 할 일을 실제 줄로 만들고, 생겼으면 '할 일' 탭을 열어 보여준다.
    /// 공유할 때 앱이 뜨지는 않으므로, 다음에 앱을 열었을 때 그 결과가 바로 보이는 게 맞다.
    private func intakeSharedTodos() {
        let added = TodoShareIntake.drain(into: todoContainer.mainContext)
        if added > 0 { selectedTab = .todo }
    }
}
