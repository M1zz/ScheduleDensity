//
//  TimelineDensityView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI
import UIKit

struct TimelineDensityView: View {
    @Bindable var viewModel: ScheduleViewModel
    @State private var densityData: [DayDensity] = []
    @State private var selectedDay: DayDensity?
    @State private var hasScrolledToToday = false
    @State private var isLoading = true
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedDateForNewEvent: Date?
    @State private var showingAddEventSheet = false

    // 드래그 선택 상태
    @State private var isDraggingSelection = false
    @State private var dragStartDate: Date?
    @State private var dragEndDate: Date?
    @State private var draggedDates: Set<Date> = []
    @State private var draggedLane: Int?

    // 토스트 메시지 상태
    @State private var showToast = false
    @State private var toastMessage = ""

    // 날짜별 시간 분석 상태
    @State private var selectedDateForTimeAnalysis: DateWrapper?

    // 인사이트 설정 (UserDefaults에 저장)
    @AppStorage("showInsightCards") private var showInsightCards = false
    // 인사이트 카드 펼침 상태
    @State private var isInsightExpanded = false

    var body: some View {
        mainContent
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        scrollToToday()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("오늘")
                        }
                    }
                }
            }
            .task {
                // task를 사용하여 비동기로 데이터 로드
                refreshData()

                // 0.2초 후 오늘로 스크롤
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollToToday()
                }
            }
            .onChange(of: viewModel.showingAddEvent) { _, isShowing in
                if !isShowing {
                    print("🔵 [TimelineView] 일정 추가 시트 닫힘")
                    // 일정이 추가되었을 때만 새로고침
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🔵 [TimelineView] 0.3초 후 실행 시작")
                        print("🔵 [TimelineView] lastAddedEventDate: \(viewModel.lastAddedEventDate != nil ? "있음" : "nil")")

                        // 일정이 추가되었으면 데이터 새로고침 후 해당 날짜로 스크롤
                        if let addedDate = viewModel.lastAddedEventDate {
                            print("✅ [TimelineView] 일정 추가됨 - refreshData() 호출 후 스크롤")
                            refreshData()
                            scrollToDate(addedDate)
                            viewModel.lastAddedEventDate = nil // 초기화
                        } else {
                            print("✅ [TimelineView] 일정 취소됨 - 아무것도 하지 않음 (스크롤 위치 유지)")
                            // 취소한 경우 데이터 변경 없음 - refreshData() 호출 안 함
                        }
                    }
                }
            }
            .onChange(of: viewModel.dataRefreshTrigger) { _, _ in
                // 데이터 삭제 등의 변경 발생 시 새로고침
                refreshData()
            }
            .sheet(isPresented: $showingAddEventSheet) {
                if let startDate = dragStartDate, let endDate = dragEndDate {
                    AddEventView(viewModel: viewModel, initialStartDate: startDate, initialEndDate: endDate)
                } else if let selectedDate = selectedDateForNewEvent {
                    AddEventView(viewModel: viewModel, initialDate: selectedDate)
                }
            }
            .onChange(of: showingAddEventSheet) { _, isShowing in
                if !isShowing {
                    print("🔵 [TimelineView] 드래그 일정 추가 시트 닫힘")
                    // sheet가 닫힐 때 선택 상태 초기화
                    isDraggingSelection = false
                    dragStartDate = nil
                    dragEndDate = nil
                    draggedDates = []
                    draggedLane = nil

                    // 일정이 추가되었을 때만 새로고침
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🔵 [TimelineView] lastAddedEventDate: \(viewModel.lastAddedEventDate != nil ? "있음" : "nil")")

                        // 일정이 추가되었으면 데이터 새로고침 후 해당 날짜로 스크롤
                        if let addedDate = viewModel.lastAddedEventDate {
                            print("✅ [TimelineView] 드래그 일정 추가됨 - refreshData() 호출 후 스크롤")
                            refreshData()
                            scrollToDate(addedDate)
                            viewModel.lastAddedEventDate = nil // 초기화
                        } else {
                            print("✅ [TimelineView] 드래그 일정 취소됨 - 아무것도 하지 않음 (스크롤 위치 유지)")
                            // 취소한 경우 데이터 변경 없음 - refreshData() 호출 안 함
                        }
                    }
                }
            }
            .sheet(item: $selectedDateForTimeAnalysis) { dateWrapper in
                DayTimeAnalysisView(date: dateWrapper.date, viewModel: viewModel)
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if densityData.isEmpty {
                emptyStateView
            } else {
                // 인사이트 카드 (설정에서 제어)
                if showInsightCards {
                    if isInsightExpanded {
                        // 펼쳐진 상태: 인사이트 카드와 접기 버튼 표시
                        VStack(spacing: 0) {
                            // 접기 버튼
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isInsightExpanded = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.caption)
                                    Text("인사이트 접기")
                                        .font(.caption)
                                    Image(systemName: "chevron.up")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .background(Color(.systemGroupedBackground))

                            InsightCardsView(insights: viewModel.getWeekInsights())
                                .background(Color(.systemGroupedBackground))

                            Divider()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        // 접힌 상태: 펼칠 수 있는 버튼(헤더) 표시
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isInsightExpanded = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.caption)
                                Text("인사이트 보기")
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGroupedBackground))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                timelineScrollView
                Divider()
                selectedDayView
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                toastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 50)
            }
        }
    }

    private var toastView: some View {
        Text(toastMessage)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("로딩 중...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timelineScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    let allEvents = viewModel.assignLanesToEvents()
                    let maxLanes = 7

                    // 헤더: 레인 1~7
                    HStack(spacing: 0) {
                        // 왼쪽 날짜 공간
                        Text("날짜")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 50)
                            .foregroundColor(.secondary)

                        Divider()

                        // 레인 헤더
                        ForEach(1...maxLanes, id: \.self) { laneNumber in
                            Text("\(laneNumber)")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))

                    Divider()

                    // 날짜 행들
                    ForEach(densityData) { dayData in
                        DateRow(
                            dayData: dayData,
                            allEvents: allEvents,
                            maxLanes: maxLanes,
                            viewModel: viewModel,
                            allDensityData: densityData,
                            onEventTap: { event in
                                handleEventTap(event)
                            },
                            onEmptyCellTap: {
                                selectedDateForNewEvent = dayData.date
                                showingAddEventSheet = true
                            },
                            onDateLabelTap: {
                                handleDateLabelTap(dayData.date)
                            },
                            isDraggingSelection: isDraggingSelection,
                            draggedDates: draggedDates,
                            draggedLane: draggedLane,
                            onDragStart: { date, lane in
                                handleDragStart(date, lane: lane)
                            },
                            isToday: isToday(dayData.date),
                            isWeekend: isWeekend(dayData.date)
                        )
                        .id(dayData.id)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: isLoading) { _, newIsLoading in
                // 로딩이 완료되면 오늘로 스크롤
                if !newIsLoading && !hasScrolledToToday && !densityData.isEmpty {
                    scrollToTodayIfNeeded(proxy: proxy, data: densityData)
                }
            }
        }
    }

    private func scrollToTodayIfNeeded(proxy: ScrollViewProxy, data: [DayDensity]) {
        if !data.isEmpty && !hasScrolledToToday {
            if let todayData = data.first(where: { isToday($0.date) }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(todayData.id, anchor: .center)
                    }
                    hasScrolledToToday = true
                }
            }
        }
    }

    private func scrollToToday() {
        guard let proxy = scrollProxy else { return }
        if let todayData = densityData.first(where: { isToday($0.date) }) {
            withAnimation {
                proxy.scrollTo(todayData.id, anchor: .center)
            }
        }
    }

    private func scrollToDate(_ date: Date) {
        guard let proxy = scrollProxy else { return }

        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        if let targetData = densityData.first(where: { dayData in
            calendar.isDate(calendar.startOfDay(for: dayData.date), inSameDayAs: targetDate)
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(targetData.id, anchor: .center)
                }
            }
            print("📍 [TimelineView] Scrolling to added event date: \(monthDay(from: date))")
        }
    }

    @ViewBuilder
    private var selectedDayView: some View {
        if let selected = selectedDay {
            eventDetailsView(for: selected)
                .frame(height: 280)
        }
    }

    private func handleDayTap(_ dayData: DayDensity) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedDay?.id == dayData.id {
                selectedDay = nil
            } else {
                selectedDay = dayData
            }
        }
    }

    private func handleEventTap(_ event: Event) {
        // 이벤트를 수정하기 위해 eventToEdit 설정 후 수정 화면 열기
        viewModel.eventToEdit = event
        viewModel.showingAddEvent = true
    }

    private func handleDateLabelTap(_ date: Date) {
        // 날짜 레이블을 탭하면 시간 분석 화면 열기
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        selectedDateForTimeAnalysis = DateWrapper(date: normalizedDate)
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

    private func eventDetailsView(for dayData: DayDensity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(dayData.date))
                        .font(.headline)
                    Text("\(dayData.events.count)개 일정")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        selectedDay = nil
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
            if dayData.events.isEmpty {
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
                List {
                    ForEach(dayData.events) { event in
                        EventListCard(event: event)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
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
        return weekday == 1 || weekday == 7
    }

    private func deleteEvent(_ event: Event) {
        viewModel.deleteEvent(event)
        refreshData()
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }

        // 2초 후 토스트 숨기기
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showToast = false
            }
        }
    }

    private func refreshData() {
        print("🔄 [TimelineView] refreshData() 시작 - isLoading = true")
        isLoading = true

        // 비동기로 데이터 로드
        DispatchQueue.main.async {
            print("🔄 [TimelineView] 데이터 로드 중...")
            densityData = viewModel.getAllDensityData()
            print("🔄 [TimelineView] 데이터 로드 완료 - isLoading = false")
            isLoading = false
        }
    }

    // 드래그 핸들러
    private func handleDragStart(_ date: Date, lane: Int) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        // 롱 프레스 시 햅틱
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if dragStartDate == nil {
            // 첫 번째 롱프레스: 시작 지점 설정
            isDraggingSelection = true
            dragStartDate = normalizedDate
            dragEndDate = nil
            draggedLane = lane
            draggedDates = [normalizedDate]

            // 토스트 메시지 표시
            showToastMessage("종료일을 꾹 눌러주세요")
        } else if let startDate = dragStartDate, draggedLane == lane {
            // 두 번째 롱프레스 (같은 레인): 종료 지점 설정
            let normalizedStartDate = calendar.startOfDay(for: startDate)

            // 시작일과 종료일을 날짜 순서대로 정렬
            let earlierDate = min(normalizedStartDate, normalizedDate)
            let laterDate = max(normalizedStartDate, normalizedDate)

            dragStartDate = earlierDate
            dragEndDate = laterDate

            // 범위 내 모든 날짜 계산
            var allDates: Set<Date> = []
            var currentDate = earlierDate
            while currentDate <= laterDate {
                allDates.insert(currentDate)
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }
            draggedDates = allDates

            // 범위 선택 완료 - sheet 열기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingAddEventSheet = true
            }
        } else {
            // 다른 레인을 선택한 경우: 선택 초기화하고 새로 시작
            dragStartDate = normalizedDate
            dragEndDate = nil
            draggedLane = lane
            draggedDates = [normalizedDate]
        }
    }

}

