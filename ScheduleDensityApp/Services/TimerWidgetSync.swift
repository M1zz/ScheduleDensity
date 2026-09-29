import Foundation
import WidgetKit

/// 타이머와 일정 조각을 위젯용 스냅샷으로 굽고 타임라인을 갱신한다 (→ TimerWidgetSnapshot.swift).
///
/// 두 곳에서 부른다 — 타이머가 바뀔 때(→ TaskTimer.persist)와 일정을 다시 읽을 때(→ ScheduleClockStore.reload).
/// 한쪽이 부를 때 다른 쪽이 적어 둔 몫은 그대로 둔다.
@MainActor
enum TimerWidgetSync {
    static func publish(timer: TaskTimerAttributes.ContentState?) {
        var snap = TimerWidgetBridge.read()
        snap.timer = timer
        write(snap)
    }

    static func publish(slots: [ScheduleSlot]) {
        var snap = TimerWidgetBridge.read()
        let converted = slots.map {
            TimerWidgetSnapshot.Slot(title: $0.title, iconName: $0.iconName, colorHex: $0.colorHex,
                                     start: $0.start, end: $0.end)
        }
        // 같은 일정이면 굽지 않는다 — 탭을 옮길 때마다 위젯을 다시 그리게 할 이유가 없다.
        guard converted != snap.slots else { return }
        snap.slots = converted
        write(snap)
    }

    private static func write(_ snap: TimerWidgetSnapshot) {
        var snap = snap
        snap.updatedAt = Date()
        TimerWidgetBridge.write(snap)
        WidgetCenter.shared.reloadTimelines(ofKind: TimerWidgetBridge.widgetKind)
    }
}
