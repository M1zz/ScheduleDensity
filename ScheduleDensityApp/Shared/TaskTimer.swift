//
//  TaskTimer.swift
//  ScheduleDensityApp
//
//  지금 하고 있는 하나와, 거기 남은 시간.
//
//  ⚠️ 맥앱 '무지개 공방'의 같은 이름 파일을 옮긴 것이다. 세는 규칙(계획에 적힌 길이에서
//     거꾸로, 넘기면 +로 계속, 한 번에 하나만)은 **똑같아야 한다** — 두 기기가 같은 계획을
//     보는데 세는 법이 다르면 어느 쪽 숫자를 믿어야 할지 알 수 없다.
//     한쪽을 고치면 다른 쪽도 반드시 같이 고칠 것.
//
//  폰이라서 다른 것 셋:
//   1. **앱이 꺼져도 끝나는 것은 알려야 한다.** 맥은 창이 떠 있으니 소리 한 번이면 되지만,
//      폰은 주머니 안이다. 끝나는 시각에 로컬 알림을 미리 걸어 두고, 멈추거나 끝내면 걷는다.
//   2. **잠금화면에서도 보인다** (→ TimerActivity.swift). 1초마다 밀어 넣지 않는다 —
//      끝나는 시각만 건네면 잠금화면이 저 혼자 센다.
//   3. 소리 대신 진동. 앱을 보고 있을 때 0을 지나면 한 번 울린다.
//
//  ⚠️ **이 기기에만 남는다.** CloudKit으로 오가는 SwiftData 스키마에는 손대지 않는다.
//     "지금 이 자리에서 하고 있다"는 사실은 다른 기기로 건너갈 이유가 없다.
//

import Foundation
import Observation
import UIKit
import UserNotifications
import ActivityKit
import WidgetKit

// MARK: - 세고 있는 일

/// 타이머가 붙잡고 있는 대상. 모델을 직접 들지 않는다 —
/// 블록이 지워지거나 앱이 꺼졌다 켜져도 타이머는 자기 힘으로 서 있어야 하기 때문이다.
struct TimerTarget: Codable, Equatable {
    /// 되찾는 열쇠. 계획 블록·루틴을 가리키는 이름 (→ ScheduleClock.slot.id).
    /// 같은 일을 두 번 시작하려 할 때 "이미 세고 있다"고 알아보는 데 쓴다.
    var token: String
    var title: String
    /// 알약·고리 색(hex). nil이면 앱 기본색.
    var colorHex: String?
    var iconName: String
    /// 일정에 적힌 길이(초). 여기서부터 거꾸로 센다.
    var plannedSeconds: Double
}

// MARK: - 알림을 드릴까요

/// 타이머가 끝날 때 알림을 보낼지.
///
/// **한 번은 반드시 묻는다.** 시스템 권한 창을 바로 띄우지 않는다 — 그 창은 한 번 '허용 안 함'을
/// 받으면 앱이 다시는 못 묻고, 사람은 그게 무엇을 위한 것이었는지도 모른 채 닫는다.
/// 먼저 우리 말로 "알림 드릴까요"를 묻고, 받겠다고 한 사람에게만 시스템 창을 보인다.
enum TimerNotifyPreference: String {
    /// 아직 안 물어봤다. 타이머를 처음 켤 때 묻는다.
    case ask
    /// 앞으로도 알린다.
    case always
    /// 알리지 않는다. 앱을 보고 있을 때의 진동은 그대로 있다.
    case never

    var label: String {
        switch self {
        case .ask:    String(localized: "물어보기")
        case .always: String(localized: "알림 받기")
        case .never:  String(localized: "안 받기")
        }
    }
}

// MARK: - 줄을 보일까

/// 탭 막대 위 타이머 줄을 언제 세울지.
///
/// **가릴 길을 둔다.** 이 줄은 아무것도 안 눌러도 서기 때문에, 그것을 원치 않는 사람에게는
/// 치울 방법이 있어야 한다. 가려도 타이머는 그대로 돈다 — 알림도, 잠금화면도 그대로다.
enum TimerBarVisibility: String, CaseIterable {
    /// 세는 중이 아니어도 지금 일정과 남은 시간을 보여준다.
    case always
    /// 직접 시작한 타이머가 있을 때만.
    case whileTiming
    /// 안 보인다. 하루 화면에서 여전히 시작할 수 있고, 잠금화면에서 본다.
    case hidden

