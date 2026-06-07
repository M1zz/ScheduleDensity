import Foundation
import SwiftData

/// 특정 주에 고정 루틴이 어느 요일에 배치되었는지를 저장한다.
/// 첫 주: dayMask + startHour 기반으로 자동 생성.
/// 이후 주: 직전 주의 배치를 그대로 복사.
@Model
final class RoutineOccurrence {
    var routineName: String = ""
    var dayRaw: Int = 0
    var weekStartDate: Date = Date.currentWeekStart

    init(routineName: String, day: DayOfWeek, weekStartDate: Date) {
        self.routineName = routineName
        self.dayRaw = day.rawValue
        self.weekStartDate = weekStartDate
    }

    var day: DayOfWeek {
        get { DayOfWeek(rawValue: dayRaw) ?? .mon }
        set { dayRaw = newValue.rawValue }
    }
}
