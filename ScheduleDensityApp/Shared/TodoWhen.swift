//
//  TodoWhen.swift
//  ScheduleDensityApp
//
//  "이건 오늘 일인가, 이번 주 일인가, 아직 적어만 둔 것인가."
//  이 질문에 답하는 것은 **시작일과 끝나는 날, 그 하나뿐**이다.
//
//  예전에는 답이 세 군데 흩어져 있었다. 오늘인지는 맥 계획 블록(PlanBlock)이,
//  이번 주 것인지는 할 일의 주차(weekStartDate)가, 언제까지인지는 무지개에 그은 줄이
//  따로 들고 있었다. 그래서 사람은 목록에서 '오늘'을 누르고 '이번 주로'를 또 누르며
//  같은 것을 두 번 말해야 했고, 셋이 어긋나면 어느 것이 맞는지 화면이 답하지 못했다.
//
//  이제 사람이 정하는 것은 상세의 **기간 하나**이고, 나머지는 전부 여기서 판정한다.
//  아무것도 안 정한 줄은 백로그다 — 갓 적은 줄은 언제나 여기서 시작한다.
//

import Foundation

/// 기간 하나로 답하는 '언제의 일인가'.
///
/// 급한 순서대로 적혀 있다(`rank`). 목록의 줄 순서가 이 순서다.
enum TodoWhen: Int, Comparable {
    /// 끝나는 날이 지났다. 가장 급하다 — 이미 늦은 일이라서.
    case overdue = 0
    /// 오늘까지 하는 일. 오늘 안에 닫아야 한다.
    case today = 1
    /// 이번 주 안에 끝나는 일.
    case thisWeek = 2
    /// 다음 주 뒤에 끝난다. 지금 급한 일은 아니다.
    case later = 3
    /// 날짜를 안 정했다. 적어 두기만 한 일.
    case backlog = 4

    static func < (lhs: TodoWhen, rhs: TodoWhen) -> Bool { lhs.rawValue < rhs.rawValue }

    /// 기간을 보고 판정한다. 기간이 없으면 백로그.
    ///
    /// ⚠️ 판정하는 것은 **끝나는 날**이다. 시작일이 아니다.
    ///    무지개에 그은 줄은 "오늘부터 그 날까지 나를 붙잡고 있다"는 뜻이라 시작일이
    ///    거의 언제나 오늘이다 (→ `TodoEventBridge.drawRainbow`). 그래서 '기간이 오늘을
    ///    덮으면 오늘'로 재면 마감이 한 달 뒤인 일까지 전부 오늘 할 일이 되고,
    ///    '오늘'이라는 말이 아무것도 안 가른다.
    ///    시작일이 하는 일은 따로 있다 — 무지개에서 **얼마나 길게 매여 있나**를 그린다.
    ///
    /// - Parameters:
    ///   - period: 무지개에 그어 둔 시작일·끝나는 날. nil이면 안 그은 것.
    ///   - now: 지금. 날짜만 본다(시:분은 버린다).
    ///   - weekStart: 이번 주 월요일 00:00.
    static func of(_ period: (start: Date, end: Date)?,
                   now: Date = Date(),
                   weekStart: Date = .currentWeekStart) -> TodoWhen
    {
        guard let period else { return .backlog }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let end = cal.startOfDay(for: period.end)

        if end < today { return .overdue }
        if end == today { return .today }

        let weekEnd = cal.date(byAdding: .day, value: 6, to: cal.startOfDay(for: weekStart)) ?? weekStart
        return end <= weekEnd ? .thisWeek : .later
    }

    /// 줄에 붙는 말. 백로그와 '이번 주'는 아무 말도 안 붙는다 —
    /// 목록에 있다는 것이 이미 그 뜻이라, 배지를 달면 모든 줄에 배지가 생긴다.
    var badge: String? {
        switch self {
        case .overdue: return "밀림"
        case .today: return "오늘"
        case .thisWeek, .later, .backlog: return nil
        }
    }
}
