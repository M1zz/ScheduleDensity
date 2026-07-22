//
//  EventManagementView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-23.
//

import SwiftUI

struct EventManagementView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel

    @State private var searchText = ""
    @State private var sortOption: SortOption = .startDate
    @State private var showingDeleteAllAlert = false
    @State private var refreshTrigger = UUID()

    enum SortOption: String, CaseIterable {
        case startDate = "시작일"
        case title = "제목"
        case duration = "기간"

        var icon: String {
            switch self {
            case .startDate: return "calendar"
            case .title: return "textformat"
            case .duration: return "clock"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 검색 바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("일정 검색", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // 정렬 옵션
                HStack(spacing: 12) {
                    Text("정렬:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            withAnimation {
                                sortOption = option
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 12))
                                Text(option.rawValue)
                                    .font(.system(size: 13))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(sortOption == option ? Color.blue : Color(.systemGray5))
                            .foregroundColor(sortOption == option ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                // 일정 리스트
                let events = filteredAndSortedEvents()

                if events.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(events) { event in
                            EventManagementRow(event: event, viewModel: viewModel, onUpdate: {
                                // 수정 후 리스트 새로고침
                                refreshTrigger = UUID()
                            })
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteEvent(event)
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .id(refreshTrigger)

                    // 하단 통계
                    VStack(spacing: 8) {
                        Divider()
                        HStack {
                            Text("총 \(events.count)개 일정")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: {
                                showingDeleteAllAlert = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("전체 삭제")
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("일정 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .alert("전체 삭제", isPresented: $showingDeleteAllAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteAllEvents()
                }
            } message: {
                Text("모든 일정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "calendar.badge.exclamationmark" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(searchText.isEmpty ? "일정이 없습니다" : "검색 결과가 없습니다")
                .font(.title3)
                .foregroundColor(.secondary)

            if !searchText.isEmpty {
                Text("'\(searchText)'에 해당하는 일정을 찾을 수 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func filteredAndSortedEvents() -> [Event] {
        var events = viewModel.fetchEvents()

        // 검색 필터링
        if !searchText.isEmpty {
            events = events.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 정렬
        switch sortOption {
        case .startDate:
            events.sort { $0.startDate < $1.startDate }
        case .title:
            events.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .duration:
            events.sort { event1, event2 in
                let duration1 = event1.endDate.timeIntervalSince(event1.startDate)
                let duration2 = event2.endDate.timeIntervalSince(event2.startDate)
                return duration1 > duration2
            }
        }

        return events
    }

    private func deleteEvent(_ event: Event) {
        withAnimation {
            viewModel.deleteEvent(event)
            // 리스트 즉시 새로고침
            refreshTrigger = UUID()
        }
    }

    private func deleteAllEvents() {
        let events = viewModel.fetchEvents()
        withAnimation {
            for event in events {
                viewModel.deleteEvent(event)
            }
            // 리스트 즉시 새로고침
            refreshTrigger = UUID()
        }
    }
}

struct EventManagementRow: View {
    let event: Event
    @Bindable var viewModel: ScheduleViewModel
    let onUpdate: () -> Void

    @State private var showingEditSheet = false

    var body: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            HStack(spacing: 12) {
                // 색상 인디케이터
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: event.color) ?? .blue)
                    .frame(width: 6)

                VStack(alignment: .leading, spacing: 6) {
                    // 제목
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    // 날짜 정보
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text("\(formatDate(event.startDate)) - \(formatDate(event.endDate))")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text("\(durationText(event))")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.secondary)
                    }

                    // 하루 시간
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 12))
                        Text(String(format: "%.1f시간/일", event.hoursPerDay))
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.orange)

                    // 선택된 요일 (있는 경우)
                    if let weekdays = event.selectedWeekdays, !weekdays.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.system(size: 12))
                            Text(weekdayText(weekdays))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.purple)
                    }
                }

                Spacer()

                // 수정 아이콘 (터치 가능 표시)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            AddEventView(viewModel: viewModel, eventToEdit: event)
        }
        .onChange(of: showingEditSheet) { _, isShowing in
            if !isShowing {
                // 수정 sheet가 닫힐 때 리스트 새로고침
                onUpdate()
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }

    private func durationText(_ event: Event) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: event.startDate, to: event.endDate)
        if let days = components.day {
            return "\(days + 1)일"
        }
        return "1일"
    }

    private func weekdayText(_ weekdays: [Int]) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        let sorted = weekdays.sorted()
        let text = sorted.map { weekdays in
            names[weekdays % 7]
        }.joined(separator: ", ")
        return text
    }
}
