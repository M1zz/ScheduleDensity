//
//  DensityCalculator.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation

// 일 단위 밀도 정보
struct DayDensity: Identifiable, Equatable {
    let date: Date
    let density: Int // 해당 날짜에 동시에 진행되는 이벤트 개수
    let events: [Event] // 해당 날짜에 진행되는 이벤트들
    /// 오늘 하는 날은 아니지만 **기간 안**인 이벤트들 (시작일~종료일 사이).
    /// 무지개에서 종료일까지 옅게 이어 칠하는 데 쓴다. 밀도(density)에는 넣지 않는다 —
    /// 그날 실제로 손을 쓰는 양이 아니기 때문에 통계·추천이 부풀면 안 된다.
    let spanEvents: [Event]

    /// 날짜(자정 정규화) 기반 고정 id.
    /// UUID를 쓰면 새로고침 때마다 행 identity가 바뀌어 스크롤 위치가 리셋되고
    /// scrollTo 대상도 무효가 되므로, 반드시 날짜로 유지한다.
    var id: Date { date }

    static func == (lhs: DayDensity, rhs: DayDensity) -> Bool {
        lhs.date == rhs.date
            && lhs.density == rhs.density
            && lhs.spanEvents.count == rhs.spanEvents.count
    }
}

class DensityCalculator {

    // 특정 날짜의 이벤트 밀도 계산
    static func calculateDensity(for date: Date, events: [Event]) -> DayDensity {
        let calendar = Calendar.current
        let checkDate = calendar.startOfDay(for: date)

        // 해당 날짜에 진행 중인 이벤트들 찾기
        let activeEvents = events.filter { $0.occursOn(date: checkDate) }

        // 하는 날은 아니지만 기간 안인 것들 (시작일 순으로 고정 — 레인 칠이 흔들리지 않게).
        let spanningEvents = events
            .filter { $0.spansOn(date: checkDate) && !$0.occursOn(date: checkDate) }
            .sorted { $0.startDate < $1.startDate }

        // 디버그: 중복 확인
        let uniqueColors = Set(activeEvents.map { $0.color })
        if activeEvents.count != uniqueColors.count {
            print("⚠️ [DensityCalculator] 중복 색상 발견! 날짜: \(checkDate), 이벤트 수: \(activeEvents.count), 고유 색상 수: \(uniqueColors.count)")
            for event in activeEvents {
                print("   - \(event.title): \(event.color)")
            }
        }

        return DayDensity(
            date: checkDate,
            density: activeEvents.count,
            events: activeEvents,
            spanEvents: spanningEvents
        )
    }

    // 날짜 범위의 밀도 계산 (메인 차트용)
    static func calculateRangeDensity(
        from startDate: Date,
        to endDate: Date,
        events: [Event]
    ) -> [DayDensity] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        var densities: [DayDensity] = []
        var currentDate = start

        while currentDate <= end {
            let density = calculateDensity(for: currentDate, events: events)
            densities.append(density)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return densities
    }

    // 모든 이벤트의 날짜 범위 계산
    static func getDateRange(for events: [Event]) -> (start: Date, end: Date)? {
        guard !events.isEmpty else { return nil }

        let startDates = events.map { $0.startDate }
        let endDates = events.map { $0.endDate }

        guard let minDate = startDates.min(),
              let maxDate = endDates.max() else {
            return nil
        }

        return (minDate, maxDate)
    }
}
