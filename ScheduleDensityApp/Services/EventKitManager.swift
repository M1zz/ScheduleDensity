//
//  EventKitManager.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-12-15.
//

import EventKit
import Foundation

@Observable
final class EventKitManager {
    var isAuthorized = false
    var calendars: [EKCalendar] = []
    var errorMessage: String?

    private let eventStore = EKEventStore()

    init() {
        checkAuthorization()
    }

    // MARK: - Permission Management

    func checkAuthorization() {
        #if targetEnvironment(simulator)
        isAuthorized = (EKEventStore.authorizationStatus(for: .event) == .fullAccess)
        #else
        isAuthorized = (EKEventStore.authorizationStatus(for: .event) == .authorized)
        #endif
    }

    func requestAuthorization() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
        } else {
            let granted = try await eventStore.requestAccess(to: .event)
            isAuthorized = granted
        }

        if isAuthorized {
            fetchAvailableCalendars()
        } else {
            errorMessage = "캘린더 접근 권한이 거부되었습니다"
        }
    }

    // MARK: - Calendar Management

    func fetchAvailableCalendars() {
        calendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }

        print("📅 [EventKit] 사용 가능한 캘린더 \(calendars.count)개 발견")
    }

    // MARK: - Event Fetching

    func fetchEvents(from selectedCalendars: [EKCalendar]) -> [EKEvent] {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .month, value: 3, to: startDate) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        let events = eventStore.events(matching: predicate)
        print("📅 [EventKit] 3개월간 \(events.count)개 일정 발견")
        return events
    }

    // MARK: - Event Transformation

    func transformToAppEvent(_ ekEvent: EKEvent) -> Event? {
        let calendar = Calendar.current

        // 1. 날짜 범위 계산
        let startDate = calendar.startOfDay(for: ekEvent.startDate)
        var endDate = calendar.startOfDay(for: ekEvent.endDate)

        // 종일 일정인 경우 endDate가 다음날 0시이므로 하루 빼기
        if ekEvent.isAllDay {
            endDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        }

        // 반복 일정인데 종료일이 없는 경우 3개월 후로 설정
        if ekEvent.hasRecurrenceRules,
           let recurrenceRule = ekEvent.recurrenceRules?.first,
           recurrenceRule.recurrenceEnd == nil {
            endDate = calendar.date(byAdding: .month, value: 3, to: startDate) ?? endDate
        }

        // 2. 시간 계산
        let hoursPerDay = calculateHoursPerDay(ekEvent)

        // 3. 반복 패턴 파싱
        let selectedWeekdays = parseRecurrenceRule(ekEvent)

        // 4. Event 생성
        return Event(
            title: ekEvent.title ?? "제목 없음",
            startDate: startDate,
            endDate: endDate,
            hoursPerDay: hoursPerDay,
            selectedWeekdays: selectedWeekdays,
            importance: .medium,
            isInfinite: false
        )
    }

    // MARK: - Private Helper Methods

    private func calculateHoursPerDay(_ ekEvent: EKEvent) -> Double {
        if ekEvent.isAllDay {
            return 8.0  // 종일 일정 기본값
        }

        let duration = ekEvent.endDate.timeIntervalSince(ekEvent.startDate)
        let hours = duration / 3600.0

        // 0.5시간 단위로 반올림 (최소 0.5)
        let rounded = max(0.5, round(hours * 2.0) / 2.0)
        return rounded
    }

    private func parseRecurrenceRule(_ ekEvent: EKEvent) -> [Int]? {
        guard let recurrenceRule = ekEvent.recurrenceRules?.first else {
            return nil  // 일회성 일정 = 모든 요일
        }

        switch recurrenceRule.frequency {
        case .daily:
            return nil  // 매일 = 모든 요일

        case .weekly:
            guard let daysOfWeek = recurrenceRule.daysOfTheWeek else {
                return nil
            }
            // EKWeekday와 앱 형식 동일: 1=일요일, 2=월요일, ..., 7=토요일
            return daysOfWeek.map { $0.dayOfTheWeek.rawValue }

        default:
            // 월간, 연간 등 복잡한 패턴은 모든 요일로 처리
            return nil
        }
    }
}
