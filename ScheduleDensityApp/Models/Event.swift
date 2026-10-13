//
//  Event.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation
import SwiftData

// 일정 중요도
enum EventImportance: String, Codable, CaseIterable {
    case high = "high"      // 상 - 높은 중요도
    case medium = "medium"  // 중 - 보통 중요도
    case low = "low"        // 하 - 낮은 중요도

    var displayName: String {
        switch self {
        case .high: return String(localized: "상")
        case .medium: return String(localized: "중")
        case .low: return String(localized: "하")
        }
    }

    var weight: Double {
        switch self {
        case .high: return 3.0
        case .medium: return 2.0
        case .low: return 1.0
        }
    }
}

@Model
final class Event {
    var title: String
    var startDate: Date  // 시작일 (날짜만)
    var endDate: Date    // 종료일 (날짜만, isInfinite가 true면 무시됨)
    var color: String // Hex color string
    var hoursPerDay: Double // 하루당 소요시간 (시간 단위)
    var selectedWeekdays: [Int]? // 선택된 요일 (1=일요일, 2=월요일, ..., 7=토요일), nil이면 모든 요일
    var weeklyPatternData: Data? = nil // 5주×7일(35일) 패턴 데이터 (CloudKit 호환)
    /// 몇 주마다 하는가 — 1 = 매주, 2 = 격주 (→ RainbowEvent.repeatWeeks와 같은 뜻).
    /// 시작일부터 7일씩 세어 그 주에만 요일이 선다. 35일 패턴이 있으면 보지 않는다.
    var repeatWeeks: Int = 1
    /// 회차 `[RainbowSession]` JSON (→ RainbowEvent.sessionsData와 같은 꼴). 있으면 이 날들만 하는 날이다.
    /// 맥에서 적는다 — 아이폰은 읽어서 그리기만 한다.
    var sessionsData: Data? = nil

    var sessions: [RainbowSession] { RainbowSession.decode(sessionsData) }

    /// 이 블록(맥 계획 미러)이 이 일정의 회차를 옮겨 적은 것인가 (→ RainbowEvent.carriesSession).
    func carriesSession(blockTitle: String, on date: Date) -> Bool {
        guard sessionsData != nil, blockTitle.hasPrefix(title) else { return false }
        let d = Calendar.current.startOfDay(for: date)
        return sessions.contains { RainbowEvent.day($0.date) == d }
    }
    var cloudKitRecordName: String? // CloudKit record ID (동기화용)
    var importanceRaw: String = EventImportance.medium.rawValue // 중요도 (EventImportance enum의 rawValue), 기본값: medium
    var isInfinite: Bool = false // 무한 반복 일정 여부 (true면 종료일 없이 최대 365일까지 표시)
    var excludedDatesData: Data? = nil  // CloudKit 호환성을 위해 Data로 저장
    /// 이어져 있는 할 일(BacklogItem)의 dragToken.
    /// 할 일에 데드라인을 정하면 이 줄이 그어지고, 무지개에 줄을 그으면 할 일로 가져갈 수 있다.
    /// (할 일 쪽 스키마는 맥앱과 공유하는 CloudKit 스키마라 건드리지 않고, 연결은 이쪽에만 둔다.)
    var todoToken: String? = nil

    // Computed property for importance
    var importance: EventImportance {
        get { EventImportance(rawValue: importanceRaw) ?? .medium }
        set { importanceRaw = newValue.rawValue }
    }

    // Computed property for excluded dates
    var excludedDates: Set<Date> {
        get {
            guard let data = excludedDatesData,
                  let dates = try? JSONDecoder().decode([Date].self, from: data) else {
                return []
            }
            let calendar = Calendar.current
            return Set(dates.map { calendar.startOfDay(for: $0) })
        }
        set {
            let calendar = Calendar.current
            let normalizedDates = newValue.map { calendar.startOfDay(for: $0) }
            excludedDatesData = try? JSONEncoder().encode(Array(normalizedDates))
        }
    }

