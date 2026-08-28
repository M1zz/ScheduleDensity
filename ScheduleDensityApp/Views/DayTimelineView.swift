//
//  DayTimelineView.swift
//  ScheduleDensityApp
//
//  무지개에서 날짜를 누르면 뜨는 하루 화면 — 0시부터 24시까지 진짜 시계 위에 그린다.
//
//  배치 규칙은 맥앱 '무지개 공방'을 그대로 쓴다 (→ DayTimelineLayout.swift).
//  두 앱이 같은 CloudKit 데이터를 읽는데 배치가 다르면 같은 하루가 두 모양으로 보인다.
//   - 고정 루틴(수면·출근·운동)이 정해진 시각에 깔려 하루의 뼈대가 된다.
//   - 그 날 하기로 올려둔 할 일은 시간대(아침 6·오후 12·저녁 18·심야 23)를 원점 삼아
//     남은 빈 자리 중 가장 가까운 곳에 통째로 들어간다.
//   - 식사 같은 주간 쿼터는 활동 구간에 균등 분산되고 겹침을 허용한다.
//
//  무지개 일정(Event)에는 시작 시각이 없다. 같은 방식으로 낮 한가운데를 원점 삼아
//  남은 자리에 넣되 점선으로 그린다 — 그 시각은 정해진 게 아니라 짐작이니까.
//  넣을 자리가 없으면 지우지 않고 아래에 따로 세운다. 안 들어간다는 사실이 곧 답이다.
//

import SwiftUI
import SwiftData

struct DayTimeAnalysisView: View {
    let date: Date
    @Bindable var viewModel: ScheduleViewModel
    @Environment(\.dismiss) var dismiss

    /// 1시간을 몇 포인트로 그릴지. 하루를 다 그리면 길어지므로 스크롤한다.
    private static let pixelsPerHour: CGFloat = 46
    private static let gutterWidth: CGFloat = 42

    /// 맥과 같은 설정 이름 — 하루 양끝의 수면을 접어 가운데를 넓게 본다.
    @AppStorage("hideSleepInTimeline") private var hideSleep = true

