//
//  PlanBlock+Mac.swift
//  무지개 공방
//
//  맥 화면만 쓰는 PlanBlock 도우미. 모델과 두 앱이 함께 읽는 규칙(종일 표시 · 알약 아이콘)은
//  Shared/PlanBlock.swift 에 있다.
//

import Foundation
import SwiftData

// MARK: - 종일 (바꾸기)

extension PlanBlock {
    /// 종일을 배경 ↔ 그날 할 일로 바꾼다.
    func setBackground(_ on: Bool) {
        guard isAllDay else { return }
        startHour = on ? Self.backgroundHour : Self.allDayHour
    }

    /// **해야 할 일인가** — 무지개 칸 · 회고 · '끝냈나요?'가 세는 것. 루틴 이름의 블록과 배경 종일은 아니다.
    func isTodo(_ routineNames: Set<String>) -> Bool {
        !isRoutineKind(routineNames) && !isBackground
    }

    /// 시각이 정해진 블록은 시각을, 종일은 '종일'을, 아니면 시간대를.
    var whenLabel: String {
        if isAllDay { return String(localized: "종일") }
        return startHour >= 0 ? formatHour(startHour) : timeBand.shortLabel
    }

    /// 종일로 만든다 — 시각은 비우고 길이는 0. 이미 배경 종일이면 배경 그대로.
    func makeAllDay() {
        if isBackground { durationHours = 0; return }
        startHour = Self.allDayHour
        durationHours = 0
    }

    /// 종일 블록을 하루 어느 시각에 세울 때. 길이가 0이면 자 위에 설 폭이 없으니 한 시간을 준다.
    func leaveAllDay(defaultHours: Double = 1) {
        guard isAllDay else { return }
        startHour = -1
        if durationHours <= 0 { durationHours = defaultHours }
    }
}

// MARK: - 끌어 옮기기

extension PlanBlock {
    /// 요일 칸·시간 자가 함께 쓰는 드래그 식별자.
    /// 두 화면이 같은 규칙으로 만들고 읽어야 어디서 집어 어디에 놓든 같은 블록에 닿는다.
    var dragToken: String { "block:" + String(describing: persistentModelID) }

    /// 드래그 토큰이 가리키는 블록. 블록 토큰이 아니거나 찾지 못하면 nil.
    static func matching(dragToken token: String, in blocks: [PlanBlock]) -> PlanBlock? {
        guard token.hasPrefix("block:") else { return nil }
        return blocks.first { $0.dragToken == token }
    }
}


// MARK: - 점검하는 줄과 아닌 줄

extension PlanBlock {
    /// **루틴에서 온 줄인가.**
    ///
    /// 루틴은 '했는지'를 묻지 않는다. 수면·끼니·출근은 달성하는 것이 아니라 지켜지는 것이고,
    /// 그것까지 체크 줄에 세우면 정작 돌아봐야 할 것이 그 사이에 묻힌다.
    ///
    /// 제목이 루틴 이름과 같은 것만 루틴으로 본다 — 루틴을 요일에 끌어 올리면 그 **이름 그대로**
    /// 계획 블록이 된다 (→ ContentView.dropBacklogItem의 `routine:` 갈래).
    ///
    /// ⚠️ `withinRoutine`('기존 루틴 시간 안에서 진행')은 보지 않는다. 그 표시는 **시간을 새로 안
    ///    잡아먹는다**는 뜻일 뿐, 회의처럼 루틴 시간 안에서 하는 일도 했는지는 찍어야 한다.
    ///
    /// ⚠️ 모델에 표시를 더하지 않고 **이름으로 가린다.** 필드를 늘리면 같은 CloudKit 그릇을 쓰는
    ///    아이폰 '욕망의 무지개'까지 스키마가 걸린다. 이름이 겹치는 일은 드물고, 겹쳐도 잃는 것은
    ///    '점검 줄에서 빠진다'뿐이다.
    func isRoutineKind(_ routineNames: Set<String>) -> Bool {
        routineNames.contains(title)
    }

    /// 지나간 날인데 아직 안 찍은 줄인가. 오지 않은 날은 세지 않는다 — 나무랄 수 없다.
    /// 같은 **보이는 주** 안에서 요일만 옮긴다.
    /// 일요일 시작 화면의 일요일은 앞 ISO 주에 적혀 있어서, 그 칸을 오가면 요일과 함께 주도 바뀐다
    /// (→ WeekStartSetting). 요일만 바꾸면 한 주 뒤의 일요일로 사라진다.
    func move(to newDay: DayOfWeek, sundayFirst: Bool = WeekStartSetting.sundayFirst) {
        guard newDay != day else { return }
        let shown = DayOfWeek.shownWeek(of: day, storedWeek: weekStartDate, sundayFirst: sundayFirst)
        day = newDay
        weekStartDate = DayOfWeek.storedWeek(of: newDay, shownWeek: shown, sundayFirst: sundayFirst)
    }

