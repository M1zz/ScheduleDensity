//
//  DayTimelineLayout.swift
//  ScheduleDensityApp
//
//  하루(0~24시)에 무엇이 언제 놓이는지를 정하는 순수 계산.
//
//  ⚠️ 맥앱 '무지개 공방'의 `DayTimelineView.swift` 안 `TimelineLayout`을 **그대로 옮긴 것**이다.
//     두 앱이 같은 CloudKit 데이터를 읽으므로, 배치 규칙이 다르면 같은 하루가 두 모양으로 보인다.
//     한쪽을 고치면 다른 쪽도 반드시 같이 고칠 것.
//
//  규칙 요약 (맥과 동일):
//   1. 고정 루틴 — 정해진 시각 그대로. 자정을 넘기면 [s,24] / [0,e-24]로 나눠 그린다. 이게 하루의 뼈대다.
//   2. 시각이 지정된 계획 블록 — 그 자리에 그대로 (겹쳐도 둔다).
//   3. 시각 미지정 계획 블록 — 시간대 시작(아침 6·오후 12·저녁 18·심야 23)을 원하는 지점으로 삼아,
//      루틴이 차지하고 남은 빈 구간 중 통째로 들어갈 가장 가까운 자리에 넣고 그 자리를 소모한다.
//   4. 주간 쿼터(식사 등) — 활동 구간 7.5~19.5에 회차 수만큼 균등 분산. 겹침 허용, 자유 시간을 깎지 않는다.
//   5. 루틴 안 일정 — 루틴 위에 겹쳐(인셋). 미지정이면 9시.
//
//  iOS가 하나 더 얹는 것: 무지개 일정(Event)은 시작 시각이 없다. 3번과 같은 방식으로
//  낮 한가운데를 원하는 지점 삼아 남은 자리에 넣되, 시각이 짐작이라는 뜻으로 '유연'하게 그린다.
//

import Foundation
import SwiftUI

/// 타임라인에 실제로 그릴 시간 범위. 기본은 하루 전체(0–24).
struct HourWindow: Equatable {
    var start: Double = 0
    var end: Double = 24

    static let full = HourWindow()

    var span: Double { max(1, end - start) }
    var isFullDay: Bool { start <= 0 && end >= 24 }

    /// 시각 → 축 위 위치 비율(0...1).
    func fraction(_ hour: Double) -> Double {
        (hour - start) / span
    }

    /// 창 밖으로 나간 부분을 잘라낸다. 완전히 벗어나면 nil.
    func clamp(_ s: Double, _ e: Double) -> (start: Double, end: Double)? {
        let cs = max(s, start), ce = min(e, end)
        return ce - cs > 0.0001 ? (cs, ce) : nil
    }

    /// 축에 숫자를 찍을 시각들 — 창의 양끝 + 그 사이 3시간 배수.
    var axisHours: [Int] {
        let lo = Int(start.rounded(.up)), hi = Int(end.rounded(.down))
        var hours = [lo]
        hours += stride(from: lo, through: hi, by: 1).filter { $0 % 3 == 0 && $0 != lo && $0 != hi }
        if hi != lo { hours.append(hi) }
        return hours
    }

    /// 격자를 그릴 시각들 (창 안쪽 정시).
    var gridHours: [Int] {
        let lo = Int(start.rounded(.down)) + 1, hi = Int(end.rounded(.up)) - 1
        guard lo <= hi else { return [] }
        return Array(lo...hi)
    }
}

/// 하루 위에 놓인 한 조각.
struct TimeSegment: Identifiable {
    let id: String
    let start: Double      // 0...24
    let end: Double
    let color: Color
    let title: String
    let isRoutine: Bool
    /// 시각이 유연한 것(주간 쿼터, 시작 시각 없는 무지개 일정) → 점선·반투명.
    var isFlexible: Bool = false
    /// 루틴 시간 안의 일정 → 루틴 위에 겹쳐(인셋) 표시.
    var isNested: Bool = false
    /// 무엇에서 온 조각인지. 화면에서 아이콘·부제를 고르는 데 쓴다.
    var kind: Kind = .routine
    /// 부제 (할 일이면 무슨 일의 일부인지 등).
    var subtitle: String? = nil