    var label: String {
        switch self {
        case .always:      String(localized: "늘 보기")
        case .whileTiming: String(localized: "세는 중에만")
        case .hidden:      String(localized: "안 보기")
        }
    }
}

// MARK: - 스토어

@Observable
@MainActor
final class TaskTimer {
    static let shared = TaskTimer()

    /// 지금 세고 있는 일. nil이면 타이머가 서 있지 않다.
    private(set) var target: TimerTarget?
    /// 지금 흐르고 있는 구간의 시작. nil이면 멈춰 있다(일시정지).
    private(set) var runningSince: Date?
    /// 멈추기 전까지 이미 흘려보낸 시간.
    private(set) var accumulated: TimeInterval = 0
    /// 화면을 다시 그리게 하는 심장. 0.5초마다 뛴다.
    private(set) var now: Date = Date()

    /// 0을 지나며 한 번만 울린다. 초과 시간을 세는 동안 계속 울리면 안 된다.
    private var didRingZero = false
    private var ticker: Timer?
    private var activity: Activity<TaskTimerAttributes>?

    /// 지금 물어볼 것. UI가 이것을 보고 묻는다 (→ TimerBar). 스토어는 화면을 모른다.
    enum NotifyAsk: Equatable {
        /// "이번 타이머가 끝나면 알림 드릴까요?"
        case thisTimer
        /// "앞으로도 그렇게 할까요?" — 앞의 답은 `allowOnce`가 이미 들고 있다.
        case always
    }
    private(set) var notifyAsk: NotifyAsk?

    /// 이번 타이머 한 번만 알린다. '이번만'이라고 답했을 때.
    private var allowOnce = false

    /// 탭 막대 위 줄을 언제 세울지 (→ TimerBarVisibility).
    private(set) var barVisibility: TimerBarVisibility = TaskTimer.storedBarVisibility

    func setBarVisibility(_ value: TimerBarVisibility) {
        barVisibility = value
        UserDefaults.standard.set(value.rawValue, forKey: Self.barVisibilityKey)
    }

    private static var storedBarVisibility: TimerBarVisibility {
        UserDefaults.standard.string(forKey: barVisibilityKey)
            .flatMap(TimerBarVisibility.init(rawValue:)) ?? .always
    }

    /// 다이나믹 아일랜드(와 잠금화면)에 타이머를 띄울지 — **새 타이머의 기본값.** 설정에서 바꾼다.
    ///
    /// ⚠️ **둘은 따로 끌 수 없다.** 라이브 액티비티 하나가 두 자리에 함께 서기 때문에,
    ///    아일랜드에서만 치우는 길은 시스템이 주지 않는다. 끄면 둘 다 걷히고, 타이머는 앱 안에서 그대로 돈다.
    private(set) var showsLiveActivity: Bool = TaskTimer.storedShowsLiveActivity

    /// **이번 타이머만** 띄울지. 타이머 시트의 스위치가 이것을 바꾼다 — 기본값은 건드리지 않는다.
    /// 타이머를 끝내면 기본값으로 돌아간다. 세는 것이 없을 때는 "이 시트에서 곧 시작할 타이머"의 값이다.
    private(set) var showsLiveActivityThisTimer: Bool = TaskTimer.storedShowsLiveActivity

    /// 기본값을 바꾼다. 지금 세는 타이머도 곧바로 따른다 — 설정에서 끈 사람에게 떠 있는 것이 남으면
    /// 스위치가 안 듣는 것처럼 보인다.
    func setShowsLiveActivity(_ value: Bool) {
        showsLiveActivity = value
        UserDefaults.standard.set(value, forKey: Self.liveActivityKey)
        setShowsLiveActivityThisTimer(value)
    }

    /// 이번 타이머만 바꾼다. 켜고 끄는 즉시 따른다.
    func setShowsLiveActivityThisTimer(_ value: Bool) {
        showsLiveActivityThisTimer = value
        persist()
        if value {
            // 붙잡고 있던 것이 이미 걷혔으면(잠금화면에서 쓸어 치웠거나 시스템이 끝냈으면) 새로 띄운다.
            // 걷힌 것을 "떠 있다"고 믿으면 스위치를 켜도 아무 일이 없다.
            if !isActivityAlive {
                activity = nil
                startActivity()
            }
        } else {
            endActivity()
        }
    }

    private static var storedShowsLiveActivity: Bool {
        UserDefaults.standard.object(forKey: liveActivityKey) as? Bool ?? true
    }

    private init() { restore() }

