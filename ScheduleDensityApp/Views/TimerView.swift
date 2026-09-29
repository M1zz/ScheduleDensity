//
//  TimerView.swift
//  ScheduleDensityApp
//
//  "운동 1시간"이라고 적어 둔 계획에, 지금 얼마 남았는가.
//
//  기본은 **일정 기준**이다. 아무것도 누르지 않아도, 수면이 23:00–07:00이고 지금이 23:29면
//  타이머는 이미 7:31:00을 세고 있다 (→ ScheduleClock.swift).
//  계획보다 늦게 시작했거나 계획에 없는 일을 할 때만 '지금부터' 따로 센다 (→ TaskTimer.swift).
//
//  ⚠️ 맥앱 '무지개 공방'의 같은 이름 파일과 **같은 얼굴**이다. 창이 아니라 탭 위에 서는 줄과
//     끌어올리는 시트로 옮겼을 뿐, 세는 규칙도 단추의 말도 같다.
//

import SwiftUI

// MARK: - 늘 보이는 한 줄

/// 탭 막대 위에 서서 지금 하는 일과 남은 시간을 한 줄로 말한다.
/// 직접 센 타이머가 있으면 그것이, 없으면 일정에 적힌 지금 것이 선다. 둘 다 없으면 서지 않는다.
struct TimerBar: View {
    @State private var timer = TaskTimer.shared
    @State private var clock = ScheduleClockStore.shared
    @State private var showingSheet = false

    /// 보여줄 것이 있는가. 없으면 초를 세지 않는다 —
    /// 빈 줄이 탭 수만큼 초당 한 번씩 깨어날 이유가 없다.
    ///
    /// 가려 둔 사람에게는 아무것도 안 선다 (→ TimerBarVisibility). 가려도 타이머는 돌고,
    /// 알림과 잠금화면은 그대로다.
    private var hasSomething: Bool {
        switch timer.barVisibility {
        case .hidden:      false
        case .whileTiming: timer.isActive
        case .always:      timer.isActive || clock.current() != nil
        }
    }

    var body: some View {
        // 보여줄 것이 없으면 초를 세는 뷰 자체를 세우지 않는다.
        Group {
            if hasSomething { ticking } else { Color.clear.frame(height: 0) }
        }
        // 일정은 자주 바뀌지 않는다. 화면이 뜰 때와 일정이 바뀌었을 때만 다시 읽는다.
        // 읽는 자리도 한 벌이다 (→ ScheduleClockStore) — 줄이 셋이어도 셈은 한 번이다.
        .task { if clock.slots.isEmpty { clock.reload() } }
        .onReceive(NotificationCenter.default.publisher(for: .todoPeriodDidChange)) { _ in
            clock.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            clock.reload()
        }
        .sheet(isPresented: $showingSheet) {
            TimerSheet(slot: clock.current())
                .presentationDragIndicator(.visible)
        }
    }

