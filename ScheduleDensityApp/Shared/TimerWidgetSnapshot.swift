//
//  TimerWidgetSnapshot.swift
//  ScheduleDensityApp
//
//  홈·잠금 화면 타이머 위젯이 읽는 것.
//
//  ⚠️ 앱 타깃과 위젯 익스텐션이 함께 컴파일한다. 위젯은 SwiftData도 UserDefaults.standard도
//     못 보므로, 앱이 App Group에 구워 둔 이 파일만 읽는다 (→ RainbowWidgetSnapshot.swift와 같은 길).
//
//  두 가지를 싣는다.
//   1. **직접 세는 타이머** — 라이브 액티비티와 같은 모양(`TaskTimerAttributes.ContentState`)을 그대로 쓴다.
//      위젯도 끝나는 시각 하나로 저 혼자 센다.
//   2. **일정 조각들** — 세는 것이 없을 때 "일정 기준" 지금 것을 보이기 위해. 위젯은 일정을 계산할 수
//      없으므로 앱이 계산해 둔 조각(어제~내일)을 싣고, 위젯은 경계마다 한 장씩 그린다.
//

import Foundation

struct TimerWidgetSnapshot: Codable {
    struct Slot: Codable, Hashable {
        var title: String
        var iconName: String
        var colorHex: String?
        var start: Date
        var end: Date

        func contains(_ date: Date) -> Bool { date >= start && date < end }
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// 직접 세는 타이머. nil이면 세는 것이 없다.
    var timer: TaskTimerAttributes.ContentState?
    var slots: [Slot]
    var updatedAt: Date

    static let empty = TimerWidgetSnapshot(timer: nil, slots: [], updatedAt: .distantPast)

    /// 지금 하고 있는 것. 겹쳐 있으면 **가장 짧은 것** — 앱의 `ScheduleClock.current`와 같은 규칙이다.
    func currentSlot(at date: Date) -> Slot? {
        slots.filter { $0.contains(date) }.min { $0.duration < $1.duration }
    }

    /// 위젯 갤러리 미리보기용.
    static var sample: TimerWidgetSnapshot {
        let now = Date()
        return TimerWidgetSnapshot(
            timer: .init(title: String(localized: "운동"), colorHex: nil, iconName: "figure.run",
                         endDate: now.addingTimeInterval(25 * 60),
                         startDate: now.addingTimeInterval(-35 * 60),
                         isRunning: true, pausedRemaining: 25 * 60),
            slots: [], updatedAt: now)
    }
}

/// 앱 ↔ 타이머 위젯 사이의 App Group 통로.
enum TimerWidgetBridge {
    static let appGroupID = TodoWidgetBridge.appGroupID

    /// `WidgetCenter.reloadTimelines(ofKind:)`에 쓰는 위젯 종류 ID.
    static let widgetKind = "TimerWidget"

    /// 위젯을 누르면 앱에서 타이머 시트가 열린다.
    static let deepLink = URL(string: "rainbow://timer")!

    private static let fileName = "timer-widget-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func read() -> TimerWidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(TimerWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    static func write(_ snapshot: TimerWidgetSnapshot) {
        guard let url = fileURL else { return }
        try? JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
