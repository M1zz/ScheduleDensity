//
//  TimelineDensityView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI
import SwiftData
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

    // 일정 빠른 보기(탭) 상태 — 수정은 길게 탭(컨텍스트 메뉴) 또는 보기 시트의 수정 버튼으로
    @State private var eventToView: Event?
    @State private var pendingEditEvent: Event?
    /// 보기 시트를 닫고 나서 단계를 적으러 갈 일정.
    @State private var pendingSplitEvent: Event?

    // 인사이트 설정 (UserDefaults에 저장)
    @AppStorage("showInsightCards") private var showInsightCards = false
    // 인사이트 카드 펼침 상태
    @State private var isInsightExpanded = false

    // 첫 진입 온보딩 — 꾹 눌러 네모를 만드는 법을 한 번만 직접 해보게 한다.
    @AppStorage(AppSettingsKey.hasSeenRainbowOnboarding) private var hasSeenRainbowOnboarding = false
    @State private var onboardingStep: RainbowOnboardingStep = .idle
    @State private var onboardingSpot: RainbowSpot?
    /// 뜻풀이 전체 화면에 보여줄, 방금 만든 줄. 취소했으면 nil이고 예시로 그린다.
    @State private var meaningEvent: Event?
    @State private var showingMeaning = false

    // 새로 그은 줄은 아직 덩어리다. 할 일로 가져가 단계로 쪼개야 손을 댈 수 있다.
    /// 쪼개기를 권할 일정. nil이면 권하는 중이 아니다.
    @State private var splitOfferEvent: Event?
    /// 온보딩이 끝난 뒤로 미뤄 둔 권유. (마무리 카드와 겹치지 않게)
    @State private var pendingSplitDate: Date?
    /// 단계를 적으러 열 할 일.
    @State private var todoToSplit: BacklogItem?

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
                            offerSplit(startingOn: addedDate)
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
            .onChange(of: hasSeenRainbowOnboarding) { _, seen in
                // 설정에서 '다시 보기'를 누르면 화면이 떠 있는 채로 플래그만 꺼진다.
                if !seen { startOnboardingIfNeeded() }
            }
            .sheet(isPresented: $showingAddEventSheet) {
                // 온보딩으로 연 시트라면, 무엇을 어떤 순서로 적는지 안내가 이어진다.
                let guided = onboardingStep == .filling
                if let startDate = dragStartDate, let endDate = dragEndDate {
                    AddEventView(viewModel: viewModel, initialStartDate: startDate,
                                 initialEndDate: endDate, showsFieldGuide: guided)
                } else if let selectedDate = selectedDateForNewEvent {
                    AddEventView(viewModel: viewModel, initialDate: selectedDate)
                }
            }
            .sheet(item: $eventToView, onDismiss: {
                // 보기 시트가 완전히 닫힌 뒤에 다음 시트를 열어야 겹침 없이 전환된다.
                if let event = pendingEditEvent {
                    pendingEditEvent = nil
                    viewModel.eventToEdit = event
                    viewModel.showingAddEvent = true
                } else if let event = pendingSplitEvent {
                    pendingSplitEvent = nil
                    todoToSplit = TodoEventBridge.shared.makeTodo(for: event)
                }
            }) { event in
                EventQuickLookView(event: event, viewModel: viewModel) {
                    pendingEditEvent = event
                    eventToView = nil
                } onSplit: {
                    pendingSplitEvent = event
                    eventToView = nil
                }
            }
            .onChange(of: showingAddEventSheet) { _, isShowing in
                if !isShowing {
                    // 만든 일정이 있으면 쪼개기를 권한다. 온보딩 중이면 마무리 카드 뒤로 미룬다.
                    if let added = viewModel.lastAddedEventDate {
                        if onboardingStep == .filling {
                            pendingSplitDate = added
                        } else {
                            offerSplit(startingOn: added)
                        }
                    }
                    // 온보딩으로 만든 일정이 닫혔다 → 마무리 카드
                    if onboardingStep == .filling {
                        // 아래 0.3초 핸들러가 지우기 전에 챙겨 둔다.
                        let createdDate = viewModel.lastAddedEventDate
                        onboardingSpot = nil
                        // 새로고침이 끝난 뒤에 띄운다 — 그래야 방금 만든 줄을 찾아 그릴 수 있다.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            meaningEvent = createdDate.flatMap { latestEvent(startingOn: $0) }
                            onboardingStep = .done
                            showingMeaning = true
                        }
                    }
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
        .overlay(alignment: .bottom) {
            if let event = splitOfferEvent {
                splitOfferBar(for: event)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // 뜻풀이는 격자 위가 아니라 전체 화면으로. 만드는 경험이 끝난 뒤에 온다.
        .fullScreenCover(isPresented: $showingMeaning, onDismiss: {
            advanceOnboarding(to: .idle)
        }) {
            RainbowMeaningView(event: meaningEvent,
                               accent: meaningAccent) { showingMeaning = false }
        }
        .sheet(item: $todoToSplit) { item in
            if let container = TodoEventBridge.shared.todoContainer {
                NavigationStack {
                    TodoDetailView(root: item)
                }
                .modelContainer(container)
            }
        }
        // 하이라이트할 칸이 스크롤을 따라 움직이므로, 칸이 올려보낸 위치를 그대로 받아 쓴다.
        .overlayPreferenceValue(SpotlightAnchorKey.self) { anchors in
            GeometryReader { geo in
                if onboardingStep.showsOverlay {
                    RainbowOnboardingOverlay(
                        step: onboardingStep,
                        // 여러 칸이 올라오면 하나로 합친다 — 방금 만든 줄 전체를 뚫어 보여주려고.
                        spotlight: geo.spotlightRect(anchors),
                        containerSize: geo.size,
                        onStart: { advanceOnboarding(to: .pressStart) },
                        onSkip: { advanceOnboarding(to: .idle) }
                    )
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: onboardingStep)
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
                            isWeekend: isWeekend(dayData.date),
                            spotlightLane: spotlightLane(for: dayData.date)
                        )
                        .id(dayData.id)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
                // 이 ScrollView는 로딩이 끝난 뒤에야 마운트되므로 (isLoading 분기),
                // onChange(isLoading)로는 첫 진입을 못 잡는다. 여기서 직접 오늘로 스크롤.
                scrollToTodayIfNeeded(proxy: proxy, data: densityData)
                startOnboardingIfNeeded()
            }
            .onChange(of: isLoading) { _, newIsLoading in
                // 로딩이 완료되면 오늘로 스크롤
                if !newIsLoading && !hasScrolledToToday && !densityData.isEmpty {
                    scrollToTodayIfNeeded(proxy: proxy, data: densityData)
                }
                if !newIsLoading { startOnboardingIfNeeded() }
            }
        }
    }

    private func scrollToTodayIfNeeded(proxy: ScrollViewProxy, data: [DayDensity]) {
        guard !data.isEmpty, !hasScrolledToToday,
              let todayData = data.first(where: { isToday($0.date) }) else { return }

        // 첫 진입: 애니메이션 없이 즉시 오늘을 화면 가운데로 (열리자마자 가운데에 보이도록)
        DispatchQueue.main.async {
            proxy.scrollTo(todayData.id, anchor: .center)
            hasScrolledToToday = true
        }
        // LazyVStack 레이아웃이 아직 잡히기 전이면 첫 scrollTo가 어긋날 수 있어 한 번 더 보정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            proxy.scrollTo(todayData.id, anchor: .center)
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
        // 탭 = 일정 보기. 수정은 길게 탭(컨텍스트 메뉴) 또는 보기 시트의 수정 버튼.
        eventToView = event
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
        // 첫 로드에만 로딩 화면을 쓴다. 데이터가 이미 있는데 isLoading을 켜면
        // ScrollView가 언마운트됐다 다시 붙으면서 스크롤 위치가 맨 위로 리셋된다
        // (CloudKit 원격 변경 갱신이 반복될 때마다 오늘 위치를 잃는 원인).
        print("🔄 [TimelineView] refreshData() 시작")
        if densityData.isEmpty {
            isLoading = true
        }

        // 비동기로 데이터 로드
        DispatchQueue.main.async {
            densityData = viewModel.getAllDensityData()
            print("🔄 [TimelineView] 데이터 로드 완료")
            isLoading = false
            // 홈·잠금 화면 위젯이 읽는 스냅샷도 같이 다시 굽는다.
            RainbowWidgetSync.refresh(from: viewModel)
        }
    }

    // MARK: - 첫 진입 온보딩

    // MARK: - 새 줄을 할 일로 가져가 쪼개기

    /// 이 날 시작하는 일정 중 가장 최근 것 = 방금 만든 것.
    private func latestEvent(startingOn date: Date) -> Event? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return viewModel.fetchEvents()
            .last { calendar.isDate($0.startDate, inSameDayAs: day) }
    }

    /// 방금 그은 줄을 할 일로 가져가 쪼개자고 권한다.
    /// 이미 이어진 할 일이 있으면(= 할 일에서 데드라인을 정해 그어진 줄) 권하지 않는다.
    private func offerSplit(startingOn date: Date) {
        guard let event = latestEvent(startingOn: date),
              event.todoToken == nil else { return }
        withAnimation { splitOfferEvent = event }
        // 계속 붙어 있으면 잔소리가 된다. 답하지 않으면 조용히 사라진다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if splitOfferEvent === event { withAnimation { splitOfferEvent = nil } }
        }
    }

    private func splitOfferBar(for event: Event) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("‘\(event.title)’, 아직 덩어리예요")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("할 일로 가져가 단계로 쪼개면 손댈 수 있는 크기가 됩니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button("쪼개기") {
                let item = TodoEventBridge.shared.makeTodo(for: event)
                withAnimation { splitOfferEvent = nil }
                todoToSplit = item
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .font(.subheadline)

            Button {
                withAnimation { splitOfferEvent = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    /// 뜻풀이 화면에 쓸 색 — 그 줄이 무지개에서 실제로 받은 레인 색.
    private var meaningAccent: Color {
        guard let event = meaningEvent,
              let lane = viewModel.eventLaneAssignments[event.laneKey],
              lane >= 0, lane < ScheduleViewModel.laneColors.count,
              let color = Color(hex: ScheduleViewModel.laneColors[lane]) else { return .accentColor }
        return color
    }

    /// 이 날짜 행에서 하이라이트할 레인. 없으면 nil.
    private func spotlightLane(for date: Date) -> Int? {
        guard onboardingStep.showsSpotlight, let spot = onboardingSpot else { return nil }
        return spot.covers(date) ? spot.lane : nil
    }

    /// 데이터가 다 올라온 뒤에 온보딩을 시작한다. 한 번 시작하면 다시는 안 뜬다.
    private func startOnboardingIfNeeded() {
        guard !hasSeenRainbowOnboarding, onboardingStep == .idle, !densityData.isEmpty else { return }
        // 오늘로 스크롤이 끝난 뒤에 띄워야 하이라이트가 화면 밖에서 시작하지 않는다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard !hasSeenRainbowOnboarding, onboardingStep == .idle else { return }
            hasSeenRainbowOnboarding = true
            onboardingSpot = findFreeSpot()
            withAnimation { onboardingStep = .intro }
        }
    }

    private func advanceOnboarding(to step: RainbowOnboardingStep) {
        withAnimation { onboardingStep = step }
        if step == .idle {
            onboardingSpot = nil
            // 마무리 카드를 닫고 나서야 쪼개기를 권한다. 두 개가 겹치면 둘 다 안 읽힌다.
            if let pending = pendingSplitDate {
                pendingSplitDate = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { offerSplit(startingOn: pending) }
            }
            // 중간에 그만두면 잡다 만 선택도 같이 치운다.
            if isDraggingSelection {
                isDraggingSelection = false
                dragStartDate = nil
                dragEndDate = nil
                draggedDates = []
                draggedLane = nil
            }
        }
    }

    /// 시작 칸으로 쓸 만한 빈 칸 찾기 — 오늘 행에서, 며칠 뒤까지 함께 비어 있는 레인.
    /// 이미 일정이 있는 칸을 가리키면 꾹 눌러도 네모가 안 만들어진다.
    private func findFreeSpot() -> RainbowSpot? {
        guard let startDay = densityData.first(where: { isToday($0.date) }) ?? densityData.first else { return nil }
        let endDay = dayData(daysAfter: startDay.date, days: onboardingSpanDays)

        for lane in 1...7 where isLaneFree(startDay, lane: lane) {
            if let endDay, !isLaneFree(endDay, lane: lane) { continue }
            return RainbowSpot(date: startDay.date, lane: lane)
        }
        // 오늘 줄이 꽉 찼다면 가장 오른쪽 줄이라도 가리킨다.
        return RainbowSpot(date: startDay.date, lane: 7)
    }

    /// 온보딩에서 만들어 보게 할 기간(일). 3일이면 네모가 눈에 보일 만큼은 길다.
    private var onboardingSpanDays: Int { 3 }

    /// 온보딩에서 가리킬 '끝나는 날'. 표에 없는 날짜는 가리켜도 하이라이트가 안 뜬다.
    private func onboardingEndDate(from date: Date) -> Date {
        dayData(daysAfter: date, days: onboardingSpanDays)?.date ?? densityData.last?.date ?? date
    }

    private func dayData(daysAfter date: Date, days: Int) -> DayDensity? {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
        return densityData.first { calendar.isDate($0.date, inSameDayAs: target) }
    }

    /// 이 날짜/레인 칸이 비어 있는지 (DateRow가 칸을 채우는 규칙과 같아야 한다).
    private func isLaneFree(_ dayData: DayDensity, lane: Int) -> Bool {
        let laneIndex = lane - 1
        for event in dayData.events where viewModel.eventLaneAssignments[event.laneKey] == laneIndex {
            return false
        }
        guard viewModel.fillSpanToEndDate else { return true }
        for event in dayData.spanEvents where viewModel.eventLaneAssignments[event.laneKey] == laneIndex {
            return false
        }
        return true
    }

    // 드래그 핸들러
    private func handleDragStart(_ date: Date, lane: Int) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        // 다 눌러서 잡혔다는 딱 소리. (누르는 동안의 진동은 GridCell이 낸다.)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // 온보딩 중이면, 어느 칸을 눌렀든 실제로 누른 칸을 기준으로 다음 지점을 가리킨다.
        if onboardingStep == .pressStart {
            onboardingSpot = RainbowSpot(date: onboardingEndDate(from: normalizedDate), lane: lane)
            withAnimation { onboardingStep = .pressEnd }
        } else if onboardingStep == .pressEnd {
            if dragStartDate != nil && draggedLane == lane {
                // 선택이 완성되어 곧 시트가 열린다. 오버레이는 비켜준다.
                withAnimation { onboardingStep = .filling }
            } else {
                // 다른 줄을 눌렀다 — 선택이 그 줄에서 새로 시작되므로 끝 지점도 다시 가리킨다.
                onboardingSpot = RainbowSpot(date: onboardingEndDate(from: normalizedDate), lane: lane)
            }
        }

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
    /// 첫 진입 온보딩이 이 행에서 가리키는 레인. 없으면 nil.
    var spotlightLane: Int? = nil

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
                let slot = getEventForLane(laneNumber: laneNumber)
                let event = slot?.event
                let isActive = event != nil
                // 이 셀이 드래그 선택되었는지: 날짜가 선택되었고 && 레인이 일치해야 함
                let isDraggedCell = draggedDates.contains(Calendar.current.startOfDay(for: dayData.date)) &&
                                    draggedLane == laneNumber

                GridCell(
                    dayData: dayData,
                    event: event,
                    isActive: isActive,
                    // 오늘 실제로 하는 날인지. 아니면 종료일까지 이어지는 구간이라 옅게 칠한다.
                    isOccurring: slot?.isOccurring ?? false,
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
                // 온보딩이 가리키는 칸이면 자기 위치를 오버레이로 올려보낸다.
                .spotlightAnchor(spotlightLane == laneNumber)
            }
        }
        .background(Color(.systemBackground))

        Divider()
    }

    // 이 레인에 해당하는 일정 찾기.
    // 실제로 하는 날이 먼저다 — 한 레인을 여러 일정이 번갈아 쓰는(gap filling) 경우,
    // 진한 칸이 옅은 칸에 밀리면 안 되기 때문.
    private func getEventForLane(laneNumber: Int) -> (event: Event, isOccurring: Bool)? {
        let laneIndex = laneNumber - 1

        // ① 이 날짜에 실제로 하는 일정 (진하게)
        for event in dayData.events {
            if let assignedLane = viewModel.eventLaneAssignments[event.laneKey],
               assignedLane == laneIndex {
                return (event, true)
            }
        }

        // ② 하는 날은 아니지만 종료일까지 기간 안인 일정 (옅게)
        guard viewModel.fillSpanToEndDate else { return nil }
        for event in dayData.spanEvents {
            if let assignedLane = viewModel.eventLaneAssignments[event.laneKey],
               assignedLane == laneIndex {
                return (event, false)
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
    /// 이 날짜에 실제로 하는 일인지. false면 종료일까지 이어지는 기간 칸(옅게).
    let isOccurring: Bool
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

    // 꾹 누르는 동안의 되먹임 — 테두리가 차오르고 진동이 같이 세진다.
    /// 이만큼 누르고 있어야 잡힌다. 테두리·진동·제스처가 모두 이 값을 쓴다.
    private static let longPressDuration: TimeInterval = 0.6
    /// 이 시간 안에 떼면 그냥 탭이다. 탭 한 번에 진동이 울리면 시끄럽다.
    private static let pressGrace: TimeInterval = 0.12
    @State private var pressProgress: CGFloat = 0
    @State private var pressTask: Task<Void, Never>?

    var body: some View {
        cellBody
        .overlay(
            Rectangle()
                .strokeBorder(
                    !isActive && isDraggedDate ? Color.blue : Color(.separator),
                    lineWidth: !isActive && isDraggedDate ? 2 : 0.5
                )
        )
        // 누르고 있는 동안 테두리가 한 바퀴 차오른다. 다 차는 순간이 곧 잡히는 순간이다.
        .overlay {
            if pressProgress > 0 {
                Rectangle()
                    .inset(by: 1.5)
                    .trim(from: 0, to: pressProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .allowsHitTesting(false)
            }
        }
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
        .onLongPressGesture(minimumDuration: Self.longPressDuration) {
            if !isActive {
                // 빈 셀: 날짜 범위 선택
                // 차오르던 진동을 끊는다. 잡혔다는 딱 소리는 handleDragStart가 낸다.
                pressTask?.cancel()
                pressTask = nil
                PressHaptics.shared.stop()
                pressProgress = 0
                onDragStart()
            }
        } onPressingChanged: { isPressing in
            // 일정이 든 칸은 컨텍스트 메뉴가 받는다. 되먹임은 빈 칸에서만.
            guard !isActive else { return }
            pressTask?.cancel()
            if isPressing {
                pressTask = Task { @MainActor in
                    // 탭인지 꾹인지 갈릴 때까지만 기다렸다가 시작한다.
                    try? await Task.sleep(for: .seconds(Self.pressGrace))
                    guard !Task.isCancelled else { return }
                    let remaining = Self.longPressDuration - Self.pressGrace
                    pressProgress = 0
                    withAnimation(.linear(duration: remaining)) { pressProgress = 1 }
                    PressHaptics.shared.begin(duration: remaining)
                }
            } else {
                pressTask = nil
                withAnimation(.easeOut(duration: 0.15)) { pressProgress = 0 }
                PressHaptics.shared.stop()
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

    /// 칸 안쪽 — 배경, 선택 표시, 일정 블록.
    /// (테두리·제스처와 한 덩어리로 두면 타입 체커가 감당을 못 한다.)
    private var cellBody: some View {
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
                let eventIndex = viewModel.eventIndexInLane[event.laneKey] ?? 0
                let totalEventsInLane = viewModel.laneEventCounts[laneNumber - 1] ?? 1

                // 색상 변형 적용
                let variantColor = baseLaneColor.variant(index: eventIndex, totalVariants: totalEventsInLane)

                if isOccurring {
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
                } else {
                    SpanFillBlock(
                        color: variantColor,
                        isStart: isStart,
                        isEnd: isEnd
                    )
                    .padding(2)
                }
            }
        }
    }

    // 해당 일정이 구멍에 들어간 일정인지 확인
    private func checkIfInGap(event: Event, date: Date, lane: Int) -> Bool {
        // 같은 레인의 모든 일정 가져오기
        let allEvents = viewModel.fetchEvents()
        let eventsInSameLane = allEvents.filter { otherEvent in
            guard let assignedLane = viewModel.eventLaneAssignments[otherEvent.laneKey] else { return false }
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

/// 종료일까지 이어지는 기간을 옅게 채우는 칸.
///
/// 주 1회 연습이라도 두 달 뒤 공연이면 그 두 달은 이 일에 매여 있다.
/// 그 사실이 무지개에서 통째로 비어 보이지 않도록 깔아 두되,
/// 실제로 하는 날(`EventLaneBlock`)보다 훨씬 옅게 해서 진한 칸이 먼저 읽히게 한다.
struct SpanFillBlock: View {
    let color: Color
    /// 기간의 첫 날 / 마지막 날이면 그 쪽만 둥글게 — 위아래로 한 덩어리처럼 이어 보이게.
    let isStart: Bool
    let isEnd: Bool

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: isStart ? 4 : 0,
            bottomLeadingRadius: isEnd ? 4 : 0,
            bottomTrailingRadius: isEnd ? 4 : 0,
            topTrailingRadius: isStart ? 4 : 0
        )
        .fill(color.opacity(0.20))
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

// 일정 빠른 보기 (칸 탭) — 수정 없이 내용만 확인, 수정은 버튼으로
struct EventQuickLookView: View {
    let event: Event
    @Bindable var viewModel: ScheduleViewModel
    let onEdit: () -> Void
    /// 이 줄을 할 일로 가져가 단계를 적으러 간다.
    let onSplit: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// 이어져 있는 할 일. 무지개 한 줄이 실제로 어디까지 갔는지는 그쪽이 안다.
    @State private var linkedTodo: BacklogItem?
    @State private var todoProgress: (done: Int, total: Int)?

    private var laneColor: Color {
        if let lane = viewModel.eventLaneAssignments[event.laneKey],
           lane >= 0 && lane < ScheduleViewModel.laneColors.count {
            return Color(hex: ScheduleViewModel.laneColors[lane]) ?? .blue
        }
        return .blue
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // 제목
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(laneColor)
                        .frame(width: 6, height: 34)
                    Text(event.title)
                        .font(.title3.weight(.semibold))
                    Spacer()
                }

                // 정보 행들
                VStack(spacing: 12) {
                    infoRow(icon: "calendar", label: "기간",
                            value: event.isInfinite
                            ? "\(formatDate(event.startDate)) ~ 무기한"
                            : "\(formatDate(event.startDate)) ~ \(formatDate(event.endDate))")
                    infoRow(icon: "clock", label: "하루 시간",
                            value: String(format: "%.1f시간", event.hoursPerDay))
                    infoRow(icon: "repeat", label: "요일", value: weekdaysText)
                    infoRow(icon: "exclamationmark.circle", label: "중요도",
                            value: event.importance.displayName)
                    infoRow(icon: "checklist", label: "할 일", value: todoText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                Text("칸을 길게 누르면 수정·삭제 메뉴가 바로 열립니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 10) {
                    Button(action: onSplit) {
                        Label(linkedTodo == nil ? "쪼개기" : "단계 보기",
                              systemImage: "arrow.triangle.branch")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onEdit) {
                        Label("수정", systemImage: "pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(laneColor)
                }
            }
            .task { loadLinkedTodo() }
            .padding()
            .navigationTitle("일정 보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// 이어진 할 일이 어디까지 갔는지 한 줄로. 아직 없으면 그렇다고 말한다.
    private var todoText: String {
        guard linkedTodo != nil else { return "아직 안 쪼갬" }
        guard let progress = todoProgress, progress.total > 0 else { return "단계 없음" }
        return "\(progress.total)단계 중 \(progress.done)단계 완료"
    }

    private func loadLinkedTodo() {
        let bridge = TodoEventBridge.shared
        guard let item = bridge.linkedTodo(for: event),
              let context = bridge.todoContainer?.mainContext else {
            linkedTodo = nil
            todoProgress = nil
            return
        }
        linkedTodo = item
        let all = (try? context.fetch(FetchDescriptor<BacklogItem>())) ?? []
        let tree = TodoTree(all)
        let steps = tree.children(of: item)
        todoProgress = (done: steps.filter(\.isCompleted).count, total: steps.count)
    }

    private var weekdaysText: String {
        if event.weeklyPattern != nil { return "맞춤 패턴" }
        guard let days = event.selectedWeekdays, !days.isEmpty, days.count < 7 else { return "매일" }
        let labels = ["", "일", "월", "화", "수", "목", "금", "토"]
        return days.sorted().compactMap { $0 >= 1 && $0 <= 7 ? labels[$0] : nil }.joined(separator: "·")
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.M.d"
        return formatter.string(from: date)
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
                        // 비율만 읽히면 되므로 스케일을 낮춰 전체 스택을 짧게 유지한다 (1시간당 10픽셀)
                        let pixelsPerHour: CGFloat = 10.0

                        VStack(spacing: 8) {
                            // 자유시간 (양수일 때만 표시)
                            if freeHours > 0 {
                                let height = max(freeHours * pixelsPerHour, 16)

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
                                let height = max(event.hoursPerDay * pixelsPerHour, 16)  // 최소 높이 16 (텍스트 가독용)
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
            let lane1 = viewModel.eventLaneAssignments[event1.laneKey] ?? 999
            let lane2 = viewModel.eventLaneAssignments[event2.laneKey] ?? 999
            return lane1 < lane2
        }
    }

    // 이벤트의 레인 색상 가져오기
    private func getLaneColor(for event: Event) -> Color {
        if let lane = viewModel.eventLaneAssignments[event.laneKey],
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

// Color(hex:)는 공용 Theme.swift에 있다.
extension Color {
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
                        .frame(width: geometry.size.width * CGFloat(min(1.0, insight.occupancyRate)))
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

    /// 색의 기준은 '얼마나 찼나'가 아니라 '80% 선을 넘었나'다 (→ LoadLevel).
    private var densityColor: Color {
        switch insight.level {
        case .easy:   return .green
        case .normal: return .blue
        case .tight:  return .orange
        case .over:   return .red
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
                        .frame(width: geometry.size.width * CGFloat(min(1.0, insight.occupancyRate)))
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

    /// 색의 기준은 '얼마나 찼나'가 아니라 '80% 선을 넘었나'다 (→ LoadLevel).
    private var densityColor: Color {
        switch insight.level {
        case .easy:   return .green
        case .normal: return .blue
        case .tight:  return .orange
        case .over:   return .red
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

            Text("여유가 가장 많은 날")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(dateString)
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                Label("\(insight.eventCount)개", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 잡힌 시간이 아니라 **남은 여유**를 적는다.
                // '가장 한가한 날'이라고만 적어 두면 다음에 할 일이 그리로 간다.
                // 여유는 메울 구멍이 아니라 지킬 자산이다 (→ LoadLevel).
                Label(String(format: "%.1fh 여유", insight.slackHours), systemImage: "leaf")
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
