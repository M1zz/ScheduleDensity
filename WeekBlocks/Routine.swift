import Foundation
import SwiftUI
import SwiftData

@Model
final class Routine {
    var name: String = ""
    var iconName: String = "calendar"
    var kindRaw: String = RoutineKind.fixed.rawValue
    var colorName: String = "blue"

    // For .fixed
    var dayMask: Int = 0
    var startHour: Double = 0
    var durationHours: Double = 1

    // For .quota
    var weeklyHours: Double = 0
    /// 쿼터 루틴의 하루 횟수(끼니·세션). 0 = 미설정. 회당 시간 계산에 사용.
    var sessionsPerDay: Int = 0

    var sortIndex: Int = 0
    var createdAt: Date = Date()

    // Planning fields
    var executionNotes: String = ""
    var premortemFailScenario: String = ""
    var premortemPrevention: String = ""

    init(name: String,
         iconName: String = "calendar",
         kind: RoutineKind,
         colorName: String = "blue",
         dayMask: Int = 0,
         startHour: Double = 0,
         durationHours: Double = 1,
         weeklyHours: Double = 0,
         sessionsPerDay: Int = 0,
         sortIndex: Int = 0)
    {
        self.name = name
        self.iconName = iconName
        self.kindRaw = kind.rawValue
        self.colorName = colorName
        self.dayMask = dayMask
        self.startHour = startHour
        self.durationHours = durationHours
        self.weeklyHours = weeklyHours
        self.sessionsPerDay = sessionsPerDay
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var kind: RoutineKind {
        get { RoutineKind(rawValue: kindRaw) ?? .fixed }
        set { kindRaw = newValue.rawValue }
    }

    var selectedDays: Set<DayOfWeek> {
        get { Set(DayOfWeek.allCases.filter { dayMask & (1 << $0.rawValue) != 0 }) }
        set { dayMask = newValue.reduce(0) { $0 | (1 << $1.rawValue) } }
    }

    var totalWeeklyHours: Double {
        switch kind {
        case .fixed:
            let count = (0..<7).filter { dayMask & (1 << $0) != 0 }.count
            return Double(count) * durationHours
        case .quota:
            return weeklyHours
        }
    }

    /// 쿼터 루틴의 하루 평균 시간 (주간 합계 ÷ 7).
    var dailyQuotaHours: Double { weeklyHours / 7 }

    var scheduleDescription: String {
        switch kind {
        case .fixed:
            let days = DayOfWeek.allCases
                .filter { dayMask & (1 << $0.rawValue) != 0 }
                .map(\.shortLabel)
                .joined(separator: "·")
            let start = formatHour(startHour)
            let end = formatHour(startHour + durationHours)
            return days.isEmpty ? "요일 미지정" : "\(days) \(start)–\(end)"
        case .quota:
            var s = String(format: "주 %.1fh · 일 평균 ", weeklyHours) + formatDuration(dailyQuotaHours)
            if sessionsPerDay > 0 {
                s += " · 회당 약 " + formatDuration(dailyQuotaHours / Double(sessionsPerDay))
            }
            return s
        }
    }

    var displayColor: Color { paletteColor(colorName) }
}

/// 팔레트 색상 이름 → SwiftUI Color (Routine·BacklogCategory 공용)
/// iOS '욕망의 무지개' 팔레트(Apple 시스템 색)와 hex까지 통일. [[Theme.swift]] 참조.
func paletteColor(_ name: String) -> Color {
    let hex: String
    switch name {
    case "red":    hex = Rainbow.red
    case "orange": hex = Rainbow.orange
    case "yellow": hex = Rainbow.yellow
    case "green":  hex = Rainbow.green
    case "blue":   hex = Rainbow.blue
    case "indigo": hex = Rainbow.indigo
    case "purple": hex = Rainbow.purple
    case "pink":   hex = "#FF2D55"   // systemPink (레거시 데이터 호환)
    case "teal":   hex = "#30B0C7"   // systemTeal
    case "cyan":   hex = "#32ADE6"   // systemCyan
    default:       return .accentColor
    }
    return Color(hex: hex) ?? .accentColor
}

// 컬러 피커 옵션 — iOS와 동일한 7색 무지개를 스펙트럼 순서로 노출.
let routineColorOptions: [(name: String, color: Color)] =
    Rainbow.spectrum.map { (name: $0.name, color: Color(hex: $0.hex) ?? .accentColor) }
