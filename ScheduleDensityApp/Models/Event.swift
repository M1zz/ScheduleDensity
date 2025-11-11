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
    var id: UUID
    var title: String
    var startTime: Date
    var endTime: Date
    var color: String // Hex color string
    var recurrencePattern: RecurrencePattern?
    var recurrenceDaysOfWeek: [Int]? // For weekly patterns: 1=일, 2=월, 3=화, 4=수, 5=목, 6=금, 7=토
    var recurrenceEndDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        endTime: Date,
        color: String = "#FF6B6B",
        recurrencePattern: RecurrencePattern? = nil,
        recurrenceDaysOfWeek: [Int]? = nil,
        recurrenceEndDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.recurrencePattern = recurrencePattern
        self.recurrenceDaysOfWeek = recurrenceDaysOfWeek
        self.recurrenceEndDate = recurrenceEndDate
    }
    
    // 특정 날짜에 이 이벤트가 발생하는지 확인
    func occursOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let eventDate = calendar.startOfDay(for: startTime)
        let checkDate = calendar.startOfDay(for: date)

        // 반복 패턴이 없는 경우
        guard let pattern = recurrencePattern else {
            return calendar.isDate(eventDate, inSameDayAs: checkDate)
        }

        // 날짜가 이벤트 시작일 이전인지 확인
        if checkDate < eventDate {
            return false
        }

        // 반복 종료일이 있는 경우 체크
        if let endDate = recurrenceEndDate {
            let recurrenceEnd = calendar.startOfDay(for: endDate)
            if checkDate > recurrenceEnd {
                return false
            }
        }

        // 반복 패턴에 따라 확인
        return pattern.matchesDate(date, daysOfWeek: recurrenceDaysOfWeek)
    }
    
    // 특정 날짜의 시간대로 이벤트 복사
    func instanceFor(date: Date) -> EventInstance {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let durationComponents = calendar.dateComponents([.hour, .minute], from: startTime, to: endTime)
        
        var newStart = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                      minute: timeComponents.minute ?? 0,
                                      second: 0,
                                      of: date) ?? date
        
        var newEnd = calendar.date(byAdding: durationComponents, to: newStart) ?? date
        
        return EventInstance(
            id: UUID(),
            parentEventId: id,
            title: title,
            startTime: newStart,
            endTime: newEnd,
            color: color
        )
    }
}

// 특정 날짜의 이벤트 인스턴스 (표시용)
struct EventInstance: Identifiable {
    let id: UUID
    let parentEventId: UUID
    let title: String
    let startTime: Date
    let endTime: Date
    let color: String
}
