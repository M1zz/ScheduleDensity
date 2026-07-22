//
//  WeekBlocksAdapter.swift
//  ScheduleDensityApp
//
//  WeekBlocks(macOS)에서 작성한 주간 계획 데이터를 iOS '욕망의 무지개'의
//  밀도 시각화가 소비하는 형태로 변환하는 읽기 전용 어댑터.
//
//  설계 메모 (todo.md "iOS 시각화 연동" 참조):
//   - iOS는 같은 iCloud 계정(private DB)의 WeekBlocks 데이터를 **읽기 전용**으로만 소비.
//   - 이 파일은 SwiftData/CloudKit/Event 등 어떤 타깃 타입에도 의존하지 않는
//     **순수 변환 코어**입니다. 따라서 지금 단독으로 컴파일·검증할 수 있고,
//     iOS 타깃 배선(모델 공유·CloudKit store)이 끝나면 아래 두 경계만 이어주면 됩니다:
//       1) fetch한 Routine/PlanBlock → WBRoutineInput/WBBlockInput (입력 경계)
//       2) WBVisualEvent → Event (출력 경계, Event(_:) 1:1 매핑)
//     두 매핑 스니펫은 todo.md에 적어 두었습니다.
//
//  ❗️출력(WBVisualEvent → Event)은 시각화 입력용 임시 객체입니다.
//    SwiftData 컨텍스트에 insert 하지 마세요(이중 저장·동기화 충돌 방지).
//

import Foundation

// MARK: - 중립 입력 (WeekBlocks 모델에서 추출, 타깃 의존성 없음)

/// WeekBlocks 루틴의 시각화용 중립 표현.
struct WBRoutineInput {
    enum Kind { case fixed, quota }
    var name: String
    var kind: Kind
    var colorName: String          // "red"/"orange"/… (WeekBlocks 팔레트 이름)
    var weekdaysMonZero: [Int]     // .fixed 전용: 0=월 … 6=일
    var durationHours: Double      // .fixed 전용: 회당 시간
    var weeklyHours: Double         // .quota 전용: 주간 시간 합계

    init(name: String, kind: Kind, colorName: String,
         weekdaysMonZero: [Int] = [], durationHours: Double = 0, weeklyHours: Double = 0) {
        self.name = name
        self.kind = kind
        self.colorName = colorName
        self.weekdaysMonZero = weekdaysMonZero
        self.durationHours = durationHours
        self.weeklyHours = weeklyHours
    }
}

/// WeekBlocks 계획 블록(특정 주)의 시각화용 중립 표현.
struct WBBlockInput {
    var title: String
    var weekStartDate: Date        // 그 주 월요일 00:00
    var dayOffset: Int             // 월요일=0 … 일요일=6
    var durationHours: Double
}

// MARK: - 중립 출력 (iOS에서 Event로 1:1 매핑)

/// 시각화 결과 — iOS에서 `Event`로 그대로 옮겨지는 중립 구조.
struct WBVisualEvent: Equatable {
    var title: String
    var startDate: Date
    var endDate: Date
    var colorHex: String
    var hoursPerDay: Double
    var selectedWeekdays: [Int]?   // iOS Calendar weekday: 일=1 … 토=7 (nil이면 모든 요일)
    var importance: String         // "high" / "medium" / "low"
}

// MARK: - 순수 변환 코어

enum WeekBlocksAdapter {

    /// 고정 루틴 반복을 펼칠 기본 표시 윈도우(주).
    static let defaultWeeks = 8

    /// WeekBlocks 계획 데이터 → 밀도 시각화용 중립 이벤트 배열.
    static func makeVisualEvents(routines: [WBRoutineInput],
                                 blocks: [WBBlockInput],
                                 referenceDate: Date,
                                 calendar: Calendar = .current,
                                 weeks: Int = defaultWeeks) -> [WBVisualEvent] {
        var out: [WBVisualEvent] = []
        out.append(contentsOf: blocks.compactMap { visualEvent(from: $0, calendar: calendar) })
        out.append(contentsOf: routines.compactMap {
            visualEvent(from: $0, referenceDate: referenceDate, calendar: calendar, weeks: weeks)
        })
        return out
    }

    // PlanBlock → 특정 주의 단일 날짜 이벤트
    static func visualEvent(from block: WBBlockInput, calendar: Calendar) -> WBVisualEvent? {
        let title = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        guard let date = calendar.date(byAdding: .day, value: block.dayOffset, to: block.weekStartDate)
        else { return nil }

        return WBVisualEvent(
            title: title,
            startDate: date,
            endDate: date,                  // 하루짜리
            colorHex: defaultBlockColorHex,
            hoursPerDay: max(0, block.durationHours),
            selectedWeekdays: nil,          // 단일 날짜이므로 요일 필터 불필요
            importance: "medium"
        )
    }

    // Routine → 주간 반복 이벤트
    static func visualEvent(from routine: WBRoutineInput,
                            referenceDate: Date,
                            calendar: Calendar,
                            weeks: Int) -> WBVisualEvent? {
        let name = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let start = calendar.startOfDay(for: referenceDate)
        guard let end = calendar.date(byAdding: .day, value: weeks * 7, to: start) else { return nil }

        switch routine.kind {
        case .fixed:
            let weekdays = routine.weekdaysMonZero.map(iosWeekday(fromMonZero:)).sorted()
            guard !weekdays.isEmpty else { return nil }
            return WBVisualEvent(
                title: name,
                startDate: start,
                endDate: end,
                colorHex: hex(for: routine.colorName),
                hoursPerDay: max(0, routine.durationHours),
                selectedWeekdays: weekdays,
                importance: "medium"
            )

        case .quota:
            // 시간대 유연 — 7일 평균 부하 밴드로 표현(모든 요일에 dailyQuota).
            guard routine.weeklyHours > 0 else { return nil }
            return WBVisualEvent(
                title: name,
                startDate: start,
                endDate: end,
                colorHex: hex(for: routine.colorName),
                hoursPerDay: routine.weeklyHours / 7,
                selectedWeekdays: nil,      // 모든 요일
                importance: "low"
            )
        }
    }

    // MARK: - 변환 헬퍼

    /// WeekBlocks 요일(월=0 … 일=6) → iOS Calendar weekday(일=1 … 토=7).
    static func iosWeekday(fromMonZero raw: Int) -> Int {
        (raw + 1) % 7 + 1
    }

    /// 루틴 팔레트 이름 → hex. iOS laneColors와 동일한 무지개 팔레트.
    static func hex(for colorName: String) -> String {
        switch colorName {
        case "red":    return "#FF3B30"
        case "orange": return "#FF9500"
        case "yellow": return "#FFCC00"
        case "green":  return "#34C759"
        case "blue":   return "#007AFF"
        case "indigo": return "#5856D6"
        case "purple": return "#AF52DE"
        case "pink":   return "#FF2D55"
        case "teal":   return "#30B0C7"
        case "cyan":   return "#32ADE6"
        default:       return "#007AFF"
        }
    }

    /// 계획 블록 기본색(소유 루틴 색 미상 → 액센트 블루).
    static let defaultBlockColorHex = "#007AFF"
}