// 날짜 행 (행: 날짜, 열: 레인 1~7)
struct DateRow: View {
    let dayData: DayDensity
    let allEvents: [Event]
    let maxLanes: Int
    let viewModel: ScheduleViewModel
    let allDensityData: [DayDensity]
    let onEventTap: (Event) -> Void  // 이벤트를 받도록 변경
    let onEmptyCellTap: () -> Void
    let onDateLabelTap: () -> Void  // 날짜 레이블 탭
    let isDraggingSelection: Bool
    let draggedDates: Set<Date>
    let draggedLane: Int?
    let onDragStart: (Date, Int) -> Void
    let isToday: Bool
    let isWeekend: Bool

    var body: some View {
        HStack(spacing: 0) {
            // 왼쪽: 날짜 레이블
            VStack(alignment: .trailing, spacing: 1) {
                Text(monthDay(from: dayData.date))
                    .font(.system(size: 11, weight: isToday ? .bold : .semibold))
                    .foregroundColor(isToday ? .blue : .primary)
                Text(weekday(from: dayData.date))
                    .font(.system(size: 9))
                    .foregroundColor(isWeekend ? .red : .secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 2)
            .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                onDateLabelTap()
            }

            Divider()

            // 오른쪽: 레인 1~7 셀들
            ForEach(1...maxLanes, id: \.self) { laneNumber in
                let event = getEventForLane(laneNumber: laneNumber)
                let isActive = event != nil
                // 이 셀이 드래그 선택되었는지: 날짜가 선택되었고 && 레인이 일치해야 함
                let isDraggedCell = draggedDates.contains(Calendar.current.startOfDay(for: dayData.date)) &&
                                    draggedLane == laneNumber

                GridCell(
                    dayData: dayData,
                    event: event,
                    isActive: isActive,
                    isToday: isToday,
                    laneNumber: laneNumber,
                    viewModel: viewModel,
                    allDensityData: allDensityData,
                    onTap: {
                        // event가 있을 때만 onEventTap 호출
                        if let event = event {
                            onEventTap(event)
                        }
                    },
                    onEmptyCellTap: onEmptyCellTap,
                    isDraggingSelection: isDraggingSelection,
                    isDraggedDate: isDraggedCell,
                    onDragStart: { onDragStart(dayData.date, laneNumber) },
                    onDelete: {
                        // 부모 뷰에게 새로고침 요청
                        viewModel.dataRefreshTrigger = UUID()
                    }
                )
                .frame(width: 40, height: 40)
            }
        }
        .background(Color(.systemBackground))

        Divider()
    }

