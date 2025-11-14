//
//  ScheduleViewModel.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation
import SwiftUI
import SwiftData

// 기간 분석 정보
struct PeriodAnalysis {
    var maxOverlappingEvents: Int  // 최대 겹치는 일정 수
    var busiestDate: Date?          // 가장 바쁜 날짜
    var busiestDateEventCount: Int  // 가장 바쁜 날의 일정 수
    var totalDays: Int              // 총 기간 (일수)
    var averageEventsPerDay: Double // 평균 일정 수
    var maxHoursPerDay: Double      // 하루 최대 소요시간
    var busiestDateByHours: Date?   // 시간 기준 가장 바쁜 날
}

@Observable
class ScheduleViewModel {
    var showingAddEvent = false
    var eventToEdit: Event? = nil  // 수정할 일정 (nil이면 수정 모드 아님)
    var currentWeekStart: Date = Date().startOfWeek
    var dataRefreshTrigger = UUID()

    // 이벤트별 레인 할당 정보 저장
    var eventLaneAssignments: [String: Int] = [:]  // color를 key로 사용

    // 현재 로드된 날짜 범위 추적
    var currentStartDate: Date
    var currentEndDate: Date

    // 설정: 표시할 개월 수 (오늘 ± N개월)
    var monthsToShow: Int

    // 설정: 평균 수면시간 (시간 단위)
    var sleepHoursPerDay: Double

    // 레인별 색상 (무지개 순서)
    static let laneColors = [
        "#FF3B30",  // 1번 레인: 빨강
        "#FF9500",  // 2번 레인: 주황
        "#FFCC00",  // 3번 레인: 노랑
        "#34C759",  // 4번 레인: 초록
        "#007AFF",  // 5번 레인: 파랑
        "#5856D6",  // 6번 레인: 남색
        "#AF52DE"   // 7번 레인: 보라
    ]

    private var modelContext: ModelContext?

    init() {
        currentWeekStart = Date().startOfWeek

        // 날짜 범위 먼저 초기화
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        currentStartDate = today
        currentEndDate = today

        // 설정 로드 (기본값: 2개월)
        let savedMonths = UserDefaults.standard.integer(forKey: "monthsToShow")
        monthsToShow = savedMonths > 0 ? savedMonths : 2

        // 수면시간 로드 (기본값: 7시간)
        let savedSleep = UserDefaults.standard.double(forKey: "sleepHoursPerDay")
        sleepHoursPerDay = savedSleep > 0 ? savedSleep : 7.0

        // 설정에 따라 날짜 범위 업데이트
        updateDateRange()
    }

    // 날짜 범위 업데이트
    func updateDateRange() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        currentStartDate = calendar.date(byAdding: .month, value: -monthsToShow, to: today) ?? today
        currentEndDate = calendar.date(byAdding: .month, value: monthsToShow, to: today) ?? today