    enum Kind {
        case routine
        case quota
        /// 맥에서 그 날 하기로 올려둔 계획 블록 (= iOS의 '오늘 할 일로 배정').
        case planBlock
        /// 무지개 일정. 시작 시각이 없어 자리를 짐작한 것.
        case rainbowEvent
    }

    var hours: Double { end - start }
}

enum TimelineLayout {
    /// 시간대별 '원하는 시작 지점'. 맥과 같은 값이어야 한다.
    static let bandStart: [TimeBand: Double] = [.morning: 6, .afternoon: 12, .evening: 18, .night: 23]
    /// 끼니가 놓이는 하루 활동 구간.
    static let quotaWindow = (start: 7.5, end: 19.5)

    /// 하루(0~24h)에 대한 조각 목록을 계산한다.
    ///
    /// - routineStartOverride: 이 요일만 따로 옮긴 고정 루틴 시작 시각(이름 → 시각).
    /// - quotaPlacement: 이 요일에서 옮긴 끼니 위치(이름 → [회차: 시각]).
    /// - flexibleEvents: 시작 시각이 없는 무지개 일정 (제목, 시간, 색).
    static func segments(routines: [Routine],
                         blocks: [PlanBlock],
                         quota: [Routine] = [],
                         routineStartOverride: [String: Double] = [:],
                         quotaPlacement: [String: [Int: Double]] = [:],
                         quotaHidden: [String: Set<Int>] = [:],
                         flexibleEvents: [FlexibleEvent] = []) -> (segments: [TimeSegment], unplaced: [FlexibleEvent])
    {
        var segs: [TimeSegment] = []
        var occupied: [(Double, Double)] = []

        func resolvedStart(_ r: Routine) -> Double { routineStartOverride[r.name] ?? r.startHour }

        // 1) 고정 루틴 — 정해진 시각 그대로. 자정을 넘기면 나눠 그린다.
        for r in routines.sorted(by: { resolvedStart($0) < resolvedStart($1) }) {
            let start = resolvedStart(r)
            var piece = 0
            for (a, b) in splitAtMidnight(start, start + r.durationHours) {
                segs.append(TimeSegment(id: "routine:\(r.name):\(piece)", start: a, end: b,
                                        color: r.displayColor, title: r.name, isRoutine: true,
                                        kind: .routine))
                occupied.append((a, b)); piece += 1
            }
        }

        var free = subtract([(0, 24)], occupied)

        /// 원하는 지점에서 가장 가까운, 통째로 들어갈 빈 자리를 찾아 그 자리를 소모한다.
        func place(desired: Double, _ dur: Double) -> (Double, Double)? {
            let d = min(max(dur, 0), 24)
            guard d > 0 else { return nil }
            var best: (dist: Double, start: Double)? = nil
            for slot in free where slot.1 - slot.0 >= d - 1e-9 {
                let cs = min(max(desired, slot.0), slot.1 - d)
                let dist = abs(cs - desired)
                if best == nil || dist < best!.dist { best = (dist, cs) }
            }
            guard let b = best else { return nil }
            free = subtract(free, [(b.start, b.start + d)])
            return (b.start, b.start + d)
        }

        let freeBlocks = blocks.filter { !$0.withinRoutine }

        // 2a) 시각이 지정된 계획 블록 — 그 자리에 그대로 (겹쳐도 됨).
        for blk in freeBlocks where blk.startHour >= 0 {
            let s = blk.startHour
            var piece = 0
            for (a, b) in splitAtMidnight(s, s + blk.durationHours) {
                segs.append(TimeSegment(id: "block:\(blockID(blk)):\(piece)", start: a, end: b,
                                        color: blockColor(blk), title: blk.title, isRoutine: false,
                                        kind: .planBlock))
                free = subtract(free, [(a, b)]); piece += 1
            }
        }

        // 2b) 시각 미지정 계획 블록 — 시간대 시작 근처 빈 구간에 통째로.
        for band in [TimeBand.morning, .afternoon, .evening, .night] {
            for blk in freeBlocks
                .filter({ $0.startHour < 0 && $0.timeBand == band })
                .sorted(by: { $0.durationHours > $1.durationHours })
            {
                if let (s, e) = place(desired: bandStart[band] ?? 12, blk.durationHours) {
                    segs.append(TimeSegment(id: "block:\(blockID(blk)):0", start: s, end: e,
                                            color: blockColor(blk), title: blk.title, isRoutine: false,
                                            kind: .planBlock))
                }
            }
        }

        // 3) 주간 쿼터(식사 등) — 활동 구간에 회차 수만큼 균등 분산. 겹침 허용.
        for q in quota where q.weeklyHours > 0 {
            let pieces = max(1, q.sessionsPerDay)
            let each = (q.weeklyHours / 7) / Double(pieces)
            guard each > 0.05 else { continue }
            let hiddenSessions = quotaHidden[q.name] ?? []
            for i in 0..<pieces where !hiddenSessions.contains(i) {
                let center = pieces == 1
                    ? (quotaWindow.start + quotaWindow.end) / 2
                    : quotaWindow.start + (quotaWindow.end - quotaWindow.start) * Double(i) / Double(pieces - 1)
                let snappedDefault = ((center - each / 2) / 0.25).rounded() * 0.25
                let defaultStart = min(max(snappedDefault, 0), 24 - each)
                let s = min(max(quotaPlacement[q.name]?[i] ?? defaultStart, 0), 24 - each)
                segs.append(TimeSegment(id: "quota:\(q.name):\(i)", start: s, end: s + each,
                                        color: q.displayColor, title: q.name, isRoutine: false,
                                        isFlexible: true, kind: .quota))
            }
        }

        // 4) 루틴 안 일정 — 루틴 위에 겹쳐(인셋). 빈 구간에 영향 없음.
        for blk in blocks where blk.withinRoutine {
            let start = blk.startHour >= 0 ? blk.startHour : 9
            var piece = 0
            for (a, b) in splitAtMidnight(start, start + blk.durationHours) {
                segs.append(TimeSegment(id: "nested:\(blockID(blk)):\(piece)", start: a, end: b,
                                        color: .accentColor, title: blk.title, isRoutine: false,
                                        isNested: true, kind: .planBlock))
                piece += 1
            }
        }

        // 5) (iOS만) 무지개 일정 — 시작 시각이 없다. 2b와 같은 방식으로 남은 자리에 넣되,
        //    낮 한가운데를 원하는 지점으로 삼는다. 자리가 없으면 못 넣었다고 돌려준다 —
        //    조용히 지우면 "하루가 넘쳤다"는 사실 자체가 안 보인다.
        var unplaced: [FlexibleEvent] = []
        for event in flexibleEvents.sorted(by: { $0.hours > $1.hours }) {
            if let (s, e) = place(desired: 12, event.hours) {
                segs.append(TimeSegment(id: "event:\(event.id)", start: s, end: e,
                                        color: event.color, title: event.title, isRoutine: false,
                                        isFlexible: true, kind: .rainbowEvent))
            } else {
                unplaced.append(event)
            }
        }

        return (segs, unplaced)
    }