    @State private var day = DayContent()
    @State private var nowHour: Double = 0

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if day.isAvailable {
                            clock
                        } else {
                            unavailableNotice
                        }
                        if !day.unplaced.isEmpty { overflow }
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .task {
                    nowHour = Self.currentHour()
                    day = load()
                    guard isToday else { return }
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation { proxy.scrollTo(Self.nowID, anchor: .center) }
                }
                .onChange(of: hideSleep) { _, _ in day = load() }
                .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                    nowHour = Self.currentHour()
                }
            }
            .navigationTitle(formatDateFull(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        hideSleep.toggle()
                    } label: {
                        Image(systemName: hideSleep ? "moon.zzz" : "moon.zzz.fill")
                    }
                    .accessibilityLabel(hideSleep ? "수면 시간 펴기" : "수면 시간 접기")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private static let nowID = "day.now"

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

            HStack(spacing: 0) {
                stat("차 있는 시간", formatHours(day.occupiedHours), tint: .primary)
                statDivider
                stat("남는 시간", formatHours(day.freeHours),
                     tint: day.freeHours < 1 ? .orange : .secondary)
                statDivider
                stat("가동률", "\(Int((day.load * 100).rounded()))%", tint: loadColor)
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var statDivider: some View {
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
        switch LoadLevel(rate: day.load) {
        case .easy:   return .green
        case .normal: return .blue
        case .tight:  return .orange
        case .over:   return .red
        }
    }

    // MARK: - 시계

    private var clock: some View {
        let window = day.window
        let height = CGFloat(window.span) * Self.pixelsPerHour
        let columns = TimelineLayout.assignColumns(day.segments.filter { !$0.isNested })

        return HStack(alignment: .top, spacing: 0) {
            hourGutter(window: window, height: height)

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    gridLines(window: window, height: height, width: geo.size.width)

                    ForEach(day.segments) { segment in
                        if let box = frame(for: segment, window: window,
                                           width: geo.size.width,
                                           columns: columns) {
                            SegmentBlock(segment: segment, isPast: isPast(segment))
                                .frame(width: box.width, height: box.height)
                                .offset(x: box.x, y: box.y)
                        }
                    }

                    if isToday, let y = nowOffset(window: window) {
                        nowLine
                            .offset(y: y)
                            .id(Self.nowID)
                    }
                }
            }
            .frame(height: height)
        }
    }

    private func hourGutter(window: HourWindow, height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear.frame(width: Self.gutterWidth, height: height)
            ForEach(window.axisHours, id: \.self) { hour in
                Text("\(hour):00")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .offset(x: -8, y: CGFloat(window.fraction(Double(hour))) * height - 7)
            }
        }
        .frame(width: Self.gutterWidth, height: height, alignment: .topTrailing)
    }

    private func gridLines(window: HourWindow, height: CGFloat, width: CGFloat) -> some View {
        ForEach(window.gridHours, id: \.self) { hour in
            Rectangle()
                .fill(Color.primary.opacity(hour % 3 == 0 ? 0.14 : 0.06))
                .frame(width: width, height: hour % 3 == 0 ? 1 : 0.5)
                .offset(y: CGFloat(window.fraction(Double(hour))) * height)
        }
    }

    private var nowLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(Color.accentColor.opacity(0.6))
                .frame(height: 1.5)
            Text(formatClock(nowHour))
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
        }
        .offset(x: -3)
    }

    private func nowOffset(window: HourWindow) -> CGFloat? {
        guard nowHour >= window.start, nowHour <= window.end else { return nil }
        return CGFloat(window.fraction(nowHour)) * CGFloat(window.span) * Self.pixelsPerHour
    }

    /// 조각 하나가 놓일 자리. 창 밖으로 나가면 nil.
    private func frame(for segment: TimeSegment,
                       window: HourWindow,
                       width: CGFloat,
                       columns: [String: (column: Int, total: Int)]) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)?
    {
        guard let clamped = window.clamp(segment.start, segment.end) else { return nil }
        let height = CGFloat(window.span) * Self.pixelsPerHour
        let y = CGFloat(window.fraction(clamped.start)) * height
        let h = max(18, CGFloat(window.fraction(clamped.end)) * height - y)

        // 루틴 안 일정은 루틴 위에 얇게 겹친다 (맥과 같다).
        if segment.isNested {
            return (x: 14, y: y + 3, width: max(10, width - 28), height: max(12, h - 6))
        }

        // 겹치는 것들은 나란히. 좁은 화면에서 겹쳐 그리면 뒤엣것이 안 보인다.
        let slot = columns[segment.id] ?? (column: 0, total: 1)
        let gap: CGFloat = 3
        let columnWidth = (width - gap * CGFloat(slot.total - 1)) / CGFloat(slot.total)
        return (x: (columnWidth + gap) * CGFloat(slot.column), y: y, width: columnWidth, height: h)
    }

    private func isPast(_ segment: TimeSegment) -> Bool {
        isToday && nowHour >= segment.end
    }

    // MARK: - 못 들어간 일정

    private var overflow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("하루에 안 들어갔어요", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)

            ForEach(day.unplaced) { event in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(event.color)
                        .frame(width: 4, height: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 15, weight: .medium))
                        Text(formatHours(event.hours))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            Text("빈 자리가 이만큼 남지 않아 아무 데도 못 놓았습니다. 다른 날로 미루거나 시간을 줄여야 해요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    private var unavailableNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("하루 뼈대를 못 읽었어요", systemImage: "icloud.slash")
                .font(.subheadline.weight(.semibold))
            Text("수면·출근 같은 고정 루틴은 맥앱 ‘무지개 공방’에 적어 둔 것을 iCloud로 읽어 옵니다. iCloud에 로그인되어 있는지 확인해주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var footnote: some View {
        Text("점선 칸은 시각이 정해지지 않은 것입니다 — 빈 자리에 놓아 본 자리예요. 정확한 시각은 맥앱 ‘무지개 공방’에서 끌어 옮길 수 있습니다.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 읽기

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    static func currentHour() -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
    }

    /// 맥에서 읽어 온 하루 + 무지개 일정을 합쳐 한 번만 계산한다.
    private func load() -> DayContent {
        let input = WeekBlocksStore.shared.dayInput(for: date)

        // ⚠️ 뷰모델의 fetchEvents는 맥 계획을 비춘 미러까지 섞어 준다. 그건 계획 블록으로
        //    이미 그려지므로, 여기서는 이 앱에 저장된 일정만 직접 읽는다.
        let ownEvents = storedEvents().filter { $0.occursOn(date: date) }
        let flexible = ownEvents.map { event in
            TimelineLayout.FlexibleEvent(id: event.laneKey,
                                         title: event.title,
                                         hours: max(0.25, event.hoursPerDay),
                                         color: laneColor(for: event))
        }

        let result = TimelineLayout.segments(
            routines: input.fixedRoutines,
            blocks: input.blocks,
            quota: input.quotaRoutines,
            routineStartOverride: input.routineStartOverride,
            quotaPlacement: input.quotaPlacement,
            quotaHidden: input.quotaHidden,
            flexibleEvents: flexible
        )

        let window = TimelineLayout.visibleWindow(fixedRoutines: input.fixedRoutines,
                                                  blocks: input.blocks,
                                                  hideSleep: hideSleep)

        // 겹친 시간은 한 번만 센다 (맥과 같은 규칙).
        let occupied = TimelineLayout.unionLength(
            result.segments.filter { !$0.isNested }.map { ($0.start, $0.end) })

        return DayContent(segments: result.segments,
                          unplaced: result.unplaced,
                          window: window,
                          occupiedHours: occupied,
                          isAvailable: input.isAvailable)
    }

    /// 이 앱에 저장된 일정만.
    private func storedEvents() -> [Event] {
        guard let context = TodoEventBridge.shared.eventContainer?.mainContext else { return [] }
        let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.startDate)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func laneColor(for event: Event) -> Color {
        if let lane = viewModel.eventLaneAssignments[event.laneKey],
           lane >= 0, lane < ScheduleViewModel.laneColors.count,
           let color = Color(hex: ScheduleViewModel.laneColors[lane]) {
            return color
        }
        return .blue
    }

    /// 계산해 둔 하루.
    struct DayContent {
        var segments: [TimeSegment] = []
        var unplaced: [TimelineLayout.FlexibleEvent] = []
        var window: HourWindow = .full
        var occupiedHours: Double = 0
        var isAvailable = false

        var freeHours: Double { max(0, 24 - occupiedHours) }
        var load: Double { occupiedHours / 24 }
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

// MARK: - 조각 하나

private struct SegmentBlock: View {
    let segment: TimeSegment
    let isPast: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            shape
            if !segment.isNested {
                VStack(alignment: .leading, spacing: 1) {
                    Text(segment.title)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(-0.2)
                        .lineLimit(2)
                    if segment.hours >= 0.75 {
                        Text(rangeText)
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
            }
        }
        .opacity(isPast ? 0.4 : 1)
    }

    @ViewBuilder
    private var shape: some View {
        let rect = RoundedRectangle(cornerRadius: segment.isNested ? 4 : 8, style: .continuous)
        if segment.isFlexible {
            // 시각이 정해지지 않은 것 — 점선으로 '여기쯤'이라는 뜻을 준다.
            rect.fill(segment.color.opacity(0.12))
                .overlay(
                    rect.strokeBorder(segment.color.opacity(0.75),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
        } else if segment.isRoutine {
            rect.fill(segment.color.opacity(0.20))
                .overlay(rect.strokeBorder(segment.color.opacity(0.35), lineWidth: 1))
        } else {
            rect.fill(segment.color.opacity(0.30))
                .overlay(rect.strokeBorder(segment.color.opacity(0.6), lineWidth: 1))
        }
    }

    private var rangeText: String {
        "\(formatClock(segment.start)) – \(formatClock(segment.end))"
    }
}

// MARK: - 글자 (파일 안에서만)

/// 7.5 → "7:30".
fileprivate func formatClock(_ hour: Double) -> String {
    let clamped = max(0, min(24, hour))
    let h = Int(clamped)
    let m = Int(((clamped - Double(h)) * 60).rounded())
    if m == 60 { return String(format: "%d:00", min(24, h + 1)) }
    return String(format: "%d:%02d", h, m)
}

/// 1.5 → "1시간 30분".
fileprivate func formatHours(_ hours: Double) -> String {
    let total = Int((hours * 60).rounded())
    let h = total / 60
    let m = total % 60
    if h == 0 { return "\(m)분" }
    if m == 0 { return "\(h)시간" }
    return "\(h)시간 \(m)분"
}