    /// 초를 세며 서 있는 줄.
    private var ticking: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let slot = clock.current(at: ctx.date)
            Group {
                if timer.isActive {
                    bar(icon: timer.isRunning ? (timer.target?.iconName ?? "timer") : "pause.fill",
                        title: timer.target?.title ?? "",
                        time: formatCountdown(timer.remaining),
                        caption: timer.isOvertime ? String(localized: "초과") : String(localized: "남음"),
                        tint: timer.isOvertime ? .red : targetTint,
                        left: 1 - timer.progress)
                } else if let slot {
                    bar(icon: slot.iconName,
                        title: slot.title,
                        time: formatCountdown(slot.remaining(at: ctx.date)),
                        caption: String(localized: "일정 기준"),
                        tint: slot.colorHex.flatMap { Color(hex: $0) } ?? .accentColor,
                        left: 1 - slot.progress(at: ctx.date))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: timer.isActive)
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: slot?.id)
        }
    }

    private var targetTint: Color {
        timer.target?.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
    }

    private func bar(icon: String, title: String, time: String, caption: String,
                     tint: Color, left: Double) -> some View {
        Button {
            showingSheet = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    // **남은 만큼** 그린다 — 시계 앱 타이머처럼 줄어든다 (→ TimerSheet.header).
                    Circle()
                        .trim(from: 0, to: max(0, min(1, left)))
                        .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: left)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(caption)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)

                // 숫자는 절대 잘리지 않는다 — 제목이 먼저 줄어든다.
                Text(time)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
        // 길게 누르면 그 자리에서 끝내거나 치운다 — 시트를 열어야만 멈출 수 있으면,
        // 급히 멈추려는 손이 한 번 더 헤맨다.
        .contextMenu {
            if timer.isActive && timer.showsLiveActivityThisTimer {
                Button {
                    TimerStarter.setIsland(false, slot: nil)
                } label: {
                    Label("다이나믹 아일랜드에서 감추기", systemImage: "eye.slash")
                }
            } else if timer.isActive || clock.current() != nil {
                Button {
                    TimerStarter.setIsland(true, slot: clock.current())
                } label: {
                    Label("다이나믹 아일랜드에 보이기", systemImage: "platter.filled.top.iphone")
                }
            }
            Divider()
            Button {
                timer.setBarVisibility(.whileTiming)
            } label: {
                Label("세는 중에만 보기", systemImage: "eye.slash")
            }
            Button {
                timer.setBarVisibility(.hidden)
            } label: {
                Label("이 줄 숨기기", systemImage: "eye.slash.fill")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("타이머 열기. 길게 누르면 끝내거나 숨깁니다")
    }
}

// MARK: - 끌어올린 타이머

/// 일정의 끝 시각(데드라인)까지 남은 것. 누를 단추는 없다 — 끝은 일정이 정한다.
///
/// ⚠️ **중간 높이 한 화면에 다 들어가게 짠다.** 큰 고리를 가운데 세우고 단추를 아래 붙이던 때에는
///    중간 높이 시트에서 아래가 잘려, 무엇을 누르려면 늘 끌어올려야 했다. 이제 작은 고리와 큰 숫자를
///    **가로로** 나란히 두고, '일정 고르기'는 내비게이션 막대로 올렸다. 글씨를 크게 쓰는 사람에게만
///    세로로 쌓고, 그래도 넘치면 스크롤한다.
struct TimerSheet: View {
    /// 일정 기준으로 지금 하고 있는 것.
    let slot: ScheduleSlot?

    @State private var timer = TaskTimer.shared
    /// 다른 일정을 고르는 목록을 열었나 (→ TimerSlotPicker).
    @State private var showingPicker = false
    @Environment(\.dismiss) private var dismiss
    /// 글씨를 키워 쓰는 사람에게는 고리와 숫자를 위아래로 쌓는다.
    @Environment(\.dynamicTypeSize) private var typeSize

    /// 시트 높이. **내용에 딱 맞춘다** — 중간 높이로 고정하면 내용이 짧을 땐 아래가 비고,
    /// 길 땐 잘렸다. 내용을 재어 그만큼만 올린다 (크게 끌어올리는 자리는 그대로 있다).
    @State private var fitHeight: CGFloat = 380
    @State private var detent: PresentationDetent = .height(380)
    /// 내비게이션 막대와 끌기 손잡이 몫.
    private let chromeHeight: CGFloat = 76

