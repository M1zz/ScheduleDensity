import Foundation
import SwiftData
import WidgetKit

/// SwiftData의 할 일을 위젯용 스냅샷으로 굽고 타임라인을 갱신한다.
///
/// 호출 지점은 TodoView 한 곳으로 모아둔다 — 할 일을 추가/토글/삭제한 직후,
/// 그리고 화면이 나타나거나 앱이 포그라운드로 돌아올 때(맥에서 CloudKit으로 넘어온
/// 변경을 반영하기 위해).
enum TodoWidgetSync {
    /// ⚠️ @Query 배열이 아니라 context에서 직접 fetch한다.
    /// `context.delete(...)` 직후에는 @Query가 아직 갱신되지 않아 이미 지운 항목이
    /// 스냅샷에 남을 수 있다. 저장이 끝난 context를 다시 읽으면 항상 현재 상태다.
    @MainActor
    static func refresh(context: ModelContext) {
        do {
            // 정렬은 TodoView의 @Query와 같게 맞춘다 — 위젯과 앱의 순서가 달라지면 헷갈린다.
            let items = try context.fetch(FetchDescriptor<BacklogItem>(
                sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]))
            let categories = try context.fetch(FetchDescriptor<BacklogCategory>(
                sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]))
            let snapshot = makeSnapshot(items: items,
                                        categories: categories,
                                        assignedToday: WeekBlocksStore.shared.titlesAssigned())
            TodoWidgetBridge.write(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: TodoWidgetBridge.widgetKind)
        } catch {
            print("⚠️ [Widget] 할 일 조회 실패, 스냅샷 갱신 생략: \(error)")
        }
    }

    /// 순수 함수 — TodoView의 필터 규칙(이번 주 / 지난 주 잔여)과 같은 기준을 쓴다.
    /// `assignedToday`는 오늘 계획 블록으로 올라간 할 일 제목들.
    static func makeSnapshot(items: [BacklogItem],
                             categories: [BacklogCategory],
                             assignedToday: Set<String> = [],
                             now: Date = Date()) -> TodoWidgetSnapshot
    {
        let cal = Calendar(identifier: .iso8601)
        let weekStart = now.weekStart()
        let categoryByID = Dictionary(categories.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })

        let thisWeek = items.filter {
            !$0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart)
        }
        let carryover = items.filter {
            !$0.isCompleted && $0.weekStartDate < weekStart && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart)
        }

        // 급한 순서로 위에서부터: 오늘 배정한 일 → 지난 주에 밀린 일 → 나머지 이번 주.
        // 위젯이 작을수록 위쪽 몇 개만 보이므로 순서가 곧 우선순위다.
        let open = carryover.map { ($0, true) } + thisWeek.map { ($0, false) }
        // Swift의 sorted는 안정 정렬이 아니므로, 동순위에서 원래 순서(sortIndex 기준 fetch 결과)가
        // 유지되도록 인덱스를 마지막 기준으로 넣는다.
        let ordered = open.enumerated()
            .sorted { lhs, rhs in
                let lRank = rank(item: lhs.element.0, isCarryover: lhs.element.1, assignedToday: assignedToday)
                let rRank = rank(item: rhs.element.0, isCarryover: rhs.element.1, assignedToday: assignedToday)
                if lRank != rRank { return lRank < rRank }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        let widgetItems = ordered.prefix(TodoWidgetSnapshot.maxItems).map { item, isCarryover in
            let category = item.categoryID.flatMap { categoryByID[$0] }
            return TodoWidgetSnapshot.Item(
                id: item.dragToken,
                title: item.title,
                colorHex: category.flatMap { paletteHex($0.colorName) },
                categoryName: category?.name,
                isCarryover: isCarryover,
                isToday: assignedToday.contains(item.title)
            )
        }

        return TodoWidgetSnapshot(
            items: Array(widgetItems),
            openCount: open.count,
            updatedAt: now
        )
    }

    /// 위젯 목록에서의 우선순위. 낮을수록 위.
    private static func rank(item: BacklogItem, isCarryover: Bool, assignedToday: Set<String>) -> Int {
        if assignedToday.contains(item.title) { return 0 }   // 오늘 하기로 한 일
        if isCarryover { return 1 }                          // 지난 주에 밀린 일
        return 2                                             // 나머지 이번 주
    }
}
