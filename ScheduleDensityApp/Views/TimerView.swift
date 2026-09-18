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
    @State private var slots: [ScheduleSlot] = []
    @State private var showingSheet = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let slot = ScheduleClock.current(slots, at: ctx.date)
            Group {
                if timer.isActive {
                    bar(icon: timer.isRunning ? (timer.target?.iconName ?? "timer") : "pause.fill",
                        title: timer.target?.title ?? "",
                        time: formatCountdown(timer.remaining),
                        caption: timer.isOvertime ? String(localized: "초과") : String(localized: "남음"),
                        tint: timer.isOvertime ? .red : targetTint,
                        progress: timer.progress)
                } else if let slot {
                    bar(icon: slot.iconName,
                        title: slot.title,
                        time: formatCountdown(slot.remaining(at: ctx.date)),
                        caption: String(localized: "일정 기준"),
                        tint: slot.colorHex.flatMap { Color(hex: $0) } ?? .accentColor,
                        progress: slot.progress(at: ctx.date))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: timer.isActive)
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: slot?.id)
        }
        // 일정은 자주 바뀌지 않는다. 화면이 뜰 때와 일정이 바뀌었을 때만 다시 읽는다.
        .task { slots = ScheduleClock.slots() }
        .onReceive(NotificationCenter.default.publisher(for: .todoPeriodDidChange)) { _ in
            slots = ScheduleClock.slots()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            slots = ScheduleClock.slots()
        }
        .sheet(isPresented: $showingSheet) {
            TimerSheet(slot: ScheduleClock.current(slots))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var targetTint: Color {
        timer.target?.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
    }

    private func bar(icon: String, title: String, time: String, caption: String,
                     tint: Color, progress: Double) -> some View {
        Button {
            showingSheet = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    Circle()
                        .trim(from: 0, to: max(0, min(1, progress)))
                        .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: progress)
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("타이머 열기")
    }
}

// MARK: - 끌어올린 타이머

/// 세고 있으면 고리와 단추, 아니면 일정에 적힌 지금 것과 '지금부터 따로 세기'.
///
/// ⚠️ **크기를 못으로 박지 않는다.** 고리를 210pt로 고정해 뒀더니 작은 화면과 중간 높이
///    시트에서 글씨와 단추가 서로 밀려 다 찌그러졌다. 고리는 남은 자리에서 정하고,
///    모자라면 스크롤한다. 단추는 어느 높이에서든 손 닿는 아래에 고정한다.
struct TimerSheet: View {
    /// 일정 기준으로 지금 하고 있는 것.
    let slot: ScheduleSlot?

    @State private var timer = TaskTimer.shared
    @Environment(\.dismiss) private var dismiss
    /// 글씨를 키워 쓰는 사람에게는 고리를 줄이고 글씨에 자리를 준다.
    @Environment(\.dynamicTypeSize) private var typeSize

    private var tint: Color {
        if timer.isOvertime { return .red }
        return timer.target?.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 18) {
                        if timer.isActive {
                            running(size: geo.size)
                        } else {
                            scheduleFace(size: geo.size)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    // 자리가 남으면 가운데, 모자라면 위에서부터 채우고 스크롤한다.
                    .frame(minHeight: geo.size.height - 8)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("타이머")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            // 단추는 스크롤과 함께 밀려 올라가지 않는다 — 멈추려는 손이 늘 같은 자리를 짚게.
            .safeAreaInset(edge: .bottom) {
                if timer.isActive {
                    controls
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .background(.bar)
                }
            }
        }
    }

    /// 고리 지름. 좁은 화면에서는 폭이, 낮은 시트에서는 높이가 먼저 걸린다.
    /// 둘 중 작은 쪽을 따르고, 글씨를 키운 사람에게는 한 번 더 줄인다.
    private func dialSize(_ size: CGSize) -> CGFloat {
        let byWidth = size.width * 0.56
        let byHeight = size.height * (timer.isActive ? 0.40 : 0.34)
        let shrink: CGFloat = typeSize.isAccessibilitySize ? 0.72 : 1
        return max(120, min(210, min(byWidth, byHeight)) * shrink)
    }

    // MARK: 고리 하나

