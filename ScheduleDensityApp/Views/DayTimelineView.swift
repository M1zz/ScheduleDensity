//
//  DayTimelineView.swift
//  ScheduleDensityApp
//
//  무지개에서 날짜를 누르면 뜨는 하루 화면.
//
//  예전에는 요약 상자와 목록이 따로 쌓여 있어서, 그 날이 실제로 어떻게 흘러가는지가
//  안 보였다. 숫자는 "몇 시간"을 말해줄 뿐 "언제부터 언제까지"를 말해주지 않는다.
//  그래서 기상부터 자정까지 한 줄로 이어 놓고, 일정과 오늘 할 일을 그 줄 위에 얹는다.
//  지나간 자리는 흐려지고, 지금 서 있는 자리에는 선이 그어진다.
//
//  ⚠️ 일정(Event)에는 시작 시각이 없다. '하루에 몇 시간'만 있다. 그래서 시각은
//     기상 시각부터 차례로 쌓아 만든 것이고, 실제 약속 시각이 아니다 — 화면에서도
//     그렇게 읽히도록 '이렇게 쌓으면'이라고 적어 둔다.
//

import SwiftUI
import SwiftData

struct DayTimeAnalysisView: View {
    let date: Date
    @Bindable var viewModel: ScheduleViewModel
    @Environment(\.dismiss) var dismiss

    /// 1시간을 몇 픽셀로 그릴지. 칸 높이가 곧 시간의 길이라 눈으로 견줄 수 있어야 한다.
    private static let pixelsPerHour: CGFloat = 62
    /// 아무리 짧아도 제목 한 줄은 들어가야 한다.
    private static let minRowHeight: CGFloat = 46

    /// 하루를 세운 결과. 계산에 fetch와 트리 구성이 들어 있어 한 번만 만들고 들고 있는다.
    @State private var plan = DayPlan.empty
    /// 1분마다 다시 그려 '지금' 선이 흐르게 한다.
    @State private var nowHour: Double = 0

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)

                        timeline
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }
                    .padding(.top, 8)
                }
                .task {
                    plan = makePlan()
                    nowHour = Self.currentHour()
                    // 오늘이면 지금 서 있는 자리가 먼저 보여야 한다.
                    guard isToday, plan.nowIndex != nil else { return }
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation { proxy.scrollTo(Self.nowMarkerID, anchor: .center) }
                }
                .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                    nowHour = Self.currentHour()
                }
            }
            .navigationTitle(formatDateFull(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private static let nowMarkerID = "day.now"

    // MARK: - 머리말

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatWeekday(date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)
                if isToday {
                    Text("오늘")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                }
                Spacer()
            }

            // 그 날이 얼마나 찼는지 한 줄로. 숫자 세 개면 충분하다.
            HStack(spacing: 0) {
                stat("일정·할 일", formatHours(plan.busyHours), tint: .primary)
                divider
                stat("남는 시간", formatHours(max(0, plan.freeHours)),
                     tint: plan.freeHours < 0 ? .red : .secondary)
                divider
                stat("가동률", "\(Int((plan.load * 100).rounded()))%", tint: loadColor)
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            if plan.freeHours < 0 {
                Label("깨어 있는 시간보다 \(formatHours(-plan.freeHours)) 더 잡혀 있어요. 하나는 다른 날로 미뤄야 합니다.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 28)
    }

    private func stat(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var loadColor: Color {
        switch LoadLevel(rate: plan.load) {
        case .easy:   return .green
        case .normal: return .blue
        case .tight:  return .orange
        case .over:   return .red
        }
    }

    // MARK: - 타임라인

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(plan.rows.enumerated()), id: \.element.id) { index, row in
                DayTimelineRow(
                    row: row,
                    isLast: index == plan.rows.count - 1,
                    height: height(for: row),
                    progress: progress(for: row),
                    nowText: plan.nowIndex == index ? formatClock(nowHour) : nil
                )
                .id(plan.nowIndex == index ? Self.nowMarkerID : row.id)
            }
        }
    }

    private func height(for row: DayPlan.Row) -> CGFloat {
        max(Self.minRowHeight, CGFloat(row.hours) * Self.pixelsPerHour)
    }

    /// 지나간 만큼을 0...1로. 오늘이 아니면 흐름 표시를 하지 않는다.
    private func progress(for row: DayPlan.Row) -> Double? {
        guard isToday else { return nil }
        if nowHour >= row.end { return 1 }
        if nowHour <= row.start { return 0 }
        guard row.hours > 0 else { return 0 }
        return (nowHour - row.start) / row.hours
    }

    // MARK: - 계산

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    static func currentHour() -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
    }

    private func makePlan() -> DayPlan {
        DayPlan(date: date,
                events: eventsForDate,
                todos: todosForDate,
                sleepHours: viewModel.sleepHoursPerDay,
                laneColor: laneColor(for:))
    }

    private var eventsForDate: [Event] {
        viewModel.fetchEvents()
            .filter { $0.occursOn(date: date) }
            .sorted { (viewModel.eventLaneAssignments[$0.laneKey] ?? 999)
                    < (viewModel.eventLaneAssignments[$1.laneKey] ?? 999) }
    }

    /// 그 날 하기로 올려둔 할 일. 일정과 같은 줄 위에 이어 붙는다 —
    /// 하루는 일정과 할 일로 나뉘어 있지 않고 한 줄기로 흐르니까.
    private var todosForDate: [(item: BacklogItem, step: BacklogItem?, hours: Double)] {
        let assigned = WeekBlocksStore.shared.titlesAssigned(to: date)
        guard !assigned.isEmpty,
              let context = TodoEventBridge.shared.todoContainer?.mainContext,
              let all = try? context.fetch(FetchDescriptor<BacklogItem>(
                  sortBy: [SortDescriptor(\BacklogItem.sortIndex), SortDescriptor(\BacklogItem.createdAt)]))
        else { return [] }

        let tree = TodoTree(all)
        return tree.roots
            .filter { assigned.contains($0.title) && !$0.isCompleted }
            .map { item in
                let step = tree.currentStep(of: item)
                // 오늘 실제로 할 만큼 = 지금 할 단계의 시간. 단계가 없으면 할 일 전체.
                return (item, step, step?.durationHours ?? tree.totalHours(of: item))
            }
    }

    private func laneColor(for event: Event) -> Color {
        if let lane = viewModel.eventLaneAssignments[event.laneKey],
           lane >= 0, lane < ScheduleViewModel.laneColors.count,
           let color = Color(hex: ScheduleViewModel.laneColors[lane]) {
            return color
        }
        return .blue
    }

    // MARK: - 글자

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

