//
//  RainbowWidget.swift
//  TodoWidget
//
//  '욕망의 무지개' 무지개 위젯 — 앞으로 며칠이 얼마나 차 있는지 홈·잠금 화면에서 본다.
//
//  앱 화면과 같은 방향으로 그린다: 위에서 아래로 날짜가 흐르고, 가로 칸은 그날
//  한꺼번에 굴리는 일의 개수다. 진한 칸은 실제로 시간을 쓰는 날, 옅은 칸은 매여만 있는 날.
//  데이터는 앱이 App Group에 구워둔 스냅샷만 읽는다. 읽기 전용.
//

import WidgetKit
import SwiftUI

// MARK: - 타임라인

struct RainbowEntry: TimelineEntry {
    /// 값을 안 낸 상태인가. 갤러리 미리보기에서는 언제나 false다.
    var isLocked: Bool = false
    let date: Date
    let snapshot: RainbowWidgetSnapshot
}

struct RainbowProvider: TimelineProvider {
    func placeholder(in context: Context) -> RainbowEntry {
        RainbowEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (RainbowEntry) -> Void) {
        // 위젯 갤러리에서는 빈 격자 대신 예시를 보여준다.
        let snapshot = context.isPreview ? .sample : RainbowWidgetBridge.read()
        completion(RainbowEntry(isLocked: !context.isPreview && !ProEntitlement.isUnlocked,
                                date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RainbowEntry>) -> Void) {
        let entry = RainbowEntry(isLocked: !ProEntitlement.isUnlocked,
                                 date: Date(), snapshot: RainbowWidgetBridge.read())
        // 내용이 바뀌면 앱이 reloadTimelines를 부른다. 여기서는 날짜가 넘어가면
        // '오늘'이 달라지므로 자정 직후 한 번만 다시 그리게 한다.
        let midnight = Calendar.current.nextDate(after: entry.date,
                                                 matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime)
            ?? entry.date.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - 위젯 정의

struct RainbowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RainbowWidgetBridge.widgetKind, provider: RainbowProvider()) { entry in
            RainbowWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(RainbowWidgetBridge.deepLink)
        }
        .configurationDisplayName("무지개")
        .description("앞으로 며칠이 얼마나 차 있는지 한눈에 봅니다.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - 패밀리별 라우팅

struct RainbowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RainbowEntry

    private var snapshot: RainbowWidgetSnapshot { entry.snapshot }

    var body: some View {
        if entry.isLocked {
            // 잠금 화면의 한 줄·동그라미 자리에는 세로로 쌓은 안내가 안 들어간다.
            if family == .accessoryInline {
                Text("🔒 무지개 Pro")
            } else if family == .accessoryCircular {
                Image(systemName: "lock.fill")
                    .accessibilityLabel("무지개 위젯이 잠겨 있습니다")
            } else {
                WidgetLockedView(name: "무지개")
            }
        } else {
            unlocked
        }
    }

    @ViewBuilder
    private var unlocked: some View {
        switch family {
        case .accessoryInline:      RainbowInlineView(snapshot: snapshot)
        case .accessoryCircular:    RainbowCircularView(snapshot: snapshot)
        case .accessoryRectangular: RainbowRectangularView(snapshot: snapshot)
        case .systemSmall:          RainbowGridView(snapshot: snapshot, dayCount: 5, showsToday: true)
        case .systemLarge:          RainbowGridView(snapshot: snapshot, dayCount: 14, showsToday: true)
        default:                    RainbowGridView(snapshot: snapshot, dayCount: 7, showsToday: true)
        }
    }
}

// MARK: - 홈 화면

/// 앱과 같은 방향의 미니 격자 — 세로로 날짜, 가로로 그날 굴리는 일.
private struct RainbowGridView: View {
    let snapshot: RainbowWidgetSnapshot
    let dayCount: Int
    let showsToday: Bool

    private var days: [RainbowWidgetSnapshot.Day] {
        Array(snapshot.days.prefix(dayCount))
    }

    var body: some View {
        if days.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "rainbow")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text("아직 그은 줄이 없어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if showsToday { todayLine }
                VStack(spacing: 2) {
                    ForEach(days) { day in
                        RainbowDayRow(day: day, isToday: isToday(day.date))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// 맨 위 한 줄로 오늘을 먼저 말한다. 격자만 있으면 무엇을 보는지 한 박자 늦는다.
    private var todayLine: some View {
        let today = snapshot.today
        let count = today?.workingCount ?? 0
        return HStack(spacing: 5) {
            Text("오늘")
                .font(.system(size: 12, weight: .bold))
            if count == 0 {
                Text("비어 있어요")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(count)개")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                Text(formatHours(today?.hours ?? 0))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let load = today?.load, load > 0 {
                Text("\(Int((load * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(loadColor(load))
            }
        }
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

/// 하루 한 줄 — 날짜와 그날의 칸들.
private struct RainbowDayRow: View {
    let day: RainbowWidgetSnapshot.Day
    let isToday: Bool

    private var laneCount: Int { RainbowWidgetSnapshot.laneColors.count }

    var body: some View {
        HStack(spacing: 4) {
            Text(dayLabel)
                .font(.system(size: 10, weight: isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.primary : Color.secondary)
                .frame(width: 26, alignment: .trailing)

            HStack(spacing: 2) {
                ForEach(0..<laneCount, id: \.self) { lane in
                    let cell = day.cells.first { $0.lane == lane }
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(fill(for: cell))
                        .frame(maxWidth: .infinity)
                        .frame(height: 10)
                }
            }
        }
    }

    private func fill(for cell: RainbowWidgetSnapshot.Cell?) -> Color {
        guard let cell,
              cell.lane < RainbowWidgetSnapshot.laneColors.count,
              let color = Color(hex: RainbowWidgetSnapshot.laneColors[cell.lane])
        else { return Color.primary.opacity(0.07) }
        // 앱 화면과 같은 규칙 — 실제로 하는 날은 진하게, 매여만 있는 날은 옅게.
        return color.opacity(cell.isWorking ? 1 : 0.22)
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: day.date)
    }
}

// MARK: - 잠금 화면

/// 한 줄. 오늘 몇 개를 굴리는지.
private struct RainbowInlineView: View {
    let snapshot: RainbowWidgetSnapshot

    var body: some View {
        if let today = snapshot.today, today.workingCount > 0 {
            Text("오늘 \(today.workingCount)개 · \(formatHours(today.hours))")
        } else {
            Text("오늘 비어 있음")
        }
    }
}

/// 원형. 오늘이 얼마나 찼는지 게이지 하나로.
private struct RainbowCircularView: View {
    let snapshot: RainbowWidgetSnapshot

    private var load: Double { min(1, snapshot.today?.load ?? 0) }

    var body: some View {
        Gauge(value: load) {
            Image(systemName: "rainbow")
        } currentValueLabel: {
            Text("\(Int(((snapshot.today?.load ?? 0) * 100).rounded()))")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

/// 가로형. 오늘 요약 한 줄 + 앞으로 나흘 미니 격자.
private struct RainbowRectangularView: View {
    let snapshot: RainbowWidgetSnapshot

    private var days: [RainbowWidgetSnapshot.Day] { Array(snapshot.days.prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let today = snapshot.today, today.workingCount > 0 {
                Text("오늘 \(today.workingCount)개 · \(formatHours(today.hours))")
                    .font(.headline)
            } else {
                Text("오늘 비어 있음")
                    .font(.headline)
            }

            // 잠금 화면은 단색으로만 그려지므로 색 대신 진하기로 갈라 보인다.
            VStack(spacing: 2) {
                ForEach(days) { day in
                    HStack(spacing: 2) {
                        ForEach(0..<RainbowWidgetSnapshot.laneColors.count, id: \.self) { lane in
                            let cell = day.cells.first { $0.lane == lane }
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(Color.primary.opacity(cell == nil ? 0.12
                                                            : (cell!.isWorking ? 0.95 : 0.35)))
                                .frame(maxWidth: .infinity)
                                .frame(height: 5)
                        }
                    }
                }
            }
        }
        .widgetAccentable()
    }
}

// MARK: - 공통

/// 15분 단위까지만. 위젯에서는 소수점이 길어지면 줄이 밀린다.
private func formatHours(_ hours: Double) -> String {
    if hours <= 0 { return "0분" }
    if hours < 1 { return "\(Int((hours * 60).rounded()))분" }
    return hours == hours.rounded()
        ? String(format: "%.0f시간", hours)
        : String(format: "%.1f시간", hours)
}

/// 하루가 80%를 넘으면 예상 못한 일 하나에 그 날이 무너진다 (→ LoadLevel).
private func loadColor(_ load: Double) -> Color {
    switch load {
    case ..<0.5:  return .green
    case ..<0.8:  return .blue
    case ..<1.0:  return .orange
    default:      return .red
    }
}
