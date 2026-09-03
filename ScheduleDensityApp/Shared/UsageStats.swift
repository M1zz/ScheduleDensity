//
//  UsageStats.swift
//
//  **내가 이 앱을 어떻게 쓰고 있나.** 네 가지를 센다 —
//  꾸준함, 쪼개기 습관, 완주율, 어디에 시간이 갔나.
//
//  일정 통계(→ StatisticsView.swift)와는 다른 것을 본다. 그쪽은 **적어 둔 일정**이
//  어떻게 생겼는지를 말하고, 여기는 **내가 어떻게 쓰고 있는지**를 말한다.
//
//  ⚠️ 여기서 나오는 것은 전부 **숫자**다. 제목도, 날짜도, 분류 이름조차 밖으로 안 나간다
//     (→ `metrics`). 화면에는 분류 이름이 뜨지만 그건 이 기기 안의 이야기다.
//

import Foundation

struct UsageStats {

    // MARK: 꾸준함
    var streakDays: Int = 0
    var activeDaysLast30: Int = 0
    var daysSinceInstall: Int = 0
    var launchCount: Int = 0

    // MARK: 쪼개기 습관
    /// 최상위 할 일의 수(단계는 안 센다).
    var todoCount: Int = 0
    /// 그중 실제로 단계를 적어 둔 것.
    var splitCount: Int = 0
    /// 쪼갠 것 하나당 평균 단계 수. 안 쪼갠 것은 평균에 안 넣는다 —
    /// 넣으면 "쪼개면 몇 단계로 쪼개는가"가 아니라 그냥 쪼갠 비율이 한 번 더 나온다.
    var averageSteps: Double = 0

    // MARK: 완주율
    var completedRate: Double = 0
    /// 쪼갠 것과 안 쪼갠 것을 갈라 본다. **이 앱이 하려는 말이 여기 있다** —
    /// 쪼갠 쪽이 더 많이 끝난다면 쪼개는 것이 값을 한 것이다.
    var splitCompletedRate: Double?
    var plainCompletedRate: Double?

    // MARK: 어디에 시간이 갔나
    /// 분류별로 적어 둔 시간의 몫. 많은 것부터.
    var hoursByCategory: [CategoryHours] = []
    var totalHours: Double = 0

    struct CategoryHours: Identifiable {
        var id: String { name }
        let name: String
        let hours: Double
        let colorName: String
    }

    /// 쪼갠 것의 비율. 0으로 나누지 않는다.
    var splitRate: Double { todoCount > 0 ? Double(splitCount) / Double(todoCount) : 0 }

    // MARK: - 세기

    /// - Parameter todos: 단계까지 **전부** 넘긴다. 여기서 최상위만 골라 센다.
    static func make(todos: [BacklogItem],
                     categories: [BacklogCategory],
                     engagement: (launchCount: Int, daysSinceInstall: Int),
                     now: Date = Date()) -> UsageStats {

        var stats = UsageStats()

        stats.streakDays = UsageDiary.streak(now)
        stats.activeDaysLast30 = UsageDiary.activeDayCount(inLast: 30, from: now)
        stats.launchCount = engagement.launchCount
        stats.daysSinceInstall = engagement.daysSinceInstall

        let tree = TodoTree(todos)
        let roots = todos.filter { $0.parentToken == nil }
        stats.todoCount = roots.count
        guard !roots.isEmpty else { return stats }

        let split = roots.filter { tree.hasChildren($0) }
        stats.splitCount = split.count
        if !split.isEmpty {
            let steps = split.map { Double(tree.leafCount(of: $0)) }
            stats.averageSteps = steps.reduce(0, +) / Double(split.count)
        }

        stats.completedRate = rate(of: roots)
        // 한쪽이 비면 비율이 아니라 없는 것이다. 0%로 그리면 "다 실패했다"로 읽힌다.
        if !split.isEmpty { stats.splitCompletedRate = rate(of: split) }
        let plain = roots.filter { !tree.hasChildren($0) }
        if !plain.isEmpty { stats.plainCompletedRate = rate(of: plain) }

        var byCategory: [String: Double] = [:]
        for root in roots {
            let key = root.categoryID ?? ""
            byCategory[key, default: 0] += tree.totalHours(of: root)
        }
        let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.uuid, $0) })
        stats.hoursByCategory = byCategory
            .filter { $0.value > 0 }
            .map { id, hours in
                CategoryHours(name: names[id]?.name ?? "미분류",
                              hours: hours,
                              colorName: names[id]?.colorName ?? "gray")
            }
            .sorted { $0.hours > $1.hours }
        stats.totalHours = stats.hoursByCategory.reduce(0) { $0 + $1.hours }

        return stats
    }

    private static func rate(of items: [BacklogItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isCompleted).count) / Double(items.count)
    }

    // MARK: - 밖으로 나가는 것

    /// 허브로 보낼 값. **숫자만 있고 글자는 하나도 없다.**
    ///
    /// 분류 이름은 안 보낸다 — 사람이 직접 지은 이름이라 그 자체가 사생활이다.
    /// 분류가 몇 개인지, 가장 큰 분류가 전체의 몇 %인지까지만 보낸다.
    var metrics: [String: Double] {
        var m: [String: Double] = [
            "streakDays": Double(streakDays),
            "activeDays30": Double(activeDaysLast30),
            "todos": Double(todoCount),
            "splitTodos": Double(splitCount),
            "avgSteps": (averageSteps * 100).rounded() / 100,
            "completedRate": (completedRate * 100).rounded() / 100,
            "categories": Double(hoursByCategory.count),
            "totalHours": totalHours.rounded(),
        ]
        if let r = splitCompletedRate { m["splitCompletedRate"] = (r * 100).rounded() / 100 }
        if let r = plainCompletedRate { m["plainCompletedRate"] = (r * 100).rounded() / 100 }
        if let top = hoursByCategory.first, totalHours > 0 {
            m["topCategoryShare"] = ((top.hours / totalHours) * 100).rounded() / 100
        }
        return m
    }
}
