//
//  StatisticsView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel

    @State private var statistics: EventStatistics = EventStatistics()
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.top, 100)
                    } else {
                        // 전체 요약
                        overviewSection

                        // 중요도 분포
                        importanceSection

                        // 시간 통계
                        timeSection

                        // 가장 바쁜 날
                        busiestDaySection

                        // 요일별 분포
                        weekdaySection

                        // 레인별 분포
                        laneSection

                        // 기간 정보
                        durationSection
                    }
                }
                .padding()
            }
            .navigationTitle("일정 통계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .task {
                await calculateStatistics()
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("전체 요약")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    icon: "calendar",
                    title: "전체 일정",
                    value: "\(statistics.totalEvents)",
                    color: .blue
                )

                StatCard(
                    icon: "play.circle.fill",
                    title: "진행 중",
                    value: "\(statistics.activeEvents)",
                    color: .green
                )

                StatCard(
                    icon: "checkmark.circle.fill",
                    title: "완료됨",
                    value: "\(statistics.completedEvents)",
                    color: .gray
                )

                StatCard(
                    icon: "repeat",
                    title: "무한 반복",
                    value: "\(statistics.infiniteEvents)",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var importanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("중요도 분포")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                ImportanceRow(
                    importance: .high,
                    count: statistics.highImportanceCount,
                    total: statistics.totalEvents
                )

                ImportanceRow(
                    importance: .medium,
                    count: statistics.mediumImportanceCount,
                    total: statistics.totalEvents
                )

                ImportanceRow(
                    importance: .low,
                    count: statistics.lowImportanceCount,
                    total: statistics.totalEvents
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("시간 통계")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                HStack {
                    Label("총 일정 시간", systemImage: "clock.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f시간", statistics.totalHours))
                        .fontWeight(.semibold)
                }

                Divider()

                HStack {
                    Label("일정당 평균", systemImage: "clock")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f시간", statistics.averageHoursPerEvent))
                        .fontWeight(.semibold)
                }

                Divider()

                HStack {
                    Label("하루 평균", systemImage: "calendar.badge.clock")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f시간", statistics.averageHoursPerDay))
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var busiestDaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("가장 바쁜 날")
                .font(.headline)
                .foregroundColor(.primary)

            if let busiestDate = statistics.busiestDate {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatDateFull(busiestDate))
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(statistics.busiestDateEventCount)개 일정")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    Divider()

                    HStack {
                        Text("총 소요시간")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f시간", statistics.busiestDateHours))
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            } else {
                Text("일정이 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("요일별 분포 (주간 평균)")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                let maxAverage = statistics.weekdayDistribution.values.max() ?? 1.0

                ForEach(1...7, id: \.self) { weekday in
                    let average = statistics.weekdayDistribution[weekday] ?? 0
                    let percentage = maxAverage > 0 ? (average / maxAverage) * 100 : 0

                    HStack(spacing: 12) {
                        Text(weekdayName(weekday))
                            .font(.subheadline)
                            .frame(width: 40, alignment: .leading)
                            .foregroundColor(isWeekend(weekday) ? .red : .primary)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isWeekend(weekday) ? Color.red.opacity(0.6) : Color.blue)
                                    .frame(width: geometry.size.width * CGFloat(percentage / 100))
                            }
                        }
                        .frame(height: 20)

                        Text(String(format: "%.1f", average))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var laneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("레인별 분포")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { lane in
                    let count = statistics.laneDistribution[lane] ?? 0
                    let laneColor = Color(hex: ScheduleViewModel.laneColors[lane]) ?? .blue

                    if count > 0 {
                        HStack(spacing: 12) {
                            Text("레인 \(lane + 1)")
                                .font(.subheadline)
                                .frame(width: 60, alignment: .leading)

                            Circle()
                                .fill(laneColor)
                                .frame(width: 16, height: 16)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(laneColor.opacity(0.7))
                                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(statistics.totalEvents))
                                }
                            }
                            .frame(height: 20)

                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기간 정보")
                .font(.headline)
                .foregroundColor(.primary)

            Text("※ 무한 반복 일정은 30일 기준으로 계산됩니다")
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                if let longest = statistics.longestEvent {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("가장 긴 일정")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(longest.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text("\(durationDays(longest))일")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    Divider()
                }

                if let shortest = statistics.shortestEvent {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("가장 짧은 일정")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(shortest.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text("\(durationDays(shortest))일")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func calculateStatistics() async {
        isLoading = true

        await Task {
            let stats = viewModel.calculateStatistics()

            await MainActor.run {
                self.statistics = stats
                self.isLoading = false
            }
        }.value
    }

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "일"
        case 2: return "월"
        case 3: return "화"
        case 4: return "수"
        case 5: return "목"
        case 6: return "금"
        case 7: return "토"
        default: return ""
        }
    }

    private func isWeekend(_ weekday: Int) -> Bool {
        return weekday == 1 || weekday == 7
    }

    private func durationDays(_ event: Event) -> Int {
        let calendar = Calendar.current
        let endDate: Date
        if event.isInfinite {
            // 무한 반복은 30일 기준으로 표시
            endDate = calendar.date(byAdding: .day, value: 30, to: event.startDate) ?? event.startDate
        } else {
            endDate = event.effectiveEndDate()
        }
        let days = calendar.dateComponents([.day], from: event.startDate, to: endDate).day ?? 0
        return days + 1
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ImportanceRow: View {
    let importance: EventImportance
    let count: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            importanceIcon

            Text(importance.displayName)
                .font(.subheadline)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(importanceColor)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 20)

            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)

            Text(String(format: "%.0f%%", percentage))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) * 100 : 0
    }

    private var importanceIcon: some View {
        Group {
            switch importance {
            case .high:
                Image(systemName: "exclamationmark.3")
                    .foregroundColor(.red)
            case .medium:
                Image(systemName: "exclamationmark.2")
                    .foregroundColor(.orange)
            case .low:
                Image(systemName: "exclamationmark")
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 24)
    }

    private var importanceColor: Color {
        switch importance {
        case .high: return .red.opacity(0.7)
        case .medium: return .orange.opacity(0.7)
        case .low: return .blue.opacity(0.7)
        }
    }
}