    // Computed property for weekly pattern (5주×7일 = 35일 패턴)
    var weeklyPattern: [Bool]? {
        get {
            guard let data = weeklyPatternData,
                  let pattern = try? JSONDecoder().decode([Bool].self, from: data),
                  pattern.count == 35 else {
                return nil
            }
            return pattern
        }
        set {
            if let pattern = newValue, pattern.count == 35 {
                weeklyPatternData = try? JSONEncoder().encode(pattern)
            } else {
                weeklyPatternData = nil
            }
        }
    }

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        color: String = "#FF3B30",
        hoursPerDay: Double = 2.0,
        selectedWeekdays: [Int]? = nil,
        weeklyPattern: [Bool]? = nil,
        cloudKitRecordName: String? = nil,
        importance: EventImportance = .medium,
        isInfinite: Bool = false,
        excludedDates: Set<Date> = []
    ) {
        self.title = title
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = Calendar.current.startOfDay(for: endDate)
        self.color = color
        self.hoursPerDay = hoursPerDay
        self.selectedWeekdays = selectedWeekdays
        self.cloudKitRecordName = cloudKitRecordName
        self.importanceRaw = importance.rawValue
        self.isInfinite = isInfinite
        self.excludedDatesData = try? JSONEncoder().encode(Array(excludedDates.map {
            Calendar.current.startOfDay(for: $0)
        }))
        if let pattern = weeklyPattern, pattern.count == 35 {
            self.weeklyPatternData = try? JSONEncoder().encode(pattern)
        }
    }

    /// 레인 배정 딕셔너리 키. **이 일정 하나를 가리키는 이름**이어야 한다.
    ///
    /// ⚠️ 예전에는 `제목|시작일|색`을 섞어 "사실상 유일한" 키를 만들었는데, 사실상은
    ///    유일하지 않았다. 이름도 시작일도 색도 같은 일정 둘(같은 팔레트에서 고른 두 줄,
    ///    같은 일을 두 번 적은 줄)이 **한 키**를 나눠 갖고, 레인 배정이 서로 덮어써져
    ///    무지개에 한 줄만 그려졌다. 두 개인데 한 줄로 나오던 것이 이것이다.
    ///
    ///    SwiftData가 이미 행마다 유일한 이름을 들고 있으므로 그것을 그대로 쓴다.
    ///    같은 행이면 어느 컨텍스트에서 읽어도 같은 값이라, 화면과 계산이 서로를 찾는다.
    ///    ⚠️ 단, **스토어에 안 넣은 임시 객체**(맥 계획을 비춘 미러 → `WeekBlocksStore.loadVisualEvents`)는
    ///    `persistentModelID`가 아직 없어서 `temporaryIdentifier`라는 **같은 글자**가 나온다.
    ///    그래서 미러 열 개가 한 키를 나눠 갖고, 레인 배정이 마지막 하나로 덮어써져
    ///    무지개가 통째로 한 칸(마지막 일정의 레인)에 그려졌다 — 1·2번 칸이 비고 3번만 노랗던 것이 이것이다.
    ///    만든 쪽이 `mirrorKey`를 새겨 주면 그것을 쓴다.
    ///    이름표가 없는 임시 객체가 다른 길로 들어와도 줄이 겹치지 않게, 그때는 **객체 자신의 주소**로
    ///    떨어뜨린다. 한 번 계산한 배정을 그리는 동안 그 객체가 살아 있으므로 그 사이에는 변하지 않는다.
    var laneKey: String {
        if let mirrorKey { return mirrorKey }
        if modelContext == nil {
            return "tmp:\(UInt(bitPattern: ObjectIdentifier(self).hashValue))"
        }
        return String(describing: persistentModelID)
    }

    /// 스토어에 안 들어가는 임시 객체의 이름표. 저장하지 않는다(@Transient).
    /// 맥 계획 미러처럼 `persistentModelID`가 없는 객체만 이것을 새긴다.
    @Transient var mirrorKey: String? = nil

    // 이 일정의 실제 종료일 계산 (무한 반복 고려)
    func effectiveEndDate() -> Date {
        if isInfinite {
            // 무한 반복: 시작일부터 365일 후
            let calendar = Calendar.current
            return calendar.date(byAdding: .day, value: 365, to: startDate) ?? endDate
        }
        return endDate
    }

    /// **종료일까지 매여 있는 줄인가** — 무지개·위젯·하루 화면이 한 기준으로 쓴다.
    ///
    /// 이 앱에 적은, 끝이 있는 일정만 그렇다.
    ///  - 캘린더·맥 계획을 비춘 줄(`mirrorKey`)은 **그 날 열리는 것**이 전부다. 매주 월요일 회의를
    ///    한 줄로 묶으면 첫 회차~마지막 회차가 기간이 되는데, 그 사이 화~일을 옅게 칠하면 회의가
    ///    취소되고 옮겨져도 무지개는 꽉 찬 채다. 하루 화면은 그 날 열리는 회의만 세운다.
    ///  - 끝없이 반복하는 일정은 마감이 없어 매여 있는 게 아니라 습관이다.
    var carriesSpan: Bool { mirrorKey == nil && !isInfinite }

    /// 이 날짜가 이 일정의 '기간 안'인지 — 시작일부터 종료일(=마감·공연일)까지.
    ///
    /// `occursOn`과 다르다. 바이올린 연습이 주 1회라도 공연이 두 달 뒤라면,
    /// 그 두 달은 통째로 이 일정에 매여 있는 시간이다. 연습하는 날만 칠하면
    /// 무지개에서 그 두 달이 비어 보여서, 실제로 짊어지고 있는 무게가 안 보인다.
    /// 그래서 기간은 옅게 이어 칠하고, 실제로 하는 날(`occursOn`)만 진하게 칠한다.
    ///
    /// 요일·35일 패턴은 보지 않는다. 다만 '이 날짜만 제외'로 직접 뺀 날은 빼준다 —
    /// 사용자가 손으로 지운 날까지 이어 칠하면 지운 뜻이 사라진다.
    func spansOn(date: Date) -> Bool {
        guard carriesSpan else { return false }
        let calendar = Calendar.current
        let checkDate = calendar.startOfDay(for: date)
        guard checkDate >= startDate && checkDate <= effectiveEndDate() else { return false }
        return !excludedDates.contains(checkDate)
    }

    // 특정 날짜에 이 이벤트가 진행 중인지 확인
    func occursOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let checkDate = calendar.startOfDay(for: date)

        // startDate <= checkDate <= effectiveEndDate 인지 확인
        let actualEndDate = effectiveEndDate()
        guard checkDate >= startDate && checkDate <= actualEndDate else {
            return false
        }

        // 회차가 있으면 그 날들만 (패턴 · 요일보다 먼저)
        let sessionList = sessions
        if !sessionList.isEmpty {
            return sessionList.contains { RainbowEvent.day($0.date) == checkDate } && !excludedDates.contains(checkDate)
        }

        // 35일 패턴 체크 (우선순위 높음)
        if let pattern = weeklyPattern {
            // 시작일로부터 며칠 지났는지 계산
            let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: checkDate).day ?? 0
            // 35일 주기로 반복되는 패턴에서의 위치
            let patternIndex = daysSinceStart % 35

            if patternIndex >= 0 && patternIndex < 35 {
                if !pattern[patternIndex] {
                    return false
                }
            }
        }
        // 요일 체크 (selectedWeekdays가 nil이면 모든 요일 허용) + N주마다
        else {
            if let weekdays = selectedWeekdays, !weekdays.isEmpty {
                let weekday = calendar.component(.weekday, from: checkDate)
                if !weekdays.contains(weekday) {
                    return false
                }
            }
            if repeatWeeks > 1 {
                let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: checkDate).day ?? 0
                if (daysSinceStart / 7) % repeatWeeks != 0 {
                    return false
                }
            }
        }

        // 예외 날짜인지 확인
        if excludedDates.contains(checkDate) {
            return false
        }

        return true
    }

    // 실제로 표시되는 칸 수 계산 (요일 선택 고려, 무한 반복 고려)
    func actualCellCount() -> Int {
        let calendar = Calendar.current
        var count = 0
        var currentDate = startDate
        let actualEndDate = effectiveEndDate()

        while currentDate <= actualEndDate {
            if occursOn(date: currentDate) {
                count += 1
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return count
    }

    // MARK: - Exception Date Management

    func addExceptionDate(_ date: Date) {
        var current = excludedDates
        let calendar = Calendar.current
        current.insert(calendar.startOfDay(for: date))
        excludedDates = current
    }

    func removeExceptionDate(_ date: Date) {
        var current = excludedDates
        let calendar = Calendar.current
        current.remove(calendar.startOfDay(for: date))
        excludedDates = current
    }

    func cleanupOldExceptions() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoffDate = calendar.date(byAdding: .day, value: -30, to: today) else {
            return
        }

        let current = excludedDates
        let cleaned = current.filter { $0 >= cutoffDate }

        if current.count != cleaned.count {
            excludedDates = Set(cleaned)
        }
    }

    func getFutureExceptions() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Array(excludedDates.filter { $0 >= today }).sorted()
    }

    func getPastExceptions() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Array(excludedDates.filter { $0 < today }).sorted()
    }
}
