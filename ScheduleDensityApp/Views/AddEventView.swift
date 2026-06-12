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
    var initialDate: Date?
    var initialStartDate: Date?
    var initialEndDate: Date?
    var eventToEdit: Event?  // 수정할 일정 (nil이면 새로 추가)

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var hoursPerDay: Double = 2.0
    @State private var periodAnalysis: PeriodAnalysis? = nil
    @State private var showingDeleteAlert = false
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]  // 기본값: 월~금 선택
    @State private var useAdvancedPattern: Bool = false  // 5×7 그리드 패턴 사용 여부
    @State private var weeklyPattern: [Bool] = Array(repeating: false, count: 35)  // 5주×7일 패턴
    @State private var importance: EventImportance = .medium
    @State private var showRecommendations = false
    @State private var recommendations: [ScheduleViewModel.FreeTimeSlot] = []
    @State private var isInfinite: Bool = false  // 무한 반복 일정
    @State private var showingExceptionDatePicker = false
    @State private var newExceptionDate = Date()
    @State private var currentExceptions: Set<Date> = []

    init(viewModel: ScheduleViewModel, initialDate: Date? = nil, initialStartDate: Date? = nil, initialEndDate: Date? = nil, eventToEdit: Event? = nil) {
        self.viewModel = viewModel
        self.initialDate = initialDate
        self.initialStartDate = initialStartDate
        self.initialEndDate = initialEndDate
        self.eventToEdit = eventToEdit

        let calendar = Calendar.current

        // 수정 모드인 경우 기존 일정 정보로 초기화
        if let event = eventToEdit {
            _title = State(initialValue: event.title)
            _startDate = State(initialValue: event.startDate)
            _endDate = State(initialValue: event.endDate)
            _hoursPerDay = State(initialValue: event.hoursPerDay)

            // 패턴 초기화 (35일 패턴이 있으면 advanced mode, 없으면 simple mode)
            if let pattern = event.weeklyPattern {
                _useAdvancedPattern = State(initialValue: true)
                _weeklyPattern = State(initialValue: pattern)
            } else {
                _useAdvancedPattern = State(initialValue: false)
                // selectedWeekdays가 nil이면 모든 요일로 초기화
                _selectedWeekdays = State(initialValue: Set(event.selectedWeekdays ?? [1, 2, 3, 4, 5, 6, 7]))
            }

            _importance = State(initialValue: event.importance)
            _isInfinite = State(initialValue: event.isInfinite)
            _currentExceptions = State(initialValue: event.excludedDates)
        }
        // 우선순위: initialStartDate & initialEndDate > initialDate > 기본값
        else if let startDate = initialStartDate, let endDate = initialEndDate {
            _startDate = State(initialValue: startDate)
            _endDate = State(initialValue: endDate)
        } else if let initialDate = initialDate {
            _startDate = State(initialValue: initialDate)
            _endDate = State(initialValue: calendar.date(byAdding: .day, value: 7, to: initialDate) ?? initialDate)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("일정 정보") {
                    TextField("일정 제목", text: $title)
                }

                Section {
                    // 시작일
                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: startDate) { oldValue, newValue in
                            // 시작일이 종료일보다 뒤면 종료일을 시작일+1로 조정
                            if newValue > endDate && !isInfinite {
                                endDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                            }
                            updateAnalysis()
                        }

                    // 무한 반복 토글
                    Toggle(isOn: $isInfinite) {
                        HStack(spacing: 8) {
                            Image(systemName: "repeat")
                                .foregroundColor(isInfinite ? .blue : .secondary)
                            Text("무한 반복")
                                .fontWeight(isInfinite ? .semibold : .regular)
                        }
                    }
                    .onChange(of: isInfinite) { _, newValue in
                        updateAnalysis()
                        showRecommendations = false
                    }

                    if !isInfinite {
                        // 종료일 (무한 반복이 아닐 때만 표시)
                        DatePicker("종료일", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .onChange(of: endDate) { oldValue, newValue in
                                // 종료일이 시작일보다 앞이면 시작일을 종료일-1로 조정
                                if newValue < startDate {
                                    startDate = Calendar.current.date(byAdding: .day, value: -1, to: newValue) ?? newValue
                                }
                                updateAnalysis()
                            }
                    }

                    // 기간 표시
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                        Text("총 기간")
                        Spacer()
                        if isInfinite {
                            HStack(spacing: 4) {
                                Image(systemName: "infinity")
                                    .font(.system(size: 14))
                                Text("(최대 365일)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .fontWeight(.semibold)
                        } else {
                            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                            Text("\(days + 1)일")
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("날짜 선택")
                } footer: {
                    if isInfinite {
                        Text("무한 반복 일정은 시작일부터 최대 365일까지 표시됩니다")
                    }
                }

                // 요일 선택 섹션
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // 패턴 모드 토글
                        Toggle(isOn: $useAdvancedPattern) {
                            HStack {
                                Image(systemName: useAdvancedPattern ? "calendar.badge.clock" : "calendar")
                                    .foregroundColor(.blue)
                                Text(useAdvancedPattern ? "5주 패턴 모드" : "간단한 요일 선택")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .onChange(of: useAdvancedPattern) { _, newValue in
                            if newValue {
                                // 간단한 모드 -> 고급 모드: weekdays를 pattern으로 변환
                                convertWeekdaysToPattern()
                            } else {
                                // 고급 모드 -> 간단한 모드: pattern을 weekdays로 변환
                                convertPatternToWeekdays()
                            }
                            updateAnalysis()
                        }

                        Divider()

                        if useAdvancedPattern {
                            // 5×7 그리드 패턴
                            advancedPatternView
                        } else {
                            // 간단한 요일 선택
                            simpleWeekdayView
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("요일 패턴")
                } footer: {
                    Text(useAdvancedPattern
                        ? "5주 단위로 반복되는 패턴을 설정하세요. 홀수/짝수 주 패턴 등을 설정할 수 있습니다."
                        : "일정이 진행되는 요일을 선택하세요")
                }

                Section("소요시간") {
                    Stepper(value: $hoursPerDay, in: 0.5...24, step: 0.5) {
                        HStack {
                            Text("하루 소요시간")
                            Spacer()
                            Text(String(format: "%.1f시간", hoursPerDay))
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: hoursPerDay) { _, _ in
                        showRecommendations = false
                    }
                }

                // 중요도 선택 섹션
                Section {
                    Picker("중요도", selection: $importance) {
                        ForEach(EventImportance.allCases, id: \.self) { imp in
                            Text(imp.displayName).tag(imp)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: importance) { _, _ in
                        showRecommendations = false
                    }

                    HStack(spacing: 8) {
                        importanceIcon(importance)
                        Text(importanceDescription(importance))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("중요도")
                } footer: {
                    Text("높은 중요도는 빠른 날짜를, 낮은 중요도는 여유로운 날짜를 추천합니다")
                }

                // 예외 날짜 섹션
                Section {
                    Button(action: {
                        showingExceptionDatePicker = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.minus")
                            Text("예외 날짜 추가")
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }

                    // 미래 예외
                    if !futureExceptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("예정된 예외")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(futureExceptions, id: \.self) { date in
                                HStack {
                                    Image(systemName: "calendar.badge.minus")
                                        .foregroundColor(.orange)
                                    Text(formatDateShort(date))
                                        .font(.subheadline)
                                    Spacer()
                                    Button(action: {
                                        removeException(date)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // 과거 예외 (편집 모드에서만)
                    if eventToEdit != nil && !pastExceptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("과거 예외 (30일 후 자동 삭제)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(pastExceptions, id: \.self) { date in
                                HStack {
                                    Image(systemName: "calendar.badge.minus")
                                        .foregroundColor(.gray)
                                    Text(formatDateShort(date))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("지남")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } header: {
                    Text("예외 날짜")
                } footer: {
                    Text("특정 날짜를 일정에서 제외합니다. 과거 예외는 30일 후 자동 삭제됩니다.")
                }
                .sheet(isPresented: $showingExceptionDatePicker) {
                    NavigationView {
                        VStack {
                            DatePicker("날짜 선택", selection: $newExceptionDate,
                                      in: startDate...endDate,
                                      displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding()
                            Spacer()
                        }
                        .navigationTitle("예외 날짜 추가")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("취소") {
                                    showingExceptionDatePicker = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("추가") {
                                    addException(newExceptionDate)
                                    showingExceptionDatePicker = false
                                }
                                .disabled(!canAddException(newExceptionDate))
                            }
                        }
                    }
                }

                // 추천 날짜 섹션 (새 일정 추가 시에만)
                if eventToEdit == nil {
                    Section {
                        Button(action: {
                            generateRecommendations()
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("최적의 날짜 추천받기")
                                Spacer()
                                if showRecommendations {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        if showRecommendations && !recommendations.isEmpty {
                            ForEach(recommendations.prefix(5), id: \.startDate) { slot in
                                Button(action: {
                                    startDate = slot.startDate
                                    endDate = slot.endDate
                                    updateAnalysis()
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("\(formatDateShort(slot.startDate)) ~ \(formatDateShort(slot.endDate))")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(String(format: "%.0f점", slot.score))
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(scoreColor(slot.score))
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                        }

                                        HStack(spacing: 12) {
                                            Label(String(format: "%.1fh", slot.availableHours), systemImage: "clock")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            let daysFromNow = Calendar.current.dateComponents([.day], from: Date(), to: slot.startDate).day ?? 0
                                            Label("\(daysFromNow)일 후", systemImage: "calendar")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        } else if showRecommendations && recommendations.isEmpty {
                            Text("추천 가능한 날짜가 없습니다")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("🤖 AI 추천")
                    } footer: {
                        if showRecommendations && !recommendations.isEmpty {
                            Text("자유시간, 중요도, 일정 밀집도를 고려한 추천입니다. 탭하여 선택하세요.")
                        }
                    }
                }

                // 과부하 분석 정보 섹션
                if let analysis = periodAnalysis, endDate >= startDate {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // 총 기간
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                Text("총 기간")
                                Spacer()
                                Text("\(analysis.totalDays)일")
                                    .fontWeight(.semibold)
                            }

                            Divider()

                            // 최대 겹치는 일정 수
                            HStack {
                                Image(systemName: "rectangle.stack")
                                    .foregroundColor(analysis.maxOverlappingEvents >= 3 ? .red : .orange)
                                Text("최대 겹치는 일정")
                                Spacer()
                                Text("\(analysis.maxOverlappingEvents)개")
                                    .fontWeight(.semibold)
                                    .foregroundColor(analysis.maxOverlappingEvents >= 3 ? .red : .primary)
                            }

                            // 가장 바쁜 날 (개수 기준)
                            if let busiestDate = analysis.busiestDate, analysis.busiestDateEventCount > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("가장 바쁜 날")
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatDate(busiestDate))
                                            .fontWeight(.semibold)
                                        Text("\(analysis.busiestDateEventCount)개 일정")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Divider()

                            // 최대 하루 소요시간
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(analysis.maxHoursPerDay > 12 ? .red : analysis.maxHoursPerDay > 8 ? .orange : .green)
                                Text("하루 최대 소요시간")
                                Spacer()
                                Text(String(format: "%.1f시간", analysis.maxHoursPerDay))
                                    .fontWeight(.semibold)
                                    .foregroundColor(analysis.maxHoursPerDay > 12 ? .red : .primary)
                            }

                            // 시간 기준 가장 바쁜 날
                            if let busiestDateByHours = analysis.busiestDateByHours, analysis.maxHoursPerDay > 0 {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.red)
                                    Text("가장 과부하된 날")
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatDate(busiestDateByHours))
                                            .fontWeight(.semibold)
                                        Text(String(format: "%.1f시간", analysis.maxHoursPerDay))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            // 경고 메시지
                            if analysis.maxHoursPerDay > 12 {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("하루 12시간 이상 일정이 배정되어 있습니다. 일정 조정을 권장합니다.")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 4)
                            } else if analysis.maxOverlappingEvents >= 3 {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("3개 이상의 일정이 겹치는 날이 있습니다.")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }
                    } header: {
                        Text("📊 과부하 분석")
                    }
                }

                Section {
                    Text("이 일정은 시작일부터 종료일까지 매일 진행됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("일정의 색상은 배치된 레인에 따라 자동으로 지정됩니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(0..<7) { i in
                            Circle()
                                .fill(Color(hex: ScheduleViewModel.laneColors[i]) ?? .blue)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text("\(i + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }

                // 삭제 버튼 (수정 모드일 때만 표시)
                if eventToEdit != nil {
                    Section {
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("일정 삭제")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(eventToEdit == nil ? "일정 추가" : "일정 수정")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 초기 분석
                updateAnalysis()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        print("🚫 [AddEventView] 취소 버튼 클릭")
                        viewModel.eventToEdit = nil  // 취소 시 초기화
                        viewModel.lastAddedEventDate = nil  // 취소 시 스크롤 위치 초기화
                        print("🚫 [AddEventView] lastAddedEventDate = nil 설정")
                        dismiss()
                        print("🚫 [AddEventView] dismiss() 호출")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(eventToEdit == nil ? "추가" : "저장") {
                        saveEvent()
                    }
                    .disabled(title.isEmpty || endDate < startDate)
                }
            }
            .alert("일정 삭제", isPresented: $showingDeleteAlert) {
                Button("삭제", role: .destructive) {
                    deleteEvent()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("이 일정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.")
            }
        }
    }

    private func saveEvent() {
        // 패턴 결정: 고급 모드면 weeklyPattern 사용, 아니면 weekdays 사용
        let patternToSave: [Bool]? = useAdvancedPattern ? weeklyPattern : nil
        let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
        let weekdaysToSave: [Int]? = useAdvancedPattern ? nil :
            (selectedWeekdays.isEmpty || selectedWeekdays == allWeekdays) ? nil : Array(selectedWeekdays).sorted()

        if let existingEvent = eventToEdit {
            // 수정 모드: 기존 일정 업데이트
            existingEvent.title = title
            existingEvent.startDate = startDate
            existingEvent.endDate = endDate
            existingEvent.hoursPerDay = hoursPerDay
            existingEvent.selectedWeekdays = weekdaysToSave
            existingEvent.weeklyPattern = patternToSave
            existingEvent.importance = importance
            existingEvent.isInfinite = isInfinite
            existingEvent.excludedDates = currentExceptions
            viewModel.updateEvent(existingEvent)
            viewModel.eventToEdit = nil  // 수정 완료 후 초기화
        } else {
            // 추가 모드: 새 일정 생성
            let tempColor = UUID().uuidString
            let event = Event(
                title: title,
                startDate: startDate,
                endDate: endDate,
                color: tempColor,
                hoursPerDay: hoursPerDay,
                selectedWeekdays: weekdaysToSave,
                weeklyPattern: patternToSave,
                importance: importance,
                isInfinite: isInfinite,
                excludedDates: currentExceptions
            )
            viewModel.addEvent(event)
        }
        dismiss()
    }

    private func deleteEvent() {
        guard let event = eventToEdit else { return }
        viewModel.deleteEvent(event)
        viewModel.eventToEdit = nil  // 삭제 완료 후 초기화
        dismiss()
    }

    private func updateAnalysis() {
        // 시작일과 종료일이 유효한 경우에만 분석 수행
        guard startDate <= endDate else {
            periodAnalysis = nil
            return
        }

        periodAnalysis = viewModel.analyzePeriod(startDate: startDate, endDate: endDate)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    // 요일 전체 이름 (1=일, 2=월, ...)
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

    // 요일 짧은 이름
    private func weekdayShortName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }

    // 중요도 아이콘
    private func importanceIcon(_ importance: EventImportance) -> some View {
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
    }

    // 중요도 설명
    private func importanceDescription(_ importance: EventImportance) -> String {
        switch importance {
        case .high:
            return "높음 - 가능한 한 빠른 날짜에 배치됩니다"
        case .medium:
            return "보통 - 균형잡힌 날짜에 배치됩니다"
        case .low:
            return "낮음 - 여유로운 날짜에 배치됩니다"
        }
    }

    // 추천 점수에 따른 색상
    private func scoreColor(_ score: Double) -> Color {
        if score >= 100 {
            return .green
        } else if score >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    // 추천 날짜 생성
    private func generateRecommendations() {
        let calendar = Calendar.current
        let duration = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0 + 1
        let weekdaysArray = selectedWeekdays.isEmpty ? nil : Array(selectedWeekdays).sorted()

        recommendations = viewModel.recommendScheduleSlots(
            duration: duration,
            hoursPerDay: hoursPerDay,
            importance: importance,
            selectedWeekdays: weekdaysArray
        )

        showRecommendations = true
        print("💡 [AddEvent] \(recommendations.count)개 추천 생성")
    }

    // MARK: - Exception Helpers

    private var futureExceptions: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Array(currentExceptions.filter { $0 >= today }).sorted()
    }

    private var pastExceptions: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Array(currentExceptions.filter { $0 < today }).sorted()
    }

    private func addException(_ date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        currentExceptions.insert(normalizedDate)
    }

    private func removeException(_ date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        currentExceptions.remove(normalizedDate)
    }

    private func canAddException(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        // 이미 예외로 등록되어 있는지 확인
        guard !currentExceptions.contains(normalizedDate) else {
            return false
        }

        // 일정 범위 내인지 확인
        guard normalizedDate >= startDate && normalizedDate <= endDate else {
            return false
        }

        // 요일 선택이 있는 경우, 해당 요일인지 확인
        if !selectedWeekdays.isEmpty {
            let weekday = calendar.component(.weekday, from: normalizedDate)
            return selectedWeekdays.contains(weekday)
        }

        return true
    }

    // MARK: - Pattern Views

    private var simpleWeekdayView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach([1, 2, 3, 4, 5, 6, 7], id: \.self) { weekday in
                    let isSelected = selectedWeekdays.contains(weekday)
                    Button(action: {
                        if isSelected {
                            selectedWeekdays.remove(weekday)
                        } else {
                            selectedWeekdays.insert(weekday)
                        }
                        updateAnalysis()
                    }) {
                        VStack(spacing: 4) {
                            Text(weekdayShortName(weekday))
                                .font(.system(size: 11, weight: .semibold))
                            Circle()
                                .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Text(weekdayName(weekday))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isSelected ? .white : .gray)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)

            if selectedWeekdays.count == 7 {
                Text("모든 요일")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else if selectedWeekdays.isEmpty {
                Text("요일 선택 안 함")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("\(selectedWeekdays.count)개 요일 선택됨")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }

    private var advancedPatternView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 빠른 선택 버튼들
            HStack(spacing: 8) {
                Button("모두") {
                    weeklyPattern = Array(repeating: true, count: 35)
                    updateAnalysis()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("없음") {
                    weeklyPattern = Array(repeating: false, count: 35)
                    updateAnalysis()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("홀수 주") {
                    setOddWeeksPattern()
                    updateAnalysis()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("짝수 주") {
                    setEvenWeeksPattern()
                    updateAnalysis()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .font(.caption)

            // 5×7 그리드
            VStack(spacing: 8) {
                // 요일 헤더
                HStack(spacing: 0) {
                    Text("주")
                        .frame(width: 30)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekdayShortName(weekday))
                            .frame(maxWidth: .infinity)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 5주 그리드
                ForEach(0..<5, id: \.self) { week in
                    HStack(spacing: 0) {
                        // 주 번호
                        Text("\(week + 1)")
                            .frame(width: 30)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // 7일
                        ForEach(0..<7, id: \.self) { day in
                            let index = week * 7 + day
                            let isSelected = weeklyPattern[index]

                            Button(action: {
                                weeklyPattern[index].toggle()
                                updateAnalysis()
                            }) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .overlay(
                                        Text(weekdayName(day + 1))
                                            .font(.caption2)
                                            .fontWeight(isSelected ? .semibold : .regular)
                                            .foregroundColor(isSelected ? .white : .gray)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // 선택된 칸 수 표시
            let selectedCount = weeklyPattern.filter { $0 }.count
            if selectedCount == 0 {
                Text("패턴 선택 안 함")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if selectedCount == 35 {
                Text("모든 날짜 선택됨")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else {
                Text("35일 중 \(selectedCount)일 선택됨")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Pattern Conversion Helpers

    private func convertWeekdaysToPattern() {
        // 선택된 요일을 35일 패턴으로 변환
        weeklyPattern = (0..<35).map { index in
            let weekday = (index % 7) + 1  // 1=일요일, ..., 7=토요일
            return selectedWeekdays.contains(weekday)
        }
    }

    private func convertPatternToWeekdays() {
        // 35일 패턴에서 선택된 요일 추출
        var weekdays = Set<Int>()
        for day in 0..<7 {
            // 각 요일에 대해 5주 중 하나라도 선택되어 있으면 해당 요일 선택
            var hasSelection = false
            for week in 0..<5 {
                let index = week * 7 + day
                if weeklyPattern[index] {
                    hasSelection = true
                    break
                }
            }
            if hasSelection {
                weekdays.insert(day + 1)
            }
        }
        selectedWeekdays = weekdays
    }

    private func setOddWeeksPattern() {
        // 홀수 주(1, 3, 5)만 true
        weeklyPattern = (0..<35).map { index in
            let week = index / 7
            return week % 2 == 0  // 0, 2, 4 (1주차, 3주차, 5주차)
        }
    }

    private func setEvenWeeksPattern() {
        // 짝수 주(2, 4)만 true
        weeklyPattern = (0..<35).map { index in
            let week = index / 7
            return week % 2 == 1  // 1, 3 (2주차, 4주차)
        }
    }
}