        print("📅 [ViewModel] 날짜 범위 업데이트: ±\(monthsToShow)개월 (\(currentStartDate) ~ \(currentEndDate))")
    }

    // 설정 업데이트
    func updateMonthsToShow(_ months: Int) {
        monthsToShow = months
        UserDefaults.standard.set(monthsToShow, forKey: "monthsToShow")
        updateDateRange()
        dataRefreshTrigger = UUID()
    }

    func updateSleepHours(_ hours: Double) {
        sleepHoursPerDay = hours
        UserDefaults.standard.set(sleepHoursPerDay, forKey: "sleepHoursPerDay")
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        print("📌 [ViewModel] ModelContext 설정됨")
    }

    // MARK: - Week Navigation

    func moveToNextWeek() {
        currentWeekStart = Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
    }

    func moveToPreviousWeek() {
        currentWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart
    }

    func moveToToday() {
        currentWeekStart = Date().startOfWeek
    }

    var weekDays: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: currentWeekStart)
        }
    }

    var weekDescription: String {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"

        return "\(formatter.string(from: currentWeekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    // MARK: - Event Management

    func addEvent(_ event: Event) {
        guard let context = modelContext else {
            print("⚠️ [ViewModel] addEvent 실패: modelContext가 nil")
            return
        }
        context.insert(event)
        do {
            try context.save()
            print("✅ [ViewModel] 이벤트 추가됨: \"\(event.title)\" (\(event.startDate) ~ \(event.endDate))")
        } catch {
            print("❌ [ViewModel] 이벤트 저장 실패: \(error)")
        }
    }

    func deleteEvent(_ event: Event) {
        guard let context = modelContext else {
            print("⚠️ [ViewModel] deleteEvent 실패: modelContext가 nil")
            return
        }
        context.delete(event)
        do {
            try context.save()
            print("🗑️ [ViewModel] 이벤트 삭제됨: \"\(event.title)\"")
        } catch {
            print("❌ [ViewModel] 이벤트 삭제 실패: \(error)")
        }
    }

    func updateEvent(_ event: Event) {
        guard let context = modelContext else {
            print("⚠️ [ViewModel] updateEvent 실패: modelContext가 nil")
            return
        }
        do {
            try context.save()
            print("🔄 [ViewModel] 이벤트 업데이트됨: \"\(event.title)\"")
        } catch {
            print("❌ [ViewModel] 이벤트 업데이트 실패: \(error)")
        }
    }

    func fetchEvents() -> [Event] {
        guard let context = modelContext else {
            print("⚠️ [ViewModel] fetchEvents 실패: modelContext가 nil")
            return []
        }

        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.startDate)]
        )

        do {
            let events = try context.fetch(descriptor)
            print("📊 [ViewModel] 이벤트 조회됨: \(events.count)개")
            return events
        } catch {
            print("❌ [ViewModel] 이벤트 조회 실패: \(error)")
            return []
        }
    }

    // MARK: - Period Analysis

    func analyzePeriod(startDate: Date, endDate: Date) -> PeriodAnalysis {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        // 기간 내 일수 계산
        let totalDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0 + 1

        // 기존 일정 가져오기
        let allEvents = fetchEvents()

        var maxOverlapping = 0
        var busiestDate: Date? = nil
        var busiestDateCount = 0
        var totalEventDays = 0
        var maxHours = 0.0
        var busiestDateByHours: Date? = nil

        // 날짜별로 순회하며 분석
        var currentDate = start
        while currentDate <= end {
            // 해당 날짜에 진행 중인 일정들 찾기
            let eventsOnDate = allEvents.filter { $0.occursOn(date: currentDate) }
            let eventCount = eventsOnDate.count

            // 해당 날짜의 총 소요시간 계산
            let totalHours = eventsOnDate.reduce(0.0) { $0 + $1.hoursPerDay }

            if eventCount > 0 {
                totalEventDays += 1
            }

            // 최대 겹치는 일정 수 업데이트 (개수 기준)
            if eventCount > busiestDateCount {
                busiestDateCount = eventCount
                busiestDate = currentDate
            }

            // 최대 소요시간 업데이트 (시간 기준)
            if totalHours > maxHours {
                maxHours = totalHours
                busiestDateByHours = currentDate
            }

            maxOverlapping = max(maxOverlapping, eventCount)

            // 다음 날로 이동
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        let averageEvents = totalDays > 0 ? Double(totalEventDays) / Double(totalDays) : 0.0

        return PeriodAnalysis(
            maxOverlappingEvents: maxOverlapping,
            busiestDate: busiestDate,
            busiestDateEventCount: busiestDateCount,
            totalDays: totalDays,
            averageEventsPerDay: averageEvents,
            maxHoursPerDay: maxHours,
            busiestDateByHours: busiestDateByHours
        )
    }

    // MARK: - Density Calculation

    func getAllDensityData() -> [DayDensity] {
        print("🔄 [ViewModel] getAllDensityData 호출됨")
        let events = fetchEvents()

        // 이벤트가 없어도 날짜 범위는 생성
        let densities = DensityCalculator.calculateRangeDensity(
            from: currentStartDate,
            to: currentEndDate,
            events: events
        )
        print("📈 [ViewModel] 밀도 데이터 계산 완료: \(densities.count)일치 (이벤트 \(events.count)개)")
        return densities
    }

    func getEventsForDate(_ date: Date) -> [Event] {
        let events = fetchEvents()
        return events.filter { $0.occursOn(date: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    // 레인별 최대 칸 채우기 알고리즘 (Lane Packing)
    // 목표: 1번 레인에 최대한 많은 칸 채우기 → 2번 레인 → 3번 레인...
    // 각 레인마다 겹치지 않는 일정을 최대한 많이 배치
    // 레인별 점수 계산 (1번 레인: 10,000,000점, 2번: 1,000,000점, ...)
    private func pointsPerCell(for lane: Int) -> Int {
        let exponent = 7 - lane  // 1번 레인(0): 7, 2번(1): 6, ..., 7번(6): 1
        return Int(pow(10.0, Double(exponent)))
    }

    func assignLanesToEvents() -> [Event] {
        let events = fetchEvents()

        guard !events.isEmpty else { return [] }

        print("\n" + String(repeating: "=", count: 60))
        print("📌 [Lane Packing] 시작 - 총 \(events.count)개 일정")
        print("   목표: 1번 레인에 최대한 많은 칸 배치 (점수 최대화)")
        print("   전략: ① 긴 일정 우선 배치 ② 백트래킹으로 최적 조합 탐색")
        print("         ③ Gap Filling으로 빈 구간 메우기 ④ 압축 최적화")
        print(String(repeating: "=", count: 60))

        var eventLanes: [(event: Event, lane: Int)] = []
        var assignedEventIds = Set<ObjectIdentifier>()
        var currentLane = 0

        // 모든 일정이 배치될 때까지 반복
        while assignedEventIds.count < events.count {
            // 아직 배치되지 않은 일정들
            let remainingEvents = events.filter { !assignedEventIds.contains(ObjectIdentifier($0)) }

            // 💡 개선: 칸 수가 많은 일정부터 배치 (더 많은 칸을 왼쪽 레인에 배치하기 위함)
            // actualCellCount()로 정렬 (요일 선택 고려)
            let sortedRemaining = remainingEvents.sorted { event1, event2 in
                let cells1 = event1.actualCellCount()
                let cells2 = event2.actualCellCount()

                if cells1 != cells2 {
                    return cells1 > cells2  // 칸 수가 많은 것 우선
                }
                if event1.startDate != event2.startDate {
                    return event1.startDate < event2.startDate  // 시작일이 빠른 것 우선
                }
                return event1.endDate < event2.endDate
            }

            // 현재 레인에 배치할 일정들 (Dynamic Programming 방식)
            // 최대 칸 수를 채우는 조합 찾기
            var bestCombination: [Event] = []
            var bestTotalDays = 0

            // 백트래킹으로 최적 조합 찾기
            func findBestCombination(index: Int, currentCombination: [Event], currentDays: Int, lastEndDate: Date?) {
                // 현재 조합이 최선인지 확인
                if currentDays > bestTotalDays {
                    bestTotalDays = currentDays
                    bestCombination = currentCombination
                }

                // 모든 일정을 확인했으면 종료
                if index >= sortedRemaining.count {
                    return
                }

                let event = sortedRemaining[index]
                let calendar = Calendar.current
                let eventCells = event.actualCellCount()  // 요일 선택 고려

                // 이 일정을 추가할 수 있는지 확인
                var canAdd = false
                if let lastEnd = lastEndDate {
                    if let dayAfterLastEnd = calendar.date(byAdding: .day, value: 1, to: lastEnd),
                       event.startDate >= dayAfterLastEnd {
                        canAdd = true
                    }
                } else {
                    canAdd = true  // 첫 번째 일정
                }

                // 선택 1: 이 일정을 추가하는 경우
                if canAdd {
                    var newCombination = currentCombination
                    newCombination.append(event)
                    findBestCombination(index: index + 1, currentCombination: newCombination, currentDays: currentDays + eventCells, lastEndDate: event.endDate)
                }

                // 선택 2: 이 일정을 건너뛰는 경우
                findBestCombination(index: index + 1, currentCombination: currentCombination, currentDays: currentDays, lastEndDate: lastEndDate)
            }

            // 최적 조합 찾기 (일정이 너무 많으면 시간이 오래 걸릴 수 있으므로 제한)
            let useBacktracking = remainingEvents.count <= 15
            if useBacktracking {
                // 백트래킹으로 최적 조합 찾기
                findBestCombination(index: 0, currentCombination: [], currentDays: 0, lastEndDate: nil)
            } else {
                // Greedy 방식으로 빠르게 처리
                var laneEvents: [Event] = []
                var lastEndDate: Date? = nil

                for event in sortedRemaining {
                    let calendar = Calendar.current
                    if let lastEnd = lastEndDate {
                        if let dayAfterLastEnd = calendar.date(byAdding: .day, value: 1, to: lastEnd),
                           event.startDate >= dayAfterLastEnd {
                            laneEvents.append(event)
                            lastEndDate = event.endDate
                        }
                    } else {
                        laneEvents.append(event)
                        lastEndDate = event.endDate
                    }
                }
                bestCombination = laneEvents
            }

            let laneEvents = bestCombination

            // 이 레인에 배치
            let totalDays = laneEvents.reduce(0) { sum, event in
                return sum + event.actualCellCount()  // 요일 선택 고려
            }

            for event in laneEvents {
                eventLanes.append((event: event, lane: currentLane))
                assignedEventIds.insert(ObjectIdentifier(event))
            }

            let method = useBacktracking ? "백트래킹" : "Greedy"
            print("   🎨 레인 \(currentLane + 1): \(laneEvents.count)개 일정, \(totalDays)칸 [\(method)]")
            for event in laneEvents {
                let cells = event.actualCellCount()
                print("      - '\(event.title)' (\(cells)칸)")
            }

            currentLane += 1
        }

        // 레인 순서대로 정렬 (왼쪽부터)
        let totalLanes = Set(eventLanes.map { $0.lane }).count

        // 점수 계산 (1번 레인: 10,000,000점/칸, 2번: 1,000,000점/칸, ...)
        var totalScore = 0
        for (event, lane) in eventLanes {
            let cells = event.actualCellCount()  // 요일 선택 고려
            let points = pointsPerCell(for: lane)
            let score = cells * points
            totalScore += score
        }

        print("   ✅ 배치 완료: \(totalLanes)개 레인 사용 (1번~\(totalLanes)번)")
        print("   📊 총 점수: \(totalScore.formatted())점")
        print("      (1번 레인: 10,000,000점/칸, 2번: 1,000,000점/칸, 3번: 100,000점/칸, 4번: 10,000점/칸, 5번: 1,000점/칸, 6번: 100점/칸, 7번: 10점/칸)")

        // STEP: Gap Filling - 레인의 빈 구간을 짧은 일정으로 메우기
        print("\n   🔧 Gap Filling: 레인의 빈 구간에 짧은 일정 배치")

        // Gap Filling 전 레인별 상세 정보 출력
        print("\n   📋 [Gap Filling 전] 레인별 상세:")
        for lane in 0..<totalLanes {
            let eventsInLane = eventLanes.filter { $0.lane == lane }.map { $0.event }.sorted { $0.startDate < $1.startDate }
            print("      레인 \(lane + 1): \(eventsInLane.count)개 일정")
            for event in eventsInLane {
                let cells = event.actualCellCount()
                let weekdaysStr = formatWeekdays(event.selectedWeekdays)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M/d"
                let startStr = dateFormatter.string(from: event.startDate)
                let endStr = dateFormatter.string(from: event.endDate)
                print("         - '\(event.title)' (\(startStr)~\(endStr), \(cells)칸, \(weekdaysStr))")
            }
        }

        var gapFilledLanes = eventLanes
        var assignedSet = Set(eventLanes.map { ObjectIdentifier($0.event) })
        var unassignedEvents = events.filter { !assignedSet.contains(ObjectIdentifier($0)) }

        print("\n      미배치 일정: \(unassignedEvents.count)개")
        for event in unassignedEvents {
            let cells = event.actualCellCount()
            let weekdaysStr = formatWeekdays(event.selectedWeekdays)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/d"
            let startStr = dateFormatter.string(from: event.startDate)
            let endStr = dateFormatter.string(from: event.endDate)
            print("         - '\(event.title)' (\(startStr)~\(endStr), \(cells)칸, \(weekdaysStr))")
        }

        var gapFilledCount = 0

        if !unassignedEvents.isEmpty {
            // 레인별로 배치 가능한 일정 찾기 (점수가 높은 레인부터 처리)
            for lane in 0..<totalLanes {
                print("\n      🔍 레인 \(lane + 1) 분석 중...")
                let eventsInLane = gapFilledLanes.filter { $0.lane == lane }.map { $0.event }

                // 💡 개선: gap에 국한되지 않고, 레인 전체에서 배치 가능한 일정 찾기
                print("         현재 레인의 일정: \(eventsInLane.count)개")
                for existingEvent in eventsInLane {
                    let weekdaysStr = formatWeekdays(existingEvent.selectedWeekdays)
                    print("            - '\(existingEvent.title)' (\(weekdaysStr))")
                }

                print("         미배치 일정 확인 중: \(unassignedEvents.count)개")
                for unassignedEvent in unassignedEvents {
                    let weekdaysStr = formatWeekdays(unassignedEvent.selectedWeekdays)
                    print("            - '\(unassignedEvent.title)' (\(weekdaysStr)) 체크 중...")

                    // 겹침 확인
                    var canFit = true
                    for existingEvent in eventsInLane {
                        if eventsOverlap(unassignedEvent, existingEvent) {
                            let existingWeekdays = formatWeekdays(existingEvent.selectedWeekdays)
                            print("               ❌ '\(existingEvent.title)' (\(existingWeekdays))와 겹침")
                            canFit = false
                            break
                        }
                    }
                    if canFit {
                        print("               ✅ 배치 가능!")
                    }
                }

                let fittableEvents = unassignedEvents.filter { event in
                    guard !assignedSet.contains(ObjectIdentifier(event)) else { return false }

                    // ✅ 중요: 해당 레인의 모든 일정들과 겹치지 않는지 확인 (요일 고려)
                    let hasOverlap = eventsInLane.contains { eventsOverlap(event, $0) }
                    return !hasOverlap
                }.sorted { event1, event2 in
                    // 칸 수가 많은 것 우선 (점수 최대화)
                    event1.actualCellCount() > event2.actualCellCount()
                }

                // 배치 가능한 일정들을 모두 이 레인에 추가
                for event in fittableEvents {
                    gapFilledLanes.append((event: event, lane: lane))
                    assignedSet.insert(ObjectIdentifier(event))
                    unassignedEvents.removeAll { ObjectIdentifier($0) == ObjectIdentifier(event) }

                    let cells = event.actualCellCount()
                    let weekdaysStr = formatWeekdays(event.selectedWeekdays)
                    print("      🎯 레인 \(lane + 1)에 '\(event.title)' 배치 (\(cells)칸, \(weekdaysStr))")
                    gapFilledCount += 1
                }
            }

            if gapFilledCount > 0 {
                // Gap filling 후 점수 재계산
                var gapFilledScore = 0
                for (event, lane) in gapFilledLanes {
                    let cells = event.actualCellCount()
                    let points = pointsPerCell(for: lane)
                    gapFilledScore += cells * points
                }

                let gapImprovement = gapFilledScore - totalScore
                print("      ✅ Gap Filling 완료: \(gapFilledCount)개 일정 배치, +\(gapImprovement.formatted())점 개선")
                totalScore = gapFilledScore

                // Gap Filling 후 레인별 상세 정보 출력
                print("\n   📋 [Gap Filling 후] 레인별 상세:")
                let gapFilledTotalLanes = Set(gapFilledLanes.map { $0.lane }).count
                for lane in 0..<gapFilledTotalLanes {
                    let eventsInLane = gapFilledLanes.filter { $0.lane == lane }.map { $0.event }.sorted { $0.startDate < $1.startDate }
                    print("      레인 \(lane + 1): \(eventsInLane.count)개 일정")
                    for event in eventsInLane {
                        let cells = event.actualCellCount()
                        let weekdaysStr = formatWeekdays(event.selectedWeekdays)
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "M/d"
                        let startStr = dateFormatter.string(from: event.startDate)
                        let endStr = dateFormatter.string(from: event.endDate)
                        print("         - '\(event.title)' (\(startStr)~\(endStr), \(cells)칸, \(weekdaysStr))")
                    }
                }
            } else {
                print("      ⏭️  Gap Filling 기회 없음")
            }
        } else {
            print("      ⏭️  미배치 일정 없음")
        }

        // STEP: 압축 (Compaction) - 긴 일정을 왼쪽으로, 짧은 일정을 오른쪽으로
        print("\n   🔄 압축 시작: 긴 일정 왼쪽 배치로 점수 최적화")
        var compactedLanes = gapFilledLanes
        var changed = true
        var iteration = 0

        while changed && iteration < 100 {  // 💡 개선: 최대 100번 반복 (변화가 없으면 자동 종료)
            changed = false
            iteration += 1

            // PART 1: 칸 수가 많은 일정부터 빈 왼쪽 레인으로 이동
            let sortedIndices = compactedLanes.enumerated().sorted { idx1, idx2 in
                let cells1 = idx1.element.event.actualCellCount()
                let cells2 = idx2.element.event.actualCellCount()
                return cells1 > cells2  // 칸 수가 많은 것부터
            }.map { $0.offset }

            for i in sortedIndices {
                let (event, currentLane) = compactedLanes[i]

                // 왼쪽 레인들을 확인 (0부터 currentLane-1까지)
                for targetLane in 0..<currentLane {
                    let eventsInTargetLane = compactedLanes.filter { $0.lane == targetLane }.map { $0.event }
                    let hasOverlap = eventsInTargetLane.contains { eventsOverlap(event, $0) }

                    if !hasOverlap {
                        let cells = event.actualCellCount()
                        print("      ↩️  '\(event.title)' (\(cells)칸): 레인 \(currentLane + 1) → 레인 \(targetLane + 1)")
                        compactedLanes[i] = (event: event, lane: targetLane)
                        changed = true
                        break
                    }
                }
            }

            // PART 2: 레인 간 스왑 - 오른쪽에 칸 수가 많은 일정, 왼쪽에 적은 일정이 있으면 스왑
            for i in 0..<compactedLanes.count {
                let (event1, lane1) = compactedLanes[i]
                let cells1 = event1.actualCellCount()

                for j in 0..<compactedLanes.count {
                    if i == j { continue }
                    let (event2, lane2) = compactedLanes[j]
                    let cells2 = event2.actualCellCount()

                    // event1이 더 오른쪽 레인에 있고, 칸 수가 더 많으면 스왑 고려
                    if lane1 > lane2 && cells1 > cells2 {
                        // 스왑해도 겹치지 않는지 확인
                        // event1을 lane2에, event2를 lane1에 배치
                        let otherInLane2 = compactedLanes.filter { $0.lane == lane2 && !isSameEvent($0.event, event2) }.map { $0.event }
                        let otherInLane1 = compactedLanes.filter { $0.lane == lane1 && !isSameEvent($0.event, event1) }.map { $0.event }

                        let event1CanGoToLane2 = !otherInLane2.contains { eventsOverlap(event1, $0) }
                        let event2CanGoToLane1 = !otherInLane1.contains { eventsOverlap(event2, $0) }

                        if event1CanGoToLane2 && event2CanGoToLane1 {
                            print("      🔄 스왑: '\(event1.title)' (\(cells1)칸) ↔ '\(event2.title)' (\(cells2)칸) | 레인 \(lane1 + 1) ↔ 레인 \(lane2 + 1)")
                            compactedLanes[i] = (event: event1, lane: lane2)
                            compactedLanes[j] = (event: event2, lane: lane1)
                            changed = true
                        }
                    }
                }
            }
        }

        // 압축 후 점수 재계산
        var compactedScore = 0
        var laneScores: [Int: Int] = [:]  // 레인별 점수 저장
        var laneCells: [Int: Int] = [:]   // 레인별 칸 수 저장
        for (event, lane) in compactedLanes {
            let cells = event.actualCellCount()  // 요일 선택 고려
            let points = pointsPerCell(for: lane)
            let score = cells * points
            compactedScore += score
            laneScores[lane, default: 0] += score
            laneCells[lane, default: 0] += cells
        }

        let improvement = compactedScore - totalScore
        let finalLanes = Set(compactedLanes.map { $0.lane }).count

        print("   ✅ 압축 완료: \(iteration)회 반복")
        print("   📊 최종 점수: \(compactedScore.formatted())점 (개선: +\(improvement.formatted())점)")
        print("   🎯 최종 레인 사용: \(finalLanes)개 (1번~\(finalLanes)번)")
        print("\n   📋 레인별 상세:")
        for lane in 0..<finalLanes {
            let score = laneScores[lane] ?? 0
            let cells = laneCells[lane] ?? 0
            let pointPerCell = pointsPerCell(for: lane)
            print("      레인 \(lane + 1): \(cells)칸 → \(score.formatted())점 (칸당 \(pointPerCell.formatted())점)")
        }
        print("      " + String(repeating: "-", count: 40))
        print("      총합: \(compactedScore.formatted())점")

        // 최종 레인별 일정 상세 출력
        print("\n   📋 [최종] 레인별 일정 상세:")
        for lane in 0..<finalLanes {
            let eventsInLane = compactedLanes.filter { $0.lane == lane }.map { $0.event }.sorted { $0.startDate < $1.startDate }
            print("      레인 \(lane + 1): \(eventsInLane.count)개 일정")
            for event in eventsInLane {
                let cells = event.actualCellCount()
                let weekdaysStr = formatWeekdays(event.selectedWeekdays)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "M/d"
                let startStr = dateFormatter.string(from: event.startDate)
                let endStr = dateFormatter.string(from: event.endDate)
                print("         - '\(event.title)' (\(startStr)~\(endStr), \(cells)칸, \(weekdaysStr))")
            }
        }
        print(String(repeating: "=", count: 60) + "\n")

        // 레인 할당 정보 저장 (압축된 결과 사용)
        var assignments: [String: Int] = [:]
        for (event, lane) in compactedLanes {
            assignments[event.color] = lane
        }
        self.eventLaneAssignments = assignments

        // 압축된 결과로 정렬
        let compactedResult = compactedLanes.sorted { $0.lane < $1.lane }.map { $0.event }
        return compactedResult
    }

    // 두 일정이 겹치는지 확인
    private func eventsOverlap(_ event1: Event, _ event2: Event) -> Bool {
        // 날짜 범위가 겹치지 않으면 false
        guard event1.startDate <= event2.endDate && event2.startDate <= event1.endDate else {
            return false
        }

        // 💡 개선: 실제로 두 일정이 동시에 활성화되는 날짜가 있는지 확인
        let calendar = Calendar.current
        let overlapStart = max(event1.startDate, event2.startDate)
        let overlapEnd = min(event1.endDate, event2.endDate)

        // 겹치는 날짜 범위를 순회하며 실제 겹침 확인
        var currentDate = overlapStart
        while currentDate <= overlapEnd {
            // 두 일정이 모두 이 날짜에 활성화되는지 확인
            if event1.occursOn(date: currentDate) && event2.occursOn(date: currentDate) {
                return true  // 실제로 겹치는 날짜 발견!
            }

            // 다음 날로 이동
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        // 겹치는 날짜가 하나도 없음
        return false
    }

    // 두 일정이 같은지 확인 (색상으로 비교)
    private func isSameEvent(_ event1: Event, _ event2: Event) -> Bool {
        return event1.color == event2.color
    }

    // 요일 배열을 문자열로 포맷 (예: "월,수,금" 또는 "모든 요일")
    private func formatWeekdays(_ weekdays: [Int]?) -> String {
        guard let weekdays = weekdays, !weekdays.isEmpty else {
            return "모든 요일"
        }

        let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]
        let sortedWeekdays = weekdays.sorted()
        let names = sortedWeekdays.compactMap { weekday -> String? in
            guard weekday >= 1 && weekday <= 7 else { return nil }
            return weekdayNames[weekday - 1]
        }

        return names.joined(separator: ",")
    }
    
    // MARK: - Sample Data

    func addSampleEvents() {
        print("🎯 [ViewModel] 샘플 데이터 추가 시작")

        // 기존 샘플 데이터가 있으면 중복 추가 방지
        let existingEvents = fetchEvents()
        let sampleTitles = ["프로젝트 A", "프로젝트 B", "출장", "교육 프로그램", "컨퍼런스"]
        let existingSampleEvents = existingEvents.filter { sampleTitles.contains($0.title) }

        if !existingSampleEvents.isEmpty {
            print("⚠️ [ViewModel] 샘플 데이터가 이미 존재합니다. 중복 추가를 건너뜁니다.")
            return
        }

        let calendar = Calendar.current
        let today = Date()

        // 샘플 이벤트 1: 프로젝트 A (오늘부터 10일간)
        guard let projectAEnd = calendar.date(byAdding: .day, value: 10, to: today) else { return }
        let projectA = Event(
            title: "프로젝트 A",
            startDate: today,
            endDate: projectAEnd,
            color: "#FF3B30",
            hoursPerDay: 8.0
        )
        addEvent(projectA)

        // 샘플 이벤트 2: 프로젝트 B (5일 후부터 12일간)
        guard let projectBStart = calendar.date(byAdding: .day, value: 5, to: today),
              let projectBEnd = calendar.date(byAdding: .day, value: 17, to: today) else { return }
        let projectB = Event(
            title: "프로젝트 B",
            startDate: projectBStart,
            endDate: projectBEnd,
            color: "#FF9500",
            hoursPerDay: 6.0
        )
        addEvent(projectB)

        // 샘플 이벤트 3: 출장 (7일 후부터 3일간)
        guard let tripStart = calendar.date(byAdding: .day, value: 7, to: today),
              let tripEnd = calendar.date(byAdding: .day, value: 10, to: today) else { return }
        let trip = Event(
            title: "출장",
            startDate: tripStart,
            endDate: tripEnd,
            color: "#FFCC00",
            hoursPerDay: 10.0
        )
        addEvent(trip)

        // 샘플 이벤트 4: 교육 프로그램 (15일 후부터 5일간)
        guard let trainingStart = calendar.date(byAdding: .day, value: 15, to: today),
              let trainingEnd = calendar.date(byAdding: .day, value: 20, to: today) else { return }
        let training = Event(
            title: "교육 프로그램",
            startDate: trainingStart,
            endDate: trainingEnd,
            color: "#34C759",
            hoursPerDay: 7.0
        )
        addEvent(training)

        // 샘플 이벤트 5: 컨퍼런스 (18일 후부터 4일간)
        guard let confStart = calendar.date(byAdding: .day, value: 18, to: today),
              let confEnd = calendar.date(byAdding: .day, value: 22, to: today) else { return }
        let conference = Event(
            title: "컨퍼런스",
            startDate: confStart,
            endDate: confEnd,
            color: "#007AFF",
            hoursPerDay: 9.0
        )
        addEvent(conference)

        print("✅ [ViewModel] 샘플 데이터 5개 추가 완료")

        // 데이터 새로고침 트리거
        dataRefreshTrigger = UUID()
    }

    func deleteAllEvents() {
        print("🗑️ [ViewModel] 모든 이벤트 삭제 시작")
        guard let context = modelContext else {
            print("⚠️ [ViewModel] deleteAllEvents 실패: modelContext가 nil")
            return
        }

        let events = fetchEvents()
        let eventCount = events.count
        print("📊 [ViewModel] 삭제할 이벤트: \(eventCount)개")

        for event in events {
            context.delete(event)
        }

        do {
            try context.save()
            print("✅ [ViewModel] 모든 이벤트(\(eventCount)개) 삭제 완료")
        } catch {
            print("❌ [ViewModel] 이벤트 삭제 실패: \(error)")
        }

        // 데이터 새로고침 트리거
        dataRefreshTrigger = UUID()
    }
}
