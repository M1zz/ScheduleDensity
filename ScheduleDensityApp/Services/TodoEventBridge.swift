//
//  TodoEventBridge.swift
//  ScheduleDensityApp
//
//  할 일과 무지개를 잇는 다리.
//
//  할 일에 한 줄 적으면 그건 단발성 심부름처럼 보인다. 하지만 "언제까지"가 붙는 순간
//  그건 오늘부터 그 날까지 계속 나를 붙잡고 있는 일이 된다. 그 매여 있음을 눈으로 보려고
//  무지개가 있는 것이므로, 데드라인을 정하면 오늘부터 그 날까지 한 줄이 그어져야 한다.
//
//  반대 방향도 같다. 무지개에 줄 하나가 새로 생기면 그건 아직 덩어리진 채다.
//  할 일로 가져가 단계로 쪼개야 실제로 손을 댈 수 있다.
//
//  ⚠️ 두 스토어는 완전히 분리돼 있다 (일정=로컬 전용, 할 일=맥앱과 공유하는 CloudKit).
//     그래서 연결 고리는 일정 쪽에만 둔다 — Event.todoToken → BacklogItem.dragToken.
//     맥앱과 공유하는 할 일 스키마는 건드리지 않는다.
//

import Foundation
import SwiftData

@MainActor
final class TodoEventBridge {
    static let shared = TodoEventBridge()

    /// 일정 쪽은 뷰모델을 거친다. CloudKit 증분 동기화·화면 갱신이 전부 여기 붙어 있어서,
    /// 컨텍스트에 직접 넣으면 무지개가 갱신되지 않는다.
    private weak var schedule: ScheduleViewModel?
    /// 할 일 쪽은 별도 컨테이너(맥앱과 공유하는 CloudKit 스토어).
    private(set) var todoContainer: ModelContainer?
    /// 일정 스토어. 읽기는 여기서 직접 한다 —
    /// 뷰모델의 fetchEvents는 맥에서 비춰 온 읽기 전용 미러까지 섞어 주기 때문.
    private(set) var eventContainer: ModelContainer?

    private init() {}

    func attach(schedule: ScheduleViewModel) {
        self.schedule = schedule
    }

    func attach(todoContainer: ModelContainer) {
        self.todoContainer = todoContainer
    }

    func attach(eventContainer: ModelContainer) {
        self.eventContainer = eventContainer
    }

    private var todoContext: ModelContext? { todoContainer?.mainContext }

    // MARK: - 할 일 → 무지개

    /// 오늘부터 데드라인까지 무지개에 한 줄을 긋는다. (시작일을 안 정했을 때)
    @discardableResult
    func drawRainbow(for item: BacklogItem, deadline: Date, hours: Double) -> Bool {
        drawRainbow(for: item, from: Date(), to: deadline, hours: hours)
    }

    /// 시작일부터 종료일까지 무지개에 한 줄을 긋는다.
    /// 이미 그어져 있으면 그 줄의 날짜만 고쳐서, 줄이 두 개로 늘어나지 않게 한다.
    @discardableResult
    func drawRainbow(for item: BacklogItem, from startDate: Date, to endDate: Date, hours: Double) -> Bool {
        guard let schedule else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: startDate)
        let end = max(today, calendar.startOfDay(for: endDate))

        let workDays = workDayRule(from: today, to: end)

        if let existing = event(for: item) {
            existing.title = item.title
            existing.startDate = today
            existing.endDate = end
            existing.hoursPerDay = max(0.5, hours)
            existing.weeklyPattern = workDays.pattern
            existing.selectedWeekdays = workDays.weekdays
            schedule.updateEvent(existing)
            return true
        }

