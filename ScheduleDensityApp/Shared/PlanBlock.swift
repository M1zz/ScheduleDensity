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


    // MARK: - 함께 쓰는 것인가 (→ TodoSharing.swift)
    //
    // 할 일에만 걸려 있던 규칙을 계획·루틴에도 넓혔다. 맥('무지개 공방')이 잠긴 채
    // 만든 계획·루틴은 여기서 false로 실려 오고, 아이폰은 그것을 안 그린다.
    // ⚠️ 맥의 같은 이름 파일과 **규칙이 똑같아야 한다.** 한쪽만 고치면 한쪽에서만 보인다.

    /// 상대 기기에도 보여도 되는가.
    var isShared: Bool = true

    /// 이것이 난 자리(앱 설치본). 감출 것을 고르려면 누가 만들었는지를 알아야 한다.
    var originInstallID: String = ""

    /// **돌아오면 무엇부터.** 맥에서 타이머를 멈출 때 한 줄 남기는 '다음 첫 동작'.
    /// 아이폰에는 아직 적는 화면이 없지만, 칸은 있어야 맥이 적은 값을 받아 들고 있는다.
    ///
    /// ⚠️ 맥 '무지개 공방'의 같은 이름 필드와 **이름·타입이 같아야 한다** (CloudKit 스키마를 함께 쓴다).
    var nextAction: String? = nil

    // Review (populated after the day passes)
    var reviewStatusRaw: String? = nil
    var reviewNote: String? = nil
    var reviewedAt: Date? = nil
    /// 알약 아이콘 (SF Symbol 이름) — 맥 일간 시간표에서 누르면 바뀐다. 아이폰은 아직 안 그린다.
    /// ⚠️ 맥 PlanBlock 에도 같은 칸이 있다. CloudKit 스키마가 늘어나는 필드 (→ README).
    var iconName: String? = nil

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

// MARK: - 종일 (→ 맥 '무지개 공방' PlanBlock.swift — 규칙이 같아야 한다)

extension PlanBlock {
    /// `startHour`에 맥이 적는 '종일' 표시. 기념일·마감일처럼 '이 날의 일'이지 한 시간을 쓰는 일이 아니다.
    ///
    /// ⚠️ 새 필드가 아니라 기존 칸의 값이다(-1 '시각 미정'보다 아래). 예전 아이폰은 이걸 '시각 없음'으로 읽어
    ///    시간대 근처 빈 자리에 알약으로 박았다 — 맥은 머리 밑 '종일' 줄에 세우는데. 같은 날이 두 앱에서 달랐다.
    static let allDayHour: Double = -2

    /// **배경 종일** — 공휴일·생일·휴가처럼 그날이 어떤 날인지만 말하는 것. 할 일로 세지 않는다.
    static let backgroundHour: Double = -3

    /// 시간을 차지하지 않고 그날 맨 위에 서는 블록인가. 루틴 안 일정은 늘 시각을 갖는다.
    var isAllDay: Bool { startHour <= Self.allDayHour + 0.5 && !withinRoutine }

    /// 배경 종일인가.
    var isBackground: Bool { isAllDay && startHour <= Self.backgroundHour + 0.5 }
}

// MARK: - 알약 아이콘 (→ 맥 PlanBlock.symbol — 같은 블록이 두 앱에서 같은 아이콘이어야 한다)

extension PlanBlock {
    /// ⚠️ 맥의 목록과 **차례까지 같아야 한다.** 고른 아이콘이 없을 때 이 목록에서 뽑으므로,
    ///    한 칸만 어긋나도 같은 블록이 두 앱에서 다른 그림이 된다.
    static let symbolChoices: [String] = [
        "star.fill", "leaf.fill", "flame.fill", "bolt.fill", "book.fill", "pencil",
        "paintbrush.fill", "hammer.fill", "cup.and.saucer.fill", "fork.knife", "figure.walk",
        "dumbbell.fill", "music.note", "gamecontroller.fill", "laptopcomputer", "phone.fill",
        "envelope.fill", "cart.fill", "house.fill", "car.fill", "airplane", "heart.fill",
        "brain.head.profile", "lightbulb.fill", "graduationcap.fill", "briefcase.fill",
        "calendar", "checklist", "paperplane.fill", "camera.fill", "gift.fill", "pawprint.fill",
        "sparkles", "moon.fill", "sun.max.fill", "drop.fill", "globe.asia.australia.fill",
        "puzzlepiece.fill", "wrench.and.screwdriver.fill", "chart.bar.fill", "scissors",
        "tshirt.fill", "bicycle", "tram.fill", "film.fill", "headphones", "mic.fill",
        "bubble.left.fill", "person.2.fill", "cloud.fill",
    ]

    /// 그릴 아이콘. 맥에서 골라 둔 것이 있으면 그것, 없으면 **만든 시각**에서 늘 같은 하나를 뽑는다
    /// (FNV-1a — 맥과 같은 셈). 아이폰은 읽기만 한다 — 바꾸는 것은 맥 몫이다.
    var symbol: String {
        if let iconName, !iconName.isEmpty { return iconName }
        let ms = UInt64(max(0, createdAt.timeIntervalSince1970 * 1000))
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        withUnsafeBytes(of: ms.littleEndian) { bytes in
            for b in bytes { h ^= UInt64(b); h &*= 0x0000_0100_0000_01b3 }
        }
        return Self.symbolChoices[Int(h % UInt64(Self.symbolChoices.count))]
    }
}