    // MARK: 읽기

    var isActive: Bool { target != nil }
    var isRunning: Bool { runningSince != nil }

    /// 시작한 뒤 실제로 흐른 시간. 멈춰 있는 동안은 늘지 않는다.
    var elapsed: TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    /// 남은 시간. 계획보다 오래 붙잡고 있으면 음수가 된다 — 그것도 사실이므로 감추지 않는다.
    var remaining: TimeInterval { (target?.plannedSeconds ?? 0) - elapsed }

    var isOvertime: Bool { remaining < 0 }

    /// 0~1. 초과해도 1을 넘지 않는다(고리가 두 바퀴 돌지 않게).
    var progress: Double {
        guard let planned = target?.plannedSeconds, planned > 0 else { return 0 }
        return min(1, max(0, elapsed / planned))
    }

    /// 이대로 가면 끝나는 시각. 멈춰 있으면 "지금부터 남은 만큼"으로 본다.
    var projectedEnd: Date { now.addingTimeInterval(max(0, remaining)) }

    /// 이 열쇠의 일을 지금 세고 있는가.
    func isTiming(_ token: String) -> Bool { target?.token == token }

    /// 끝날 때 알릴지. 설정에서 바꾼다.
    ///
    /// ⚠️ **저장 프로퍼티라야 한다.** 계산 프로퍼티로 UserDefaults를 직접 읽으면 `@Observable`이
    ///    그 값을 못 본다 — 설정에서 골라도 화면이 다시 그려질 근거가 없다.
    private(set) var notifyPreference: TimerNotifyPreference = TaskTimer.storedPreference

    func setNotifyPreference(_ value: TimerNotifyPreference) {
        notifyPreference = value
        UserDefaults.standard.set(value.rawValue, forKey: Self.preferenceKey)
        if value == .never { allowOnce = false }
        armNotifications()
    }

    private static var storedPreference: TimerNotifyPreference {
        UserDefaults.standard.string(forKey: preferenceKey)
            .flatMap(TimerNotifyPreference.init(rawValue:)) ?? .ask
    }

    /// 이번 것에 알림을 걸어 둘 것인가. 두 번째 물음의 말도 이 값을 따른다.
    var willNotifyThisTimer: Bool {
        notifyPreference == .always || allowOnce
    }

    // MARK: 묻고 답 받기

    /// "이번 타이머가 끝나면 알림 드릴까요?"의 답.
    func answerThisTimer(notify: Bool) {
        allowOnce = notify
        armNotifications()
        // 한 번 더 묻는다 — 이번만인지, 앞으로도인지.
        notifyAsk = .always
    }

    /// "앞으로도 그렇게 할까요?"의 답. 기억하지 않으면 다음 타이머에서 다시 묻는다.
    func answerAlways(remember: Bool) {
        if remember { setNotifyPreference(allowOnce ? .always : .never) }
        notifyAsk = nil
    }

    /// **알림을 걸거나 걷는다.** 지금 규칙으로 다시 재는 자리는 여기 하나뿐이다 —
    /// 시작할 때·답을 들었을 때·설정을 바꿨을 때가 같은 말을 세 벌 적고 있었다.
    private func armNotifications() {
        guard willNotifyThisTimer else {
            cancelEndNotification()
            return
        }
        askForNotificationsIfNeeded()
        scheduleEndNotification()
    }

    /// 물음을 닫기만 한다 (시트를 쓸어내린 경우). 이번 타이머의 답은 그대로 두고,
    /// 다음에 다시 묻는다 — 답을 안 들었으면 아직 모르는 것이다.
    func dismissAsk() { notifyAsk = nil }

    // MARK: 쓰기

    /// 새로 시작한다. 이미 다른 일을 세고 있었다면 그건 그대로 끝난다 —
    /// 한 번에 하나만 센다. 두 개를 동시에 세면 어느 쪽도 믿을 수 없다.
    ///
    /// `alreadyElapsed` — 일정 한가운데서 켰을 때 이미 지나간 몫. 90분 일정에 45분 남았다면
    /// 45분짜리 새 타이머가 아니라 **90분 중 45분이 흐른 타이머**로 선다.
    /// 아직 오지 않은 일정이면 **음수**다 — 끝 시각(데드라인)이 일정에 적힌 그대로 서야 하기 때문이다.
    func start(token: String, title: String, plannedSeconds: Double,
               alreadyElapsed: TimeInterval = 0,
               iconName: String = "timer", colorHex: String? = nil) {
        endActivity()
        let planned = max(60, plannedSeconds)
        target = TimerTarget(token: token, title: title, colorHex: colorHex,
                             iconName: iconName, plannedSeconds: planned)
        accumulated = min(alreadyElapsed, planned)
        now = Date()
        runningSince = now
        didRingZero = false
        persist()
        startTicking()
        // 알린다고 정해 둔 사람에게만 곧바로 건다. 아직 안 물어봤으면 여기서 묻는다.
        allowOnce = false
        if notifyPreference == .ask { notifyAsk = .thisTimer }
        armNotifications()
        startActivity()
    }

