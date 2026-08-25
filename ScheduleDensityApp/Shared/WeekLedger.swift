//
//  WeekLedger.swift
//
//  일이 아닌 두 가지를 적는 주간 장부.
//
//  할 일 목록은 '성과 칸'이다. 그 칸에 넣으면 안 되는데 그렇다고 사라져서도 안 되는
//  두 가지가 있어서, 칸을 따로 냈다.
//
//  1) **회수한 시간** — 아낀 시간이 실제로 내게 돌아왔는가.
//     조각으로 돌아온 것과 블록으로 돌아온 것을 **따로 센다.** 합치면 정직하지 않다:
//     5분 열 번은 50분이 아니라 다른 단위다 (Schulte 2014 · Whillans 2020).
//     그리고 종료 시간이 시계로 고정된 하루라면 절약분은 애초에 시간으로 회수되지 않고
//     여유(부하 감소)로만 회수된다 — 그때 이 칸이 0인 것은 실패가 아니라 사실이다.
//
//  2) **회복** — 짧은 휴식.
//     마이크로브레이크 메타분석(Albulescu et al. 2022, PLOS ONE, 22개 표본 N=2,335)은
//     짧은 휴식이 활력(d=.36)과 피로(d=.35)에는 효과가 있지만 **성과에는 유의한 효과가
//     없다**(d=.16, p=.116)고 말한다. 그러니 휴식을 성과 칸에 적으면 언제나 손해로 보인다.
//     회복은 회복 칸에 적는다. 여기 쌓이는 숫자는 진행률에 절대 섞이지 않는다.
//
//  큐잉 관점에서 2번은 사치가 아니다. 가동률이 100%에 수렴하면 대기 시간은 사실상
//  무한대가 되고, 예상 못한 일 하나에 전체가 무너진다 (DeMarco, *Slack*).
//
//  ⚠️ 이 장부는 **기기 안에만** 있다 (App Group UserDefaults). CloudKit에 올리지 않는다 —
//     스키마를 건드리지 않으므로 맥앱·기존 사용자 데이터와 무관하고, 배포 전 deploy도 없다.
//     대신 기기 간에 따라다니지 않는다는 뜻이기도 하다.
//

import Foundation

/// 아낀 시간이 어떤 모양으로 돌아왔는가.
enum ReclaimKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 사이사이 흩어져 돌아온 것. 5~15분.
    case fragment
    /// 한 덩어리로 돌아온 것. 이것만 새 일을 시작할 수 있다.
    case block

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fragment: return "조각으로"
        case .block:    return "블록으로"
        }
    }

    var symbol: String {
        switch self {
        case .fragment: return "circle.grid.3x3.fill"
        case .block:    return "rectangle.fill"
        }
    }

    /// 이 모양으로 돌아온 시간에 무엇을 할 수 있는가.
    var note: String {
        switch self {
        case .fragment:
            return "새 일을 시작하기엔 전환 비용에 다 먹힙니다. 다음 일의 계획을 적어 두는 데 쓰세요."
        case .block:
            return "여기서만 새 일이 시작됩니다. 미리 정해 둔 블록 대기열의 맨 위를 집으세요."
        }
    }

    /// 한 번에 적어 넣을 수 있는 크기들 (분).
    var steps: [Int] {
        switch self {
        case .fragment: return [5, 10, 15]
        case .block:    return [30, 60, 90]
        }
    }
}

/// 한 주치 장부.
struct WeekLedgerEntry: Codable, Equatable {
    /// 조각으로 회수된 분.
    var fragmentMinutes: Int = 0
    /// 블록으로 회수된 분.
    var blockMinutes: Int = 0
    /// 숨 돌린 횟수.
    var breakCount: Int = 0
    /// 숨 돌린 분.
    var breakMinutes: Int = 0

    var isEmpty: Bool {
        fragmentMinutes == 0 && blockMinutes == 0 && breakCount == 0 && breakMinutes == 0
    }

    func minutes(of kind: ReclaimKind) -> Int {
        switch kind {
        case .fragment: return fragmentMinutes
        case .block:    return blockMinutes
        }
    }
}

enum WeekLedger {
    /// 위젯·익스텐션도 언젠가 읽을 수 있게 App Group에 둔다.
    static let appGroupID = "group.com.devkoan.ScheduleDensity"

    private static var store: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// 주의 시작일(월요일 00:00)로 만든 키. 로케일·시간대에 흔들리지 않게 직접 조립한다.
    private static func key(_ weekStart: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let c = cal.dateComponents([.year, .month, .day], from: weekStart)
        return String(format: "weekLedger.%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func entry(for weekStart: Date) -> WeekLedgerEntry {
        guard let data = store.data(forKey: key(weekStart)),
              let value = try? JSONDecoder().decode(WeekLedgerEntry.self, from: data)
        else { return WeekLedgerEntry() }
        return value
    }

    private static func update(_ weekStart: Date, _ body: (inout WeekLedgerEntry) -> Void) {
        var value = entry(for: weekStart)
        body(&value)
        guard let data = try? JSONEncoder().encode(value) else { return }
        store.set(data, forKey: key(weekStart))
    }

    /// 회수한 시간을 적는다. **조각과 블록은 각자의 칸에만 쌓인다.**
    static func reclaim(_ minutes: Int, as kind: ReclaimKind, weekStart: Date) {
        guard minutes > 0 else { return }
        update(weekStart) { value in
            switch kind {
            case .fragment: value.fragmentMinutes += minutes
            case .block:    value.blockMinutes += minutes
            }
        }
    }

    /// 숨 돌린 것을 적는다. 성과 칸이 아니다.
    static func tookBreak(minutes: Int, weekStart: Date) {
        update(weekStart) { value in
            value.breakCount += 1
            value.breakMinutes += max(0, minutes)
        }
    }

    static func clear(weekStart: Date) {
        store.removeObject(forKey: key(weekStart))
    }
}