    ///
    /// **오늘도 센다 — 적힌 끝 시각이 지났으면.** 09:30–11:00 인터뷰를 12시까지 안 찍었으면 이미 지나간 줄이다.
    /// 바로 찍으라고 다그치지는 않지만, 끝났는지는 물어야 한다 (→ OverdueAskBadge).
    /// 시각이 없는 것(시간대 · 종일)은 그날이 지나야 센다.
    /// **지금 진행 중인가.** 그날 적힌 시각 안이고 아직 안 찍었다. 저장하지 않는다 — 시계가 정한다.
    /// 끝냈다고 찍는 것은 사람의 몫이라, 찍으면(달성·부분·건너뜀) 진행 중에서 빠진다.
    /// 시각이 없는 것(시간대 · 종일)은 언제 시작하는지 모르므로 세지 않는다.
    /// - Returns: 진행 중이면 그 끝 시각, 아니면 nil.
    func inProgressEnd(on date: Date, now: Date = Date()) -> Date? {
        guard reviewStatus == nil, let end = scheduledEnd(on: date) else { return nil }
        let start = end.addingTimeInterval(-durationHours * 3600)
        // 끝 시각이 지나도 '아직 하는 중'이라고 했으면 진행 중이다. 그날 안에서만.
        if now >= end, StillGoing.contains(self), Calendar.current.isDate(now, inSameDayAs: date) { return end }
        return now >= start && now < end ? end : nil
    }

    /// 그날 적힌 끝 시각. 시각이 없는 것(시간대 · 종일)은 nil.
    func scheduledEnd(on date: Date) -> Date? {
        guard startHour >= 0, !isAllDay, durationHours > 0 else { return nil }
        return Calendar.current.startOfDay(for: date).addingTimeInterval((startHour + durationHours) * 3600)
    }

    func isUnreviewedPast(weekStart: Date, routineNames: Set<String>, now: Date = Date()) -> Bool {
        guard reviewStatus == nil, isTodo(routineNames) else { return false }
        let cal = Calendar(identifier: .iso8601)
        guard let d = cal.date(byAdding: .day, value: day.rawValue, to: weekStart) else { return false }
        let dayStart = cal.startOfDay(for: d)
        if dayStart < cal.startOfDay(for: now) { return true }
        guard cal.isDate(dayStart, inSameDayAs: now), startHour >= 0, !isAllDay else { return false }
        // 오늘 '아직 하는 중'이라고 답한 것은 묻지 않는다 — 끝나면 사람이 찍는다 (→ StillGoing).
        // 그날이 지나면 다시 묻는다.
        if StillGoing.contains(self) { return false }
        return dayStart.addingTimeInterval((startHour + durationHours) * 3600) <= now
    }
}

// MARK: - 알약 아이콘 (새로 뽑기)

extension PlanBlock {
    /// 지금 것과 다른 아이콘을 새로 뽑아 적는다.
    func shuffleSymbol() {
        let current = symbol
        iconName = Self.symbolChoices.filter { $0 != current }.randomElement() ?? current
    }
}


// MARK: - 아직 하는 중

/// **끝 시각이 지났지만 아직 하는 중**이라고 답한 블록들. '끝냈나요?'를 다시 묻지 않고 진행 중으로 둔다.
///
/// ⚠️ 기기에만 남는다 (→ TaskTimer와 같은 까닭: CloudKit 스키마를 건드리지 않는다).
///    열쇠는 `dragToken`이 아니라 주·요일·시각·제목이다 — persistentModelID 글자는 앱을 다시 켜면 달라질 수 있다.
///    이틀 지난 것은 저절로 지운다.
enum StillGoing {
    static let storageKey = "stillGoing.blocks"

    private static func key(_ b: PlanBlock) -> String {
        "\(Int(b.weekStartDate.timeIntervalSince1970))|\(b.day.rawValue)|\(b.startHour)|\(b.title)"
    }

    /// 열쇠 → 답한 시각.
    private static func load() -> [String: Double] {
        guard let data = UserDefaults.standard.string(forKey: storageKey)?.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return map
    }

    private static func save(_ map: [String: Double]) {
        let fresh = map.filter { Date().timeIntervalSince1970 - $0.value < 2 * 86_400 }
        let data = (try? JSONEncoder().encode(fresh)) ?? Data()
        UserDefaults.standard.set(String(data: data, encoding: .utf8) ?? "{}", forKey: storageKey)
    }

    static func contains(_ b: PlanBlock) -> Bool { load()[key(b)] != nil }

    static func mark(_ b: PlanBlock) {
        var map = load()
        map[key(b)] = Date().timeIntervalSince1970
        save(map)
    }

    static func clear(_ b: PlanBlock) {
        var map = load()
        guard map.removeValue(forKey: key(b)) != nil else { return }
        save(map)
    }
}
