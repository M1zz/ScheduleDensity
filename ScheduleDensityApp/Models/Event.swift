//
//  Event.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation
import SwiftData

@Model
final class Event {
    var title: String
    var startDate: Date  // 시작일 (날짜만)
    var endDate: Date    // 종료일 (날짜만)
    var color: String // Hex color string
    var hoursPerDay: Double // 하루당 소요시간 (시간 단위)
    var selectedWeekdays: [Int]? // 선택된 요일 (1=일요일, 2=월요일, ..., 7=토요일), nil이면 모든 요일

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        color: String = "#FF3B30",
        hoursPerDay: Double = 2.0,
        selectedWeekdays: [Int]? = nil
    ) {
        self.title = title
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = Calendar.current.startOfDay(for: endDate)
        self.color = color
        self.hoursPerDay = hoursPerDay
        self.selectedWeekdays = selectedWeekdays
    }

    // 특정 날짜에 이 이벤트가 진행 중인지 확인
    func occursOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let checkDate = calendar.startOfDay(for: date)

        // startDate <= checkDate <= endDate 인지 확인
        guard checkDate >= startDate && checkDate <= endDate else {
            return false
        }

        // 요일 체크 (selectedWeekdays가 nil이면 모든 요일 허용)
        if let weekdays = selectedWeekdays, !weekdays.isEmpty {
            let weekday = calendar.component(.weekday, from: checkDate)
            return weekdays.contains(weekday)
        }

        return true
    }

    // 실제로 표시되는 칸 수 계산 (요일 선택 고려)
    func actualCellCount() -> Int {
        let calendar = Calendar.current
        var count = 0
        var currentDate = startDate

        while currentDate <= endDate {
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
}
