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
    func start(token: String, title: String, plannedSeconds: Double,
               iconName: String = "timer", colorHex: String? = nil) {
        endActivity()
        target = TimerTarget(token: token, title: title, colorHex: colorHex,
                             iconName: iconName, plannedSeconds: max(60, plannedSeconds))
        accumulated = 0
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

    func pause() {
        guard let since = runningSince else { return }
        accumulated += Date().timeIntervalSince(since)
        runningSince = nil
        now = Date()
        persist()
        stopTicking()
        cancelEndNotification()
        updateActivity()
    }

    func resume() {
        guard isActive, runningSince == nil else { return }
        now = Date()
        runningSince = now
        persist()
        startTicking()
        scheduleEndNotification()
        updateActivity()
    }

    func toggle() { isRunning ? pause() : resume() }

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
    }

    /// 시간을 더 준다. 계획을 늘리는 것이지 이미 쓴 시간을 지우는 게 아니다.
    func extend(minutes: Double) {
        guard var t = target else { return }
        t.plannedSeconds += minutes * 60
        target = t
        // 다시 0 위로 올라왔으면 종이 한 번 더 울릴 자격이 있다.
        if remaining > 0 { didRingZero = false }
        persist()
        scheduleEndNotification()
        updateActivity()
    }

    /// 처음부터 다시 센다.
    func restart() {
        guard isActive else { return }
        accumulated = 0
        now = Date()
        runningSince = now
        didRingZero = false
        persist()
        startTicking()
        scheduleEndNotification()
        updateActivity()
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
        if !didRingZero, isActive, remaining <= 0 {
            didRingZero = true
            // 앱을 보고 있을 때의 알림. 주머니 속이라면 로컬 알림이 대신 울린다.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            persist()
            updateActivity()
        }
    }

    // MARK: 알림 (앱이 꺼져 있어도 끝나는 것은 알려야 한다)

    private static let notificationID = "taskTimer.end"
    private static let preferenceKey = "taskTimer.notify"
    private static let barVisibilityKey = "taskTimer.bar"

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
            pausedRemaining: remaining)
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let target, let state = activityState else { return }
        activity = try? Activity.request(
            attributes: TaskTimerAttributes(token: target.token),
            content: .init(state: state, staleDate: nil))
    }

    private func updateActivity() {
        guard let activity, let state = activityState else { return }
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// 앱을 껐다 켰을 때, 지난번에 띄워 둔 잠금화면 타이머를 다시 붙잡는다.
    /// 안 붙잡으면 화면에는 떠 있는데 앱이 그것을 끝낼 수 없는 유령이 된다.
    private func adoptRunningActivity() {
        activity = Activity<TaskTimerAttributes>.activities.first { $0.attributes.token == target?.token }
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
    }

    private static let key = "taskTimer.snapshot"

    private func persist() {
        guard let target else {
            UserDefaults.standard.removeObject(forKey: Self.key)
            return
        }
        let snap = Snapshot(target: target, runningSince: runningSince,
                            accumulated: accumulated, didRingZero: didRingZero)
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
        now = Date()

        if elapsed > snap.target.plannedSeconds + 12 * 3600 {
            stop()
            return
        }
        adoptRunningActivity()
        if isRunning { startTicking() }
    }
}