    // ⚠️ **멈추기·다시 가기·시간 더하기·처음부터는 없다.** 이 타이머의 끝은 일정에 적힌 끝 시각(데드라인)이다.
    //    사람이 늘리거나 되감을 수 있으면 숫자가 더는 "일정까지 얼마"를 말하지 않는다. 끝나면 저절로 걷힌다 (→ tick).

    /// 끝낸다. 세던 것을 지우고 자리를 비운다.
    func stop() {
        target = nil
        runningSince = nil
        accumulated = 0
        didRingZero = false
        allowOnce = false
        notifyAsk = nil
        persist()
        stopTicking()
        cancelEndNotification()
        endActivity()
        // 이번 것에만 걸었던 선택은 여기서 끝난다. 다음 타이머는 기본값으로 선다.
        showsLiveActivityThisTimer = showsLiveActivity
    }

    // MARK: 심장

    private func startTicking() {
        stopTicking()
        // 0.5초 — 초 단위 표시가 한 박자 늦게 넘어가는 것을 막을 만큼만 자주.
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // 목록을 스크롤하는 동안에도 숫자가 멈추지 않게 common 모드로.
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        now = Date()
        // 데드라인에 닿으면 끝이다. 넘긴 시간을 '+'로 세지 않는다 — 끝은 일정이 정한 것이다.
        if isActive, remaining <= 0 {
            // 앱을 보고 있을 때의 알림. 주머니 속이라면 로컬 알림이 대신 울린다.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            stop()
        }
    }

    // MARK: 알림 (앱이 꺼져 있어도 끝나는 것은 알려야 한다)

    private static let notificationID = "taskTimer.end"
    private static let preferenceKey = "taskTimer.notify"
    private static let barVisibilityKey = "taskTimer.bar"
    private static let liveActivityKey = "taskTimer.liveActivity"

