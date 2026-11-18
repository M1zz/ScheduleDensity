import Foundation
import SwiftData

// 아이폰 '욕망의 무지개' · 맥 '무지개 공방' 이 이 모델 하나를 쓴다 (Shared/).
// 같은 CloudKit 레코드 타입(CD_PlanBlock)이라 칸을 더하면 두 앱이 함께 바뀐다.
// 맥 화면만 쓰는 도우미는 macOS/WeekBlocks/PlanBlock+Mac.swift 에 있다.

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

    /// 맥 캘린더에서 온 블록이면 그 일정을 가리키는 이름 (→ macOS/WeekBlocks/CalendarImport.swift).
    /// nil이면 사람이 직접 세운 블록이라 가져오기가 절대 건드리지 않는다. 아이폰은 쓰지 않지만 칸은 같이 든다.
    ///
    /// ⚠️ **CloudKit 스키마가 늘어나는 필드다.** 옵셔널이라 기존 레코드는 그대로 열리지만,
    ///    출시 전에 Development → Production 스키마 배포를 빠뜨리면 이 필드를 모르는
    ///    서버가 미러링 초기화 자체를 실패시킨다 (→ WeekBlocks.entitlements의 경고).
    var calendarEventID: String? = nil


    // MARK: - 함께 쓰는 것인가 (→ TodoSharing.swift)
    //
    // 할 일과 같은 규칙을 계획·루틴에도 건다. 동기화 엔진은 골라서 안 올리는 것을
    // 못 하므로, **올라가게 두고 받는 쪽에서 안 그린다.** 그 판단에 필요한 것이
    // 레코드에 같이 실려 가야 한다 — 받는 쪽은 상대가 그때 샀는지를 알 길이 없다.

    /// 상대 기기에도 보여도 되는가. 잠긴 기기에서 만든 것은 false로 찍힌다.
    var isShared: Bool = true

    /// 이것이 난 자리(앱 설치본). 잠긴 기기의 스토어에는 자기 것과 상대 것이 섞여 있어서,
    /// 감출 것을 고르려면 누가 만들었는지를 알아야 한다.
    /// 비어 있으면 이 기능이 생기기 전에 만든 것이고, 그때는 내 것으로 본다.
    var originInstallID: String = ""

    /// **다음 첫 동작.** 이 일을 멈출 때 "돌아오면 무엇부터 하면 되는지"를 한 줄로 남긴다.
    ///
    /// 끊긴 일로 돌아올 때 가장 비싼 것은 시간이 아니라 **다시 올라오는 일**이다 — 어디까지
    /// 했는지, 무엇부터 손대야 하는지를 기억에서 다시 지어내야 한다. 그 한 줄을 멈추는 사람이
    /// 적어 두면(그때가 가장 잘 아는 때다) 돌아온 사람은 읽기만 하면 된다 (→ TimerView).
    ///
    /// ⚠️ **CloudKit 스키마가 늘어나는 필드다.** 옵셔널이라 기존 레코드는 그대로 열리지만,
    ///    출시 전에 Development → Production 스키마 배포를 해야 한다
    ///       (→ CloudSchemaPrimer.swift가 이 칸에 표본 값을 채워 올린다).
    var nextAction: String? = nil

    /// **알약 아이콘** (SF Symbol 이름). nil 이면 만든 시각에서 늘 같은 하나를 뽑아 그린다
    /// (→ `symbol`). 일간 시간표에서 알약 아이콘을 누르면 새로 뽑아 여기 적는다.
    ///
    /// ⚠️ **CloudKit 스키마가 늘어나는 필드다.** 두 앱이 이 정의 하나를 쓴다.
    ///    출시 전 Development → Production 스키마 배포에 실려 가야 한다 (→ CloudSchemaPrimer).
    var iconName: String? = nil

    /// **실제로 걸린 분.** '걸린 시간 재기'(설정 ▸ 타이머)를 켠 사람이 타이머로 이 일을 센 만큼이
    /// 쌓인다 (→ ActualTime.swift). nil이면 재지 않은 것이다 — 0분 걸렸다는 뜻이 아니다.
    /// 계획한 길이(`durationHours`)와 견주어 '이 일은 늘 몇 % 더 걸리는가'를 낸다 (→ ReflectionTrends.paces).
    ///
    /// ⚠️ **CloudKit 스키마가 늘어나는 필드다.** 두 앱이 이 정의 하나를 쓴다.
    ///    출시 전 Development → Production 스키마 배포에 실려 가야 한다 (→ CloudSchemaPrimer).
    var actualMinutes: Double? = nil

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
        // ⚠️ **여기서 찍는다.** 만드는 자리가 여섯 곳이라 부르는 쪽에 맡기면 언젠가
        //    한 곳을 빠뜨리고, 빠뜨린 것은 '잠긴 기기에서 만든 게 상대에게 보인다'는
        //    조용한 구멍이 된다. CloudKit이 내려준 레코드는 init을 거치지 않으므로
        //    남의 값이 덮이지 않는다.
        TodoSharing.stamp(self)
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
        if isAllDay { return -1 }
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

// MARK: - 종일

extension PlanBlock {
    /// `startHour`에 적는 '종일' 표시. 기념일·마감일처럼 '이 날의 일'이지 한 시간을 쓰는 일이 아니다.
    ///
    /// ⚠️ **필드를 늘리지 않고 기존 칸에 적는다** (-1 '시각 미정'보다 아래). 길이가 0이라
    ///    어디서도 시간을 차지하지 않는다.
    static let allDayHour: Double = -2

    /// **배경 종일** — 공휴일 · 생일 · 휴가 · 출장처럼 '그날이 어떤 날인지'를 말할 뿐 할 일이 아닌 것.
    /// 무지개 칸을 안 차지하고, 회고·'끝냈나요?'도 묻지 않는다. 종일과 같은 까닭으로 한 칸 더 아래(-3).
    static let backgroundHour: Double = -3

    /// 시간을 차지하지 않고 그날 맨 위에 서는 블록인가. 루틴 안 일정은 늘 시각을 갖는다.
    var isAllDay: Bool { startHour <= Self.allDayHour + 0.5 && !withinRoutine }

    /// 배경 종일인가 (→ backgroundHour). 캘린더에서 가져온 종일은 이것이 기본이다.
    var isBackground: Bool { isAllDay && startHour <= Self.backgroundHour + 0.5 }
}

// MARK: - 알약 아이콘

extension PlanBlock {
    /// 뽑을 수 있는 아이콘. 할 일의 성격을 짐작하지 않는 두루 쓰이는 것들이다.
    /// ⚠️ **차례까지 그대로 둔다.** 고른 아이콘이 없을 때 이 목록에서 뽑으므로 순서가 바뀌면 그림이 바뀐다.
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

    /// 그릴 아이콘. 정해 둔 것이 없으면 **만든 시각**에서 늘 같은 하나를 뽑는다.
    ///
    /// ⚠️ 씨앗으로 `dragToken`(= persistentModelID)을 쓰지 않는다. 저장 전후로 바뀌고 기기마다
    ///    달라서, 같은 블록이 맥과 아이폰에서 다른 아이콘이 된다. Swift 의 `hashValue` 도 실행마다
    ///    달라서 안 쓴다 — FNV-1a 로 직접 섞는다.
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
