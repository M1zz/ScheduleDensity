//
//  DensityChartView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI

struct DensityChartView: View {
    @Bindable var viewModel: ScheduleViewModel
    @State private var densityData: [DayDensity] = []
    @State private var selectedDay: DayDensity?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if densityData.isEmpty {
                    emptyStateView
                } else {
                    chartView
                    if let selected = selectedDay {
                        eventDetailsView(for: selected)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            refreshData()
        }
        .onChange(of: viewModel.showingAddEvent) { _, _ in
            // 이벤트 추가 후 데이터 새로고침
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshData()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("일정이 없습니다")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("+ 버튼을 눌러 일정을 추가하거나\n샘플 데이터를 추가해보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var chartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일별 동시 진행 일정 수")
                .font(.headline)
                .foregroundColor(.primary)

            let maxDensity = densityData.map { $0.density }.max() ?? 1

            ForEach(densityData) { dayData in
                DensityBarView(
                    dayData: dayData,
                    maxDensity: maxDensity,
                    isSelected: selectedDay?.id == dayData.id
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedDay?.id == dayData.id {
                            selectedDay = nil
                        } else {
                            selectedDay = dayData
                        }
                    }
                }
            }
        }
    }

    private func eventDetailsView(for dayData: DayDensity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("진행 중인 일정")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        selectedDay = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }

            Text(formattedDate(dayData.date))
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(dayData.events) { event in
                EventCard(event: event)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }

    private func refreshData() {
        densityData = viewModel.getDensityData()
    }
}

struct DensityBarView: View {
    let dayData: DayDensity
    let maxDensity: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 날짜 레이블
            VStack(alignment: .trailing, spacing: 2) {
                Text(monthDay(from: dayData.date))
                    .font(.system(size: 14, weight: .semibold))
                Text(weekday(from: dayData.date))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, alignment: .trailing)

            // 막대 그래프
            ZStack(alignment: .leading) {
                // 배경
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 32)

                // 밀도 막대
                if dayData.density > 0 {
                    GeometryReader { geometry in
                        let barWidth = CGFloat(dayData.density) / CGFloat(maxDensity) * geometry.size.width
                        RoundedRectangle(cornerRadius: 6)
                            .fill(densityColor(for: dayData.density))
                            .frame(width: barWidth, height: 32)
                    }
                }

                // 숫자 레이블
                HStack {
                    Spacer()
                    Text("\(dayData.density)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(dayData.density > 0 ? .white : .secondary)
                        .padding(.trailing, 8)
                }
                .frame(height: 32)
            }

            // 선택 표시
            if isSelected {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 2)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
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

struct EventCard: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            // 색상 인디케이터
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: event.color) ?? .blue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))

                Text("\(formattedDate(event.startDate)) - \(formattedDate(event.endDate))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
