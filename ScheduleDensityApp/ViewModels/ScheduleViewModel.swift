//
//  ScheduleViewModel.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import Foundation
import SwiftUI
import SwiftData

@Observable
class ScheduleViewModel {
    var currentWeek: Date = Date()
    var selectedDate: Date?
    var showingAddEvent = false
    var showingRecommendations = false
    
    private var modelContext: ModelContext?
    
    init() {
        currentWeek = Date().startOfWeek
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Week Navigation
    
    func moveToNextWeek() {
        currentWeek = currentWeek.nextWeek
    }
    
    func moveToPreviousWeek() {
        currentWeek = currentWeek.previousWeek
    }
    
    func moveToToday() {
        currentWeek = Date().startOfWeek
    }
    
    var daysInCurrentWeek: [Date] {
        currentWeek.daysInWeek
    }
    
    var weekDescription: String {
        currentWeek.weekDescription
    }
    
    // MARK: - Event Management
    
    func addEvent(_ event: Event) {
        guard let context = modelContext else { return }
        context.insert(event)
        try? context.save()
    }
    
    func deleteEvent(_ event: Event) {
        guard let context = modelContext else { return }
        context.delete(event)
        try? context.save()
    }
    
    func updateEvent(_ event: Event) {
        guard let context = modelContext else { return }
        try? context.save()
    }
    
    func fetchEvents() -> [Event] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.startTime)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - Density Calculation
    
    func densityForDate(_ date: Date) -> [TimeSlot] {
        let events = fetchEvents()
        return DensityCalculator.calculateDensity(for: date, events: events)
    }
    
    func weekDensity() -> [DayDensity] {
        let events = fetchEvents()
        return DensityCalculator.calculateWeekDensity(startOfWeek: currentWeek, events: events)
    }
    
    func eventsForDate(_ date: Date) -> [EventInstance] {
        let events = fetchEvents()
        return events.compactMap { event in
            event.occursOn(date: date) ? event.instanceFor(date: date) : nil
        }.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Recommendations
    
    func getRecommendations(duration: TimeInterval = 7200) -> [Recommendation] {
        let events = fetchEvents()
        return DensityCalculator.recommendTimeSlots(
            for: duration,
            in: currentWeek,
            events: events
        )
    }
    
    // MARK: - Sample Data
    
    func addSampleEvents() {
        let calendar = Calendar.current
        
        // 3월 1일 기준
        guard let marchFirst = calendar.date(from: DateComponents(year: 2025, month: 3, day: 1)),
              let decemberLast = calendar.date(from: DateComponents(year: 2025, month: 12, day: 31)) else {
            return
        }
        
        // 1. 수업 (매일 09:00 - 18:00)
        let classStart = marchFirst.settingTime(hour: 9, minute: 0)
        let classEnd = marchFirst.settingTime(hour: 18, minute: 0)
        let classEvent = Event(
            title: "수업",
            startTime: classStart,
            endTime: classEnd,
            color: "#4ECDC4",
            recurrencePattern: .daily,
            recurrenceDaysOfWeek: RecurrencePattern.everyDayPattern,
            recurrenceEndDate: decemberLast
        )
        addEvent(classEvent)

        // 2. 운동 (월수금 18:00 - 20:00)
        let workoutStart = marchFirst.settingTime(hour: 18, minute: 0)
        let workoutEnd = marchFirst.settingTime(hour: 20, minute: 0)
        let workoutEvent = Event(
            title: "운동",
            startTime: workoutStart,
            endTime: workoutEnd,
            color: "#FF6B6B",
            recurrencePattern: .weekly,
            recurrenceDaysOfWeek: RecurrencePattern.mondayWednesdayFridayPattern,
            recurrenceEndDate: decemberLast
        )
        addEvent(workoutEvent)

        // 3. 스터디 준비 (수요일 20:00 - 22:00)
        let studyPrepStart = marchFirst.settingTime(hour: 20, minute: 0)
        let studyPrepEnd = marchFirst.settingTime(hour: 22, minute: 0)
        let studyPrepEvent = Event(
            title: "스터디 준비",
            startTime: studyPrepStart,
            endTime: studyPrepEnd,
            color: "#95E1D3",
            recurrencePattern: .weekly,
            recurrenceDaysOfWeek: [4], // 수요일
            recurrenceEndDate: decemberLast
        )
        addEvent(studyPrepEvent)

        // 4. 스터디 (주말 14:00 - 16:00)
        let studyStart = marchFirst.settingTime(hour: 14, minute: 0)
        let studyEnd = marchFirst.settingTime(hour: 16, minute: 0)
        let studyEvent = Event(
            title: "스터디",
            startTime: studyStart,
            endTime: studyEnd,
            color: "#F38181",
            recurrencePattern: .weekly,
            recurrenceDaysOfWeek: RecurrencePattern.weekendsPattern,
            recurrenceEndDate: decemberLast
        )
        addEvent(studyEvent)
    }
}