    private var tint: Color {
        if timer.isOvertime { return .red }
        return timer.target?.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if timer.isActive {
                        runningHeader
                    } else if let slot {
                        scheduleFace(slot)
                    } else {
                        emptyFace
                    }
                    islandSwitch
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                    fitHeight = (h + chromeHeight).rounded()
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("타이머")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingPicker) {
                // 고르면 목록을 닫고 이 시트로 돌아와 숫자를 보여준다.
                TimerSlotPicker {
                    showingPicker = false
                    detent = .height(fitHeight)
                }
            }
            .toolbar {
                // 지금 것 말고 **다른 일정**을 골라 센다. 세는 중이면 고른 것으로 갈아탄다 — 한 번에 하나만 센다.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        detent = .large
                        showingPicker = true
                    } label: {
                        Label("일정 고르기", systemImage: "list.bullet")
                            .labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(fitHeight), .large], selection: $detent)
        // 내용이 바뀌면(세기 시작·끝) 높이도 따라간다. 크게 끌어올려 둔 사람은 그대로 둔다.
        .onChange(of: fitHeight) { _, h in
            if detent != .large { detent = .height(h) }
        }
    }

    // MARK: 머리 — 고리와 숫자를 나란히

    /// 작은 고리(속에 그림) 옆에 제목·숫자·한 줄 말. 세는 것도, 일정에 적힌 것도 같은 얼굴로 선다.
    private func header(icon: String, title: String, time: String, caption: String,
                        detail: String, color: Color, left: Double, animated: Bool) -> some View {
        let ring = ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 8)
            // ⚠️ 고리는 **남은 만큼**이다. 지난 만큼 차오르게 두었더니, 9–18시 회사에 85분 남았을 때
            //    고리가 84% 차 있어 "80%나 남았다"로 읽혔다. 시계 앱 타이머처럼 줄어드는 쪽이 숫자와 같은 말을 한다.
            Circle()
                .trim(from: 0, to: max(0, min(1, left)))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animated ? .linear(duration: 0.5) : nil, value: left)
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(width: 88, height: 88)

        let text = VStack(alignment: typeSize.isAccessibilitySize ? .center : .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: time)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    // "+1:02:03"처럼 길어져도 한 줄에 선다.
                    .minimumScaleFactor(0.6)
                Text(caption)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Text(detail)
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }

        return Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) { ring; text }
                    .multilineTextAlignment(.center)
            } else {
                HStack(spacing: 16) {
                    ring
                    text.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        .accessibilityElement(children: .combine)
    }

    // MARK: 직접 세는 중

    private var runningHeader: some View {
        header(icon: timer.isRunning ? (timer.target?.iconName ?? "timer") : "pause.fill",
               title: timer.target?.title ?? "",
               time: formatCountdown(timer.remaining),
               caption: timer.isOvertime ? String(localized: "초과") : String(localized: "남음"),
               detail: String(localized: "\(formatClockTime(timer.projectedEnd))에 끝납니다"),
               color: tint,
               left: 1 - timer.progress,
               animated: true)
    }

    // MARK: 일정 기준

    /// 세는 것이 없을 때 일정에 적힌 지금 것. 누를 단추는 없다 — 끝은 이미 일정에 적혀 있다.
    /// 아일랜드에 띄우려면 아래 스위치를, 다른 것을 세려면 '일정 고르기'를 쓴다.
    private func scheduleFace(_ slot: ScheduleSlot) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            header(icon: slot.iconName,
                   title: slot.title,
                   time: formatCountdown(slot.remaining(at: ctx.date)),
                   caption: String(localized: "남음"),
                   detail: "\(formatClockTime(slot.start))–\(formatClockTime(slot.end)) · " + String(localized: "일정 기준"),
                   color: slot.colorHex.flatMap { Color(hex: $0) } ?? .accentColor,
                   left: 1 - slot.progress(at: ctx.date),
                   animated: false)
        }
    }

    /// 지금 하기로 한 일이 없을 때. 큰 빈 화면 대신 한 줄 말과 고르는 단추 하나.
    private var emptyFace: some View {
        VStack(spacing: 10) {
            Label("지금 하기로 한 일이 없어요", systemImage: "timer")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                detent = .large
                showingPicker = true
            } label: {
                Label("다른 일정 고르기", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    // MARK: 아일랜드

    /// **이번 타이머만** 다이나믹 아일랜드에 보이거나 감춘다. 기본값은 설정에 있다 (→ TaskTimer.showsLiveActivityThisTimer).
    ///
    /// ⚠️ **밀어서 켜는 스위치이고, 스위치는 '지금 떠 있나'를 그대로 말한다.**
    ///    - 한때 세는 것이 없어도 켜진 채로 서 있어서 "켜져 있는데 왜 안 보이냐"는 말을 들었다 — 아일랜드는
    ///      직접 세는 타이머만 띄울 수 있다. 그래서 세는 것이 없으면 꺼진 채로 서고, 밀면 지금 일정으로 시작해 곧바로 띄운다.
    ///    - 단추로 바꿔 '감추기'라고 적었더니 거꾸로 읽혔다(지금 감춰진 것으로). 상태와 글이 한 몸인 스위치로 되돌렸다.
    private var islandSwitch: some View {
        let showing = Binding(
            get: { timer.isActive && timer.showsLiveActivityThisTimer },
            set: { TimerStarter.setIsland($0, slot: slot) })
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: showing) {
                Label("다이나믹 아일랜드에서도 보기", systemImage: "platter.filled.top.iphone")
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            // 세는 것도, 지금 일정도 없으면 띄울 것이 없다.
            .disabled(!timer.isActive && slot == nil)

            if !timer.areLiveActivitiesEnabled {
                Text("iOS 설정 ▸ 이 앱 ▸ 실시간 현황이 꺼져 있어 보이지 않습니다.")
                    .font(.body)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }
}


// MARK: - 일정 고르기

/// 지금 하고 있는 것과 앞으로 올 것 중에서 **내가 셀 일정**을 고른다.
/// 고르면 그 일정의 전체 길이로 선다 (→ TimerStarter). 이미 끝난 것은 보이지 않는다.
struct TimerSlotPicker: View {
    /// 고른 뒤 부른다. 목록을 닫는 일은 부른 쪽이 한다.
    let onPicked: () -> Void

    @State private var timer = TaskTimer.shared
    @State private var clock = ScheduleClockStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let now = ctx.date
            let ongoing = clock.slots.filter { $0.contains(now) }
            let upcoming = clock.slots.filter { $0.start > now }
            List {
                if ongoing.isEmpty && upcoming.isEmpty {
                    ContentUnavailableView {
                        Label("고를 일정이 없어요", systemImage: "calendar")
                    } description: {
                        Text("오늘과 내일 남은 일정이 여기에 보입니다.")
                    }
                    .listRowBackground(Color.clear)
                }
                if !ongoing.isEmpty {
                    Section("지금 하는 중") {
                        ForEach(ongoing) { row($0, now: now) }
                    }
                }
                if !upcoming.isEmpty {
                    Section("다가올 일정") {
                        ForEach(upcoming) { row($0, now: now) }
                    }
                }
            }
        }
        .navigationTitle("일정 고르기")
        .navigationBarTitleDisplayMode(.inline)
        .task { clock.reload() }
    }

    private func row(_ slot: ScheduleSlot, now: Date) -> some View {
        let tint = slot.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
        return Button {
            TimerStarter.start(slot: slot, from: now)
            onPicked()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: slot.iconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(timeRange(slot))
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                if timer.isTiming(slot.id) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tint)
                        .accessibilityLabel("세는 중")
                }
            }
        }
    }

    /// "14:00–15:30". 오늘이 아닌 날이면 앞에 날을 붙인다 — 자정 넘어 있는 것을 오늘로 읽지 않게.
    private func timeRange(_ slot: ScheduleSlot) -> String {
        let range = "\(formatClockTime(slot.start))–\(formatClockTime(slot.end))"
        let cal = Calendar.current
        if cal.isDateInToday(slot.start) { return range }
        if cal.isDateInTomorrow(slot.start) { return String(localized: "내일 \(range)") }
        return String(localized: "어제 \(range)")
    }
}

