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
    @State private var transformedEvents: [(id: String, event: Event)] = []
    @State private var selectedEvents: Set<String> = []
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var showEventPreview = false

    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if !eventKitManager.isAuthorized {
                        authorizationView
                            .transition(.opacity)
                    } else if showEventPreview && !transformedEvents.isEmpty {
                        eventPreviewView
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        calendarSelectionView
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showEventPreview)
                .animation(.easeInOut(duration: 0.3), value: eventKitManager.isAuthorized)

                // 로딩 오버레이
                if isLoading {
                    loadingOverlay
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: isLoading)
                }
            }
            .navigationTitle("캘린더 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                if eventKitManager.isAuthorized {
                    eventKitManager.fetchAvailableCalendars()
                }
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(loadingMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
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

    // MARK: - Empty Calendar View

    private var emptyCalendarView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            VStack(spacing: 12) {
                Text("캘린더가 없습니다")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("시스템 캘린더 앱에서\n캘린더를 먼저 만들어주세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: openSystemCalendar) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("캘린더 앱 열기")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }

                Button(action: refreshCalendars) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("새로고침")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("💡 팁")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("1. 캘린더 앱을 열어 새 캘린더를 생성하세요")
                Text("2. 생성 후 이 화면으로 돌아와 새로고침하세요")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Spacer()
        }
        .padding()
    }

    // MARK: - Calendar Selection View

    private var calendarSelectionView: some View {
        VStack(spacing: 0) {
            if eventKitManager.calendars.isEmpty {
                emptyCalendarView
            } else {
                List {
                    Section {
                        Text("가져올 캘린더를 선택하세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Section("내 캘린더") {
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
                        Text("다음 (\(selectedCalendars.count)개 선택)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
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
        Task {
            isLoading = true
            loadingMessage = "캘린더에서 일정을 가져오는 중..."

            // 약간의 지연으로 UI 업데이트 보장
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초

            let selected = eventKitManager.calendars.filter {
                selectedCalendars.contains($0.calendarIdentifier)
            }

            fetchedEvents = eventKitManager.fetchEvents(from: selected)

            loadingMessage = "\(fetchedEvents.count)개 일정 발견!\n변환 중..."
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초

            // EKEvent를 Event로 변환하고 고유 ID 생성
            transformedEvents = fetchedEvents.compactMap { ekEvent -> (id: String, event: Event)? in
                guard let event = eventKitManager.transformToAppEvent(ekEvent) else { return nil }
                // 고유 ID 생성: 제목 + 시작일 + 종료일 + 시간
                let id = "\(event.title)_\(event.startDate.timeIntervalSince1970)_\(event.endDate.timeIntervalSince1970)_\(event.hoursPerDay)"
                return (id: id, event: event)
            }

            // 기본적으로 모두 선택
            selectedEvents = Set(transformedEvents.map { $0.id })

            if transformedEvents.isEmpty {
                loadingMessage = "일정을 찾을 수 없습니다"
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초
                isLoading = false
            } else {
                loadingMessage = "완료!"
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초
                isLoading = false
                showEventPreview = true
            }
        }
    }

    // MARK: - Event Preview View

    private var eventPreviewView: some View {
        VStack(spacing: 0) {
            // 뒤로가기 버튼
            HStack {
                Button(action: {
                    withAnimation {
                        showEventPreview = false
                        transformedEvents = []
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("캘린더 선택")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("향후 3개월간 \(transformedEvents.count)개 일정을 찾았습니다")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(selectedCalendars.count)개 캘린더에서 가져왔습니다")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("가져올 일정을 선택하거나 해제하세요")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("가져올 일정") {
                    if transformedEvents.isEmpty {
                        Text("일정이 없습니다")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(transformedEvents, id: \.id) { item in
                            eventPreviewRow(item.event, id: item.id)
                        }
                    }
                }
            }

            if !selectedEvents.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: importSelectedEvents) {
                        Text("선택한 일정 추가 (\(selectedEvents.count)개)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func eventPreviewRow(_ event: Event, id: String) -> some View {
        let isSelected = selectedEvents.contains(id)

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
            toggleEventSelection(id)
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
        Task {
            isLoading = true
            loadingMessage = "일정을 추가하는 중..."

            let eventsToImport = transformedEvents.filter {
                selectedEvents.contains($0.id)
            }

            // 약간의 지연으로 피드백 제공
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초

            for (index, item) in eventsToImport.enumerated() {
                viewModel.addEvent(item.event)
                if eventsToImport.count > 5 && index % 5 == 0 {
                    loadingMessage = "일정 추가 중... (\(index + 1)/\(eventsToImport.count))"
                }
            }

            loadingMessage = "완료!"
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초

            isLoading = false
            dismiss()
        }
    }

    // MARK: - Helper Methods

    private func openSystemCalendar() {
        if let url = URL(string: "calshow://") {
            #if !targetEnvironment(simulator)
            UIApplication.shared.open(url)
            #endif
        }
    }

    private func refreshCalendars() {
        eventKitManager.fetchAvailableCalendars()
    }

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