// MARK: - 하루 한 줄

private struct DayTimelineRow: View {
    let row: DayPlan.Row
    let isLast: Bool
    let height: CGFloat
    /// 지나간 정도 0...1. nil이면 오늘이 아니라 표시하지 않는다.
    let progress: Double?
    /// 지금이 이 줄에 걸쳐 있으면 그 시각. 아니면 nil.
    let nowText: String?

    private var isPast: Bool { (progress ?? 0) >= 1 }
    private var isNow: Bool { if let progress { return progress > 0 && progress < 1 } else { return false } }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 왼쪽 시각 눈금
            Text(row.overflows ? "—" : formatClock(row.start))
                .font(.system(size: 11, weight: isNow ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isNow ? Color.primary : Color.secondary.opacity(0.6))
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 2)

            // 이어지는 레일 — 위아래 칸과 끊기지 않아야 '하루'로 읽힌다.
            rail

            // 내용
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: height, alignment: .top)
                // '지금'은 이 줄 안 제자리에 긋는다. 줄과 줄 사이에 두면 시각이 어긋난다.
                .overlay(alignment: .top) {
                    if let nowText, let progress {
                        nowLine(nowText)
                            .offset(y: height * progress)
                    }
                }
        }
        .opacity(isPast ? 0.45 : 1)
    }

    private func nowLine(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(Color.accentColor.opacity(0.55))
                .frame(height: 1.5)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
        }
        .offset(x: -4)
    }

    private var rail: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(row.isFree ? Color.secondary.opacity(0.3) : row.color)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle()
                        .strokeBorder(Color(.systemBackground), lineWidth: isNow ? 2.5 : 0)
                        .frame(width: 15, height: 15)
                )
                .padding(.top, 4)

            Rectangle()
                .fill(row.isFree ? Color.secondary.opacity(0.18) : row.color.opacity(0.28))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 15, height: height)
    }

    private var content: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .top) {
                // 시간의 길이를 그대로 가진 알약. 지나간 만큼은 안쪽이 차 있다.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(row.isFree ? Color.secondary.opacity(0.10) : row.color.opacity(0.16))

                if let progress, progress > 0, !row.isFree {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(row.color.opacity(0.30))
                            .frame(height: geo.size.height * progress)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(row.isFree ? Color.secondary : row.color)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(row.isFree
                                          ? Color.secondary.opacity(0.12)
                                          : row.color.opacity(0.22))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.3)
                            .lineLimit(2)
                            .strikethrough(isPast && !row.isFree, color: .secondary)

                        Text(row.timeText)
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(row.overflows ? Color.red : .secondary)

                        if let subtitle = row.subtitle {
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
            }
            .frame(height: height - 6)
        }
    }
}

