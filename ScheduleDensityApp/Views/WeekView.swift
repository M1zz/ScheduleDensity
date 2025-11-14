//
//  WeekView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI

struct WeekView: View {
    @Bindable var viewModel: ScheduleViewModel
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 주차 헤더
            HStack {
                Button(action: viewModel.moveToPreviousWeek) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(viewModel.weekDescription)
                    .font(.headline)
                
                Spacer()
                
                Button(action: viewModel.moveToNextWeek) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            // 요일 헤더
            HStack(spacing: 2) {
                // 시간 열 공간
                Color.clear
                    .frame(width: 50)
                
                ForEach(viewModel.daysInCurrentWeek, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(weekdayName(for: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isToday(date) ? .white : .primary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isToday(date) ? Color.blue : Color.clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            
            Divider()
            
            // 시간표
            ScrollView {
                HStack(alignment: .top, spacing: 2) {
                    // 시간 라벨 열
                    VStack(spacing: 0) {
                        ForEach(0..<48, id: \.self) { index in
                            let hour = index / 2
                            let minute = (index % 2) * 30
                            
                            if minute == 0 {
                                Text(String(format: "%02d:00", hour))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, height: 30, alignment: .topTrailing)
                                    .padding(.trailing, 4)
                            } else {
                                Color.clear
                                    .frame(width: 50, height: 30)
                            }
                        }
                    }
                    
                    // 일별 그리드
                    ForEach(viewModel.daysInCurrentWeek, id: \.self) { date in
                        DayColumnView(date: date, viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        viewModel.moveToNextWeek()
                    } else if value.translation.width > 100 {
                        viewModel.moveToPreviousWeek()
                    }
                    dragOffset = 0
                }
        )
    }
    
    private func weekdayName(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
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
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

struct DayColumnView: View {
    let date: Date
    @Bindable var viewModel: ScheduleViewModel
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 배경 그리드
            VStack(spacing: 0) {
                ForEach(0..<48, id: \.self) { index in
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 30)
                        .overlay(
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1),
                            alignment: .bottom
                        )
                }
            }
            
            // 일정 표시
            let events = viewModel.eventsForDate(date)
            let slots = viewModel.densityForDate(date)
            
            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                EventBlockView(event: event, maxDensity: getMaxDensityForEvent(event, slots: slots), offset: index)
            }
        }
    }
    
    private func getMaxDensityForEvent(_ event: EventInstance, slots: [TimeSlot]) -> Int {
        let relevantSlots = slots.filter { slot in
            slot.startTime >= event.startTime && slot.startTime < event.endTime
        }
        return relevantSlots.map { $0.density }.max() ?? 1
    }
}

struct EventBlockView: View {
    let event: EventInstance
    let maxDensity: Int
    let offset: Int
    
    private let slotHeight: CGFloat = 30
    
    var body: some View {
        let startMinutes = minutesFromMidnight(event.startTime)
        let duration = event.endTime.timeIntervalSince(event.startTime) / 60.0
        let yOffset = (CGFloat(startMinutes) / 30.0) * slotHeight
        let height = (CGFloat(duration) / 30.0) * slotHeight
        
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(timeRange)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: max(height - 2, 20))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(densityOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(color, lineWidth: 1)
                )
        )
        .offset(y: yOffset)
        .padding(.leading, CGFloat(offset * 4)) // 겹치는 일정은 약간 오른쪽으로
    }
    
    private var color: Color {
        Color(hex: event.color) ?? .blue
    }
    
    private var densityOpacity: Double {
        // 밀도가 높을수록 진하게
        return 0.5 + (Double(min(maxDensity, 3)) * 0.15)
    }
    
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startTime))-\(formatter.string(from: event.endTime))"
    }
    
    private func minutesFromMidnight(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

// Color extension for hex
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
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
