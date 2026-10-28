//
//  UpcomingTimer.swift
//  ScheduleDensityApp
//
//  일정 15분 전에 잠금화면·다이나믹 아일랜드에 **다음 일정**이 선다. 설정 ▸ 타이머에서 켠다.
//
//  앱이 꺼져 있어도 제때 떠야 하므로 **미리 예약해 둔다** (iOS 26 `Activity.request(…start:)`).
//  예약은 앱이 일정을 다시 읽을 때마다(→ ScheduleClockStore.reload) 고친다 —
//  일정이 옮겨졌는데 옛 시각에 뜨면 안 되기 때문이다. 시작이 지난 것도 그때 걷는다.
//
//  숫자는 일정이 **시작하는 시각까지** 센다. 세는 타이머(TaskTimer)와는 따로 선다 —
//  그 일정의 타이머를 켜면 이것은 걷힌다 (→ TimerStarter).
//

import Foundation
import ActivityKit

@MainActor
enum UpcomingTimer {
    /// 시작보다 얼마나 먼저 띄우나.
    static let lead: TimeInterval = 15 * 60
    /// 앱을 한동안 안 열어도 다음 몇 일정은 제때 뜨도록, 이만큼 미리 걸어 둔다.
    private static let maxScheduled = 3

    static let enabledKey = "timer.upcoming"

    /// 예약해서 띄우는 길은 iOS 26부터 있다. 그 전에는 설정에 보이지 않는다.
    static var isSupported: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// 걸어 둘 것만 남기고 나머지는 걷는다. 이미 맞게 걸린 것은 건드리지 않는다.
    static func reschedule(_ slots: [ScheduleSlot], now: Date = Date()) {
        guard #available(iOS 26.0, *) else { return }
        let enabled = UserDefaults.standard.bool(forKey: enabledKey)
            && ActivityAuthorizationInfo().areActivitiesEnabled
        let wanted = enabled
            ? Array(slots.filter { $0.start > now }.sorted { $0.start < $1.start }.prefix(maxScheduled))
            : []

        var placed = Set<String>()
        for activity in Activity<TaskTimerAttributes>.activities where activity.attributes.isUpcoming {
            let token = activity.attributes.token
            let fits = wanted.contains { Self.token(for: $0) == token && $0.start == activity.content.state.endDate }
            if fits, !placed.contains(token) {
                placed.insert(token)
            } else {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
        for slot in wanted where !placed.contains(token(for: slot)) {
            request(slot, now: now)
        }
    }

    /// 그 일정의 미리 보기를 걷는다. 타이머를 켜면 같은 일정이 두 자리에 서지 않게.
    static func end(slotID: String) {
        let token = Self.token(forID: slotID)
        for activity in Activity<TaskTimerAttributes>.activities where activity.attributes.token == token {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: -

    private static func token(for slot: ScheduleSlot) -> String { token(forID: slot.id) }
    private static func token(forID id: String) -> String { TaskTimerAttributes.upcomingPrefix + id }

    @available(iOS 26.0, *)
    private static func request(_ slot: ScheduleSlot, now: Date) {
        let begin = slot.start.addingTimeInterval(-lead)
        let state = TaskTimerAttributes.ContentState(
            title: slot.title,
            colorHex: slot.colorHex,
            iconName: slot.iconName,
            endDate: slot.start,
            startDate: begin,
            isRunning: true,
            pausedRemaining: slot.start.timeIntervalSince(max(begin, now)),
            showsHours: CountdownStyle.current.showsHours)
        // 시작 시각에 숫자가 0에 서고 '시작했습니다'로 넘어간다.
        let content = ActivityContent(state: state, staleDate: slot.start)
        let attributes = TaskTimerAttributes(token: token(for: slot))
        do {
            if begin <= now {
                // 이미 15분 안쪽이면 지금 띄운다.
                _ = try Activity.request(attributes: attributes, content: content, style: .standard)
            } else {
                _ = try Activity.request(
                    attributes: attributes, content: content, style: .standard,
                    alertConfiguration: AlertConfiguration(
                        title: "\(slot.title)",
                        body: "\(formatClockTime(slot.start))에 시작",
                        sound: .default),
                    start: begin)
            }
        } catch {
            print("⚠️ [Upcoming] 다음 일정을 못 띄웠다: \(error)")
        }
    }
}