// MARK: - 하루를 한 줄기로 세우는 계산

/// 기상부터 자정까지를 한 줄로 세우고, 일정과 할 일을 차례로 얹는다.
struct DayPlan {
    struct Row: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let icon: String
        let color: Color
        let hours: Double
        /// 시작·끝 시각(시). 실제 약속 시각이 아니라 쌓아서 만든 자리다.
        let start: Double
        let end: Double
        let isFree: Bool

        /// 쌓다 보니 자정을 넘어간 줄. 시각을 적으면 거짓말이 된다.
        var overflows: Bool { start >= 24 }

        var timeText: String {
            overflows
                ? "\(formatHours(hours)) · 하루를 넘겼어요"
                : "\(formatClock(start)) – \(formatClock(end)) · \(formatHours(hours))"
        }
    }

    static let empty = DayPlan()

    let rows: [Row]
    /// 일정과 할 일이 차지한 시간.
    let busyHours: Double
    /// 깨어 있는 시간에서 남는 시간. 음수면 넘친 것.
    let freeHours: Double
    /// 깨어 있는 시간 대비 점유율.
    let load: Double
    /// 지금이 걸쳐 있는 줄의 자리. 오늘이 아니면 nil.
    let nowIndex: Int?

    /// 아직 계산하기 전.
    private init() {
        rows = []
        busyHours = 0
        freeHours = 0
        load = 0
        nowIndex = nil
    }

    init(date: Date,
         events: [Event],
         todos: [(item: BacklogItem, step: BacklogItem?, hours: Double)],
         sleepHours: Double,
         laneColor: (Event) -> Color)
    {
        // 자는 시간은 자정부터 sleepHours 동안 — 그래서 하루는 그 시각에 시작한다.
        // (깨어 있는 시간 = 24 - sleepHours. 앱의 다른 계산과 같은 분모다.)
        let wake = min(12, max(0, sleepHours))
        let capacity = max(1, 24 - wake)

        var rows: [Row] = []
        var cursor = wake

        for event in events {
            let hours = max(0.25, event.hoursPerDay)
            rows.append(Row(id: "event-\(event.laneKey)",
                            title: event.title,
                            subtitle: nil,
                            icon: "calendar",
                            color: laneColor(event),
                            hours: hours,
                            start: cursor,
                            end: cursor + hours,
                            isFree: false))
            cursor += hours
        }

        for todo in todos {
            let hours = max(0.25, todo.hours)
            let label = (todo.step ?? todo.item).label
            rows.append(Row(id: "todo-\(todo.item.dragToken)",
                            title: todo.step?.title ?? todo.item.title,
                            // 단계를 하고 있으면 그게 무슨 일의 일부인지 밝혀 준다.
                            subtitle: todo.step == nil ? nil : todo.item.title,
                            icon: label.symbol,
                            color: label.tint,
                            hours: hours,
                            start: cursor,
                            end: cursor + hours,
                            isFree: false))
            cursor += hours
        }

        busyHours = cursor - wake
        freeHours = capacity - busyHours

        // 남는 시간도 줄 하나로 세운다. 비어 있는 걸 눈으로 봐야 넣을지 말지 정한다.
        if freeHours > 0.25 {
            rows.append(Row(id: "free",
                            title: "남는 시간",
                            subtitle: nil,
                            icon: "leaf.fill",
                            color: .secondary,
                            hours: freeHours,
                            start: cursor,
                            end: 24,
                            isFree: true))
        }

        self.rows = rows
        load = busyHours / capacity

        if Calendar.current.isDateInToday(date) {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let now = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
            nowIndex = rows.firstIndex { now >= $0.start && now < $0.end }
        } else {
            nowIndex = nil
        }
    }
}

// MARK: - 글자 (파일 안에서 함께 쓴다)

/// 7.5 → "7:30". 하루를 시각으로 읽으려면 소수점이 아니라 분이어야 한다.
fileprivate func formatClock(_ hour: Double) -> String {
    let clamped = max(0, min(24, hour))
    let h = Int(clamped)
    let m = Int(((clamped - Double(h)) * 60).rounded())
    if m == 60 { return String(format: "%d:00", min(24, h + 1)) }
    return String(format: "%d:%02d", h, m)
}

/// 1.5 → "1시간 30분". 길이는 시각과 다른 단위로 읽혀야 헷갈리지 않는다.
fileprivate func formatHours(_ hours: Double) -> String {
    let total = Int((hours * 60).rounded())
    let h = total / 60
    let m = total % 60
    if h == 0 { return "\(m)분" }
    if m == 0 { return "\(h)시간" }
    return "\(h)시간 \(m)분"
}