// MARK: - 시작하는 자리

/// 일정 한 조각에서 타이머를 켜는 길. 하루 화면·타이머 시트가 같은 문으로 들어온다.
@MainActor
enum TimerStarter {
    /// **끝은 일정에 적힌 끝 시각이다.** 언제 켜든 그 시각까지 센다 —
    /// 17:00–18:30 일정을 17:45에 켜면 90분 중 45분이 지난 타이머이고, 아직 안 온 일정이면
    /// 시작 전부터 끝 시각까지 센다. 이미 끝난 일정은 켜지 않는다 (데드라인이 지났다).
    static func start(slot: ScheduleSlot, from now: Date = Date()) {
        guard slot.end > now else { return }
        TaskTimer.shared.start(token: slot.id,
                               title: slot.title,
                               plannedSeconds: slot.duration,
                               alreadyElapsed: now.timeIntervalSince(slot.start),
                               iconName: slot.iconName,
                               colorHex: slot.colorHex)
    }

    /// 이번 타이머를 다이나믹 아일랜드에 보이거나 감춘다. 시트의 단추와 줄의 메뉴가 같은 문으로 들어온다.
    /// 세는 것이 없으면 아일랜드에 띄울 것도 없으므로, 보이라고 하면 이 일정으로 시작부터 한다.
    static func setIsland(_ on: Bool, slot: ScheduleSlot?) {
        let timer = TaskTimer.shared
        if timer.isActive {
            timer.setShowsLiveActivityThisTimer(on)
        } else if on, let slot {
            timer.setShowsLiveActivityThisTimer(true)
            start(slot: slot)
        }
    }
}

