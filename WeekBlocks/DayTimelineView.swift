import SwiftUI

// MARK: - 요일별 하루 24시간 타임라인
//
// 고정 루틴은 정해진 시각 그대로 그린다(자정을 넘기면 22~24 / 0~6 처럼 나눠서).
// 계획 블록은 정확한 시각이 없으므로 시간대 시작 근처의 빈 구간에 통째로,
// 루틴·다른 계획과 겹치지 않게 채운다. 남는 구간 = 자유 시간.

struct TimeSegment: Identifiable {
    let id = UUID()
    let start: Double      // 0...24
    let end: Double
    let color: Color
    let title: String
    let isRoutine: Bool
    var isFlexible: Bool = false   // 주간 쿼터(시간 유연) → 점선·반투명
    var isNested: Bool = false     // 루틴 시간 안의 일정 → 루틴 위에 겹쳐(인셋) 표시
}

enum TimelineLayout {
    /// 하루(0~24h)에 대한 색칠 구간 목록을 계산.
    static func segments(routines: [Routine], blocks: [PlanBlock], quota: [Routine] = []) -> [TimeSegment] {
        var segs: [TimeSegment] = []
        var occupied: [(Double, Double)] = []

        // 1) 고정 루틴 — 정해진 시각 그대로. 자정을 넘기면 [s,24] / [0,e-24] 로 나눠 그린다.
        //    (예: 수면 22:00+8h → 22~24 와 0~6)
        for r in routines.sorted(by: { $0.startHour < $1.startHour }) {
            for (a, b) in splitAtMidnight(r.startHour, r.startHour + r.durationHours) {
                segs.append(TimeSegment(start: a, end: b, color: r.displayColor, title: r.name, isRoutine: true))
                occupied.append((a, b))
            }
        }

        // 2) 계획 블록 — 정확한 시각이 없으므로 시간대 시작 근처 빈 구간에 통째로(겹치지 않게).
        //    단, '루틴 안' 블록은 빈 구간 배치에서 제외(아래 3단계에서 겹쳐 그림).
        var free = subtract([(0, 24)], occupied)
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
        let bandStart: [TimeBand: Double] = [.morning: 6, .afternoon: 12, .evening: 18, .night: 23]
        for band in [TimeBand.morning, .afternoon, .evening, .night] {
            for blk in freeBlocks.filter({ $0.timeBand == band }).sorted(by: { $0.durationHours > $1.durationHours }) {
                let color: Color = blk.concreteVerified ? .accentColor : .orange
                if let (s, e) = place(desired: bandStart[band] ?? 12, blk.durationHours) {
                    segs.append(TimeSegment(start: s, end: e, color: color, title: blk.title, isRoutine: false))
                }
            }
        }

        // 3) 주간 쿼터(시간 유연) — 남은 자유 시간에 회당 개수만큼 분산해 유연 블록으로.
        for q in quota where q.weeklyHours > 0 {
            let pieces = max(1, q.sessionsPerDay)
            let each = (q.weeklyHours / 7) / Double(pieces)
            guard each > 0.05 else { continue }
            for i in 0..<pieces {
                let desired = 24.0 * (Double(i) + 0.5) / Double(pieces)  // 하루에 고르게 분산
                if let (s, e) = place(desired: desired, each) {
                    segs.append(TimeSegment(start: s, end: e, color: q.displayColor,
                                            title: q.name, isRoutine: false, isFlexible: true))
                }
            }
        }

        // 4) 루틴 안 일정 — 정확한 시각에 루틴 위로 겹쳐(인셋) 그린다. 빈 구간/자유 시간엔 영향 없음.
        for blk in blocks where blk.withinRoutine {
            let start = blk.startHour >= 0 ? blk.startHour : 9
            for (a, b) in splitAtMidnight(start, start + blk.durationHours) {
                segs.append(TimeSegment(start: a, end: b, color: .accentColor,
                                        title: blk.title, isRoutine: false, isNested: true))
            }
        }
        return segs
    }

    /// 자정을 넘기는 구간을 [s,24] 와 [0,e-24] 로 나눈다.
    private static func splitAtMidnight(_ s: Double, _ e: Double) -> [(Double, Double)] {
        let start = max(0, s)
        if e <= 24 { return [(start, e)] }
        return [(start, 24), (0, min(e - 24, 24))]
    }

    static let bands: [TimeBand] = [.morning, .afternoon, .evening, .night]

