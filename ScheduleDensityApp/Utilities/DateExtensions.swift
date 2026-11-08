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
    
    /// 형식(`"yyyy-MM-dd"` 같은)으로 적는다. 포맷터는 형식마다 하나를 다시 쓴다 (→ `DateTextCache`).
    func formatted(_ format: String) -> String {
        DateTextCache.formatter(format: format).string(from: self)
    }

    /// 템플릿(`"MMMdE"` 같은)으로 적는다. 낱말과 순서는 기기 언어가 정한다.
    /// 형식을 손으로 적지 않을 때는 늘 이것을 쓴다.
    func formatted(template: String) -> String {
        DateTextCache.formatter(template: template).string(from: self)
    }
    
    // 주차 표시 (예: "3월 1주차", "Mar, week 1")
    var weekDescription: String {
        // 달 이름은 형식을 손으로 적지 않는다 — 템플릿만 말하고 로케일이 낱말을 고른다.
        let month = formatted(DateFormatter.dateFormat(fromTemplate: "MMM", options: 0,
                                                       locale: .autoupdatingCurrent) ?? "MMM")
        let calendar = Calendar.current
        let weekOfMonth = calendar.component(.weekOfMonth, from: self)
        return String(localized: "\(month) \(weekOfMonth)주차")
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

// MARK: - 날짜 글자의 포맷터

/// **형식마다 포맷터 하나.** `DateFormatter` 는 만드는 값이 비싸다(로케일 · 달력 자료를 읽는다).
/// 무지개 · 차트는 칸마다 날짜를 적으므로, 그릴 때마다 새로 만들면 스크롤하는 내내 그 값이 든다.
///
/// ⚠️ 로케일은 `.autoupdatingCurrent` 라 기기 언어를 바꿔도 따라간다(언어를 바꾸면 앱이 다시 뜬다).
/// ⚠️ `NSCache` 는 여러 스레드에서 불러도 안전하고, `string(from:)` 도 그렇다.
private enum DateTextCache {
    private static let cache = NSCache<NSString, DateFormatter>()

    static func formatter(format: String) -> DateFormatter {
        cached("f|" + format) { format }
    }

    static func formatter(template: String) -> DateFormatter {
        cached("t|" + template) {
            DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .autoupdatingCurrent) ?? template
        }
    }

    private static func cached(_ key: String, format: () -> String) -> DateFormatter {
        if let hit = cache.object(forKey: key as NSString) { return hit }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = format()
        cache.setObject(formatter, forKey: key as NSString)
        return formatter
    }
}
