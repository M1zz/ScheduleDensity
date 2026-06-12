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
        case .high: return "상"
        case .medium: return "중"
        case .low: return "하"
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
    var cloudKitRecordName: String? // CloudKit record ID (동기화용)
    var importanceRaw: String = EventImportance.medium.rawValue // 중요도 (EventImportance enum의 rawValue), 기본값: medium
    var isInfinite: Bool = false // 무한 반복 일정 여부 (true면 종료일 없이 최대 365일까지 표시)
    var excludedDatesData: Data? = nil  // CloudKit 호환성을 위해 Data로 저장

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

    // 이 일정의 실제 종료일 계산 (무한 반복 고려)
    func effectiveEndDate() -> Date {
        if isInfinite {
            // 무한 반복: 시작일부터 365일 후
            let calendar = Calendar.current
            return calendar.date(byAdding: .day, value: 365, to: startDate) ?? endDate
        }
        return endDate
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
        // 요일 체크 (selectedWeekdays가 nil이면 모든 요일 허용)
        else if let weekdays = selectedWeekdays, !weekdays.isEmpty {
            let weekday = calendar.component(.weekday, from: checkDate)
            if !weekdays.contains(weekday) {
                return false
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