    static func bandIntervals(_ b: TimeBand) -> [(Double, Double)] {
        switch b {
        case .morning:   return [(6, 12)]
        case .afternoon: return [(12, 18)]
        case .evening:   return [(18, 23)]
        case .night:     return [(23, 24), (0, 6)]
        }
    }

    /// 고정 루틴과 기존 계획을 피해 가장 여유가 많은 시간대를 추천. (새 계획 블록 기본 배정)
    static func suggestedBand(routines: [Routine], blocks: [PlanBlock]) -> TimeBand {
        var occ: [(Double, Double)] = []
        for r in routines {
            occ.append(contentsOf: splitAtMidnight(r.startHour, r.startHour + r.durationHours))
        }
        func length(_ ranges: [(Double, Double)]) -> Double { ranges.reduce(0) { $0 + ($1.1 - $1.0) } }

        var best: (band: TimeBand, free: Double)? = nil
        for b in bands {
            let routineFree = length(subtract(bandIntervals(b), occ))
            let blockHrs = blocks.filter { $0.timeBand == b }.reduce(0) { $0 + $1.durationHours }
            let free = max(0, routineFree - blockHrs)
            if best == nil || free > best!.free + 1e-9 { best = (b, free) }
        }
        return best?.band ?? .afternoon
    }

    /// ranges에서 occ 구간들을 뺀 나머지(빈 구간).
    private static func subtract(_ ranges: [(Double, Double)], _ occ: [(Double, Double)]) -> [(Double, Double)] {
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
}

// MARK: - 한 요일 행

struct DayTimelineRow: View {
    let day: DayOfWeek
    let date: Date
    let routines: [Routine]
    let blocks: [PlanBlock]
    var quotaRoutines: [Routine] = []

    private var occupied: Double {
        routines.reduce(0) { $0 + $1.durationHours }
            + blocks.filter { !$0.withinRoutine }.reduce(0) { $0 + $1.durationHours }
            + quotaRoutines.reduce(0) { $0 + $1.dailyQuotaHours }
    }
    private var freeHours: Double { max(0, 24 - occupied) }
    private var isOverbooked: Bool { occupied > 24.0001 }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                Text(day.shortLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)
                Text(dayNumber)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
            }
            .frame(width: 26)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.05))

                    // 시간 격자 (24칸)
                    ForEach(1..<24) { h in
                        let isMajor = (h % 6 == 0)
                        Rectangle()
                            .fill(Color.secondary.opacity(isMajor ? 0.18 : 0.07))
                            .frame(width: isMajor ? 1 : 0.5)
                            .offset(x: CGFloat(h) / 24 * w)
                    }

                    // 활동 구간
                    ForEach(TimelineLayout.segments(routines: routines, blocks: blocks, quota: quotaRoutines)) { seg in
                        let x = CGFloat(seg.start) / 24 * w
                        let segW = CGFloat(seg.end - seg.start) / 24 * w
                        segmentView(seg, width: max(1, segW))
                            .offset(x: x)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 24)

            Text("남은 시간 \(fmtHours(freeHours))h")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isOverbooked ? .red : .secondary)
                .frame(width: 90, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func segmentView(_ seg: TimeSegment, width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        ZStack {
            if seg.isFlexible {
                shape.fill(seg.color.opacity(0.20))
                shape.strokeBorder(seg.color.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            } else if seg.isNested {
                shape.fill(seg.color.opacity(0.95))
                shape.strokeBorder(Color.white.opacity(0.85), lineWidth: 1)
            } else {
                shape.fill(seg.color.opacity(0.85))
            }
        }
        // 루틴 안 일정은 위아래로 살짝 인셋해 루틴 위에 '얹힌' 느낌을 준다.
        .padding(.vertical, seg.isNested ? 5 : 0)
        .frame(width: width)
        .overlay(alignment: .leading) {
            if width > 30 {
                Text(seg.title)
                    .font(.system(size: 9, weight: seg.isNested ? .semibold : .medium))
                    .foregroundStyle(seg.isFlexible ? seg.color : Color.white)
                    .lineLimit(1)
                    .padding(.leading, 4)
                    .frame(width: width, alignment: .leading)
            }
        }
    }

    private var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - 시간 축 (0·6·12·18·24)

struct HourAxis: View {
    var body: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 26)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                        Text("\(h)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                            .offset(x: min(w - 12, CGFloat(h) / 24 * w))
                    }
                }
            }
            .frame(height: 12)
            Spacer().frame(width: 90)
        }
    }
}

func fmtHours(_ v: Double) -> String {
    v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
}
