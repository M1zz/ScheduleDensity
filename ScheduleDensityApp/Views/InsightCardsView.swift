//
//  InsightCardsView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

struct InsightCardsView: View {
    let insights: WeekInsights

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 오늘 카드
                if let today = insights.todayInsight {
                    TodayInsightCard(insight: today)
                }

                // 내일 카드
                if let tomorrow = insights.tomorrowInsight {
                    TomorrowInsightCard(insight: tomorrow)
                }

                // 가장 한가한 날
                if let freest = insights.freestDay {
                    FreestDayCard(insight: freest)
                }

                // 가장 바쁜 날
                if let busiest = insights.busiestDay {
                    BusiestDayCard(insight: busiest)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 오늘 카드
struct TodayInsightCard: View {
    let insight: DayInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("오늘")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(insight.statusEmoji)
                    .font(.title2)
            }

            Text(insight.statusText)
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                Label("\(insight.eventCount)개", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(String(format: "%.1fh", insight.totalHours), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 밀도 바
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(densityColor)
                        .frame(width: geometry.size.width * CGFloat(insight.occupancyRate))
                }
            }
            .frame(height: 6)
        }
        .padding()
        .frame(width: 160)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var densityColor: Color {
        if insight.occupancyRate < 0.3 {
            return .green
        } else if insight.occupancyRate < 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - 내일 카드
struct TomorrowInsightCard: View {
    let insight: DayInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("내일")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(insight.statusEmoji)
                    .font(.title2)
            }

            Text(insight.statusText)
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                Label("\(insight.eventCount)개", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(String(format: "%.1fh", insight.totalHours), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 밀도 바
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(densityColor)
                        .frame(width: geometry.size.width * CGFloat(insight.occupancyRate))
                }
            }
            .frame(height: 6)
        }
        .padding()
        .frame(width: 160)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var densityColor: Color {
        if insight.occupancyRate < 0.3 {
            return .green
        } else if insight.occupancyRate < 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - 가장 한가한 날 카드
struct FreestDayCard: View {
    let insight: DayInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Spacer()
                Text("😌")
                    .font(.title2)
            }

            Text("가장 한가한 날")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(dateString)
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                Label("\(insight.eventCount)개", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(String(format: "%.1fh", insight.totalHours), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 160)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .green.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: insight.date)
    }
}

// MARK: - 가장 바쁜 날 카드
struct BusiestDayCard: View {
    let insight: DayInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                Spacer()
                Text("🔥")
                    .font(.title2)
            }

            Text("가장 바쁜 날")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(dateString)
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                Label("\(insight.eventCount)개", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(String(format: "%.1fh", insight.totalHours), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 160)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .red.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: insight.date)
    }
}