        let event = Event(
            title: item.title,
            startDate: today,
            endDate: end,
            color: UUID().uuidString,   // 실제 색은 배정된 레인이 정한다.
            hoursPerDay: max(0.5, hours),
            // 오늘부터 마감까지 통째로 매여 있고(옅은 칸), 실제로 손대는 날은 아래 규칙대로.
            // 짐작일 뿐이므로 칸을 눌러 언제든 고칠 수 있다.
            selectedWeekdays: workDays.weekdays,
            weeklyPattern: workDays.pattern,
            importance: .medium
        )
        event.todoToken = item.dragToken
        schedule.addEvent(event)
        return true
    }

    /// 마감이 붙은 일에서 '실제로 시간 쓰는 날'을 어떻게 잡을지.
    ///
    /// 할 일에 붙는 마감은 대개 그 날 한 번에 끝내는 일이지, 매주 돌아오는 일이 아니다.
    /// 그런데 마감 요일로 반복을 걸면 기간 한가운데에 뜬금없이 진한 칸이 생겨서
    /// "이 날은 왜 진하지?"가 된다. 그래서 35일 주기 패턴에 **마감 하루만** 켜 둔다.
    ///
    /// 35일을 넘는 먼 마감은 그 패턴이 다시 돌아오므로, 그럴 때만 마감 요일 반복으로 둔다.
    /// (다섯 주 넘게 걸리는 일이라면 실제로도 여러 날 손을 대야 한다.)
    private func workDayRule(from start: Date, to end: Date) -> (pattern: [Bool]?, weekdays: [Int]?) {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard days >= 0, days < 35 else {
            return (nil, [calendar.component(.weekday, from: end)])
        }
        var pattern = [Bool](repeating: false, count: 35)
        pattern[days] = true
        return (pattern, nil)
    }

    /// 이 할 일에 걸린 데드라인(= 이어진 줄의 종료일).
    func deadline(for item: BacklogItem) -> Date? {
        event(for: item)?.endDate
    }

    /// 이 할 일이 무지개에서 차지하고 있는 기간.
    func period(for item: BacklogItem) -> (start: Date, end: Date)? {
        guard let event = event(for: item) else { return nil }
        return (event.startDate, event.endDate)
    }

    /// 지금 걸려 있는 데드라인을 토큰별로 한 번에 읽는다. 목록에서 줄마다 훑지 않으려고.
    func deadlinesByToken() -> [String: Date] {
        var result: [String: Date] = [:]
        for event in storedEvents() {
            if let token = event.todoToken { result[token] = event.endDate }
        }
        return result
    }

    /// 무지개에는 그어져 있는데 아직 할 일로 안 가져온 일들 — 그중 이번 주에 걸친 것만.
    ///
    /// 다음 달에 끝나는 일까지 전부 이번 주 할 일에 세우면 목록이 일정표가 된다.
    /// 이번 주와 겹치는 것만이 지금 손을 대야 하는 일이다.
    func pendingFromRainbow(weekStart: Date) -> [Event] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: weekStart)
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else { return [] }
        return storedEvents()
            .filter { event in
                event.todoToken == nil
                    && calendar.startOfDay(for: event.startDate) <= end
                    && calendar.startOfDay(for: event.effectiveEndDate()) >= start
            }
            // 급한 것부터. 목록 맨 위를 차지하는 자리라 순서가 곧 우선순위로 읽힌다.
            .sorted { $0.effectiveEndDate() < $1.effectiveEndDate() }
    }

    /// 데드라인을 지우면 그어 둔 줄도 같이 지운다. 할 일을 지울 때도 이걸 쓴다.
    func clearRainbow(for item: BacklogItem) {
        guard let schedule, let event = event(for: item) else { return }
        schedule.deleteEvent(event)
    }

    /// 할 일 제목을 고치면 무지개에 그어 둔 줄의 이름도 따라간다.
    func renameRainbow(for item: BacklogItem) {
        guard let schedule, let event = event(for: item), event.title != item.title else { return }
        event.title = item.title
        schedule.updateEvent(event)
    }

    // MARK: - 무지개 → 할 일

    /// 이 줄에 이어진 할 일.
    func linkedTodo(for event: Event) -> BacklogItem? {
        guard let token = event.todoToken else { return nil }
        return todo(withToken: token)
    }

    /// 무지개에 그은 줄을 할 일로 가져온다. 이미 가져왔으면 그것을 그대로 돌려준다.
    /// 여기서 만든 할 일을 단계로 쪼개면, 덩어리진 일정이 실제로 손댈 수 있는 크기가 된다.
    @discardableResult
    func makeTodo(for event: Event) -> BacklogItem? {
        if let existing = linkedTodo(for: event) { return existing }
        guard let todoContext, let schedule else { return nil }

        let descriptor = FetchDescriptor<BacklogItem>()
        let maxIndex = (try? todoContext.fetch(descriptor))?.map(\.sortIndex).max() ?? -1

        let item = BacklogItem(title: event.title,
                               durationHours: max(0.5, event.hoursPerDay),
                               sortIndex: maxIndex + 1,
                               weekStartDate: Date.currentWeekStart,
                               label: .ready)
        todoContext.insert(item)
        try? todoContext.save()

        event.todoToken = item.dragToken
        schedule.updateEvent(event)
        return item
    }

    // MARK: - 내부

    /// 이 앱에 저장된 일정만. (맥에서 비춰 온 미러는 읽기 전용이라 여기 끼면 안 된다.)
    private func storedEvents() -> [Event] {
        guard let context = eventContainer?.mainContext else { return [] }
        let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.startDate)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func event(for item: BacklogItem) -> Event? {
        storedEvents().first { $0.todoToken == item.dragToken }
    }

    private func todo(withToken token: String) -> BacklogItem? {
        guard let todoContext else { return nil }
        let descriptor = FetchDescriptor<BacklogItem>(
            predicate: #Predicate { $0.dragToken == token }
        )
        return (try? todoContext.fetch(descriptor))?.first
    }
}