    /// 시작 시각이 없는 무지개 일정.
    struct FlexibleEvent: Identifiable {
        let id: String
        let title: String
        let hours: Double
        let color: Color
    }

    /// 맥은 '구체성 확인'을 통과한 블록만 액센트로 칠한다. 같은 규칙을 쓴다.
    private static func blockColor(_ blk: PlanBlock) -> Color {
        blk.concreteVerified ? .accentColor : .orange
    }

    private static func blockID(_ blk: PlanBlock) -> String { String(describing: blk.persistentModelID) }

    /// 자정을 넘기는 구간을 [s,24] 와 [0,e-24] 로 나눈다.
    static func splitAtMidnight(_ s: Double, _ e: Double) -> [(Double, Double)] {
        let start = max(0, s)
        if e <= 24 { return [(start, e)] }
        return [(start, 24), (0, min(e - 24, 24))]
    }

    /// 수면을 접었을 때 실제로 그릴 시간 범위.
    ///
    /// 하루 양끝의 수면만 잘라낸다. 한가운데 낮잠은 자르지 않는데, 가운데를 도려내면
    /// 시간 축이 끊겨서 앞뒤 시각을 읽을 수 없기 때문이다.
    static func visibleWindow(fixedRoutines: [Routine],
                              blocks: [PlanBlock],
                              hideSleep: Bool) -> HourWindow
    {
        guard hideSleep else { return .full }

        var sleep: [(Double, Double)] = []
        var protected: [(Double, Double)] = []
        for r in fixedRoutines {
            let parts = splitAtMidnight(r.startHour, r.startHour + r.durationHours)
            if r.isSleepRoutine { sleep.append(contentsOf: parts) } else { protected.append(contentsOf: parts) }
        }
        // 시각이 정해진 계획만 보호 대상. 시각이 없는 계획은 빈 구간(=수면 밖)에 배치되므로 안전하다.
        for b in blocks where b.startHour >= 0 {
            protected.append(contentsOf: splitAtMidnight(b.startHour, b.startHour + b.durationHours))
        }
        guard !sleep.isEmpty else { return .full }

        var start = 0.0, end = 24.0
        var moved = true
        while moved {                       // 0시에서 이어지는 수면을 앞에서 밀어낸다
            moved = false
            for (s, e) in sleep where s <= start + 1e-6 && e > start + 1e-6 { start = e; moved = true }
        }
        moved = true
        while moved {                       // 24시에 닿는 수면을 뒤에서 당긴다
            moved = false
            for (s, e) in sleep where e >= end - 1e-6 && s < end - 1e-6 { end = s; moved = true }
        }

        for (s, e) in protected {           // 다른 일정을 자르지 않는다
            if s < start { start = s }
            if e > end { end = e }
        }

        // 너무 좁아지면 그냥 하루 전체를 보여준다.
        // 이 검사는 아래 클램프보다 **먼저** 와야 한다 (클램프가 창을 넓히기 때문).
        guard end - start >= 6 else { return .full }

        // 정오는 언제나 보이게.
        start = max(0, min(start, 12))
        end = min(24, max(end, 12))
        return HourWindow(start: start.rounded(.down), end: end.rounded(.up))
    }

