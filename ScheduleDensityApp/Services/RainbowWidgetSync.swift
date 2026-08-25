import Foundation
import WidgetKit

/// 무지개 화면이 보여주는 것을 위젯용 스냅샷으로 굽고 타임라인을 갱신한다.
///
/// 호출 지점은 무지개 화면의 데이터 갱신 한 곳으로 모아둔다 — 일정을 더하거나 고치면
/// 그 화면이 다시 그려지고, 그때 스냅샷도 같이 다시 굽는다.
enum RainbowWidgetSync {
    /// 뷰모델에서 바로 굽는다. 레인 배정은 화면과 같은 계산을 써야
    /// 위젯의 색과 앱의 색이 어긋나지 않는다.
    @MainActor
    static func refresh(from viewModel: ScheduleViewModel) {
        // 레인 배정을 먼저 돌려야 eventLaneAssignments가 채워진다.
        _ = viewModel.assignLanesToEvents()
        let snapshot = makeSnapshot(events: viewModel.fetchEvents(),
                                    laneAssignments: viewModel.eventLaneAssignments,
                                    fillSpanToEndDate: viewModel.fillSpanToEndDate,
                                    sleepHoursPerDay: viewModel.sleepHoursPerDay)
        RainbowWidgetBridge.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: RainbowWidgetBridge.widgetKind)
    }

    /// 순수 함수 — 무지개 격자가 칸을 채우는 규칙과 같은 기준을 쓴다
    /// (실제로 하는 날이 먼저, 그다음이 종료일까지 이어지는 기간 칸).
    static func makeSnapshot(events: [Event],
                             laneAssignments: [String: Int],
                             fillSpanToEndDate: Bool,
                             sleepHoursPerDay: Double,
                             now: Date = Date()) -> RainbowWidgetSnapshot
    {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        // 점유율의 분모는 잘 시간을 뺀 하루다 (→ DayInsight.capacityHours).
        let capacity = max(1, 24 - sleepHoursPerDay)

        var days: [RainbowWidgetSnapshot.Day] = []
        for offset in 0..<RainbowWidgetSnapshot.maxDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { break }

            var cells: [RainbowWidgetSnapshot.Cell] = []
            var hours = 0.0

            for lane in 0..<RainbowPalette.laneColors.count {
                let inLane = events.filter { laneAssignments[$0.laneKey] == lane }
                // ① 이 날짜에 실제로 하는 일정이 먼저다. 진한 칸이 옅은 칸에 밀리면 안 된다.
                if let working = inLane.first(where: { $0.occursOn(date: date) }) {
                    cells.append(.init(lane: lane, isWorking: true))
                    hours += working.hoursPerDay
                } else if fillSpanToEndDate, inLane.contains(where: { $0.spansOn(date: date) }) {
                    // ② 하는 날은 아니지만 종료일까지 기간 안 — 옅게.
                    cells.append(.init(lane: lane, isWorking: false))
                }
            }

            days.append(.init(date: date,
                              cells: cells,
                              hours: hours,
                              load: hours / capacity))
        }

        return RainbowWidgetSnapshot(days: days, updatedAt: now)
    }
}