    /// 처음 타이머를 켤 때만 묻는다. 앱을 켜자마자 묻지 않는 이유는, 그때는 아직
    /// 무엇 때문에 알림이 필요한지 사람이 모르기 때문이다.
    private func askForNotificationsIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// 끝나는 시각에 한 번 울리도록 걸어 둔다. 멈추거나 시간을 더하면 다시 건다.
    private func scheduleEndNotification() {
        cancelEndNotification()
        guard willNotifyThisTimer, let target, isRunning, remaining > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = target.title
        content.body = String(localized: "계획한 시간이 다 됐습니다.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelEndNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    // MARK: 잠금화면 (→ TimerActivity.swift)

    private var activityState: TaskTimerAttributes.ContentState? {
        guard let target else { return nil }
        return TaskTimerAttributes.ContentState(
            title: target.title,
            colorHex: target.colorHex,
            iconName: target.iconName,
            // 멈춰 있을 때도 끝 시각은 적어 둔다 — 다시 갈 때 잠금화면이 곧바로 이어 센다.
            endDate: Date().addingTimeInterval(remaining),
            startDate: Date().addingTimeInterval(-elapsed),
            isRunning: isRunning,
            pausedRemaining: remaining,
            showsHours: countdownStyle.showsHours)
    }

    /// 한 시간이 넘는 숫자를 어떻게 적나 (→ CountdownStyle). 화면이 따라 그리도록 여기서도 든다.
    private(set) var countdownStyle: CountdownStyle = CountdownStyle.current

    /// 설정에서 바꾼다. 떠 있는 아일랜드와 위젯도 곧바로 같은 모양으로 다시 그린다.
    func setCountdownStyle(_ style: CountdownStyle) {
        guard style != countdownStyle else { return }
        CountdownStyle.current = style
        countdownStyle = style
        updateActivity()
        WidgetCenter.shared.reloadTimelines(ofKind: TimerWidgetBridge.widgetKind)
    }

    /// iOS 설정에서 이 앱의 '실시간 현황'이 켜져 있나. 꺼져 있으면 무엇을 해도 안 뜬다 — 화면이 그 사실을 말한다.
    var areLiveActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// 붙잡은 것이 아직 화면에 서 있나.
    private var isActivityAlive: Bool {
        guard let activity else { return false }
        return activity.activityState == .active || activity.activityState == .stale
    }

    /// 끝 시각. 이때 시스템이 아일랜드를 다시 그려 빨강과 '+'로 넘긴다 — 앱이 꺼져 있어도.
    /// 멈춰 있거나 이미 넘겼으면 둘 필요가 없다.
    private var activityStaleDate: Date? {
        guard isRunning, remaining > 0 else { return nil }
        return Date().addingTimeInterval(remaining)
    }

    private func startActivity() {
        guard showsLiveActivityThisTimer, ActivityAuthorizationInfo().areActivitiesEnabled,
              let target, let state = activityState else { return }
        do {
            activity = try Activity.request(
                attributes: TaskTimerAttributes(token: target.token),
                content: .init(state: state, staleDate: activityStaleDate))
        } catch {
            // 조용히 삼키면 "켜져 있는데 안 보인다"의 까닭을 찾을 길이 없다.
            print("⚠️ [Timer] 라이브 액티비티를 못 띄웠다: \(error)")
        }
    }

    private func updateActivity() {
        guard let activity, let state = activityState else { return }
        Task { await activity.update(.init(state: state, staleDate: activityStaleDate)) }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// 앱을 껐다 켰을 때, 지난번에 띄워 둔 잠금화면 타이머를 다시 붙잡는다.
    /// 안 붙잡으면 화면에는 떠 있는데 앱이 그것을 끝낼 수 없는 유령이 된다.
    private func adoptRunningActivity() {
        // 꺼 두었으면 붙잡지 않고 모두 걷는다.
        // 이미 걷힌 것은 붙잡지 않는다 — 붙잡으면 다시 켜도 안 뜬다.
        activity = !showsLiveActivityThisTimer ? nil : Activity<TaskTimerAttributes>.activities.first {
            $0.attributes.token == target?.token
                && ($0.activityState == .active || $0.activityState == .stale)
        }
        for stray in Activity<TaskTimerAttributes>.activities where stray.id != activity?.id {
            Task { await stray.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: 남겨두기

    private struct Snapshot: Codable {
        var target: TimerTarget
        var runningSince: Date?
        var accumulated: TimeInterval
        var didRingZero: Bool
        /// 이번 타이머만의 아일랜드 선택. 예전 스냅샷에는 없으므로 없으면 기본값을 쓴다.
        var showsLiveActivity: Bool?
    }

    private static let key = "taskTimer.snapshot"

    private func persist() {
        // 홈·잠금 화면 위젯도 같은 값을 본다 (→ TimerWidgetSync). 아일랜드를 꺼 두어도 위젯은 따로다.
        TimerWidgetSync.publish(timer: activityState)
        guard let target else {
            UserDefaults.standard.removeObject(forKey: Self.key)
            return
        }
        let snap = Snapshot(target: target, runningSince: runningSince,
                            accumulated: accumulated, didRingZero: didRingZero,
                            showsLiveActivity: showsLiveActivityThisTimer)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// 앱을 껐다 켜도 세던 것을 이어 센다. 흐른 시간은 `runningSince`에서 다시 계산되므로
    /// 꺼져 있던 동안의 시간도 그대로 지나간 것으로 본다 — 실제로 지나갔기 때문이다.
    ///
    /// 다만 하루를 넘긴 것은 "켜 두고 잊어버린 타이머"다. 되살리지 않는다.
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            // 앱은 지워졌는데 잠금화면에만 남은 것을 걷는다.
            for stray in Activity<TaskTimerAttributes>.activities {
                Task { await stray.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }

        target = snap.target
        runningSince = snap.runningSince
        accumulated = snap.accumulated
        didRingZero = snap.didRingZero
        showsLiveActivityThisTimer = snap.showsLiveActivity ?? showsLiveActivity
        now = Date()

        // 꺼져 있던 사이 데드라인이 지났으면 끝난 것이다. 예전 판에서 멈춰 둔 것도 걷는다 — 이제 멈춤은 없다.
        if remaining <= 0 || !isRunning {
            stop()
            return
        }
        adoptRunningActivity()
        TimerWidgetSync.publish(timer: activityState)
        if isRunning { startTicking() }
    }
}
