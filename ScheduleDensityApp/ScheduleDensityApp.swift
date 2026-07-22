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
        Task { await FamilyShareStore.shared.accept(cloudKitShareMetadata) }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // 앱이 꺼진 상태에서 초대 링크로 실행된 경우.
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Task { await FamilyShareStore.shared.accept(metadata) }
        }
    }
}

@main
struct ScheduleDensityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        LeeoEngagement.shared.registerLaunch()
    }

    var sharedModelContainer: ModelContainer = {
        // 1단계: 기존 데이터베이스 로드 시도 (하위 호환성)
        // ⚠️ cloudKitDatabase: .none 을 명시한다. 앱에 CloudKit 컨테이너(WeekBlocks 연동용)가
        //    추가되면 기본값 .automatic 이 Event 스토어까지 CloudKit을 켜려다 실패한다
        //    (Event는 기본값 없는 비옵셔널 속성 보유 → CloudKit 비호환). Event는 로컬 전용 유지.
        do {
            let config = ModelConfiguration(schema: Schema([Event.self]), cloudKitDatabase: .none)
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
        let cloudConfig = ModelConfiguration(
            "WeekBlocksTodos",
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.devkoan.ScheduleDensity")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // iCloud 미로그인 등으로 실패하면 로컬 전용으로라도 동작하게 한다.
            print("⚠️ [Todo] CloudKit 컨테이너 실패, 로컬 전용으로 전환: \(error)")
            let localConfig = ModelConfiguration("WeekBlocksTodos", schema: schema, cloudKitDatabase: .none)
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
            TabView {
                // 원래 앱(일정 밀도)이 기본 화면, 할 일(내/가족)은 추가 탭.
                ContentView()
                    .tabItem { Label("무지개", systemImage: "rainbow") }
                TodoView()
                    .modelContainer(todoContainer)
                    .tabItem { Label("할 일", systemImage: "checklist") }
            }
            .leeoSatisfactionCheck(ScheduleDensityAppSpec.self)
        }
        .modelContainer(sharedModelContainer)
    }
}
