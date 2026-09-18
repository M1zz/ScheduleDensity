//
//  ScheduleClock.swift
//  ScheduleDensityApp
//
//  "지금 무엇을 하고 있고, 거기 얼마 남았는가."
//
//  아무 버튼도 누르지 않아도 답이 나와야 한다. 수면이 23:00–07:00으로 적혀 있고
//  지금이 23:29라면, 타이머는 이미 7시간 31분을 세고 있는 중이어야 한다 —
//  타이머를 켠 시각이 아니라 **일정에 적힌 시각**이 기준이다.
//
//  그래서 이 파일은 시간을 재지 않는다. 이미 그려져 있는 하루(→ DayTimelineLayout)를
//  그대로 읽어, 지금이 어느 조각 안인지 답할 뿐이다. 하루 화면에 보이는 것과 어긋날 수 없다.
//
//  ⚠️ 맥앱 '무지개 공방'의 같은 이름 파일과 **답이 같아야 한다.** 겹친 것 중 가장 짧은 것을
//     고르는 규칙까지 같다 — 09:00–18:00 회사 안의 13:00 식사라면 지금 하는 일은 식사다.
//

import Foundation
import SwiftUI

/// 하루에 그려진 한 조각을 **절대 시각**으로 옮긴 것.
/// 자정을 넘기는 수면 때문에 0–24 소수 시간으로는 "지금 그 안인가"를 물을 수 없다.
struct ScheduleSlot: Identifiable, Equatable {
    /// 타이머가 쓰는 열쇠와 같다 (→ TaskTimer). 같은 일을 두 자리에서 같은 이름으로 부른다.
    let id: String
    let title: String
    let iconName: String
    /// 알약·고리 색(hex). nil이면 앱 기본색.
    let colorHex: String?
    let start: Date
    let end: Date
    /// 시간이 유연한 것(끼니 등) — 그 자리는 앱이 임의로 놓은 것이라 단정을 조금 낮춘다.
    let isFlexible: Bool

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var hours: Double { duration / 3600 }

    func contains(_ date: Date) -> Bool { date >= start && date < end }
    func remaining(at date: Date) -> TimeInterval { end.timeIntervalSince(date) }
    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / duration))
    }
}

enum ScheduleClock {

    /// 지금을 둘러싼 사흘(어제·오늘·내일)의 조각들.
    ///
    /// **어제까지 보는 이유**: 수면 23:00+8h는 어제 줄에서 시작해 오늘 07:00에 끝난다.
    /// 오늘만 보면 새벽 두 시에 "지금 아무것도 없다"고 답하게 된다.
    /// **내일까지 보는 이유**: '다음 일정'은 자정을 넘어 있을 수 있다.
    static func slots(around now: Date = Date()) -> [ScheduleSlot] {
        let cal = Calendar.current
        return (-1...1).flatMap { offset -> [ScheduleSlot] in
            guard let date = cal.date(byAdding: .day, value: offset, to: now) else { return [] }
            return slots(on: date)
        }
    }

    /// 지금 하고 있는 것. 겹쳐 있으면 **가장 짧은 것**을 고른다 —
    /// 09:00–18:00 회사 안의 13:00 식사라면, 지금 하고 있는 일은 식사다.
    static func current(_ slots: [ScheduleSlot], at now: Date = Date()) -> ScheduleSlot? {
        slots.filter { $0.contains(now) }
            .min { $0.duration < $1.duration }
    }

    /// 다음에 올 것. 지금 하는 것이 없을 때 "그럼 언제부터"에 답한다.
    static func next(_ slots: [ScheduleSlot], at now: Date = Date()) -> ScheduleSlot? {
        slots.filter { $0.start > now }.min { $0.start < $1.start }
    }

    /// 그 날 하루에 그려지는 조각들. 하루 화면과 **같은 계산**을 쓴다 (→ DayTimelineView.load).
    ///
    /// 자정을 넘기는 잠은 하루 화면에서 [23,24]·[0,7] 두 조각으로 그려지는데, 여기서는
    /// 그 날짜의 0시를 기준으로 절대 시각을 만들 뿐이라 두 조각 그대로 온다.
    /// 이어 붙이지 않는다 — '지금 그 안인가'는 어느 조각으로 물어도 답이 같다.
    static func slots(on date: Date) -> [ScheduleSlot] {
        let input = WeekBlocksStore.shared.dayInput(for: date)
        guard input.isAvailable else { return [] }

        let result = TimelineLayout.segments(
            routines: input.fixedRoutines,
            blocks: input.blocks,
            quota: input.quotaRoutines,
            routineStartOverride: input.routineStartOverride,
            quotaPlacement: input.quotaPlacement,
            quotaHidden: input.quotaHidden)

        // 알약 속 그림과 색은 루틴이 고른 것을 쓴다. 조각은 이름만 들고 있으므로 이름으로 찾는다.
        var icons: [String: String] = [:]
        var colors: [String: String] = [:]
        for r in input.fixedRoutines + input.quotaRoutines {
            icons[r.name] = r.iconName
            colors[r.name] = paletteHex(r.colorName)
        }

        let midnight = Calendar.current.startOfDay(for: date)
        let dayKey = Self.dayKey(midnight)

        return result.segments.compactMap { seg -> ScheduleSlot? in
            // 루틴 안에 얹힌 일정은 그 루틴과 같은 시각을 두 번 세는 셈이라 뺀다.
            guard !seg.isNested, seg.hours > 0 else { return nil }
            let isRoutineLike = seg.kind == .routine || seg.kind == .quota
            return ScheduleSlot(
                // 같은 일이 여러 날 서 있으므로 날짜까지 넣어야 그 날의 그것을 가리킨다.
                id: "\(dayKey):\(seg.id)",
                title: seg.title,
                iconName: isRoutineLike ? (icons[seg.title] ?? "timer") : "square.stack.3d.up",
                colorHex: isRoutineLike ? colors[seg.title] ?? nil : nil,
                start: midnight.addingTimeInterval(seg.start * 3600),
                end: midnight.addingTimeInterval(seg.end * 3600),
                isFlexible: seg.isFlexible)
        }
    }

    /// "2026-09-18". 같은 이름의 조각을 날짜로 가른다.
    private static func dayKey(_ midnight: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: midnight)
    }
}
