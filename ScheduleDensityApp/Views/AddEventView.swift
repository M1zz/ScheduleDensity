//
//  AddEventView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel
    
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var selectedColor = "#4ECDC4"
    @State private var hasRecurrence = false
    @State private var selectedPattern: RecurrencePatternOption = .none
    @State private var recurrenceEndDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var customDays: Set<Int> = []
    
    let colors = ["#4ECDC4", "#FF6B6B", "#95E1D3", "#F38181", "#AA96DA", "#FCBAD3", "#A8D8EA", "#FFCF81"]
    
    enum RecurrencePatternOption: String, CaseIterable {
        case none = "없음"
        case daily = "매일"
        case weekdays = "평일"
        case weekends = "주말"
        case mondayWednesdayFriday = "월/수/금"
        case tuesdayThursday = "화/목"
        case custom = "사용자 지정"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("일정 정보") {
                    TextField("일정 제목", text: $title)
                    
                    DatePicker("시작 시간", selection: $startDate)
                    
                    DatePicker("종료 시간", selection: $endDate)
                    
                    // 색상 선택
                    VStack(alignment: .leading) {
                        Text("색상")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 8), spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color) ?? .blue)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("반복") {
                    Toggle("반복 일정", isOn: $hasRecurrence)
                    
                    if hasRecurrence {
                        Picker("반복 패턴", selection: $selectedPattern) {
                            ForEach(RecurrencePatternOption.allCases, id: \.self) { pattern in
                                Text(pattern.rawValue).tag(pattern)
                            }
                        }
                        
                        if selectedPattern == .custom {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("요일 선택")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    ForEach([("일", 1), ("월", 2), ("화", 3), ("수", 4), ("목", 5), ("금", 6), ("토", 7)], id: \.1) { day in
                                        Text(day.0)
                                            .font(.caption)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(customDays.contains(day.1) ? Color.blue : Color.gray.opacity(0.2))
                                            )
                                            .foregroundColor(customDays.contains(day.1) ? .white : .primary)
                                            .onTapGesture {
                                                if customDays.contains(day.1) {
                                                    customDays.remove(day.1)
                                                } else {
                                                    customDays.insert(day.1)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        
                        DatePicker("반복 종료일", selection: $recurrenceEndDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        addEvent()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addEvent() {
        var pattern: RecurrencePattern? = nil
        var daysOfWeek: [Int]? = nil

        if hasRecurrence {
            switch selectedPattern {
            case .none:
                pattern = nil
            case .daily:
                pattern = .daily
                daysOfWeek = RecurrencePattern.everyDayPattern
            case .weekdays:
                pattern = .weekly
                daysOfWeek = RecurrencePattern.weekdaysPattern
            case .weekends:
                pattern = .weekly
                daysOfWeek = RecurrencePattern.weekendsPattern
            case .mondayWednesdayFriday:
                pattern = .weekly
                daysOfWeek = RecurrencePattern.mondayWednesdayFridayPattern
            case .tuesdayThursday:
                pattern = .weekly
                daysOfWeek = RecurrencePattern.tuesdayThursdayPattern
            case .custom:
                if !customDays.isEmpty {
                    pattern = .weekly
                    daysOfWeek = Array(customDays)
                }
            }
        }

        let event = Event(
            title: title,
            startTime: startDate,
            endTime: endDate,
            color: selectedColor,
            recurrencePattern: pattern,
            recurrenceDaysOfWeek: daysOfWeek,
            recurrenceEndDate: hasRecurrence ? recurrenceEndDate : nil
        )

        viewModel.addEvent(event)
        dismiss()
    }
}
