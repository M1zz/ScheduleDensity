//
//  WeekDensityView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI

struct WeekDensityView: View {
    @Bindable var viewModel: ScheduleViewModel
    @State private var densityData: [DayDensity] = []
    @State private var selectedDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            // 상단: 주간 네비게이션
            weekNavigationHeader

            Divider()

            // 중단: 주간 밀도 차트
            weekDensityChart
                .frame(height: 280)

            Divider()

            // 하단: 선택한 날짜의 이벤트 리스트
            if let selected = selectedDate {
                eventListView(for: selected)
            } else {
                emptySelectionView
            }
        }
        .onAppear {
            refreshData()
        }
        .onChange(of: viewModel.currentWeekStart) { _, _ in
            refreshData()
            selectedDate = nil
        }
        .onChange(of: viewModel.showingAddEvent) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshData()
            }
        }
    }

    private var weekNavigationHeader: some View {
        HStack {
            Button(action: {
                viewModel.moveToPreviousWeek()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(spacing: 4) {
                Text(viewModel.weekDescription)
                    .font(.headline)

                Button(action: {
                    viewModel.moveToToday()
                }) {
                    Text("이번 주")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            Button(action: {
                viewModel.moveToNextWeek()
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var weekDensityChart: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("주간 일정 밀도")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 12)

                if densityData.isEmpty {
                    emptyWeekView
                } else {
                    let maxDensity = densityData.map { $0.density }.max() ?? 1

                    VStack(spacing: 8) {
                        ForEach(densityData) { dayData in
                            WeekDayDensityBar(
                                dayData: dayData,
                                maxDensity: maxDensity,
                                isSelected: selectedDate != nil && Calendar.current.isDate(selectedDate!, inSameDayAs: dayData.date)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if let selected = selectedDate, Calendar.current.isDate(selected, inSameDayAs: dayData.date) {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = dayData.date
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyWeekView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("이번 주 일정이 없습니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            Text("요일을 선택하세요")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("위의 요일을 탭하면\n해당 날짜의 일정을 확인할 수 있습니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func eventListView(for date: Date) -> some View {
        let events = viewModel.getEventsForDate(date)

        return VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(date))
                        .font(.headline)
                    Text("\(events.count)개 일정")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        selectedDate = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // 이벤트 리스트
            if events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("일정이 없습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(events) { event in
                            EventListCard(event: event)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }

    private func refreshData() {
        densityData = viewModel.getWeekDensityData()
    }
}

struct WeekDayDensityBar: View {
    let dayData: DayDensity
    let maxDensity: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 날짜 및 요일 레이블
            VStack(alignment: .trailing, spacing: 2) {
                Text(monthDay(from: dayData.date))
                    .font(.system(size: 15, weight: .semibold))
                Text(weekday(from: dayData.date))
                    .font(.system(size: 12))
                    .foregroundColor(isWeekend(dayData.date) ? .red : .secondary)
            }
            .frame(width: 50, alignment: .trailing)

            // 막대 그래프
            ZStack(alignment: .leading) {
                // 배경
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(height: 36)

                // 밀도 막대
                if dayData.density > 0 {
                    GeometryReader { geometry in
                        let barWidth = CGFloat(dayData.density) / CGFloat(maxDensity) * geometry.size.width
                        RoundedRectangle(cornerRadius: 8)
                            .fill(densityColor(for: dayData.density))
                            .frame(width: barWidth, height: 36)
                    }
                }

                // 숫자 레이블
                HStack {
                    Spacer()
                    Text("\(dayData.density)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(dayData.density > 0 ? .white : .secondary)
                        .padding(.trailing, 12)
                }
                .frame(height: 36)
            }

            // 선택 표시
            if isSelected {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 2)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(10)
    }

    private func monthDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func weekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func isWeekend(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // 일요일(1) 또는 토요일(7)
    }

    private func densityColor(for density: Int) -> Color {
        switch density {
        case 1:
            return Color.green
        case 2:
            return Color.blue
        case 3:
            return Color.orange
        default:
            return Color.red
        }
    }
}

struct EventListCard: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            // 색상 인디케이터
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: event.color) ?? .blue)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("\(formattedDate(event.startDate)) - \(formattedDate(event.endDate))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// Color extension for hex string
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&int) else {
            return nil
        }

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
