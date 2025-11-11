//
//  DateExtensions.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation

extension Date {
    // 주의 시작일 (월요일)
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        var startOfWeek = calendar.date(from: components) ?? self
        
        // 월요일로 조정 (기본은 일요일)
        startOfWeek = calendar.date(byAdding: .day, value: 1, to: startOfWeek) ?? startOfWeek
        
        return calendar.startOfDay(for: startOfWeek)
    }
    
    // 주의 모든 날짜 (월~일)
    var daysInWeek: [Date] {
        let calendar = Calendar.current
        var days: [Date] = []
        
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                days.append(day)
            }
        }
        
        return days
    }
    
    // 다음 주
    var nextWeek: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: 1, to: self) ?? self
    }
    
    // 이전 주
    var previousWeek: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -1, to: self) ?? self
    }
    
    // 시간 컴포넌트 (시, 분)
    var timeComponents: (hour: Int, minute: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    // 특정 시간으로 설정
    func settingTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }
    
    // 30분 단위로 반올림
    var roundedToHalfHour: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        
        let minute = components.minute ?? 0
        let roundedMinute = minute < 15 ? 0 : (minute < 45 ? 30 : 0)
        let hourAdjustment = minute >= 45 ? 1 : 0
        
        var newComponents = DateComponents()
        newComponents.year = components.year
        newComponents.month = components.month
        newComponents.day = components.day
        newComponents.hour = (components.hour ?? 0) + hourAdjustment
        newComponents.minute = roundedMinute
        newComponents.second = 0
        
        return calendar.date(from: newComponents) ?? self
    }
    
    // 날짜 포맷팅
    func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    // 주차 표시 (예: "3월 1주차")
    var weekDescription: String {
        let month = formatted("M월")
        let calendar = Calendar.current
        let weekOfMonth = calendar.component(.weekOfMonth, from: self)
        return "\(month) \(weekOfMonth)주차"
    }
}

extension Calendar {
    // 두 날짜가 같은 날인지 확인
    func isSameDay(_ date1: Date, as date2: Date) -> Bool {
        return isDate(date1, inSameDayAs: date2)
    }
    
    // 30분 슬롯 생성 (00:00 ~ 23:30)
    func halfHourSlots(for date: Date) -> [Date] {
        var slots: [Date] = []
        let startOfDay = startOfDay(for: date)
        
        for hour in 0..<24 {
            for minute in [0, 30] {
                if let slot = self.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) {
                    slots.append(slot)
                }
            }
        }
        
        return slots
    }
}