    // 이 레인에 해당하는 일정 찾기
    private func getEventForLane(laneNumber: Int) -> Event? {
        let laneIndex = laneNumber - 1

        // 이 날짜에 활성화된 이벤트들 중에서
        // 해당 레인에 할당된 이벤트 찾기
        for event in dayData.events {
            if let assignedLane = viewModel.eventLaneAssignments[event.color],
               assignedLane == laneIndex {
                return event
            }
        }

        return nil
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
}

// 그리드 셀
struct GridCell: View {
    let dayData: DayDensity
    let event: Event?
    let isActive: Bool
    let isToday: Bool
    let laneNumber: Int
    @Bindable var viewModel: ScheduleViewModel
    let allDensityData: [DayDensity]
    let onTap: () -> Void
    let onEmptyCellTap: () -> Void
    let isDraggingSelection: Bool
    let isDraggedDate: Bool
    let onDragStart: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            // 배경
            Rectangle()
                .fill(isToday ? Color.blue.opacity(0.05) : Color(.systemGray6))

            // 드래그 선택 하이라이트 (빈 셀에만)
            if !isActive && isDraggedDate {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
            }

            // 일정 색상 (레인별 무지개 색상 + 같은 레인 내 변형)
            if isActive, let event = event {
                let calendar = Calendar.current
                let checkDate = calendar.startOfDay(for: dayData.date)
                let isStart = calendar.isDate(checkDate, inSameDayAs: event.startDate)
                let isEnd = calendar.isDate(checkDate, inSameDayAs: event.endDate)

                // 레인 번호에 따른 기본 색상
                let baseLaneColor = Color(hex: ScheduleViewModel.laneColors[laneNumber - 1]) ?? .blue

                // 같은 레인 내 이벤트 인덱스와 총 개수 가져오기
                let eventIndex = viewModel.eventIndexInLane[event.color] ?? 0
                let totalEventsInLane = viewModel.laneEventCounts[laneNumber - 1] ?? 1

                // 색상 변형 적용
                let variantColor = baseLaneColor.variant(index: eventIndex, totalVariants: totalEventsInLane)

                // 구멍에 들어간 일정인지 확인
                let isInGap = checkIfInGap(event: event, date: checkDate, lane: laneNumber - 1)

                EventLaneBlock(
                    isActive: true,
                    isStart: isStart,
                    isEnd: isEnd,
                    variantColor: variantColor,
                    isInGap: isInGap
                )
                .padding(2)
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(
                    !isActive && isDraggedDate ? Color.blue : Color(.separator),
                    lineWidth: !isActive && isDraggedDate ? 2 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // 더블탭: 빈 셀만, 날짜 범위 선택
            if !isActive {
                onDragStart()
            }
        }
        .onTapGesture {
            if isActive {
                onTap()
            } else {
                // 선택 모드가 아닐 때만 단일 날짜로 sheet 열기
                if !isDraggingSelection {
                    onEmptyCellTap()
                }
            }
        }
        .contextMenu {
            if isActive, let event = event {
                // 일정 수정
                Button(action: {
                    viewModel.eventToEdit = event
                    viewModel.showingAddEvent = true
                }) {
                    Label("일정 수정", systemImage: "pencil")
                }

                // 이 날짜만 제외
                Button(action: {
                    addExceptionForDate(event: event, date: dayData.date)
                }) {
                    Label("이 날짜만 제외", systemImage: "calendar.badge.minus")
                }

                Divider()

                // 전체 일정 삭제
                Button(role: .destructive, action: {
                    showDeleteAlert = true
                }) {
                    Label("전체 일정 삭제", systemImage: "trash")
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            if !isActive {
                // 빈 셀: 날짜 범위 선택
                onDragStart()
            }
        }
        .alert("일정 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                if let event = event {
                    viewModel.deleteEvent(event)
                    onDelete()
                }
            }
        } message: {
            if let event = event {
                Text("'\(event.title)' 일정을 전체 삭제하시겠습니까?")
            }
        }
    }