/// "14:35". 타이머가 말하는 시각은 늘 이 모양이다.
func formatClockTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale.autoupdatingCurrent
    f.dateFormat = DateFormatter.dateFormat(fromTemplate: "jm", options: 0,
                                            locale: .autoupdatingCurrent)
    return f.string(from: date)
}

// MARK: - 한 번은 반드시 묻는 자리

/// 알림을 드릴지 묻는 두 물음 (→ TaskTimer.TimerNotifyPreference).
///
/// **앱에 하나만 둔다.** 타이머 줄은 탭마다 서므로 거기 붙이면 같은 물음이 여러 벌 생기고,
/// 그중 어느 것이 뜰지는 그때그때 다르다. 그래서 루트에 한 번만 붙인다 (→ `.timerNotifyAsk()`).
private struct TimerNotifyAskModifier: ViewModifier {
    @State private var timer = TaskTimer.shared

    func body(content: Content) -> some View {
        content
            .alert("타이머가 끝나면 알림 드릴까요?", isPresented: askingThisTimer) {
                Button("알림 받기") { timer.answerThisTimer(notify: true) }
                Button("안 받기") { timer.answerThisTimer(notify: false) }
            } message: {
                Text("앱을 닫아 두어도 끝나는 시각에 한 번 울립니다.")
            }
            .alert(alwaysAskTitle, isPresented: askingAlways) {
                Button(alwaysAskConfirm) { timer.answerAlways(remember: true) }
                Button("이번만") { timer.answerAlways(remember: false) }
            } message: {
                Text("설정에서 언제든 바꿀 수 있습니다.")
            }
    }

    private var askingThisTimer: Binding<Bool> {
        Binding(get: { timer.notifyAsk == .thisTimer },
                set: { if !$0, timer.notifyAsk == .thisTimer { timer.dismissAsk() } })
    }

    private var askingAlways: Binding<Bool> {
        Binding(get: { timer.notifyAsk == .always },
                set: { if !$0, timer.notifyAsk == .always { timer.dismissAsk() } })
    }

    /// 앞의 답이 무엇이었냐에 따라 두 번째 물음의 말이 달라진다.
    private var alwaysAskNotify: Bool { timer.willNotifyThisTimer }

    private var alwaysAskTitle: String {
        alwaysAskNotify
            ? String(localized: "앞으로도 알림 드릴까요?")
            : String(localized: "앞으로도 알림을 끌까요?")
    }

    private var alwaysAskConfirm: String {
        alwaysAskNotify
            ? String(localized: "앞으로도 알림 받기")
            : String(localized: "앞으로 안 받기")
    }
}

extension View {
    /// 알림을 드릴지 묻는 두 물음을 이 화면에 붙인다. **앱에 한 번만** 붙인다.
    func timerNotifyAsk() -> some View { modifier(TimerNotifyAskModifier()) }

    /// 탭 막대 **위에** 타이머 줄을 세운다.
    ///
    /// ⚠️ 이 줄은 탭뷰가 아니라 **각 탭의 내용**에 붙인다. 탭뷰에 붙였더니 줄이 탭 막대를
    ///    통째로 덮어, 탭을 누를 수가 없었다. 탭뷰의 아래 여백은 탭 막대가 이미 쓰고 있다.
    func timerBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { TimerBar() }
    }
}
