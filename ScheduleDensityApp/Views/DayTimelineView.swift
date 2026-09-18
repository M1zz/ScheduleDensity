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
//  **모양도 맥의 일간(DayScheduleView)을 따른다 — 알약 타임라인.**
//  일정마다 색 알약(루틴 아이콘·계획 첫 글자)을 한 줄 등뼈 위에 세우고, 옆에 시각·제목을 적는다.
//  알약 사이의 빈 시간은 앞 일정 색에서 다음 일정 색으로 번지는 선으로 잇는다.
//  아이폰은 맥 계획표를 읽기만 하므로 체크는 누르는 단추가 아니라 찍힌 표시로만 선다.
//

import SwiftUI
import SwiftData
import UIKit

struct DayTimeAnalysisView: View {
    let date: Date
    @Bindable var viewModel: ScheduleViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 한 시간의 키. 알약과 글씨가 숨 쉴 자리가 있어야 말랑하게 읽힌다 (맥과 같은 값).
    private static let hourHeight: CGFloat = 46
    /// 왼쪽 시각 글씨가 서는 폭.
    private static let gutter: CGFloat = 46
    /// 알약의 폭. 아이콘 하나가 가운데 들어가는 크기.
    private static let pillWidth: CGFloat = 34
    /// 한 줄(알약 + 시각·제목)이 차지하는 가장 작은 키. 15분짜리도 이만큼은 선다.
    private static let minRowHeight: CGFloat = 38

    /// 살짝 넘쳤다가 제자리로 — 맥의 `Motion.squish`와 같은 결.
    private static let squish = Animation.spring(response: 0.3, dampingFraction: 0.82)
    /// 늘어나는 다리 — squish보다 조금 더 출렁여 떡처럼 늘었다 멎는다.
    private static let stretch = Animation.spring(response: 0.46, dampingFraction: 0.62)

    /// 맥과 같은 설정 이름 — 하루 양끝의 수면을 접어 가운데를 넓게 본다.
    @AppStorage("hideSleepInTimeline") private var hideSleep = true