    // 해당 일정이 구멍에 들어간 일정인지 확인
    private func checkIfInGap(event: Event, date: Date, lane: Int) -> Bool {
        // 같은 레인의 모든 일정 가져오기
        let allEvents = viewModel.fetchEvents()
        let eventsInSameLane = allEvents.filter { otherEvent in
            guard let assignedLane = viewModel.eventLaneAssignments[otherEvent.color] else { return false }
            return assignedLane == lane
        }

        // 이 날짜에 같은 레인의 다른 일정도 활성화되어 있는지 확인
        for otherEvent in eventsInSameLane {
            // 자기 자신은 제외
            if otherEvent.color == event.color {
                continue
            }

            // 다른 일정도 이 날짜에 활성화되어 있으면 구멍에 들어간 것
            if otherEvent.occursOn(date: date) {
                return true
            }
        }

        return false
    }

    private func addExceptionForDate(event: Event, date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        // 이미 예외로 등록되어 있는지 확인
        if event.excludedDates.contains(normalizedDate) {
            return
        }

        // 예외 추가
        event.addExceptionDate(normalizedDate)

        // 저장 및 새로고침
        viewModel.updateEvent(event)

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

struct TimelineDayRow: View {
    let dayData: DayDensity
    let maxDensity: Int
    let allEvents: [Event]
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 오늘 표시 (왼쪽)
            if isToday {
                Text("오늘")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .cornerRadius(8)
            } else {
                // 오늘이 아닌 경우 빈 공간 유지 (정렬 맞추기)
                Color.clear
                    .frame(width: 36, height: 20)
            }

            // 날짜 레이블
            VStack(alignment: .trailing, spacing: 2) {
                Text(monthDay(from: dayData.date))
                    .font(.system(size: 15, weight: isToday ? .bold : .semibold))
                    .foregroundColor(isToday ? .blue : .primary)
                Text(weekday(from: dayData.date))
                    .font(.system(size: 12))
                    .foregroundColor(isWeekend(dayData.date) ? .red : .secondary)
            }
            .frame(width: 60, alignment: .trailing)

            // 막대 그래프 - Gantt 차트 스타일
            ZStack(alignment: .leading) {
                // 배경
                RoundedRectangle(cornerRadius: 6)
                    .fill(isToday ? Color.blue.opacity(0.1) : Color(.systemGray5))
                    .frame(height: 32)

                // 각 일정의 고정된 레인 유지 (기간 긴 순서로 왼쪽부터)
                // 항상 7개 레인 유지 (최대 일정 개수)
                GeometryReader { geometry in
                    let maxLanes = 7
                    let calendar = Calendar.current
                    let checkDate = calendar.startOfDay(for: dayData.date)
                    let activeEventColors = Set(dayData.events.map { $0.color })

                    HStack(spacing: 2) {
                        ForEach(0..<maxLanes, id: \.self) { index in
                            if index < allEvents.count {
                                let event = allEvents[index]
                                let isActive = activeEventColors.contains(event.color)
                                let isStart = isActive && calendar.isDate(checkDate, inSameDayAs: event.startDate)
                                let isEnd = isActive && calendar.isDate(checkDate, inSameDayAs: event.endDate)

                                EventLaneBlock(
                                    isActive: isActive,
                                    isStart: isStart,
                                    isEnd: isEnd,
                                    variantColor: Color(hex: event.color) ?? .blue,
                                    isInGap: false  // TimelineDayRow에서는 빗금 패턴 사용 안 함
                                )
                                .frame(maxWidth: .infinity)
                            } else {
                                // 빈 레인 (투명)
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
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
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
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

    private func isWeekend(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
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

struct EventLaneBlock: View {
    let isActive: Bool
    let isStart: Bool
    let isEnd: Bool
    let variantColor: Color
    let isInGap: Bool  // 구멍에 들어간 일정인지 여부

    var body: some View {
        ZStack {
            if isActive {
                let eventColor = variantColor
                // 시작/끝 칸은 진하게, 중간 칸은 연하게
                let opacity: Double = (isStart || isEnd) ? 1.0 : 0.65

                // 배경 색상
                if isStart && isEnd {
                    // 하루짜리 일정 - 진하게
                    RoundedRectangle(cornerRadius: 4)
                        .fill(eventColor.opacity(opacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                        )
                        .overlay(
                            // 구멍에 들어간 일정이면 빗금 패턴
                            isInGap ? DiagonalStripesPattern(color: .white.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 4)) : nil
                        )
                } else if isStart {
                    // 시작일: 위쪽만 둥근 - 진하게
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 4
                    )
                    .fill(eventColor.opacity(opacity))
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 4
                        )
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                    )
                    .overlay(
                        isInGap ? DiagonalStripesPattern(color: .white.opacity(0.6))
                            .clipShape(UnevenRoundedRectangle(
                                topLeadingRadius: 4,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 4
                            )) : nil
                    )
                } else if isEnd {
                    // 종료일: 아래쪽만 둥근 - 진하게
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 0
                    )
                    .fill(eventColor.opacity(opacity))
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 4,
                            bottomTrailingRadius: 4,
                            topTrailingRadius: 0
                        )
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                    )
                    .overlay(
                        isInGap ? DiagonalStripesPattern(color: .white.opacity(0.6))
                            .clipShape(UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 4,
                                bottomTrailingRadius: 4,
                                topTrailingRadius: 0
                            )) : nil
                    )
                } else {
                    // 중간일: 직사각형 - 연하게
                    Rectangle()
                        .fill(eventColor.opacity(opacity))
                        .overlay(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: 1.5)
                                Spacer()
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: 1.5)
                            }
                        )
                        .overlay(
                            isInGap ? DiagonalStripesPattern(color: .white.opacity(0.6)) : nil
                        )
                }
            }
        }
    }
}

