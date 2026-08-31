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
            WidgetCenter.shared.reloadTimelines(ofKind: TodoWidgetBridge.fragmentWidgetKind)
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

        // 위젯도 최상위 할 일만 줄로 세운다. 단계는 그 줄 안에서 '지금 할 일'로 보여준다.
        let tree = TodoTree(items)
        let thisWeek = tree.roots.filter {
            !$0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart)
        }
        let carryover = tree.roots.filter {
            !$0.isCompleted && $0.weekStartDate < weekStart && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart)
        }

        // 급한 순서로 위에서부터: 오늘 배정한 일 → 지난 주에 밀린 일 → 나머지 이번 주.
        // 위젯이 작을수록 위쪽 몇 개만 보이므로 순서가 곧 우선순위다.
        let open = carryover.map { ($0, true) } + thisWeek.map { ($0, false) }
        // Swift의 sorted는 안정 정렬이 아니므로, 동순위에서 원래 순서(sortIndex 기준 fetch 결과)가
        // 유지되도록 인덱스를 마지막 기준으로 넣는다.
        let ordered = open.enumerated()
            .sorted { lhs, rhs in
                let lRank = rank(item: lhs.element.0, isCarryover: lhs.element.1,
                                 assignedToday: assignedToday, tree: tree)
                let rRank = rank(item: rhs.element.0, isCarryover: rhs.element.1,
                                 assignedToday: assignedToday, tree: tree)
                if lRank != rRank { return lRank < rRank }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        let widgetItems = ordered.prefix(TodoWidgetSnapshot.maxItems).map { item, isCarryover in
            let category = item.categoryID.flatMap { categoryByID[$0] }
            // 잠금 화면에서 5분을 집으려면 판정이 거기 이미 있어야 한다.
            // 표시해 둔 단계가 있으면 차례를 건너뛰고 그것을 세운다(앱 목록과 같은 규칙),
            // 없으면 '지금 할 단계'가 곧 지금 할 일이다.
            let step = tree.markedStep(of: item) ?? tree.currentStep(of: item) ?? item
            let advice = TodoSplitAdvisor.advice(title: step.title,
                                                 durationHours: step.durationHours,
                                                 pick: step.fragmentPick)
            return TodoWidgetSnapshot.Item(
                id: item.dragToken,
                title: item.title,
                colorHex: category.flatMap { paletteHex($0.colorName) },
                categoryName: category?.name,
                isCarryover: isCarryover,
                isToday: assignedToday.contains(item.title),
                stepTitle: tree.hasChildren(item) ? step.title : nil,
                progress: tree.hasChildren(item) ? tree.progress(of: item) : 0,
                isFragment: advice.isFragment,
                stepIndex: tree.hasChildren(item)
                    ? (tree.leaves(of: item).firstIndex { $0.dragToken == step.dragToken }.map { $0 + 1 })
                    : nil,
                stepCount: tree.hasChildren(item) ? tree.leafCount(of: item) : nil
            )
        }

        let fragments = makeFragments(ordered: ordered, tree: tree,
                                      categoryByID: categoryByID,
                                      assignedToday: assignedToday)

        return TodoWidgetSnapshot(
            items: Array(widgetItems),
            fragments: Array(fragments.prefix(TodoWidgetSnapshot.maxFragments)),
            openCount: open.count,
            fragmentCount: fragments.count,
            updatedAt: now
        )
    }

    /// **지금 5분에 집을 수 있는 단계들.** 번개 위젯이 읽는다.
    ///
    /// 목록의 단위가 다르다 — 위쪽 `items`는 최상위 할 일 하나에 한 줄이지만, 여기서는
    /// **단계 하나가 한 줄**이다. 순서 없는 묶음에서는 한 일 안에서도 조각이 여럿 나오고,
    /// 5분이 났을 때 필요한 건 '무슨 일이 남았나'가 아니라 '지금 집을 게 뭐가 있나'다.
    ///
    /// 무엇이 지금 손댈 수 있는지는 `TodoTree.availableSteps`가 정한다 (순서대로면 하나,
    /// 아무거나면 남은 것 전부, 표시해 둔 단계는 차례 무관). 그중 조각만 남긴다.
    private static func makeFragments(ordered: [(BacklogItem, Bool)],
                                      tree: TodoTree,
                                      categoryByID: [String: BacklogCategory],
                                      assignedToday: Set<String>) -> [TodoWidgetSnapshot.Fragment]
    {
        var result: [TodoWidgetSnapshot.Fragment] = []
        var seen = Set<String>()

        for (root, _) in ordered {
            let category = root.categoryID.flatMap { categoryByID[$0] }
            for step in tree.availableSteps(of: root) {
                let advice = TodoSplitAdvisor.advice(title: step.title,
                                                     durationHours: step.durationHours,
                                                     pick: step.fragmentPick)
                guard advice.isFragment else { continue }
                guard seen.insert(step.dragToken).inserted else { continue }
                result.append(TodoWidgetSnapshot.Fragment(
                    id: step.dragToken,
                    title: step.title,
                    // 단계 이름만 서 있으면 무슨 일의 일부인지 알 수 없다 (앱 목록과 같은 이유).
                    parentTitle: step.dragToken == root.dragToken ? nil : root.title,
                    colorHex: category.flatMap { paletteHex($0.colorName) },
                    minutes: Int((max(0, step.durationHours) * 60).rounded()),
                    isMarked: step.isMarkedNow
                ))
            }
        }

        // 사람이 표시한 것이 앱의 짐작보다 앞선다. 그 다음은 위쪽 목록과 같은 급한 순서인데,
        // `ordered`를 그대로 돌았으므로 이미 그 순서다 — 안정 정렬로 표시한 것만 끌어올린다.
        return result.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isMarked != rhs.element.isMarked { return lhs.element.isMarked }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// 위젯 목록에서의 우선순위. 낮을수록 위.
    private static func rank(item: BacklogItem, isCarryover: Bool,
                             assignedToday: Set<String>, tree: TodoTree) -> Int
    {
        if assignedToday.contains(item.title) { return 0 }   // 오늘 하기로 한 일
        // '바로 하면 되는 일'로 표시해 둔 것. 잠금 화면에서 5분을 집는 자리라
        // 앱 목록에서 맨 위인 것과 같은 이유로 여기서도 위로 온다.
        if tree.markedStep(of: item) != nil { return 1 }
        if isCarryover { return 2 }                          // 지난 주에 밀린 일
        return 3                                             // 나머지 이번 주
    }

}