    /// 구간들의 합집합 총 길이. 겹치는 부분은 한 번만 센다.
    static func unionLength(_ intervals: [(Double, Double)]) -> Double {
        let sorted = intervals.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        var total = 0.0
        var curStart = -1.0, curEnd = -1.0
        for (s, e) in sorted {
            if s > curEnd {
                if curEnd > curStart { total += curEnd - curStart }
                curStart = s; curEnd = e
            } else {
                curEnd = max(curEnd, e)
            }
        }
        if curEnd > curStart { total += curEnd - curStart }
        return total
    }

    /// ranges에서 occ 구간들을 뺀 나머지(빈 구간).
    static func subtract(_ ranges: [(Double, Double)], _ occ: [(Double, Double)]) -> [(Double, Double)] {
        var result: [(Double, Double)] = []
        for (rs, re) in ranges {
            var pieces = [(rs, re)]
            for (os, oe) in occ {
                var next: [(Double, Double)] = []
                for (ps, pe) in pieces {
                    if oe <= ps || os >= pe { next.append((ps, pe)); continue }
                    if os > ps { next.append((ps, os)) }
                    if oe < pe { next.append((oe, pe)) }
                }
                pieces = next
            }
            result.append(contentsOf: pieces)
        }
        return result.filter { $0.1 - $0.0 > 0.0001 }
    }

    /// 겹치는 조각들을 나란히 세우기 위한 열 배정. 세로 화면(iOS)에서만 쓴다 —
    /// 맥은 가로 막대 하나에 다 얹지만, 좁은 화면에서 그러면 뒤엣것이 안 보인다.
    static func assignColumns(_ segments: [TimeSegment]) -> [String: (column: Int, total: Int)] {
        let sorted = segments.sorted { $0.start < $1.start }
        var result: [String: (Int, Int)] = [:]
        var cluster: [TimeSegment] = []
        var clusterEnd = -1.0

        func flush() {
            guard !cluster.isEmpty else { return }
            var columnEnds: [Double] = []
            var columnOf: [String: Int] = [:]
            for seg in cluster {
                if let free = columnEnds.firstIndex(where: { $0 <= seg.start + 1e-9 }) {
                    columnEnds[free] = seg.end
                    columnOf[seg.id] = free
                } else {
                    columnEnds.append(seg.end)
                    columnOf[seg.id] = columnEnds.count - 1
                }
            }
            for (id, column) in columnOf { result[id] = (column, columnEnds.count) }
            cluster = []
            clusterEnd = -1
        }

        for seg in sorted {
            if seg.start >= clusterEnd - 1e-9 { flush() }
            cluster.append(seg)
            clusterEnd = max(clusterEnd, seg.end)
        }
        flush()
        return result
    }
}
