//
//  CalendarImportView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI
import EventKit

struct CalendarImportView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel
    @State private var eventKitManager = EventKitManager()

    @State private var selectedCalendars: Set<String> = []
    @State private var fetchedEvents: [EKEvent] = []
    @State private var transformedEvents: [Event] = []
    @State private var selectedEvents: Set<String> = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Group {
                if !eventKitManager.isAuthorized {
                    authorizationView
                } else if selectedCalendars.isEmpty || transformedEvents.isEmpty {
                    calendarSelectionView
                } else {
                    eventPreviewView
                }
            }
            .navigationTitle("캘린더 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: - Authorization View

    private var authorizationView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("캘린더 접근 권한 필요")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("시스템 캘린더에서 일정을 가져와\n자동으로 추가합니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "checkmark.circle.fill", text: "선택한 캘린더에서만 가져오기")
                featureRow(icon: "calendar", text: "향후 3개월 일정 자동 분석")
                featureRow(icon: "repeat", text: "반복 일정 자동 변환")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                Task {
                    try? await eventKitManager.requestAuthorization()
                }
            }) {
                Text("권한 요청")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Text("일정 데이터는 기기에만 저장되며\n외부로 전송되지 않습니다")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let error = eventKitManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Calendar Selection View

    private var calendarSelectionView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Text("가져올 캘린더를 선택하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("내 캘린더") {
                    if eventKitManager.calendars.isEmpty {
                        Text("사용 가능한 캘린더가 없습니다")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(eventKitManager.calendars, id: \.calendarIdentifier) { calendar in
                            calendarRow(calendar)
                        }
                    }
                }
            }

            if !selectedCalendars.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: loadEventsFromCalendars) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("다음 (\(selectedCalendars.count)개 선택)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        let isSelected = selectedCalendars.contains(calendar.calendarIdentifier)

        return HStack {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 20, height: 20)

            Text(calendar.title)
                .font(.body)

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleCalendarSelection(calendar.calendarIdentifier)
        }
    }

    private func toggleCalendarSelection(_ id: String) {
        if selectedCalendars.contains(id) {
            selectedCalendars.remove(id)
        } else {
            selectedCalendars.insert(id)
        }
    }

    private func loadEventsFromCalendars() {
        isLoading = true

        let selected = eventKitManager.calendars.filter {
            selectedCalendars.contains($0.calendarIdentifier)
        }

        fetchedEvents = eventKitManager.fetchEvents(from: selected)

        // EKEvent를 Event로 변환
        transformedEvents = fetchedEvents.compactMap {
            eventKitManager.transformToAppEvent($0)
        }

        // 기본적으로 모두 선택
        selectedEvents = Set(transformedEvents.map { $0.color })

        isLoading = false
    }

    // MARK: - Event Preview View

    private var eventPreviewView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Text("향후 3개월간 \(transformedEvents.count)개 일정을 찾았습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("가져올 일정") {
                    if transformedEvents.isEmpty {
                        Text("일정이 없습니다")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(transformedEvents, id: \.color) { event in
                            eventPreviewRow(event)
                        }
                    }
                }
            }

            if !selectedEvents.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: importSelectedEvents) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("선택한 일정 추가 (\(selectedEvents.count)개)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func eventPreviewRow(_ event: Event) -> some View {
        let isSelected = selectedEvents.contains(event.color)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label(formatDateRange(event), systemImage: "calendar")
                        Label(String(format: "%.1f시간", event.hoursPerDay), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if let weekdays = event.selectedWeekdays {
                        Text(formatWeekdays(weekdays))
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleEventSelection(event.color)
        }
    }

    private func toggleEventSelection(_ id: String) {
        if selectedEvents.contains(id) {
            selectedEvents.remove(id)
        } else {
            selectedEvents.insert(id)
        }
    }

    private func importSelectedEvents() {
        isLoading = true

        let eventsToImport = transformedEvents.filter {
            selectedEvents.contains($0.color)
        }

        for event in eventsToImport {
            viewModel.addEvent(event)
        }

        isLoading = false
        dismiss()
    }

    // MARK: - Helper Methods

    private func formatDateRange(_ event: Event) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ko_KR")

        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)

        if start == end {
            return start
        } else {
            return "\(start) - \(end)"
        }
    }

    private func formatWeekdays(_ weekdays: [Int]) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        return weekdays.sorted().map { names[$0 - 1] }.joined(separator: ", ")
    }
}
