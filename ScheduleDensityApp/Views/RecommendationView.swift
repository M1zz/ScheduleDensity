//
//  RecommendationView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI

struct RecommendationView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel
    
    @State private var duration: Double = 2 // 시간 단위
    @State private var recommendations: [Recommendation] = []
    
    var body: some View {
        NavigationView {
            VStack {
                // 소요 시간 설정
                VStack(alignment: .leading, spacing: 8) {
                    Text("새 일정의 소요 시간")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Text("\(Int(duration))시간")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Slider(value: $duration, in: 0.5...8, step: 0.5)
                    }
                    .padding(.horizontal)
                    
                    Button(action: searchRecommendations) {
                        Label("추천 시간 찾기", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))
                
                // 주간 밀도 요약
                if !recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("이번 주 일정 밀도")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.weekDensity(), id: \.date) { density in
                                    DensityCardView(density: density)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // 추천 리스트
                if recommendations.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("위에서 시간을 설정하고\n'추천 시간 찾기'를 눌러주세요")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        Section("추천 시간대 (밀도 낮은 순)") {
                            ForEach(recommendations) { recommendation in
                                RecommendationRowView(recommendation: recommendation)
                            }
                        }
                    }
                }
            }
            .navigationTitle("시간 추천")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                searchRecommendations()
            }
        }
    }
    
    private func searchRecommendations() {
        let durationInSeconds = duration * 3600
        recommendations = viewModel.getRecommendations(duration: durationInSeconds)
    }
}

struct DensityCardView: View {
    let density: DayDensity
    
    var body: some View {
        VStack(spacing: 8) {
            Text(weekdayName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Calendar.current.component(.day, from: density.date))")
                .font(.title2)
                .fontWeight(.bold)
            
            // 밀도 바
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(densityColor)
                        .frame(height: geometry.size.height * CGFloat(density.occupancyRate))
                }
            }
            .frame(width: 30, height: 60)
            
            Text("\(Int(density.occupancyRate * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var weekdayName: String {
        let weekday = Calendar.current.component(.weekday, from: density.date)
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
    
    private var densityColor: Color {
        let rate = density.occupancyRate
        if rate < 0.3 {
            return .green
        } else if rate < 0.6 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct RecommendationRowView: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.timeSlot)
                        .font(.headline)
                    
                    Text(recommendation.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 점수 표시
                ScoreIndicator(score: recommendation.score)
            }
            
            // 날짜 표시
            Text(dateString)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: recommendation.date)
    }
}

struct ScoreIndicator: View {
    let score: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: CGFloat(score))
                .stroke(scoreColor, lineWidth: 4)
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(score * 100))")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .frame(width: 40, height: 40)
    }
    
    private var scoreColor: Color {
        if score > 0.7 {
            return .green
        } else if score > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }
}
