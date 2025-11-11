//
//  DensityCalculator.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation

struct TimeSlot: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let startTime: Date
    let endTime: Date
    let density: Int // 겹치는 일정 개수
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TimeSlot, rhs: TimeSlot) -> Bool {
        lhs.id == rhs.id
    }
}

struct DayDensity {
    let date: Date
    let totalSlots: Int
    let occupiedSlots: Int
    let averageDensity: Double
    let maxDensity: Int
    
    var occupancyRate: Double {
        guard totalSlots > 0 else { return 0 }
        return Double(occupiedSlots) / Double(totalSlots)
    }
}

struct Recommendation: Identifiable {
    let id = UUID()
    let date: Date
    let timeSlot: String
    let startTime: Date
    let endTime: Date
    let reason: String
    let score: Double // 0~1, 높을수록 좋음
}

class DensityCalculator {
    
    // 특정 날짜의 30분 단위 밀도 계산
    static func calculateDensity(for date: Date, events: [Event]) -> [TimeSlot] {
        let calendar = Calendar.current
        let slots = calendar.halfHourSlots(for: date)
        
        return slots.map { slotStart in
            let slotEnd = calendar.date(byAdding: .minute, value: 30, to: slotStart) ?? slotStart
            
            // 이 슬롯에 겹치는 이벤트 개수 계산
            let density = events.filter { event in
                guard event.occursOn(date: date) else { return false }
                
                let instance = event.instanceFor(date: date)
                return isOverlapping(
                    start1: instance.startTime, end1: instance.endTime,
                    start2: slotStart, end2: slotEnd
                )
            }.count
            
            return TimeSlot(
                date: date,
                startTime: slotStart,
                endTime: slotEnd,
                density: density
            )
        }
    }
    
    // 주간 밀도 계산
    static func calculateWeekDensity(startOfWeek: Date, events: [Event]) -> [DayDensity] {
        let calendar = Calendar.current
        var densities: [DayDensity] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                continue
            }
            
            let slots = calculateDensity(for: date, events: events)
            let occupiedSlots = slots.filter { $0.density > 0 }.count
            let totalDensity = slots.reduce(0) { $0 + $1.density }
            let avgDensity = Double(totalDensity) / Double(slots.count)
            let maxDensity = slots.map { $0.density }.max() ?? 0
            
            densities.append(DayDensity(
                date: date,
                totalSlots: slots.count,
                occupiedSlots: occupiedSlots,
                averageDensity: avgDensity,
                maxDensity: maxDensity
            ))
        }
        
        return densities
    }
    
    // 비어있는 시간대 추천
    static func recommendTimeSlots(
        for duration: TimeInterval,
        in week: Date,
        events: [Event],
        preferredHours: ClosedRange<Int> = 9...22 // 선호 시간대: 오전 9시 ~ 오후 10시
    ) -> [Recommendation] {
        let calendar = Calendar.current
        let startOfWeek = week.startOfWeek
        var recommendations: [Recommendation] = []
        
        // 각 요일 확인
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                continue
            }
            
            let slots = calculateDensity(for: date, events: events)
            
            // duration에 맞는 연속된 빈 슬롯 찾기
            let requiredSlots = Int(ceil(duration / 1800)) // 30분 = 1800초
            
            for i in 0...(slots.count - requiredSlots) {
                let consecutiveSlots = Array(slots[i..<(i + requiredSlots)])
                
                // 모든 슬롯이 비어있는지 확인
                if consecutiveSlots.allSatisfy({ $0.density == 0 }) {
                    let startSlot = consecutiveSlots.first!
                    let endSlot = consecutiveSlots.last!
                    
                    // 선호 시간대인지 확인
                    let hour = calendar.component(.hour, from: startSlot.startTime)
                    if preferredHours.contains(hour) {
                        let weekday = calendar.component(.weekday, from: date)
                        let dayName = weekdayName(for: weekday)
                        
                        let timeFormatter = DateFormatter()
                        timeFormatter.locale = Locale(identifier: "ko_KR")
                        timeFormatter.dateFormat = "HH:mm"
                        
                        let timeString = "\(timeFormatter.string(from: startSlot.startTime)) - \(timeFormatter.string(from: endSlot.endTime))"
                        
                        // 주변 슬롯의 밀도 계산 (점수 산정)
                        let surroundingDensity = calculateSurroundingDensity(
                            centerIndex: i,
                            slots: slots,
                            range: 4 // 앞뒤 2시간
                        )
                        
                        let score = 1.0 - (surroundingDensity / 10.0) // 주변이 비어있을수록 높은 점수
                        
                        recommendations.append(Recommendation(
                            date: date,
                            timeSlot: "\(dayName) \(timeString)",
                            startTime: startSlot.startTime,
                            endTime: endSlot.endTime,
                            reason: "주변 일정이 적어 여유있는 시간대입니다.",
                            score: max(0, min(1, score))
                        ))
                    }
                }
            }
        }
        
        // 점수 순으로 정렬
        return recommendations.sorted { $0.score > $1.score }
    }
    
    // 두 시간대가 겹치는지 확인
    private static func isOverlapping(start1: Date, end1: Date, start2: Date, end2: Date) -> Bool {
        return start1 < end2 && end1 > start2
    }
    
    // 주변 슬롯의 평균 밀도 계산
    private static func calculateSurroundingDensity(
        centerIndex: Int,
        slots: [TimeSlot],
        range: Int
    ) -> Double {
        let startIndex = max(0, centerIndex - range)
        let endIndex = min(slots.count - 1, centerIndex + range)
        
        let surroundingSlots = slots[startIndex...endIndex]
        let totalDensity = surroundingSlots.reduce(0) { $0 + $1.density }
        
        return Double(totalDensity) / Double(surroundingSlots.count)
    }
    
    private static func weekdayName(for weekday: Int) -> String {
        switch weekday {
        case 1: return "일요일"
        case 2: return "월요일"
        case 3: return "화요일"
        case 4: return "수요일"
        case 5: return "목요일"
        case 6: return "금요일"
        case 7: return "토요일"
        default: return ""
        }
    }
}
