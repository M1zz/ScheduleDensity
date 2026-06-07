import SwiftUI

// MARK: - 요일별 하루 24시간 타임라인
//
// 모든 블록(고정 루틴 + 계획)을 **절대 겹치지 않게** 통째로 배치한다.
// 각 블록은 원하는 시각(루틴=시작 시각, 계획=시간대 시작) 근처의 빈 구간에
// 통으로 들어가며, 자리가 겹치면 가장 가까운 빈 구간으로 밀려난다.
// 남는 구간 = 자유 시간.

struct TimeSegment: Identifiable {
    let id = UUID()
    let start: Double      // 0...24
    let end: Double
    let color: Color
    let title: String
    let isRoutine: Bool
}

enum TimelineLayout {
    /// 하루(0~24h)에 대한 색칠 구간 목록을 계산. 모든 블록은 통째로, 서로 겹치지 않게 배치된다.
    static func segments(routines: [Routine], blocks: [PlanBlock]) -> [TimeSegment] {
        var free: [(Double, Double)] = [(0, 24)]
        var segs: [TimeSegment] = []

        /// 원하는 시각(desired) 근처의 빈 구간에 길이 dur짜리 블록을 통째로 배치.
        /// 들어갈 빈 구간이 없으면 nil(과예약 → 그리지 않음, 절대 겹치지 않게).
        func place(desired: Double, _ dur: Double) -> (Double, Double)? {
            let d = min(max(dur, 0), 24)
            guard d > 0 else { return nil }
            var best: (dist: Double, start: Double)? = nil
            for slot in free where slot.1 - slot.0 >= d - 1e-9 {
                let cs = min(max(desired, slot.0), slot.1 - d)   // 빈 구간 안에서 desired에 최대한 가깝게
                let dist = abs(cs - desired)
                if best == nil || dist < best!.dist { best = (dist, cs) }
            }
            guard let b = best else { return nil }
            free = subtract(free, [(b.start, b.start + d)])
            return (b.start, b.start + d)
        }

        // 1) 고정 루틴 — 시작 시각 순서대로. 자정을 넘기면 아침쪽(0시 근처)에 한 덩어리로.
        for r in routines.sorted(by: { $0.startHour < $1.startHour }) {
            let wraps = r.startHour + r.durationHours > 24
            let desired = wraps ? 0 : r.startHour
            if let (s, e) = place(desired: desired, r.durationHours) {
                segs.append(TimeSegment(start: s, end: e, color: r.displayColor, title: r.name, isRoutine: true))
            }
        }

        // 2) 계획 블록 — 시간대 시작 시각 근처의 빈 구간에 통째로.
        let bandStart: [TimeBand: Double] = [.morning: 6, .afternoon: 12, .evening: 18, .night: 23]
        for band in [TimeBand.morning, .afternoon, .evening, .night] {
            let bandBlocks = blocks.filter { $0.timeBand == band }
                .sorted { $0.durationHours > $1.durationHours }
            for blk in bandBlocks {
                let color: Color = blk.concreteVerified ? .accentColor : .orange
                if let (s, e) = place(desired: bandStart[band] ?? 12, blk.durationHours) {
                    segs.append(TimeSegment(start: s, end: e, color: color, title: blk.title, isRoutine: false))
                }
            }
        }
        return segs
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

    private var occupied: Double {
        routines.reduce(0) { $0 + $1.durationHours } + blocks.reduce(0) { $0 + $1.durationHours }
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
                    ForEach(TimelineLayout.segments(routines: routines, blocks: blocks)) { seg in
                        let x = CGFloat(seg.start) / 24 * w
                        let segW = CGFloat(seg.end - seg.start) / 24 * w
                        RoundedRectangle(cornerRadius: 3)
                            .fill(seg.color.opacity(0.85))
                            .frame(width: max(1, segW))
                            .overlay(alignment: .leading) {
                                if segW > 38 {
                                    Text(seg.title)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(.leading, 4)
                                        .frame(width: segW, alignment: .leading)
                                }
                            }
                            .offset(x: x)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 24)

            Text("자유 \(fmtHours(freeHours))h")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isOverbooked ? .red : .secondary)
                .frame(width: 66, alignment: .trailing)
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
            Spacer().frame(width: 66)
        }
    }
}

func fmtHours(_ v: Double) -> String {
    v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
}
