//
//  DensityIntents.swift
//  ScheduleDensityApp
//
//  "욕망의 무지개, 이번 주 제일 빽빽한 날 언제야?" — 앞으로 7일 중 일정이 가장 겹치는 날을 알려 준다.
//  주간 밀도 화면과 같은 계산(DensityCalculator)을 쓴다.
//
//  할 일도 Siri · Spotlight 가 알아보게 한다 — 아직 안 끝낸 최상위 할 일을 색인하고,
//  누르면 '할 일' 탭에서 그 할 일의 상세가 열린다.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

struct BusiestDayIntent: AppIntent {
    static let title = LocalizedStringResource("가장 빽빽한 날", comment: "Siri: the busiest day of the coming week")
    static let description = IntentDescription(
        LocalizedStringResource("앞으로 7일 중 일정이 가장 겹치는 날을 알려 줍니다.", comment: "Siri: busiest day description")
    )

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: today) else { return .result(dialog: "") }
        let events = (try? ModelContext(container).fetch(FetchDescriptor<Event>())) ?? []
        let week = DensityCalculator.calculateRangeDensity(from: today, to: weekEnd, events: events)
        guard let busiest = week.max(by: { $0.density < $1.density }), busiest.density > 0 else {
            return .result(dialog: IntentDialog(LocalizedStringResource("앞으로 7일은 비어 있어요.", comment: "Siri: nothing scheduled this week")))
        }
        let day = busiest.date.formatted(.dateTime.month().day().weekday(.wide))
        return .result(dialog: IntentDialog(LocalizedStringResource("가장 빽빽한 날은 \(day)이에요. 일정 \(busiest.density)개가 겹쳐요.", comment: "Siri: busiest day. Arguments: date, number of overlapping events")))
    }
}

// MARK: - 할 일

/// 할 일 저장소. 일정 저장소와 같은 타입(ModelContainer)이라 감싸서 따로 넘긴다.
struct TodoStore: Sendable {
    let container: ModelContainer
}

/// Siri · Spotlight 에서 열어 달라는 할 일. TodoView 가 상세를 열고 비운다.
@MainActor @Observable
final class TodoRouter {
    static let shared = TodoRouter()
    /// 열 할 일의 dragToken.
    var token: String?
}

struct TodoEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("할 일", comment: "Siri/Spotlight: one to-do item")
    )
    static let defaultQuery = TodoQuery()

    /// dragToken — 기기와 맥 사이에서도 바뀌지 않는 문자열이다.
    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(_ item: BacklogItem) {
        id = item.dragToken
        title = item.title
    }
}

@available(iOS 18.0, *)
extension TodoEntity: IndexedEntity {}

struct TodoQuery: EntityStringQuery {
    @Dependency private var store: TodoStore

    func entities(for identifiers: [String]) async throws -> [TodoEntity] {
        let wanted = Set(identifiers)
        return TodoLibrary.all(in: store.container).filter { wanted.contains($0.dragToken) }.map(TodoEntity.init)
    }

    func entities(matching string: String) async throws -> [TodoEntity] {
        TodoLibrary.open(in: store.container)
            .filter { $0.title.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            .map(TodoEntity.init)
    }

    func suggestedEntities() async throws -> [TodoEntity] {
        TodoLibrary.open(in: store.container).prefix(20).map(TodoEntity.init)
    }
}

/// 할 일을 연다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenTodoIntent: OpenIntent {
    static let title = LocalizedStringResource("할 일 열기", comment: "Siri/Spotlight: open a to-do")
    static let description = IntentDescription(
        LocalizedStringResource("할 일을 열어 단계와 걸리는 시간을 봅니다.", comment: "Siri: open to-do description")
    )

    @Parameter(title: LocalizedStringResource("할 일", comment: "Siri/Spotlight: one to-do item"),
               description: LocalizedStringResource("열어 볼 할 일", comment: "Siri: to-do parameter description"))
    var target: TodoEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        TodoRouter.shared.token = target.id
        return .result()
    }
}

enum TodoLibrary {
    static func all(in container: ModelContainer) -> [BacklogItem] {
        let descriptor = FetchDescriptor<BacklogItem>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return (try? ModelContext(container).fetch(descriptor)) ?? []
    }

    /// 아직 안 끝낸 최상위 할 일 (단계는 빼고).
    static func open(in container: ModelContainer) -> [BacklogItem] {
        all(in: container).filter { $0.parentToken == nil && !$0.isCompleted && !$0.title.isEmpty }
    }

    /// Spotlight 에 싣는 할 일을 지금 것에 맞춘다. 앱을 열 때와 뒤로 보낼 때 부른다.
    static func reindex(_ container: ModelContainer) async {
        guard #available(iOS 18.0, *) else { return }
        let entities = open(in: container).map(TodoEntity.init)
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: TodoEntity.self)
        try? await index.indexAppEntities(entities)
    }
}

// MARK: - Siri 문구

struct ScheduleDensityShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BusiestDayIntent(),
            phrases: ["What’s my busiest day in \(.applicationName)", "\(.applicationName) busiest day"],
            shortTitle: "Busiest Day",
            systemImageName: "chart.bar.fill"
        )
    }
}
