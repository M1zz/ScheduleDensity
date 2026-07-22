//
//  RecurrencePattern.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation
import SwiftData

enum RecurrencePattern: String, Codable {
    case daily
    case weekly
    case custom

    func matchesDate(_ date: Date, daysOfWeek: [Int]?) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        switch self {
        case .daily:
            return true
        case .weekly:
            return daysOfWeek?.contains(weekday) ?? false
        case .custom:
            return false
        }
    }

    func description(daysOfWeek: [Int]?) -> String {
        switch self {
        case .daily:
            return "매일"
        case .weekly:
            guard let days = daysOfWeek else { return "매주" }
            let dayNames = days.sorted().map { weekdayName(for: $0) }
            return dayNames.joined(separator: ", ")
        case .custom:
            return "사용자 지정"
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        switch weekday {
        case 1: return "일"
        case 2: return "월"
        case 3: return "화"
        case 4: return "수"
        case 5: return "목"
        case 6: return "금"
        case 7: return "토"
        default: return ""
        }
    }

    // 미리 정의된 요일 패턴들
    static var everyDayPattern: [Int] {
        [1, 2, 3, 4, 5, 6, 7]
    }

    static var weekdaysPattern: [Int] {
        [2, 3, 4, 5, 6] // 월~금
    }

    static var weekendsPattern: [Int] {
        [1, 7] // 일, 토
    }

    static var mondayWednesdayFridayPattern: [Int] {
        [2, 4, 6] // 월, 수, 금
    }

    static var tuesdayThursdayPattern: [Int] {
        [3, 5] // 화, 목
    }
}