// 대각선 빗금 패턴
struct DiagonalStripesPattern: View {
    let color: Color
    let spacing: CGFloat = 3  // 줄 간격 (더 촘촘하게)
    let lineWidth: CGFloat = 1.5  // 줄 두께

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                // 45도 대각선 빗금 (왼쪽 위에서 오른쪽 아래로)
                // 시작점을 왼쪽 위 코너에서 오른쪽으로 이동하며 그림
                var startX: CGFloat = -height

                while startX < width + height {
                    // 대각선 시작점
                    let x1 = startX
                    let y1: CGFloat = 0

                    // 대각선 끝점 (45도 각도)
                    let x2 = startX + height
                    let y2 = height

                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))

                    startX += spacing
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

// 날짜별 시간 분석 뷰
struct DayTimeAnalysisView: View {
    let date: Date
    @Bindable var viewModel: ScheduleViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 날짜 헤더
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDateFull(date))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(formatWeekday(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // 시간 사용량 요약
                    let events = getEventsForDate(date)
                    let totalHours = events.reduce(0.0) { $0 + $1.hoursPerDay }
                    let sleepHours = viewModel.sleepHoursPerDay
                    let awakeHours = 24.0 - sleepHours  // 깨어있는 시간
                    let freeHours = awakeHours - totalHours  // 진짜 자유시간 (음수 가능)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("일정 시간")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.1f시간", totalHours))
                                .font(.headline)
                                .foregroundColor(totalHours > 12 ? .red : .primary)
                        }

                        HStack {
                            Text("수면 시간")
                                .font(.subheadline)
                                .foregroundColor(.indigo)
                            Spacer()
                            Text(String(format: "%.1f시간", sleepHours))
                                .font(.subheadline)
                                .foregroundColor(.indigo)
                        }

                        HStack {
                            Text("자유 시간")
                                .font(.subheadline)
                                .foregroundColor(freeHours < 0 ? .red : .secondary)
                            Spacer()
                            Text(String(format: "%.1f시간", freeHours))
                                .font(.subheadline)
                                .foregroundColor(freeHours < 0 ? .red : .secondary)
                            if freeHours < 0 {
                                Text("(과부하)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                            }
                        }

                        Divider()

                        HStack {
                            Text("깨어있는 시간")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                            Text(String(format: "%.1f시간", awakeHours))
                                .font(.headline)
                                .fontWeight(.bold)
                        }

                        // 시간 사용 바 (깨어있는 시간 기준)
                        // 고정 비율: 1시간당 30픽셀
                        let pixelsPerHour: CGFloat = 30.0

                        VStack(spacing: 8) {
                            // 자유시간 (양수일 때만 표시)
                            if freeHours > 0 {
                                let height = freeHours * pixelsPerHour

                                HStack(spacing: 8) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: height)
                                        .cornerRadius(4)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("자유시간")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f시간", freeHours))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }

                            // 이벤트들 (레인 번호 역순으로 표시: 7번→1번)
                            ForEach(events.indices.reversed(), id: \.self) { index in
                                let event = events[index]
                                let height = max(event.hoursPerDay * pixelsPerHour, 20)  // 최소 높이 20
                                let laneColor = getLaneColor(for: event)

                                HStack(spacing: 8) {
                                    Rectangle()
                                        .fill(laneColor)
                                        .frame(width: 50, height: height)
                                        .cornerRadius(4)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(.system(size: 14, weight: .medium))
                                        Text(String(format: "%.1f시간", event.hoursPerDay))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 일정 목록
                    if !events.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("일정 상세")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(events) { event in
                                let laneColor = getLaneColor(for: event)
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(laneColor)
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .font(.system(size: 15, weight: .medium))
                                        HStack(spacing: 8) {
                                            Text(String(format: "%.1f시간", event.hoursPerDay))
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                            Text("•")
                                                .foregroundColor(.secondary)
                                            Text("\(formatDateShort(event.startDate)) ~ \(formatDateShort(event.endDate))")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                            }
                        }
                        .padding(.vertical)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("시간 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func getEventsForDate(_ date: Date) -> [Event] {
        let allEvents = viewModel.fetchEvents()
        let filtered = allEvents.filter { $0.occursOn(date: date) }

        // 레인 번호로 정렬 (레인 번호가 낮을수록 먼저)
        return filtered.sorted { event1, event2 in
            let lane1 = viewModel.eventLaneAssignments[event1.color] ?? 999
            let lane2 = viewModel.eventLaneAssignments[event2.color] ?? 999
            return lane1 < lane2
        }
    }

    // 이벤트의 레인 색상 가져오기
    private func getLaneColor(for event: Event) -> Color {
        if let lane = viewModel.eventLaneAssignments[event.color],
           lane >= 0 && lane < ScheduleViewModel.laneColors.count {
            return Color(hex: ScheduleViewModel.laneColors[lane]) ?? .blue
        }
        return .blue
    }

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// DateWrapper for sheet(item:) - Identifiable wrapper around Date
struct DateWrapper: Identifiable {
    let id = UUID()
    let date: Date
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

    // 색상 믹스 기반 변형 함수
    // variantIndex: 같은 레인 내의 이벤트 인덱스 (0, 1, 2, ...)
    // totalVariants: 같은 레인 내의 총 이벤트 수
    func variant(index variantIndex: Int, totalVariants: Int) -> Color {
        // 변형이 필요 없는 경우 (단일 이벤트)
        if totalVariants <= 1 {
            return self
        }

        // UIColor로 변환하여 RGB 추출
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // 믹스 강도 계산 (0.0 ~ 0.5 범위)
        // 총 이벤트 수가 많을수록 각 단계의 차이를 크게
        let maxBlendFactor: CGFloat = totalVariants >= 4 ? 0.5 : 0.4

        // 인덱스에 따라 흰색 또는 검정색 믹스
        // 첫 번째 이벤트: 흰색 믹스 (밝게)
        // 중간 이벤트: 원색에 가깝게
        // 마지막 이벤트: 검정색 믹스 (어둡게)
        let midpoint = CGFloat(totalVariants - 1) / 2.0
        let position = CGFloat(variantIndex)

        var newRed: CGFloat
        var newGreen: CGFloat
        var newBlue: CGFloat

        if position <= midpoint {
            // 앞쪽 절반: 흰색 믹스 (tint)
            let blendFactor = (midpoint - position) / midpoint * maxBlendFactor
            newRed = red + (1.0 - red) * blendFactor
            newGreen = green + (1.0 - green) * blendFactor
            newBlue = blue + (1.0 - blue) * blendFactor
        } else {
            // 뒤쪽 절반: 검정색 믹스 (shade)
            let blendFactor = (position - midpoint) / (CGFloat(totalVariants - 1) - midpoint) * maxBlendFactor
            newRed = red * (1.0 - blendFactor)
            newGreen = green * (1.0 - blendFactor)
            newBlue = blue * (1.0 - blendFactor)
        }

        // 최종 색상이 너무 극단적이지 않도록 제한
        newRed = max(0.1, min(1.0, newRed))
        newGreen = max(0.1, min(1.0, newGreen))
        newBlue = max(0.1, min(1.0, newBlue))

        return Color(red: Double(newRed), green: Double(newGreen), blue: Double(newBlue), opacity: Double(alpha))
    }
}
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
