//
//  TodoArchive.swift
//  ScheduleDensityApp
//
//  **할 일을 스토어 밖에 한 벌 더 떠 둔다.**
//
//  왜 필요하냐면 — 오늘까지 이 앱의 할 일은 **이 기기에만 있는 유일본**이었다.
//  맥과의 동기화가 막혀 있었으므로 클라우드에 사본이 없다. 그런데 그 유일본이
//  사는 곳(SwiftData 스토어)은 마이그레이션이 어긋나거나 CloudKit이 미러를
//  다시 받으라고 판단하면 **통째로 비워질 수 있는** 자리다.
//
//  그래서 켤 때마다 JSON으로 한 벌 뜬다. 스토어가 빈 채로 열렸는데 떠 둔 것이
//  있으면 되돌린다. 맥 '무지개 공방'의 LegacyTodoArchive와 같은 생각이고,
//  이쪽에는 그게 없어서 비대칭이었다.
//
//  ⚠️ **되돌리기는 '스토어가 비었을 때'만 한다.** 한 줄이라도 남아 있으면 손대지
//     않는다. 오래된 벌을 위에 덮으면 사용자가 지운 할 일이 되살아나고, 그건
//     데이터가 없어지는 것만큼 나쁘다. 클라우드가 내려주는 중일 수도 있어
//     '적으니까 채운다' 같은 판단도 하지 않는다.
//

import Foundation
import SwiftData

enum TodoArchive {

    // MARK: 떠 두는 모양 (모델과 따로 둔다 — 모델이 바뀌어도 옛 파일을 읽을 수 있게)

    struct Snapshot: Codable {
        var takenAt: Date
        var items: [Item]
        var categories: [Category]
    }

    struct Item: Codable {
        var title: String
        var durationHours: Double
        var sortIndex: Int
        var createdAt: Date
        var dragToken: String
        var categoryID: String?
        var weekStartDate: Date
        var isCompleted: Bool
        var completedAt: Date?
        var parentToken: String?
        var labelRaw: String?
    }

    struct Category: Codable {
        var uuid: String
        var name: String
        var colorName: String
        var iconName: String
        var sortIndex: Int
        var createdAt: Date
    }

    // MARK: 자리

    private static var fileURL: URL? {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "todo-archive.json")
    }

    static var exists: Bool {
        guard let url = fileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: 뜨기

    /// 지금 스토어에 있는 할 일을 통째로 떠 둔다.
    ///
    /// ⚠️ **빈 목록으로는 덮어쓰지 않는다.** 스토어가 잠깐 비어 보이는 순간에 떠 버리면
    ///    안전망이 스스로 비워진다 — 그게 제일 나쁜 실패다.
    static func write(from context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<BacklogItem>())) ?? []
        guard !items.isEmpty else { return }
        let categories = (try? context.fetch(FetchDescriptor<BacklogCategory>())) ?? []

        let snapshot = Snapshot(
            takenAt: Date(),
            items: items.map {
                Item(title: $0.title, durationHours: $0.durationHours, sortIndex: $0.sortIndex,
                     createdAt: $0.createdAt, dragToken: $0.dragToken, categoryID: $0.categoryID,
                     weekStartDate: $0.weekStartDate, isCompleted: $0.isCompleted,
                     completedAt: $0.completedAt, parentToken: $0.parentToken, labelRaw: $0.labelRaw)
            },
            categories: categories.map {
                Category(uuid: $0.uuid, name: $0.name, colorName: $0.colorName,
                         iconName: $0.iconName, sortIndex: $0.sortIndex, createdAt: $0.createdAt)
            })

        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        print("🧷 [Archive] 할 일 \(snapshot.items.count)개 떠 둠")
    }

    static func load() -> Snapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    // MARK: 되돌리기

    /// 스토어가 **완전히 빈 채로** 열렸고 떠 둔 것이 있으면 되돌린다.
    ///
    /// 클라우드가 내려주는 중일 수 있으므로 곧바로 판단하지 않는다. 잠깐 기다렸다가
    /// 그때도 비어 있으면 그때 채운다 — 내려받는 중에 채우면 같은 할 일이 둘이 된다.
    @MainActor
    static func restoreIfStoreIsEmpty(_ context: ModelContext,
                                      after seconds: UInt64 = 20) async {
        guard exists else { return }
        let before = (try? context.fetchCount(FetchDescriptor<BacklogItem>())) ?? 0
        guard before == 0 else { return }

        try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)

        // 기다리는 사이에 내려왔으면 손대지 않는다.
        let now = (try? context.fetchCount(FetchDescriptor<BacklogItem>())) ?? 0
        guard now == 0, let snapshot = load(), !snapshot.items.isEmpty else { return }

        print("🚑 [Archive] 스토어가 비어 있다 — 떠 둔 \(snapshot.items.count)개를 되돌린다")

        var byUUID: [String: BacklogCategory] = [:]
        for c in snapshot.categories {
            let category = BacklogCategory(name: c.name, colorName: c.colorName,
                                           iconName: c.iconName, sortIndex: c.sortIndex)
            category.uuid = c.uuid
            category.createdAt = c.createdAt
            context.insert(category)
            byUUID[c.uuid] = category
        }

        for i in snapshot.items {
            let item = BacklogItem(title: i.title, durationHours: i.durationHours,
                                   sortIndex: i.sortIndex, categoryID: i.categoryID,
                                   weekStartDate: i.weekStartDate)
            item.dragToken = i.dragToken
            item.createdAt = i.createdAt
            item.isCompleted = i.isCompleted
            item.completedAt = i.completedAt
            item.parentToken = i.parentToken
            item.labelRaw = i.labelRaw
            context.insert(item)
        }
        try? context.save()
    }
}