    @State private var day = DayContent()
    @State private var nowHour: Double = 0
    /// 일정이 다 드러났는가. 하루가 설 때 위에서부터 하나씩 톡톡 선다.
    @State private var drawn = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if !day.carried.isEmpty { carriedSection }
                        if day.isAvailable {
                            clock
                        } else {
                            unavailableNotice
                        }
                        if !day.pickups.isEmpty { pickupSection }
                        if !day.unplaced.isEmpty { overflow }
                        footnote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .task {
                    nowHour = Self.currentHour()
                    day = load()
                    // 알약이 먼저 자리에 선 다음 드러나야 차례로 튀어 오른다.
                    try? await Task.sleep(for: .milliseconds(30))
                    drawn = true
                    guard isToday else { return }
                    try? await Task.sleep(for: .milliseconds(320))
                    withAnimation { proxy.scrollTo(Self.nowID, anchor: .center) }
                }
                .onChange(of: hideSleep) { _, _ in
                    withAnimation(Self.squish) { day = load() }
                }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(formatWeekday(date))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(isToday ? Color.red : .primary)
                if isToday {
                    Text("오늘")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red))
                }
                Spacer()
            }

            // 숫자는 표의 칸이 아니라 말랑한 알약 한마디로 읽힌다 (맥의 '남은 시간' 알약과 같은 결).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    statPill(icon: "hourglass",
                             label: String(localized: "남는 시간"), value: formatHours(day.freeHours),
                             tint: day.freeHours < 1 ? .orange : .accentColor)
                    statPill(icon: "clock.fill",
                             label: String(localized: "차 있는 시간"), value: formatHours(day.occupiedHours),
                             tint: .secondary)
                    statPill(icon: "gauge.with.dots.needle.50percent",
                             label: String(localized: "가동률"), value: "\(Int((day.load * 100).rounded()))%",
                             tint: loadColor)
                }
            }
            .scrollClipDisabled()
        }
    }

    private func statPill(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .opacity(0.8)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .animation(.snappy(duration: 0.25), value: value)
        .accessibilityElement(children: .combine)
    }

    private var loadColor: Color {
        switch LoadLevel(rate: day.load) {
        case .easy:   return .green
        case .normal: return .blue
        case .tight:  return .orange
        case .over:   return .red
        }
    }

    // MARK: - 하루

    private var clock: some View {
        let window = day.window
        let segs = day.segments
        // 나란히 설 칸을 나누는 건 루틴·계획 블록, 그리고 빈 자리에 놓인 일정뿐이다. 루틴 안 일정과
        // 다른 일정 위에 겹친 끼니는 칸을 따로 갖지 않고 오른쪽에 얹힌다 — 회사 9시간이 끼니 한 번
        // 때문에 반쪽이 되지 않게.
        let base = segs.filter { !$0.isNested && !$0.isFlexible }
        let laned = segs.filter { !Self.overlaysOther($0, base: base) }
        let lanes = Self.lanes(laned, minHours: Double(Self.minRowHeight / Self.hourHeight))
        let order = Dictionary(uniqueKeysWithValues: segs.sorted { $0.start < $1.start }
            .enumerated().map { ($1.id, $0) })

        return GeometryReader { geo in
            let trackWidth = max(40, geo.size.width - Self.gutter)
            ZStack(alignment: .topLeading) {
                hourGrid(window: window, width: geo.size.width)

                // **하루는 한 줄이다.** 알약과 알약 사이의 빈 시간은 앞 일정의 색에서 다음 일정의 색으로
                // 번지는 선으로 잇는다. 하루의 처음과 끝은 투명하게 스러진다.
                ForEach(connectors(laned, lanes: lanes, window: window)) { c in
                    connectorView(c)
                }

                ForEach(segs) { seg in
                    if let box = frame(for: seg, window: window, base: base, lanes: lanes, trackWidth: trackWidth) {
                        let i = order[seg.id] ?? 0
                        DaySegmentRow(segment: seg,
                                      size: box.size,
                                      symbol: day.icon(for: seg),
                                      status: day.status(for: seg),
                                      isPast: isPast(seg))
                            // 누르면 그 일로 타이머가 선다 (→ TimerView.swift).
                            // 길이는 일정에 적힌 그대로, 오늘이면 남은 만큼부터 센다.
                            .onTapGesture { startTimer(for: seg) }
                            .offset(x: Self.gutter + box.minX, y: box.minY)
                            .zIndex(seg.isNested || seg.isFlexible ? 2 : 1)
                            // 하루가 설 때 위에서부터 하나씩 톡톡 튀어 오른다.
                            .scaleEffect(drawn ? 1 : 0.92, anchor: .leading)
                            .opacity(drawn ? 1 : 0)
                            .animation(reduceMotion ? nil : Self.squish.delay(Double(min(i, 16)) * 0.03),
                                       value: drawn)
                    }
                }

                if isToday { nowLine(window: window) }
            }
        }
        .frame(height: CGFloat(window.span) * Self.hourHeight + Self.minRowHeight / 2)
    }

    /// 정시마다 아주 옅은 선, 3시간마다 시각 글씨를 조금 더 또렷하게.
    private func hourGrid(window: HourWindow, width: CGFloat) -> some View {
        let lo = Int(window.start.rounded(.up)), hi = Int(window.end.rounded(.down))
        return ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: lo, through: hi, by: 1)), id: \.self) { h in
                HStack(spacing: 8) {
                    Text(formatClock(Double(h)))
                        .font(.system(size: 10, weight: h % 3 == 0 ? .semibold : .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(h % 3 == 0 ? .secondary : .tertiary)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: Self.gutter - 10, alignment: .trailing)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 1)
                        .padding(.leading, Self.pillWidth + 8)
                }
                .offset(y: y(Double(h), window) - 6)
            }
        }
        .frame(width: width, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 지금 — 오늘이면 붉은 선 하나와 둥근 시각 알약. 하루 어디까지 왔는지가 이 한 줄로 읽힌다.
    @ViewBuilder
    private func nowLine(window: HourWindow) -> some View {
        if nowHour >= window.start, nowHour <= window.end {
            let top = y(nowHour, window)
            ZStack(alignment: .topLeading) {
                // 스크롤이 찾아갈 자리. offset은 배치를 안 옮기므로 여백으로 실제 높이에 세운다.
                Color.clear
                    .frame(width: 1, height: 1)
                    .padding(.top, top)
                    .id(Self.nowID)

                HStack(spacing: 0) {
                    Text(formatClock(nowHour))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .shadow(color: .red.opacity(0.3), radius: 3, y: 1)
                        .frame(width: Self.gutter - 4, alignment: .trailing)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
                        .padding(.leading, Self.pillWidth / 2 - 2)
                    Capsule()
                        .fill(Color.red.opacity(0.7))
                        .frame(height: 2)
                }
                .offset(y: top - 7)
                .animation(Self.squish, value: nowHour)
            }
            .allowsHitTesting(false)
            .zIndex(4)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: formatClock(nowHour)))
        }
    }

    // MARK: 빈 시간

    /// 알약과 알약 사이를 잇는 다리 한 토막.
    struct Connector: Identifiable {
        let id: String
        let top: CGFloat
        let bottom: CGFloat
        let from: Color
        let to: Color
        /// 실제로 비어 있는 시간(h). 알약이 최소 키만큼 서서 화면의 길이와는 조금 다르다.
        let hours: Double
        /// 빈 시간이 끝나는 시각. 이미 지나간 빈 시간에는 조각을 권하지 않는다.
        var endHour: Double = 24
        /// 위아래 끝이 꽉 찬 알약에 닿는가. 점선 알약(속이 비침)에는 목을 붙이지 않는다.
        var joinsTop = true
        var joinsBottom = true
        /// 지나간 알약에 닿은 끝은 알약처럼 흐리게.
        var dimsTop = false
        var dimsBottom = false
        /// 몇 번째로 드러나는가 — 위쪽 알약이 선 뒤에 늘어난다.
        var order = 0

        /// 하루의 첫머리·끝머리 — 이어 줄 일정이 없는 쪽은 투명하게 스러진다.
        var fadesTop: Bool { !joinsTop }
        var fadesBottom: Bool { !joinsBottom }
    }

    /// 등뼈 위에 서는 일정(첫 칸) 사이의 빈자리를 찾는다 (→ 맥 DayScheduleView.connectors).
    ///
    /// 옆 칸으로 밀려난 겹친 일정과 루틴 위에 얹힌 일정은 등뼈 위에 있지 않으므로 잇지 않는다 —
    /// 그것들은 이미 등뼈 위의 어떤 일정과 같은 시각에 있어 빈 시간이 아니다.
    private func connectors(_ laned: [TimeSegment], lanes: [String: Lane], window: HourWindow) -> [Connector] {
        let spine = laned
            .filter { (lanes[$0.id]?.index ?? 0) == 0 }
            .compactMap { seg -> (top: CGFloat, bottom: CGFloat, seg: TimeSegment)? in
                guard let vis = window.clamp(seg.start, seg.end) else { return nil }
                let top = y(vis.start, window)
                return (top, top + max(Self.minRowHeight, y(vis.end, window) - y(vis.start, window) - 3), seg)
            }
            .sorted { $0.top < $1.top }

        let dayTop = y(window.start, window)
        let dayBottom = y(window.end, window)
        guard let first = spine.first else {
            return [Connector(id: "empty", top: dayTop, bottom: dayBottom,
                              from: .secondary, to: .secondary, hours: window.span,
                              endHour: window.end, joinsTop: false, joinsBottom: false)]
        }

        var result: [Connector] = []
        // 하루의 첫머리 — 첫 일정 색이 위에서부터 차오른다.
        if first.top > dayTop + 2 {
            result.append(Connector(id: "head", top: dayTop, bottom: first.top,
                                    from: first.seg.color, to: first.seg.color,
                                    hours: max(0, first.seg.start - window.start),
                                    endHour: first.seg.start, joinsTop: false, joinsBottom: !first.seg.isFlexible,
                                    dimsBottom: isPast(first.seg)))
        }
        var reach = first
        var reachHour = first.seg.end
        for (i, item) in spine.enumerated().dropFirst() {
            if item.top > reach.bottom + 2 {
                result.append(Connector(id: "gap:\(item.seg.id)", top: reach.bottom, bottom: item.top,
                                        from: reach.seg.color, to: item.seg.color,
                                        hours: max(0, item.seg.start - reachHour),
                                        endHour: item.seg.start, joinsTop: !reach.seg.isFlexible, joinsBottom: !item.seg.isFlexible,
                                        dimsTop: isPast(reach.seg), dimsBottom: isPast(item.seg),
                                        order: i))
            }
            if item.bottom >= reach.bottom { reach = item }
            reachHour = max(reachHour, item.seg.end)
        }
        // 하루의 끝머리 — 마지막 일정 색이 아래로 스러진다.
        if dayBottom > reach.bottom + 2 {
            result.append(Connector(id: "tail", top: reach.bottom, bottom: dayBottom,
                                    from: reach.seg.color, to: reach.seg.color,
                                    hours: max(0, window.end - reachHour),
                                    endHour: window.end, joinsTop: !reach.seg.isFlexible, joinsBottom: false,
                                    dimsTop: isPast(reach.seg), order: spine.count))
        }
        return result
    }

    /// 빈 시간 한 토막 — **쫀득하게 늘어난 다리**, 그리고 30분이 넘으면 가운데에 "빈 시간 1시간 30분".
    ///
    /// 가는 선을 알약 밑에 찔러 넣었더니 이음매가 꼬챙이처럼 보였다. 알약에 닿는 끝은 알약 폭으로
    /// 퍼졌다가 오목하게 좁아져 목이 되고, 다음 알약 앞에서 다시 퍼진다 — 떡을 늘인 모양.
    /// 빈 시간이 짧을수록 목이 굵다(덜 늘어났다). 하루가 설 때 위 알약에서 아래로 쭉 늘어난다.
    private func connectorView(_ c: Connector) -> some View {
        let gap = max(0, c.bottom - c.top)
        let radius = Self.pillWidth / 2
        // 알약에 닿는 끝은 알약 반지름만큼 파고들어 둥근 끝을 감싼다. 안 닿는 끝은 그대로.
        let tuckTop: CGFloat = c.joinsTop ? radius : (c.fadesTop ? 0 : 12)
        let tuckBottom: CGFloat = c.joinsBottom ? radius : (c.fadesBottom ? 0 : 12)
        let height = gap + tuckTop + tuckBottom
        // 목이 퍼지는 길이 — 알약 안(반지름) + 밖으로 조금. 둘이 붙어 있으면 밖 몫이 줄어든다.
        let spread = min(14, gap / 2)
        let flareTop = c.joinsTop ? radius + spread : 0
        let flareBottom = c.joinsBottom ? radius + spread : 0
        // 짧게 비면 굵게, 길게 비면 가늘게 — 4pt까지.
        let neck = 4 + 10 * exp(-gap / 40)

        let end: Double = 0.85, waist: Double = 0.42
        let topOpacity = (c.joinsTop ? end : 0) * (c.dimsTop ? 0.5 : 1)
        let bottomOpacity = (c.joinsBottom ? end : 0) * (c.dimsBottom ? 0.5 : 1)
        let waistTop = (c.fadesTop ? waist * 0.6 : waist) * (c.dimsTop ? 0.5 : 1)
        let waistBottom = (c.fadesBottom ? waist * 0.6 : waist) * (c.dimsBottom ? 0.5 : 1)
        let upper = height > 0 ? min(0.5, max(flareTop, tuckTop + 6) / height) : 0
        let lower = height > 0 ? max(0.5, 1 - max(flareBottom, tuckBottom + 6) / height) : 1
        let showsLabel = c.hours >= 0.5 && gap >= 30

        return ZStack(alignment: .topLeading) {
            GooeyBridge(topFlare: flareTop, bottomFlare: flareBottom, neck: neck)
                .fill(LinearGradient(
                    stops: [
                        .init(color: c.from.opacity(topOpacity), location: 0),
                        .init(color: c.from.opacity(waistTop), location: upper),
                        .init(color: c.to.opacity(waistBottom), location: lower),
                        .init(color: c.to.opacity(bottomOpacity), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: Self.pillWidth, height: height)
                // 위 알약에서 아래로 쭉 늘어났다가 한 번 출렁이고 멎는다.
                .scaleEffect(x: 1, y: drawn ? 1 : 0.15, anchor: .top)
                .opacity(drawn ? 1 : 0)
                .animation(reduceMotion ? nil : Self.stretch.delay(0.08 + Double(min(c.order, 16)) * 0.03),
                           value: drawn)
                .offset(x: Self.gutter, y: c.top - tuckTop)

            if showsLabel {
                // 오늘의 아직 안 지난 빈 시간이면, 그 안에 들어가는 조각이 몇 개인지 함께 적는다 —
                // 빈 시간이 '비어 있다'에서 '이걸 집을 수 있다'로 읽힌다.
                let fits = isToday && c.endHour > nowHour ? pickupsFitting(hours: c.hours) : 0
                HStack(spacing: 4) {
                    Text("빈 시간 \(formatHours(c.hours))")
                        .foregroundStyle(.tertiary)
                    if fits > 0 {
                        Label("조각 \(fits)개", systemImage: "bolt.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .fixedSize()
                .offset(x: Self.gutter + Self.pillWidth + 10, y: c.top + gap / 2 - 7)
                .opacity(drawn ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25).delay(0.2), value: drawn)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: 자리 셈

    private func y(_ hour: Double, _ window: HourWindow) -> CGFloat {
        CGFloat(hour - window.start) * Self.hourHeight
    }

    /// 루틴 안 일정, 다른 일정 위에 겹친 끼니·일정 — 칸을 따로 갖지 않고 오른쪽에 얹힌다.
    private static func overlaysOther(_ seg: TimeSegment, base: [TimeSegment]) -> Bool {
        seg.isNested
            || (seg.isFlexible && base.contains { $0.start < seg.end - 1e-6 && seg.start < $0.end - 1e-6 })
    }

    /// 조각 하나가 놓일 자리 (시각 칸 오른쪽 기준). 창 밖으로 나가면 nil.
    private func frame(for seg: TimeSegment, window: HourWindow, base: [TimeSegment],
                       lanes: [String: Lane], trackWidth w: CGFloat) -> CGRect? {
        guard let vis = window.clamp(seg.start, seg.end) else { return nil }
        let top = y(vis.start, window)
        // 짧은 일도 알약 하나와 글씨 한 줄은 들어간다. 겹칠 몫은 칸 나누기가 미리 셌다.
        let height = max(Self.minRowHeight, y(vis.end, window) - y(vis.start, window) - 3)

        if Self.overlaysOther(seg, base: base) {
            let x = w * 0.45
            return CGRect(x: x, y: top, width: max(Self.pillWidth, w - x), height: height)
        }
        guard let lane = lanes[seg.id], lane.count > 1 else {
            return CGRect(x: 0, y: top, width: w, height: height)
        }
        let gap: CGFloat = 8
        let columnWidth = (w - gap * CGFloat(lane.count - 1)) / CGFloat(lane.count)
        return CGRect(x: CGFloat(lane.index) * (columnWidth + gap), y: top, width: columnWidth, height: height)
    }

    struct Lane {
        let index: Int
        let count: Int
    }

    /// 겹치는 일정은 옆으로 나란히 세운다. id → (몇 번째 칸, 모두 몇 칸). 맥과 같은 셈이다.
    ///
    /// 서로 이어 겹치는 **묶음마다** 칸 수를 따로 센다 — 오전에 둘이 겹쳤다고 오후 일정까지
    /// 반쪽이 되지 않게.
    /// - Parameter minHours: 짧은 일도 화면에서는 이만큼 차지한다. 시각으로는 안 겹쳐도
    ///   알약이 겹쳐 보이면 나란히 세운다.
    static func lanes(_ segs: [TimeSegment], minHours: Double = 0) -> [String: Lane] {
        var result: [String: Lane] = [:]
        var cluster: [(id: String, lane: Int)] = []
        var laneEnds: [Double] = []
        var clusterEnd = -Double.infinity

        func flush() {
            for item in cluster { result[item.id] = Lane(index: item.lane, count: laneEnds.count) }
            cluster = []
            laneEnds = []
        }

        for seg in segs.sorted(by: { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }) {
            if seg.start >= clusterEnd - 1e-6 {
                flush()
                clusterEnd = -Double.infinity
            }
            let lane: Int
            let end = max(seg.end, seg.start + minHours)
            if let open = laneEnds.firstIndex(where: { $0 <= seg.start + 1e-6 }) {
                laneEnds[open] = end
                lane = open
            } else {
                laneEnds.append(end)
                lane = laneEnds.count - 1
            }
            cluster.append((seg.id, lane))
            clusterEnd = max(clusterEnd, end)
        }
        flush()
        return result
    }

    /// 이 조각으로 타이머를 켠다. 하루 화면이 타이머로 가는 단 하나의 문이다.
    private func startTimer(for seg: TimeSegment) {
        let midnight = Calendar.current.startOfDay(for: date)
        let slot = ScheduleSlot(id: "\(date.timeIntervalSince1970):\(seg.id)",
                                title: seg.title,
                                iconName: day.icon(for: seg) ?? "timer",
                                colorHex: day.routineColors[seg.title],
                                start: midnight.addingTimeInterval(seg.start * 3600),
                                end: midnight.addingTimeInterval(seg.end * 3600),
                                isFlexible: seg.isFlexible)
        // 오늘이 아니면 '남은 시간'이라는 말이 성립하지 않는다 — 적힌 길이를 통째로 센다.
        TimerStarter.start(slot: slot, from: isToday ? Date() : slot.start)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func isPast(_ segment: TimeSegment) -> Bool {
        isToday && nowHour >= segment.end
    }

    // MARK: - 매여 있는 일

    /// **마감까지 붙잡고 있지만 오늘 시각은 안 정한 덩어리.**
    ///
    /// 무지개는 마감까지 줄을 긋는데 이 시계는 '손대는 날'만 그려서, 9일 뒤 마감인 일이
    /// 그 전 8일 동안 하루 화면 어디에도 없었다. 안 보이면 머리가 대신 들고 있어야 한다.
    /// 그렇다고 시각이 없는 일을 시계에 박으면 거짓이 되므로, 시계 **위에** 따로 걸어 둔다.
    /// 오늘 시간을 먹는 것이 아니니 남는 시간에서는 빼지 않는다.
    private var carriedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 11, weight: .bold))
                Text("매여 있는 일")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text("오늘 시각은 안 정함")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)

            ForEach(day.carried) { item in
                HStack(spacing: 10) {
                    DayGlyph(symbol: nil, title: item.title, color: item.color, size: 28, dashed: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        Text(verbatim: [formatShortDate(item.end), item.stepPhrase]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    dDayPill(item.daysLeft)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// "D-9". 가까울수록 급한 색 — 사흘 안이면 주황, 내일·오늘이면 빨강.
    private func dDayPill(_ days: Int) -> some View {
        let tint: Color = days <= 1 ? .red : (days <= 3 ? .orange : .secondary)
        return Text(verbatim: days <= 0 ? "D-day" : "D-\(days)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }

    // MARK: - 조각

    /// **빈 시간에 집을 수 있는 조각.** 시계에 자리를 잡지 않는다 — 조각은 언제 할지 정하는 일이
    /// 아니라 틈이 나면 집는 일이라서. 대신 빈 시간 다리 옆에 "조각 3개"로 걸리고, 무엇인지는 여기 모인다.
    /// 무엇이 지금 손댈 수 있는 조각인지는 번개 위젯과 같은 규칙이다 (→ TodoWidgetSync.makeFragments).
    private var pickupSection: some View {
        let shown = day.pickups.prefix(5)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("빈 시간에 집을 조각")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(.orange)

            ForEach(shown) { item in
                HStack(spacing: 10) {
                    DayGlyph(symbol: item.isMarked ? "bolt.fill" : "bolt", title: item.title,
                             color: item.color, size: 28, dashed: !item.isMarked)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        if let parent = item.parentTitle {
                            Text(parent)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 6)
                    if item.minutes > 0 {
                        Text("\(item.minutes)분")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    if let days = item.daysLeft { dDayPill(days) }
                }
                .accessibilityElement(children: .combine)
            }

            if day.pickups.count > shown.count {
                Text("외 \(day.pickups.count - shown.count)개")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    /// 이만큼의 빈 시간에 통째로 들어가는 조각 수. 시간을 안 잡은 조각은 어디든 들어간다고 본다.
    private func pickupsFitting(hours: Double) -> Int {
        let minutes = Int((hours * 60).rounded())
        return day.pickups.filter { $0.minutes <= minutes }.count
    }

    // MARK: - 못 들어간 일정

    private var overflow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("하루에 안 들어갔어요", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.red)

            ForEach(day.unplaced) { event in
                HStack(spacing: 10) {
                    DayGlyph(symbol: nil, title: event.title, color: event.color, size: 28, dashed: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text(formatHours(event.hours))
                            .font(.system(size: 12, design: .rounded))
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    private var unavailableNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("하루 뼈대를 못 읽었어요", systemImage: "icloud.slash")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("수면·출근 같은 고정 루틴은 맥앱 ‘무지개 공방’에 적어 둔 것을 iCloud로 읽어 옵니다. iCloud에 로그인되어 있는지 확인해주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var footnote: some View {
        Text("점선 알약은 시각이 정해지지 않은 것입니다 — 빈 자리에 놓아 본 자리예요. 정확한 시각은 맥앱 ‘무지개 공방’에서 끌어 옮길 수 있습니다.")
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
        let stored = storedEvents()
        let ownEvents = stored.filter { $0.occursOn(date: date) }
        let flexible = ownEvents.map { event in
            TimelineLayout.FlexibleEvent(id: event.laneKey,
                                         title: event.title,
                                         hours: max(0.25, event.hoursPerDay),
                                         color: laneColor(for: event))
        }

        var result = TimelineLayout.segments(
            routines: input.fixedRoutines,
            blocks: input.blocks,
            quota: input.quotaRoutines,
            routineStartOverride: input.routineStartOverride,
            quotaPlacement: input.quotaPlacement,
            quotaHidden: input.quotaHidden,
            flexibleEvents: flexible
        )

        // **무지개와 같은 색으로 칠한다.**
        //
        // 같은 계획이 무지개에서는 제 줄 색(빨강·주황·…)인데 여기서는 파랑 하나였다.
        // 두 화면이 같은 것을 다른 색으로 부르면, 무지개에서 눈에 익은 줄을 하루 화면에서
        // 다시 찾아야 한다. 색은 그 일의 이름표다 — 한 벌이어야 한다.
        //
        // 무지개가 그 계획에 준 색은 **줄(레인) 배정**에서 나온다 (→ ScheduleViewModel.assignLanesToEvents).
        // 그래서 여기서 새로 정하지 않고, 그 날 무지개에 서 있는 미러 일정에서 받아 온다.
        let rainbowColors = planColorsFromRainbow()
        result.segments = result.segments.map { seg in
            guard seg.kind == .planBlock, let color = rainbowColors[seg.title] else { return seg }
            return TimeSegment(id: seg.id, start: seg.start, end: seg.end, color: color,
                               title: seg.title, isRoutine: seg.isRoutine,
                               isFlexible: seg.isFlexible, isNested: seg.isNested,
                               kind: seg.kind, subtitle: seg.subtitle)
        }

        let window = TimelineLayout.visibleWindow(fixedRoutines: input.fixedRoutines,
                                                  blocks: input.blocks,
                                                  hideSleep: hideSleep)

        // 겹친 시간은 한 번만 센다 (맥과 같은 규칙).
        let occupied = TimelineLayout.unionLength(
            result.segments.filter { !$0.isNested }.map { ($0.start, $0.end) })

        // 알약 속 그림은 루틴이 고른 아이콘. 조각은 이름만 들고 있으므로 이름으로 찾는다.
        var icons: [String: String] = [:]
        var colors: [String: String] = [:]
        for r in input.fixedRoutines + input.quotaRoutines {
            icons[r.name] = r.iconName
            colors[r.name] = paletteHex(r.colorName)
        }

        // 맥에서 찍은 회고 표시. 조각 id는 "block:<블록>:<토막>" 이라 가운데 몫으로 찾는다.
        var statuses: [String: ReviewStatus] = [:]
        for blk in input.blocks {
            if let status = blk.reviewStatus { statuses[String(describing: blk.persistentModelID)] = status }
        }

        // 할 일 쪽 — 매여 있는 일이 무슨 일인지, 지금 집을 조각이 무엇인지.
        let todos = todoItems()
        let tree = TodoTree(todos)
        let todoByToken = Dictionary(todos.map { ($0.dragToken, $0) }, uniquingKeysWith: { first, _ in first })
        let calendar = Calendar.current
        let day0 = calendar.startOfDay(for: date)
        func daysLeft(_ end: Date) -> Int {
            calendar.dateComponents([.day], from: day0, to: calendar.startOfDay(for: end)).day ?? 0
        }
        func isFragment(_ item: BacklogItem) -> Bool {
            TodoSplitAdvisor.advice(title: item.title, durationHours: item.durationHours,
                                    pick: item.fragmentPick).isFragment
        }

        // 기간 안인데 오늘은 손대는 날이 아닌 줄. 끝낸 일, 쪼개지 않은 조각 하나짜리는 매여 있지 않다.
        // 끝없이 반복하는 일정은 마감이 없어 '매여 있다'가 아니라 습관이다 — 여기 세우면 늘 떠 있는 잡음이 된다.
        var carried: [Carried] = []
        for event in stored where !event.isInfinite && event.spansOn(date: date) && !event.occursOn(date: date) {
            let todo = event.todoToken.flatMap { todoByToken[$0] }
            if let todo {
                if todo.isCompleted { continue }
                if !tree.hasChildren(todo), isFragment(todo) { continue }
            }
            carried.append(Carried(id: event.laneKey,
                                   title: event.title,
                                   color: laneColor(for: event),
                                   end: event.effectiveEndDate(),
                                   daysLeft: daysLeft(event.effectiveEndDate()),
                                   stepPhrase: todo.flatMap { tree.stepProgressPhrase(of: $0) }))
        }
        carried.sort { $0.daysLeft < $1.daysLeft }

        // 조각은 '지금'의 일이라 오늘에만 세운다. 목록 범위는 번개 위젯과 같다 — 이번 주 + 밀린 일.
        var pickups: [Pickup] = []
        if isToday {
            let categories = todoCategories()
            let weekStart = Date().weekStart()
            let deadlineByToken = Dictionary(stored.compactMap { e in e.todoToken.map { ($0, e.effectiveEndDate()) } },
                                             uniquingKeysWith: { first, _ in first })
            var seen = Set<String>()
            let roots = tree.roots.filter {
                !$0.isCompleted && ($0.weekStartDate <= weekStart || calendar.isDate($0.weekStartDate, inSameDayAs: weekStart))
            }
            for root in roots {
                let color = root.categoryID.flatMap { categories[$0] }.map { paletteColor($0.colorName) } ?? .orange
                for step in tree.availableSteps(of: root) where !tree.hasChildren(step) && isFragment(step) {
                    guard seen.insert(step.dragToken).inserted else { continue }
                    pickups.append(Pickup(id: step.dragToken,
                                          title: step.title,
                                          parentTitle: step.dragToken == root.dragToken ? nil : root.title,
                                          color: color,
                                          minutes: Int((max(0, step.durationHours) * 60).rounded()),
                                          isMarked: step.isMarkedNow,
                                          daysLeft: deadlineByToken[root.dragToken].map(daysLeft)))
                }
            }
            // 사람이 표시한 것 → 마감이 가까운 것 → 적어 둔 순서.
            pickups = pickups.enumerated().sorted { l, r in
                if l.element.isMarked != r.element.isMarked { return l.element.isMarked }
                let ld = l.element.daysLeft ?? .max, rd = r.element.daysLeft ?? .max
                if ld != rd { return ld < rd }
                return l.offset < r.offset
            }.map(\.element)
        }

        return DayContent(segments: result.segments,
                          unplaced: result.unplaced,
                          window: window,
                          occupiedHours: occupied,
                          isAvailable: input.isAvailable,
                          routineIcons: icons,
                          routineColors: colors,
                          blockStatuses: statuses,
                          carried: carried,
                          pickups: pickups)
    }

    /// 할 일 전부 — 남이 잠근 채 적은 줄은 뺀다 (할 일 목록과 같은 거름).
    private func todoItems() -> [BacklogItem] {
        guard let context = TodoEventBridge.shared.todoContainer?.mainContext else { return [] }
        let descriptor = FetchDescriptor<BacklogItem>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return ((try? context.fetch(descriptor)) ?? []).filter(TodoSharing.isVisible)
    }

    /// 분류 id → 분류.
    private func todoCategories() -> [String: BacklogCategory] {
        guard let context = TodoEventBridge.shared.todoContainer?.mainContext else { return [:] }
        let all = (try? context.fetch(FetchDescriptor<BacklogCategory>())) ?? []
        return Dictionary(all.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 이 앱에 저장된 일정만.
    private func storedEvents() -> [Event] {
        guard let context = TodoEventBridge.shared.eventContainer?.mainContext else { return [] }
        let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.startDate)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 그 날 무지개에 서 있는 계획들의 색 (제목 → 줄 색).
    ///
    /// 맥 계획은 무지개에 '미러 일정'으로 서고, 줄 색은 거기서 이미 정해져 있다.
    /// ⚠️ 제목으로 맞춘다 — 미러 일정과 계획 블록을 잇는 안정적인 열쇠가 아직 없다
    ///    (→ WeekBlocksStore의 머리주석, "제목으로 맞추지 말 것"은 **쓰는 쪽** 이야기다.
    ///    여기서는 색 하나를 고르는 일이라, 같은 제목이 둘이면 같은 색이 되는 정도가 전부다).
    private func planColorsFromRainbow() -> [String: Color] {
        var result: [String: Color] = [:]
        for event in viewModel.fetchEvents() where event.occursOn(date: date) {
            // 이 앱에서 직접 만든 일정은 아래 `flexible`로 따로 들어간다. 여기서 찾는 것은
            // 맥에서 비춰 온 계획뿐이다 — 그것만 제목으로 계획 블록과 짝이 된다.
            guard event.mirrorKey != nil else { continue }
            result[event.title] = laneColor(for: event)
        }
        return result
    }

    private func laneColor(for event: Event) -> Color {
        if let lane = viewModel.eventLaneAssignments[event.laneKey],
           lane >= 0, lane < ScheduleViewModel.laneColors.count,
           let color = Color(hex: ScheduleViewModel.laneColors[lane]) {
            return color
        }
        return .blue
    }

    struct Carried: Identifiable {
        let id: String
        let title: String
        let color: Color
        let end: Date
        let daysLeft: Int
        /// "3단계 중 2번째". 할 일로 가져와 쪼갠 일에만.
        let stepPhrase: String?
    }

    struct Pickup: Identifiable {
        let id: String
        let title: String
        /// 무슨 일의 일부인지. 안 쪼갠 줄이면 nil.
        let parentTitle: String?
        let color: Color
        /// 0이면 시간을 안 잡은 조각.
        let minutes: Int
        /// 사용자가 '바로 하면 되는 일'로 표시했나.
        let isMarked: Bool
        /// 이 조각이 속한 일의 마감까지 남은 날.
        let daysLeft: Int?
    }

    /// 계산해 둔 하루.
    struct DayContent {
        var segments: [TimeSegment] = []
        var unplaced: [TimelineLayout.FlexibleEvent] = []
        var window: HourWindow = .full
        var occupiedHours: Double = 0
        var isAvailable = false
        /// 루틴 이름 → 아이콘.
        var routineIcons: [String: String] = [:]
        /// 루틴 이름 → 색(hex). 타이머가 그 루틴 색으로 서게 한다.
        var routineColors: [String: String] = [:]
        /// 계획 블록 id → 맥에서 찍은 회고 표시.
        var blockStatuses: [String: ReviewStatus] = [:]
        /// 마감까지 매여 있지만 오늘 시각은 없는 덩어리.
        var carried: [Carried] = []
        /// 오늘 빈 시간에 집을 수 있는 조각.
        var pickups: [Pickup] = []

        var freeHours: Double { max(0, 24 - occupiedHours) }
        var load: Double { occupiedHours / 24 }

        func icon(for seg: TimeSegment) -> String? {
            switch seg.kind {
            case .routine, .quota: routineIcons[seg.title]
            case .planBlock, .rainbowEvent: nil
            }
        }

        func status(for seg: TimeSegment) -> ReviewStatus? {
            guard seg.kind == .planBlock else { return nil }
            for prefix in ["block:", "nested:"] where seg.id.hasPrefix(prefix) {
                let body = seg.id.dropFirst(prefix.count)
                guard let cut = body.lastIndex(of: ":") else { return nil }
                return blockStatuses[String(body[..<cut])]
            }
            return nil
        }
    }

    // MARK: - 글자

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        // 형식은 템플릿으로만 말한다 — 낱말과 순서는 기기 언어가 정한다.
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0,
                                                    locale: .autoupdatingCurrent)
        formatter.locale = Locale.autoupdatingCurrent
        return formatter.string(from: date)
    }

    /// "9월 26일까지".
    private func formatShortDate(_ date: Date) -> String {
        String(localized: "\(formatDateFull(date))까지")
    }

    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        // 형식은 템플릿으로만 말한다 — 낱말과 순서는 기기 언어가 정한다.
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEEE", options: 0,
                                                    locale: .autoupdatingCurrent)
        formatter.locale = Locale.autoupdatingCurrent
        return formatter.string(from: date)
    }
}

// MARK: - 한 줄

/// 알약 + 시각·제목 + (찍혀 있으면) 둥근 체크. 맥 일간의 한 줄과 같은 모양이다.
private struct DaySegmentRow: View {
    let segment: TimeSegment
    let size: CGSize
    let symbol: String?
    let status: ReviewStatus?
    let isPast: Bool

    private static let pillWidth: CGFloat = 34

    private var done: Bool { status == .done }

    var body: some View {
        // 넓으면 알약 + 시각·제목 + 표시, 좁으면 알약 + 제목, 아주 좁으면 알약만.
        let showsText = size.width >= Self.pillWidth + 44
        let showsTime = size.width >= Self.pillWidth + 110
        let showsStatus = status != nil && size.width >= Self.pillWidth + 90

        HStack(alignment: .top, spacing: 10) {
            pill

            if showsText {
                VStack(alignment: .leading, spacing: 1) {
                    if showsTime {
                        Text(verbatim: timeRange)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(segment.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .strikethrough(done, color: .secondary)
                        .foregroundStyle(done ? .secondary : .primary)
                        .lineLimit(size.height >= 60 ? 2 : 1)
                }
                .padding(.top, 3)
                .padding(.trailing, showsStatus ? 30 : 4)
                .opacity(isPast ? 0.5 : 1)
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if showsStatus, let status {
                StatusMark(status: status, color: segment.color)
                    .padding(.top, 7)
                    .padding(.trailing, 2)
                    .opacity(isPast ? 0.5 : 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [segment.title, timeRange, status?.label]
            .compactMap { $0 }.joined(separator: ", ")))
    }

    /// **알약.** 길이가 곧 걸리는 시간이고, 색과 그림이 곧 무엇인지다.
    private var pill: some View {
        let shape = Capsule(style: .continuous)
        let tint = segment.color
        return ZStack(alignment: .top) {
            // 알약 밑은 늘 불투명하게 막는다 — 밑으로 파고든 다리가 비쳐 알약 허리에 금이 가지 않게.
            // 지나간 일정도 알약 **색만** 흐려지고 이 바탕은 그대로다.
            shape.fill(Color(.systemBackground))
            Group {
                if segment.isFlexible {
                    // 시각이 유연한 것은 옅게 채우고 점선 — 정해진 자리가 아니라는 뜻이 모양에 있다.
                    shape.fill(tint.opacity(0.3))
                    shape.strokeBorder(tint.opacity(0.75), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                } else {
                    shape.fill(tint.gradient)
                        .opacity(done ? 0.55 : (segment.isRoutine ? 0.85 : 1))
                }

                glyph
                    .foregroundStyle(segment.isFlexible ? tint : .white)
                    .frame(width: Self.pillWidth, height: Self.pillWidth)
            }
            .opacity(isPast ? 0.5 : 1)
        }
        .frame(width: Self.pillWidth, height: max(Self.pillWidth, size.height))
        .shadow(color: segment.isFlexible ? .clear : tint.opacity(isPast ? 0.1 : 0.22), radius: 3, y: 2)
    }

    @ViewBuilder
    private var glyph: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
        } else {
            Text(verbatim: DayGlyph.letter(of: segment.title))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
        }
    }

    /// "9:00–18:00 · 9시간".
    private var timeRange: String {
        "\(formatClock(segment.start))–\(formatClock(segment.end)) · \(formatHours(segment.hours))"
    }
}

/// 색 동그라미 안의 흰 그림이나 첫 글자 — 알약 밖(못 들어간 일정 등)에서 무엇인지를 말한다.
private struct DayGlyph: View {
    let symbol: String?
    let title: String
    let color: Color
    var size: CGFloat = 24
    var dashed = false

    static func letter(of title: String) -> String {
        title.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "•"
    }

    var body: some View {
        ZStack {
            if dashed {
                Circle().fill(color.opacity(0.22))
                Circle().strokeBorder(color.opacity(0.75), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
            } else {
                Circle().fill(color.gradient)
            }
            Group {
                if let symbol {
                    Image(systemName: symbol)
                } else {
                    Text(verbatim: Self.letter(of: title))
                }
            }
            .font(.system(size: size * 0.46, weight: .heavy, design: .rounded))
            .foregroundStyle(dashed ? color : .white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// **떡을 늘인 다리.** 위아래 끝은 알약 폭으로 퍼져 있다가 오목한 곡선으로 좁아져 목이 된다.
///
/// 곡선의 조절점을 끝 쪽에 붙여 두어 알약의 둥근 끝보다 늘 조금 바깥을 지난다 — 알약과 다리가
/// 따로 놓인 두 조각이 아니라 한 덩어리가 늘어난 것으로 읽힌다. 퍼짐이 0인 끝은 목 굵기 그대로 끝난다.
private struct GooeyBridge: Shape {
    var topFlare: CGFloat
    var bottomFlare: CGFloat
    var neck: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(topFlare, bottomFlare), neck) }
        set {
            topFlare = newValue.first.first
            bottomFlare = newValue.first.second
            neck = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let half = min(neck, rect.width) / 2
        let left = rect.midX - half, right = rect.midX + half
        let top = min(topFlare, rect.height / 2)
        let bottom = min(bottomFlare, rect.height / 2)

        var p = Path()
        // 왼쪽 — 위 끝에서 목으로
        if top > 0 {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addCurve(to: CGPoint(x: left, y: rect.minY + top),
                       control1: CGPoint(x: rect.minX, y: rect.minY + top * 0.55),
                       control2: CGPoint(x: left, y: rect.minY + top * 0.5))
        } else {
            p.move(to: CGPoint(x: left, y: rect.minY))
        }
        // 목에서 아래 끝으로, 바닥을 건너
        p.addLine(to: CGPoint(x: left, y: rect.maxY - bottom))
        if bottom > 0 {
            p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                       control1: CGPoint(x: left, y: rect.maxY - bottom * 0.5),
                       control2: CGPoint(x: rect.minX, y: rect.maxY - bottom * 0.55))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addCurve(to: CGPoint(x: right, y: rect.maxY - bottom),
                       control1: CGPoint(x: rect.maxX, y: rect.maxY - bottom * 0.55),
                       control2: CGPoint(x: right, y: rect.maxY - bottom * 0.5))
        } else {
            p.addLine(to: CGPoint(x: right, y: rect.maxY))
        }
        // 오른쪽 — 목에서 위 끝으로
        p.addLine(to: CGPoint(x: right, y: rect.minY + top))
        if top > 0 {
            p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control1: CGPoint(x: right, y: rect.minY + top * 0.5),
                       control2: CGPoint(x: rect.maxX, y: rect.minY + top * 0.55))
        } else {
            p.addLine(to: CGPoint(x: right, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}

/// 맥에서 찍어 둔 표시 — 그 색으로 꽉 찬 동그라미에 흰 표시 (맥의 SoftCheck가 찍힌 모양).
/// 아이폰은 맥 계획표를 읽기만 하므로 누르는 단추가 아니다. 빈 동그라미도 그리지 않는다 —
/// 눌러지지 않는 빈칸은 눌러 보라는 거짓말이다.
private struct StatusMark: View {
    let status: ReviewStatus
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().fill(tint)
            Image(systemName: symbol)
                .font(.system(size: size * 0.45, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.35), radius: 3, y: 1.5)
        .accessibilityHidden(true)
    }

    private var symbol: String {
        switch status {
        case .partial: "circle.lefthalf.filled"
        case .skipped: "xmark"
        case .done: "checkmark"
        }
    }

    private var tint: Color {
        switch status {
        case .partial: .yellow
        case .skipped: .red.opacity(0.85)
        case .done: color
        }
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
    if h == 0 { return String(localized: "\(m)분") }
    if m == 0 { return String(localized: "\(h)시간") }
    return String(localized: "\(h)시간 \(m)분")
}
