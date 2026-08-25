//
//  AddEventView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI
import UIKit

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel
    var initialDate: Date?
    var initialStartDate: Date?
    var initialEndDate: Date?
    var eventToEdit: Event?  // 수정할 일정 (nil이면 새로 추가)
    /// 첫 일정을 만드는 중이면, 무엇을 어떤 순서로 적는지 항목별로 짚어준다.
    var showsFieldGuide: Bool = false

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
    /// '추가'를 눌렀는데 아직 비어 있는 칸이 있을 때만 켜진다 — 그때부터 빨갛게 짚어준다.
    @State private var showValidationErrors = false
    /// 지금 짚어주고 있는 항목. nil이면 안내가 끝났거나 애초에 없는 경우.
    @State private var guideStep: AddEventGuideStep?
    @State private var showingExceptionDatePicker = false
    @State private var newExceptionDate = Date()
    @State private var currentExceptions: Set<Date> = []

    init(viewModel: ScheduleViewModel, initialDate: Date? = nil, initialStartDate: Date? = nil,
         initialEndDate: Date? = nil, eventToEdit: Event? = nil, showsFieldGuide: Bool = false) {
        self.viewModel = viewModel
        self.initialDate = initialDate
        self.initialStartDate = initialStartDate
        self.initialEndDate = initialEndDate
        self.eventToEdit = eventToEdit
        self.showsFieldGuide = showsFieldGuide
        _guideStep = State(initialValue: showsFieldGuide ? .title : nil)

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
            // 예전 '무한 반복' 일정은 끝나는 날을 정해 둔 일정으로 바꿔 연다.
            // 저장하면 그대로 굳는다 — 끝이 없는 일정은 더 이상 만들지 않는다.
            if event.isInfinite {
                _endDate = State(initialValue: event.effectiveEndDate())
            }
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
            ScrollViewReader { proxy in
            Form {
                titleSection

                periodSection

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
                    .id(Self.activeDaysFieldID)
                    .spotlightAnchor(guideStep == .activeDays)
                    .padding(.vertical, 8)
                } header: {
                    Text("시간 쓰는 날")
                } footer: {
                    Text(useAdvancedPattern
                        ? "5주 단위로 반복되는 패턴을 설정하세요. 격주 스터디처럼 홀수/짝수 주가 다른 일도 적을 수 있습니다."
                        : "기간 안에서 실제로 시간을 쓰는 요일만 고르세요. 고르지 않은 날도 기간 안이면 무지개에 옅게 남습니다.")
                }

                hoursSection

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
                                            // 고를 때 봐야 하는 숫자는 '지금 얼마나 비었나'가 아니라
                                            // '넣고 나면 얼마나 차나'다. 80%를 넘기면 예상 못한 일
                                            // 하나에 그 날이 무너진다 (→ LoadLevel).
                                            Label("넣으면 \(Int((slot.projectedUtilization * 100).rounded()))%",
                                                  systemImage: "speedometer")
                                                .font(.caption)
                                                .foregroundColor(utilizationColor(slot.projectedUtilization))

                                            Label(String(format: "%.1fh 여유", max(0, slot.availableHours - hoursPerDay)),
                                                  systemImage: "leaf")
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
                            Text("가장 한가한 날이 아니라, 넣고 나서도 여유가 남는 날을 먼저 올립니다.\n하루가 80% 넘게 차면 예상 못한 일 하나에 그 날 전체가 밀립니다. 그 위로는 감점된 추천이니, 굳이 넣어야 할 때만 고르세요.")
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
                    Text("시작일부터 종료일까지가 이 일정에 매여 있는 기간이고, 그중 고른 날에만 시간이 실제로 들어갑니다.")
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
            .overlayPreferenceValue(SpotlightAnchorKey.self) { anchors in
                GeometryReader { geo in
                    if let step = guideStep {
                        SpotlightCoachOverlay(
                            hole: geo.spotlightRect(anchors)?.insetBy(dx: -8, dy: -6),
                            containerSize: geo.size,
                            icon: step.icon,
                            title: guideTitle(step),
                            message: step.message,
                            // 안내를 보면서 그 자리를 바로 만질 수 있어야 한다.
                            passesTouches: true
                        ) {
                            Spacer()
                            Button("그만 볼래요") { withAnimation { guideStep = nil } }
                                .font(.footnote)
                            if let next = step.next {
                                Button("다음") { advanceGuide(to: next, proxy: proxy) }
                                    .buttonStyle(.borderedProminent)
                            } else {
                                Button("알겠어요") { withAnimation { guideStep = nil } }
                                    .buttonStyle(.borderedProminent)
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
                    // 진짜로 .disabled를 걸면 눌러도 아무 일이 안 일어나서
                    // "왜 안 눌리지"만 남는다. 눌리게 두고, 무엇이 비었는지 알려준다.
                    Button(eventToEdit == nil ? "추가" : "저장") {
                        attemptSave(scrollTo: proxy)
                    }
                    .foregroundColor(canSave ? nil : .secondary)
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
            // 끝이 없던 일정은 여기서 끝나는 날이 있는 일정으로 굳는다.
            existingEvent.isInfinite = false
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


    // MARK: - 화면 조각
    // (한 덩어리로 두면 타입 체커가 감당을 못 해 빌드가 멈춘다.)

    private var titleSection: some View {
            Section {
                TextField("일정 제목", text: $title)
                    .id(Self.titleFieldID)
                    .spotlightAnchor(guideStep == .title)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red, lineWidth: 1.5)
                            .padding(.horizontal, -6)
                            .opacity(isTitleMissing ? 1 : 0)
                    )

                if isTitleMissing {
                    Label("일정 제목을 적어주세요", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("일정 정보")
                    .foregroundColor(isTitleMissing ? .red : nil)
            }
    }

    @ViewBuilder
    private var periodSection: some View {
            Section {
                // 시작일
                DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .id(Self.periodFieldID)
                    .spotlightAnchor(guideStep == .period)
                    .onChange(of: startDate) { oldValue, newValue in
                        // 시작일이 종료일보다 뒤면 종료일을 시작일+1로 조정
                        if newValue > endDate {
                            endDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                        }
                        updateAnalysis()
                    }

                // 종료일 — 반드시 있다. 끝나는 날을 안 정하면 그 일은 영영 안 끝난다.
                DatePicker("종료일", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .spotlightAnchor(guideStep == .period)
                    .onChange(of: endDate) { oldValue, newValue in
                        // 종료일이 시작일보다 앞이면 시작일을 종료일-1로 조정
                        if newValue < startDate {
                            startDate = Calendar.current.date(byAdding: .day, value: -1, to: newValue) ?? newValue
                        }
                        updateAnalysis()
                    }

                // 매여 있는 기간과 실제로 시간을 쓰는 날을 나란히 보여준다.
                // 이 둘이 다르다는 걸 눈으로 봐야, 무지개에서 옅은 칸과 진한 칸이 읽힌다.
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text("매여 있는 기간")
                    Spacer()
                    Text("\(totalSpanDays)일")
                        .fontWeight(.semibold)
                }

                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.orange)
                    Text("실제로 시간 쓰는 날")
                    Spacer()
                    Text("\(activeDayCount)일")
                        .fontWeight(.semibold)
                        .foregroundColor(activeDayCount == 0 ? .red : .primary)
                }
        } header: {
            Text("기간")
                .foregroundColor(isDateRangeInvalid ? .red : nil)
        } footer: {
            if isDateRangeInvalid {
                Label("종료일이 시작일보다 앞섭니다", systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            } else if activeDayCount == 0 {
                    Text("이 기간에 실제로 하는 날이 하루도 없습니다. 아래 '시간 쓰는 날'에서 요일을 골라주세요.")
                        .foregroundColor(.red)
                } else {
                    Text("끝나는 날은 반드시 정합니다. 스터디처럼 화요일에만 모이더라도, 그 스터디가 끝나는 날까지는 계속 매여 있는 시간이니까요.\n무지개에는 매여 있는 기간이 옅게, 실제로 시간을 쓰는 날이 진하게 칠해집니다.")
                }
            }
    }

    private var hoursSection: some View {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    // 하루에 몇 시간인지가 이 화면에서 제일 중요한 숫자다. 눈에 먼저 들어와야 한다.
                    Stepper(value: $hoursPerDay, in: 0.5...24, step: 0.5) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("하루 소요시간")
                                .font(.headline)
                            Spacer()
                            Text(hourText(hoursPerDay))
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundColor(.blue)
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.15), value: hoursPerDay)
                        }
                    }
                    .onChange(of: hoursPerDay) { _, _ in
                        showRecommendations = false
                    }

                    // 자주 쓰는 값은 한 번에 — 0.5시간씩 열 번 누르지 않게.
                    HStack(spacing: 8) {
                        ForEach(quickHourChoices, id: \.self) { hours in
                            Button {
                                hoursPerDay = hours
                                showRecommendations = false
                            } label: {
                                Text(hourText(hours))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(hoursPerDay == hours
                                                       ? Color.blue
                                                       : Color(.systemGray5))
                                    )
                                    .foregroundColor(hoursPerDay == hours ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    HStack {
                        Text("이 일정에 들어가는 시간")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f시간", Double(activeDayCount) * hoursPerDay))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    Text("\(activeDayCount)일 × \(hourText(hoursPerDay))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .id(Self.hoursFieldID)
                .spotlightAnchor(guideStep == .hours)
                .padding(.vertical, 6)
            } header: {
                Text("소요시간")
            } footer: {
                Text("위에서 고른 '시간 쓰는 날' 하루에 들어가는 시간입니다. 기간 전체로 나눈 값이 아닙니다.")
            }
    }

    // MARK: - 항목 안내

    /// 카드 제목에 몇 번째 항목인지 붙인다. 남은 개수가 보여야 끝이 보인다.
    private func guideTitle(_ step: AddEventGuideStep) -> String {
        guard let order = step.order else { return step.title }
        return "\(order.index)/\(order.total) · \(step.title)"
    }

    private func advanceGuide(to step: AddEventGuideStep, proxy: ScrollViewProxy) {
        withAnimation { guideStep = step }
        guard let id = guideFieldID(step) else { return }
        // 짚어주는 자리가 화면 밖이면 설명만 뜨고 정작 그 자리는 안 보인다.
        withAnimation { proxy.scrollTo(id, anchor: .center) }
    }

    private func guideFieldID(_ step: AddEventGuideStep) -> String? {
        switch step {
        case .title: return Self.titleFieldID
        case .period: return Self.periodFieldID
        case .activeDays: return Self.activeDaysFieldID
        case .hours: return Self.hoursFieldID
        case .save: return nil
        }
    }

    // MARK: - 저장 전 확인

    /// 비어 있는 칸(또는 지금 짚어주는 항목)으로 스크롤해 데려가기 위한 표식.
    private static let titleFieldID = "titleField"
    private static let periodFieldID = "periodField"
    private static let activeDaysFieldID = "activeDaysField"
    private static let hoursFieldID = "hoursField"

    /// '추가'를 눌러 봤는데 제목이 아직 비어 있는 상태.
    private var isTitleMissing: Bool {
        showValidationErrors && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 날짜가 뒤집힌 상태. (양쪽 DatePicker가 서로 밀어주므로 보통은 나지 않는다.)
    private var isDateRangeInvalid: Bool {
        showValidationErrors && endDate < startDate
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

    /// 눌렀는데 저장할 수 없으면, 어디가 비었는지 빨갛게 짚어주고 그 자리로 데려간다.
    private func attemptSave(scrollTo proxy: ScrollViewProxy? = nil) {
        guard canSave else {
            // 아직 못 적은 게 있으면 안내보다 그 빨간 표시가 먼저 보여야 한다.
            withAnimation { guideStep = nil }
            withAnimation { showValidationErrors = true }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let proxy {
                withAnimation { proxy.scrollTo(Self.titleFieldID, anchor: .center) }
            }
            return
        }
        saveEvent()
    }


    // MARK: - 소요시간

    /// 한 번에 고를 수 있게 둔 흔한 값들.
    private var quickHourChoices: [Double] { [0.5, 1, 2, 3, 4] }

    /// 30분 단위라 소수점이 필요할 때만 붙인다. (2시간 / 1.5시간)
    private func hourText(_ hours: Double) -> String {
        hours == hours.rounded()
            ? String(format: "%.0f시간", hours)
            : String(format: "%.1f시간", hours)
    }

    // MARK: - 기간 vs 실제로 시간 쓰는 날

    /// 시작일부터 종료일까지, 이 일정에 매여 있는 날 수.
    private var totalSpanDays: Int {
        guard startDate <= endDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate),
                                                   to: Calendar.current.startOfDay(for: endDate)).day ?? 0
        return days + 1
    }

    /// 그중 실제로 시간이 들어가는 날 수. 요일/5주 패턴과 예외 날짜를 그대로 반영한다.
    /// (Event.occursOn과 같은 규칙 — 저장 전 화면에서 미리 세어 보여주려고 여기서 한 번 더 센다.)
    private var activeDayCount: Int {
        guard startDate <= endDate else { return 0 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let exceptions = Set(currentExceptions.map { calendar.startOfDay(for: $0) })

        var count = 0
        var current = start
        while current <= end {
            if !exceptions.contains(current), spendsTime(on: current, from: start) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return count
    }

    private func spendsTime(on date: Date, from start: Date) -> Bool {
        let calendar = Calendar.current
        if useAdvancedPattern {
            let daysSinceStart = calendar.dateComponents([.day], from: start, to: date).day ?? 0
            let index = ((daysSinceStart % 35) + 35) % 35
            return weeklyPattern.indices.contains(index) ? weeklyPattern[index] : false
        }
        if selectedWeekdays.isEmpty { return true }  // 아무것도 안 고르면 매일로 저장된다
        return selectedWeekdays.contains(calendar.component(.weekday, from: date))
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

    // 넣고 난 뒤의 가동률에 따른 색상. 80% 선이 기준이다 (→ LoadLevel).
    private func utilizationColor(_ rate: Double) -> Color {
        switch LoadLevel(rate: rate) {
        case .easy:   return .green
        case .normal: return .blue
        case .tight:  return .orange
        case .over:   return .red
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
