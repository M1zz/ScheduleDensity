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

    // Review (populated after the day passes)
    var reviewStatusRaw: String? = nil
    var reviewNote: String? = nil
    var reviewedAt: Date? = nil


    // MARK: - 전파 계약 (맥 '무지개 공방' 전용 기능)
    //
    // ⚠️ **이 앱은 이 값들을 쓰지 않는다. 그런데 반드시 있어야 한다.**
    //
    // 맥과 iOS가 **같은 CloudKit 스토어 하나**를 공유하므로(→ WeekBlocksStore)
    // 레코드의 모양이 양쪽에서 같아야 한다. 이 앱 모델에 칸이 없으면, 저장할 때마다
    // 맥이 적어 둔 계약(대상·두 날짜·넘길 형태·이미 보낸 시점)이 날아갈 수 있고
    // 무엇이 날아갔는지 이 앱은 알지도 못한다.
    //
    // 저장 프로퍼티만 맥과 똑같이 둔다. 계산·화면은 맥에만 있다
    // (→ 무지개 공방/WeekBlocks/BroadcastContract.swift).
    // **맥에서 필드가 늘면 여기도 같이 늘릴 것.**
    var needsBroadcast: Bool = false
    var deadline: Date? = nil
    var broadcastAudienceRaw: String = "decisionMaker"
    var broadcastRecipient: String = ""
    var handoffForm: String = ""
    var earliestDate: Date? = nil
    var latestDate: Date? = nil
    var broadcastConfidenceRaw: String = "medium"
    var openVariable: String = ""
    var variableResolveDate: Date? = nil
    var noSignalRuleAgreed: Bool = false
    var broadcastContractVerified: Bool = false
    var sentCheckpointsRaw: String = ""

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