    /// 고리와 그 안의 숫자. 세는 것도, 일정에 적힌 것도 같은 얼굴로 선다.
    private func dial(progress: Double, text: String, caption: LocalizedStringKey,
                      color: Color, size: CGFloat, animated: Bool) -> some View {
        ZStack {
            // 다 쓴 만큼 고리가 채워진다. 초과해도 두 바퀴 돌지 않는다.
            Circle().stroke(color.opacity(0.14), lineWidth: size * 0.068)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.068, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animated ? .linear(duration: 0.5) : nil, value: progress)

            VStack(spacing: 2) {
                Text(text)
                    .font(.system(size: size * 0.21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    // "+1:02:03"처럼 길어져도 고리 밖으로 안 넘친다.
                    .minimumScaleFactor(0.5)
                Text(caption)
                    .font(.system(size: max(11, size * 0.062), weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, size * 0.14)
        }
        .frame(width: size, height: size)
    }

    // MARK: 직접 세는 중

    @ViewBuilder
    private func running(size: CGSize) -> some View {
        Label(timer.target?.title ?? "", systemImage: timer.target?.iconName ?? "timer")
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .lineLimit(2)
            .multilineTextAlignment(.center)

        dial(progress: timer.progress,
             text: formatCountdown(timer.remaining),
             caption: timer.isOvertime ? "초과" : "남음",
             color: tint,
             size: dialSize(size),
             animated: true)

        // 멈춰 있으면 끝나는 시각을 말하지 않는다 — 안 가는 시계의 도착 시각은 거짓말이다.
        Text(timer.isRunning
             ? String(localized: "\(formatClockTime(timer.projectedEnd))에 끝납니다")
             : String(localized: "멈춰 있습니다"))
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            // 좁은 화면에서 두 단추가 한 줄에 안 들어가면 위아래로 선다.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    toggleButton
                    stopButton
                }
                VStack(spacing: 10) {
                    toggleButton
                    stopButton
                }
            }

            HStack(spacing: 14) {
                Button("+5분") { timer.extend(minutes: 5) }
                Button("+10분") { timer.extend(minutes: 10) }
                Button("처음부터") { timer.restart() }
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var toggleButton: some View {
        Button {
            timer.toggle()
        } label: {
            Label(timer.isRunning ? "일시정지" : "이어서",
                  systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                .frame(maxWidth: .infinity)
                .lineLimit(1)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var stopButton: some View {
        Button {
            timer.stop()
        } label: {
            Label("끝내기", systemImage: "stop.fill")
                .frame(maxWidth: .infinity)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    // MARK: 일정 기준

    /// 시작 단추가 하나뿐이다 — 시작은 이미 일정에 적혀 있다.
    /// 직접 세는 것은 계획보다 늦게 시작했을 때를 위한 것이라, 여기서 한 번 더 누르게 한다.
    @ViewBuilder
    private func scheduleFace(size: CGSize) -> some View {
        if let slot {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let slotTint = slot.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
                VStack(spacing: 18) {
                    Label(slot.title, systemImage: slot.iconName)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    dial(progress: slot.progress(at: ctx.date),
                         text: formatCountdown(slot.remaining(at: ctx.date)),
                         caption: "남음",
                         color: slotTint,
                         size: dialSize(size),
                         animated: false)

                    Text(verbatim: "\(formatClockTime(slot.start))–\(formatClockTime(slot.end))")
                        .font(.system(size: 13, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    Button {
                        TimerStarter.start(slot: slot, from: ctx.date)
                    } label: {
                        Label("지금부터 따로 세기", systemImage: "timer")
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("계획보다 늦게 시작했을 때. 남은 시간만큼 거꾸로 셉니다.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            ContentUnavailableView {
                Label("지금 하기로 한 일이 없어요", systemImage: "timer")
            } description: {
                Text("하루 화면에서 일정을 눌러 타이머를 시작할 수 있습니다.")
            }
        }
    }
}


// MARK: - 시작하는 자리

/// 일정 한 조각에서 타이머를 켜는 길. 하루 화면·타이머 시트가 같은 문으로 들어온다.
@MainActor
enum TimerStarter {
    /// 남은 만큼 센다. 계획보다 늦게 시작했으면 이미 지나간 몫은 돌려주지 않는다 —
    /// 18시까지 하기로 한 일을 17시 30분에 시작했다면 남은 것은 30분이지 한 시간이 아니다.
    static func start(slot: ScheduleSlot, from now: Date = Date()) {
        let remaining = slot.remaining(at: now)
        TaskTimer.shared.start(token: slot.id,
                               title: slot.title,
                               plannedSeconds: remaining > 0 ? remaining : slot.duration,
                               iconName: slot.iconName,
                               colorHex: slot.colorHex)
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
                Button(alwaysAskConfirm) { timer.answerAlways(remember: true, notify: alwaysAskNotify) }
                Button("이번만") { timer.answerAlways(remember: false, notify: alwaysAskNotify) }
            } message: {
                Text("설정에서 언제든 바꿀 수 있습니다.")
            }
    }

    private var askingThisTimer: Binding<Bool> {
        Binding(get: { timer.notifyAsk == .thisTimer },
                set: { if !$0, timer.notifyAsk == .thisTimer { timer.dismissAsk() } })
    }

    private var askingAlways: Binding<Bool> {
        Binding(get: { if case .always = timer.notifyAsk { return true }; return false },
                set: { if !$0, case .always = timer.notifyAsk { timer.dismissAsk() } })
    }

    /// 앞의 답이 무엇이었냐에 따라 두 번째 물음의 말이 달라진다.
    private var alwaysAskNotify: Bool {
        if case .always(let notify) = timer.notifyAsk { return notify }
        return false
    }

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
