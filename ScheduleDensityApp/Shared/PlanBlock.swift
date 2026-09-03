import Foundation
import SwiftData

@Model
final class PlanBlock {
    var dayRaw: Int = DayOfWeek.mon.rawValue
    var timeBandRaw: String = TimeBand.evening.rawValue
    var durationHours: Double = 1
    var title: String = ""
    var successCriteria: String = ""
    var deliverable: String = ""

    /// Monday 00:00 of this block's week.
    var weekStartDate: Date = Date.currentWeekStart

    /// Whether the user passed the concreteness check at save time.
    var concreteVerified: Bool = false

    /// 회사일 같은 기존 루틴 시간 *안에서* 진행되는 일정인지.
    /// true면 자유 시간을 추가로 소비하지 않고, 타임라인에서 루틴 위에 겹쳐 표시한다.
    var withinRoutine: Bool = false
    /// 정확한 시작 시각(h). -1 = 미설정(시간대 기반 배치). 루틴 내부 일정에서 사용.
    var startHour: Double = -1

    var createdAt: Date = Date()

    /// 맥('무지개 공방')의 캘린더 가져오기가 쓰는 칸 (→ 맥의 CalendarImport.swift).
    ///
    /// ⚠️ **아이폰은 이 값을 쓰지 않는다. 그래도 모델에 둔다.** 두 앱이 같은
    ///    `CD_PlanBlock` 레코드 타입 하나를 나눠 쓰기 때문이다. 한쪽에만 있는 칸은
    ///    스키마를 어긋나게 만들고, 이 저장소가 한 번 크게 데인 자리가 바로 그것이다
    ///    (모르는 필드 하나가 미러링 초기화를 통째로 실패시켜 동기화가 조용히 멈췄다).
    ///    맥이 이 칸을 만들면 아이폰도 알고는 있어야 한다.
    var calendarEventID: String? = nil

    // Review (populated after the day passes)
    var reviewStatusRaw: String? = nil
    var reviewNote: String? = nil
    var reviewedAt: Date? = nil

    init(day: DayOfWeek,
         timeBand: TimeBand,
         durationHours: Double,
         title: String,
         successCriteria: String,
         deliverable: String,
         weekStartDate: Date,
         concreteVerified: Bool = false,
         withinRoutine: Bool = false,
         startHour: Double = -1)
    {
        self.dayRaw = day.rawValue
        self.timeBandRaw = timeBand.rawValue
        self.durationHours = durationHours
        self.title = title
        self.successCriteria = successCriteria
        self.deliverable = deliverable
        self.weekStartDate = weekStartDate
        self.concreteVerified = concreteVerified
        self.withinRoutine = withinRoutine
        self.startHour = startHour
        self.createdAt = Date()
    }

    var day: DayOfWeek {
        get { DayOfWeek(rawValue: dayRaw) ?? .mon }
        set { dayRaw = newValue.rawValue }
    }

    var timeBand: TimeBand {
        get { TimeBand(rawValue: timeBandRaw) ?? .evening }
        set { timeBandRaw = newValue.rawValue }
    }

    /// 하루 일정 흐름대로 정렬하기 위한 대표 시작 시각.
    /// 정확한 시각이 있으면 그 값을, 없으면 시간대(아침/오후/저녁/심야)의 시작 시각을 쓴다.
    var sortHour: Double {
        if startHour >= 0 { return startHour }
        switch timeBand {
        case .morning: return 6
        case .afternoon: return 12
        case .evening: return 18
        case .night: return 23
        }
    }

    var reviewStatus: ReviewStatus? {
        get { reviewStatusRaw.flatMap(ReviewStatus.init(rawValue:)) }
        set {
            reviewStatusRaw = newValue?.rawValue
            reviewedAt = newValue == nil ? nil : Date()
        }
    }
}
