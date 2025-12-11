//
//  ScheduleDensityApp.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI
import SwiftData

@main
struct ScheduleDensityApp: App {
    var sharedModelContainer: ModelContainer = {
        // 1단계: 기존 데이터베이스 로드 시도 (하위 호환성)
        do {
            let container = try ModelContainer(for: Event.self)
            print("✅ [Migration] Using existing database successfully")
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
                    try context.save()
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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
