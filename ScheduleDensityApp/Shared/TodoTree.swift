//
//  TodoTree.swift
//
//  할 일의 뎁스(단계) 계산 — 순수 로직.
//
//  시간은 **위에서 아래로** 내려간다.
//  단계는 같은 BacklogItem이고, `parentToken`(부모의 dragToken)으로 매달린다.
//
//  시간은 **아래에서 위로** 쌓인다: 단계마다 소요시간을 적으면 그 값이
//  시간을 데려오고, 상위 할 일의 시간은 단계들의 합이다.
//
//  예전에는 반대였다 — 상위 할 일의 시간이 100%이고 단계들이 그걸 나눠 갖는 구조로,
//  비중 슬라이더·자물쇠·N분의 1이 딸려 있었다. 그 구조는 "이 단계가 전체의 몇 %냐"에
//  답했는데, 쪼개는 사람은 그 물음에 답할 수가 없다. 단계를 실제로 하느냐 마느냐를
//  가르는 건 비율이 아니라 '지금 시작할 수 있느냐'였다.
//
import Foundation

/// 부모-자식 관계를 한 번만 색인해두고 쓰는 조회기.
/// `BacklogItem.parentToken`(부모의 `dragToken`)으로 연결된다.
struct TodoTree {
    /// 부모 토큰 → 자식들 (진행 순서대로 정렬).
    private let childrenByParent: [String: [BacklogItem]]
    /// 자식 토큰 → 부모.
    private let parentByToken: [String: BacklogItem]
    /// 최상위 할 일들 (= 단계를 매다는 단위).
    let roots: [BacklogItem]

    /// 잘못된 데이터(부모-자식 순환)로 무한 재귀에 빠지지 않도록 두는 한계.
    /// 사람이 손으로 만드는 단계 구조가 이보다 깊을 일은 없다.
    static let maxDepth = 12

    init(_ items: [BacklogItem]) {
        let tokens = Set(items.map(\.dragToken))
        var byParent: [String: [BacklogItem]] = [:]
        var byToken: [String: BacklogItem] = [:]
        var tops: [BacklogItem] = []

        for item in items {
            // 부모가 목록에 없으면(삭제됐거나 아직 동기화 전이면) 최상위로 취급한다.
            // 그래야 고아가 된 단계가 화면에서 사라지지 않는다.
            if let parent = item.parentToken, !parent.isEmpty, tokens.contains(parent), parent != item.dragToken {
                byParent[parent, default: []].append(item)
            } else {
                tops.append(item)
            }
        }

        let inOrder: (BacklogItem, BacklogItem) -> Bool = { a, b in
            if a.sortIndex != b.sortIndex { return a.sortIndex < b.sortIndex }
            return a.createdAt < b.createdAt
        }

        self.childrenByParent = byParent.mapValues { $0.sorted(by: inOrder) }
        self.roots = tops.sorted(by: inOrder)

        for (parentToken, kids) in byParent {
            guard let parent = items.first(where: { $0.dragToken == parentToken }) else { continue }
            for kid in kids { byToken[kid.dragToken] = parent }
        }
        self.parentByToken = byToken
    }

    // MARK: - 구조 조회

    func children(of item: BacklogItem) -> [BacklogItem] {
        childrenByParent[item.dragToken] ?? []
    }

    func hasChildren(_ item: BacklogItem) -> Bool {
        !(childrenByParent[item.dragToken] ?? []).isEmpty
    }

    func parent(of item: BacklogItem) -> BacklogItem? {
        parentByToken[item.dragToken]
    }

    /// 최상위 조상 (그 할 일 전체 = 100%인 항목).
    func root(of item: BacklogItem) -> BacklogItem {
        var current = item
        var depth = 0
        while let up = parentByToken[current.dragToken], depth < Self.maxDepth {
            current = up
            depth += 1
        }
        return current
    }

    /// 자기를 포함한 하위 전체를 진행 순서(깊이 우선)로.
    func subtree(of item: BacklogItem) -> [BacklogItem] {
        var result: [BacklogItem] = []
        visit(item, depth: 0) { node, _ in result.append(node) }
        return result
    }

    /// 잎(더 쪼개지 않은 단계)들을 진행 순서대로. 자식이 없으면 자기 자신 하나.
    func leaves(of item: BacklogItem) -> [BacklogItem] {
        var result: [BacklogItem] = []
        visit(item, depth: 0) { node, _ in
            if (childrenByParent[node.dragToken] ?? []).isEmpty { result.append(node) }
        }
        return result
    }

    /// 화면에 들여쓰기와 함께 그리기 위한 (항목, 깊이) 목록. 자기 자신은 깊이 0.
    func flattened(from item: BacklogItem) -> [(item: BacklogItem, depth: Int)] {
        var result: [(BacklogItem, Int)] = []
        visit(item, depth: 0) { node, depth in result.append((node, depth)) }
        return result
    }

    private func visit(_ item: BacklogItem, depth: Int, _ body: (BacklogItem, Int) -> Void) {
        guard depth < Self.maxDepth else { return }
        body(item, depth)
        for child in childrenByParent[item.dragToken] ?? [] {
            visit(child, depth: depth + 1, body)
        }
    }

    // MARK: - 시간·비중·진행률

    /// 이 일에 걸리는 예상 시간. **아래에서 위로 합산한다** —
    /// 단계가 있으면 단계들의 합이고, 없으면 자기 속성이 정한 시간이다.
    ///
    /// 예전에는 반대였다(상위가 100%이고 단계들이 그걸 나눠 가짐). 그 구조는
    /// "이 단계가 전체의 몇 %냐"에 답했는데, 단계를 실제로 하느냐 마느냐를 가르는 건
    /// 비율이 아니라 '한 자리에서 닫히는 크기'였다. 그래서 비중을 걷어내고,
    /// 시간은 단계를 하나씩 더할 때마다 위로 쌓이게 했다.
    func totalHours(of item: BacklogItem) -> Double {
        let kids = children(of: item)
        guard !kids.isEmpty else { return max(0, item.durationHours) }
        return kids.reduce(0) { $0 + totalHours(of: $1) }
    }

    /// 완료한 잎들의 시간 합.
    func doneHours(of item: BacklogItem) -> Double {
        leaves(of: item).filter(\.isCompleted).reduce(0) { $0 + max(0, $1.durationHours) }
    }

    /// 0...1 진행률 = 끝낸 단계 수 ÷ 전체 단계 수.
    ///
    /// 시간으로 재지 않는다. '기다림'은 내 시간을 0으로 쓰는데, 시간으로 재면 그 단계를
    /// 끝내도 진행률이 꿈쩍하지 않는다. 사람이 세는 방식(4개 중 2개)과도 맞다.
    func progress(of item: BacklogItem) -> Double {
        let all = leaves(of: item)
        guard !all.isEmpty else { return item.isCompleted ? 1 : 0 }
        return Double(all.filter(\.isCompleted).count) / Double(all.count)
    }

    // MARK: - 갈라 세기 (합치지 않는 집계)

    /// 지금 할 단계. 단계가 없으면 자기 자신.
    ///
    /// 묶음마다 제 스위치(→ `BacklogItem.stepOrder`)를 본다.
    /// - `.sequential`: 남은 것 중 **첫 번째**. (예전 동작 그대로)
    /// - `.free`: 남은 것 중 **조각인 것 먼저**. 차례가 없으니 '지금 집을 수 있는 것'을
    ///   세우는 게 맞다 — 사슬에서는 못 하던 일이고, 두 질문의 판정이 그제서야 일을 한다.
    ///
    /// 묶음이 섞여 있어도 각 층이 제 스위치를 따른다. '순서대로'인 큰 일 안에
    /// '아무거나'인 묶음이 들어 있으면, 그 묶음 차례가 왔을 때 그 안에서만 조각이 앞선다.
    func currentStep(of item: BacklogItem) -> BacklogItem? {
        if let found = openStep(in: item, depth: 0) { return found }
        // 층을 따라 내려가다 못 찾았는데 안 끝난 잎이 남아 있다면 데이터가 어긋난 것이다
        // (동기화 도중 묶음만 완료로 표시되는 등). 잎을 직접 훑어 되찾는다 —
        // 여기서 nil을 돌려주면 그 할 일이 목록에서 '다 끝난 것'처럼 보인다.
        return leaves(of: item).first { !$0.isCompleted }
    }

    private func openStep(in item: BacklogItem, depth: Int) -> BacklogItem? {
        guard depth < Self.maxDepth else { return nil }
        let kids = children(of: item)
        guard !kids.isEmpty else { return item.isCompleted ? nil : item }
        let open = kids.filter { !$0.isCompleted }
        guard let first = open.first else { return nil }
        let next = item.stepOrder == .free ? fragmentFirst(open) ?? first : first
        return openStep(in: next, depth: depth + 1)
    }

    /// 순서가 없는 묶음에서 앞에 세울 것 — **5분에 집을 수 있는 것 먼저**.
    /// 없으면 nil을 돌려 적어 둔 순서를 그대로 쓴다(줄이 이유 없이 튀지 않게).
    ///
    /// 묶음은 후보에서 뺀다. 묶음의 `durationHours`는 저장된 값이라 실제 크기가 아니고,
    /// 앱도 묶음은 판정하지 않는다 (→ `TodoDetailView.stepsSection`).
    private func fragmentFirst(_ steps: [BacklogItem]) -> BacklogItem? {
        steps.first { step in
            guard !hasChildren(step) else { return false }
            return TodoSplitAdvisor.advice(title: step.title,
                                           durationHours: step.durationHours,
                                           pick: step.fragmentPick).isFragment
        }
    }

    /// **지금 손댈 수 있는 단계 전부.** 차례가 온 것과, 차례를 안 기다리는 것.
    ///
    /// `currentStep`은 "다음에 뭘 세울까"에 하나로 답하지만, '5분이 났을 때 집을 수 있는 게
    /// 뭐가 있나'는 그 하나로는 답이 안 된다. 순서가 없는 묶음에서는 남은 게 전부 지금 할 수
    /// 있고, 표시해 둔 단계는 어느 묶음에서든 차례를 안 기다린다.
    ///
    /// - 표시해 둔 단계(`isMarkedNow`)가 먼저다. 앱의 짐작이 아니라 사람이 표시한 것이라,
    ///   앱 목록 맨 위 칸이 그렇듯 여기서도 앞선다.
    /// - `.sequential` 묶음은 첫 번째 하나, `.free` 묶음은 남은 것 전부.
    /// - 단계가 없는 줄은 자기 자신 하나.
    func availableSteps(of item: BacklogItem) -> [BacklogItem] {
        var result: [BacklogItem] = []
        var seen = Set<String>()
        func add(_ step: BacklogItem) {
            guard seen.insert(step.dragToken).inserted else { return }
            result.append(step)
        }
        for leaf in leaves(of: item) where !leaf.isCompleted && leaf.isMarkedNow { add(leaf) }
        collectAvailable(in: item, depth: 0, add)
        return result
    }

    private func collectAvailable(in item: BacklogItem, depth: Int, _ add: (BacklogItem) -> Void) {
        guard depth < Self.maxDepth else { return }
        let kids = children(of: item)
        guard !kids.isEmpty else {
            if !item.isCompleted { add(item) }
            return
        }
        let open = kids.filter { !$0.isCompleted }
        guard !open.isEmpty else { return }
        switch item.stepOrder {
        case .sequential:
            // 앞의 것이 끝나야 다음이 오므로, 지금 손댈 수 있는 건 첫 번째뿐이다.
            if let first = open.first { collectAvailable(in: first, depth: depth + 1, add) }
        case .free:
            // 서로 기다리지 않으므로 남은 게 전부 지금 할 수 있다.
            for kid in open { collectAvailable(in: kid, depth: depth + 1, add) }
        }
    }

    /// 방금 끝낸 단계 (되돌리기 대상).
    ///
    /// 순서가 없는 묶음에서는 '목록의 마지막'이 아니라 **가장 나중에 끝낸 것**을 되돌린다.
    /// 아무 순서로나 집는 곳에서 목록 위치로 고르면, 방금 누른 것이 아닌 게 풀린다.
    func lastDoneStep(of item: BacklogItem) -> BacklogItem? {
        let done = leaves(of: item).filter(\.isCompleted)
        guard !done.isEmpty else { return nil }
        guard item.stepOrder == .free else { return done.last }
        return done.max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    func leafCount(of item: BacklogItem) -> Int { leaves(of: item).count }

    func doneLeafCount(of item: BacklogItem) -> Int { leaves(of: item).filter(\.isCompleted).count }

    /// "3단계 중 2번째" 처럼 쓸 현재 단계 번호(1부터). 다 끝났으면 nil.
    ///
    /// 순서가 없는 묶음에는 '몇 번째'가 없다 — nil이다. 세는 말이 필요하면
    /// `stepProgressPhrase(of:)`를 쓴다.
    func currentStepNumber(of item: BacklogItem) -> Int? {
        guard item.stepOrder != .free else { return nil }
        let all = leaves(of: item)
        guard let index = all.firstIndex(where: { !$0.isCompleted }) else { return nil }
        return index + 1
    }

    /// 어디까지 왔나를 **말로** 적은 것. 도넛은 그림이라 소리로는 안 읽힌다.
    /// 순서대로면 "3단계 중 2번째", 아무거나면 "3개 중 1개 끝". 단계가 없으면 nil.
    func stepProgressPhrase(of item: BacklogItem) -> String? {
        guard hasChildren(item) else { return nil }
        let total = leafCount(of: item)
        guard total > 0 else { return nil }
        if item.stepOrder == .free {
            return "\(total)개 중 \(doneLeafCount(of: item))개 끝"
        }
        guard let number = currentStepNumber(of: item) else { return nil }
        return "\(total)단계 중 \(number)번째"
    }

    // MARK: - 변경 (호출한 쪽에서 context.save())

    /// 지금 할 일을 끝냈다고 표시하고 다음 단계로 넘긴다.
    /// 마지막 단계였다면 할 일 전체가 완료된다. 완료 처리한 단계를 돌려준다.
    @discardableResult
    func advance(_ item: BacklogItem, now: Date = Date()) -> BacklogItem? {
        guard let step = currentStep(of: item) else { return nil }
        setCompleted(step, true, now: now)
        return step
    }

    /// 마지막으로 완료한 단계를 되돌린다. 되돌린 단계를 돌려준다.
    @discardableResult
    func rewind(_ item: BacklogItem) -> BacklogItem? {
        guard let step = lastDoneStep(of: item) else { return nil }
        setCompleted(step, false)
        return step
    }

    /// 한 단계의 완료 상태를 바꾸고, 하위와 조상의 상태를 다시 맞춘다.
    func setCompleted(_ item: BacklogItem, _ value: Bool, now: Date = Date()) {
        // 중간 단계를 직접 체크하면 그 아래 단계도 전부 따라간다.
        for node in subtree(of: item) {
            node.isCompleted = value
            node.completedAt = value ? (node.completedAt ?? now) : nil
        }
        rollUp(from: item, now: now)
    }

    /// 조상들의 완료 상태를 자식 기준으로 다시 계산한다.
    /// (자식이 전부 끝났으면 부모도 완료, 하나라도 남았으면 부모는 미완료)
    ///
    /// 시간은 건드리지 않는다 — 부모의 시간은 저장된 값이 아니라 자식들의 합으로
    /// 그때그때 계산되기 때문이다 (→ totalHours).
    func rollUp(from item: BacklogItem, now: Date = Date()) {
        var current = item
        var depth = 0
        while let parent = parentByToken[current.dragToken], depth < Self.maxDepth {
            let kids = children(of: parent)
            let allDone = !kids.isEmpty && kids.allSatisfy(\.isCompleted)
            parent.isCompleted = allDone
            parent.completedAt = allDone ? (parent.completedAt ?? now) : nil
            current = parent
            depth += 1
        }
    }

    // MARK: - 속성 정하기

    /// 단계를 새로 붙일 때 쓸 sortIndex (형제들 맨 뒤).
    func nextSortIndex(under parent: BacklogItem) -> Int {
        (children(of: parent).map(\.sortIndex).max() ?? -1) + 1
    }
}

// MARK: - 단계 만들기

extension TodoTree {
    /// 부모 아래에 새 단계를 만든다. 저장(insert/save)은 호출한 쪽에서 한다.
    ///
    /// 상위 할 일의 시간은 단계들의 합이므로 여기서 따로 손대지 않는다(아래에서 위로).
    /// 주(weekStartDate)와 카테고리는 부모를 따라간다 — 단계는 부모와 한 덩어리로 움직인다.
    static func makeStep(under parent: BacklogItem,
                         title: String,
                         sortIndex: Int,
                         durationHours: Double = TodoTree.defaultStepHours) -> BacklogItem
    {
        let step = BacklogItem(title: title,
                               durationHours: durationHours,
                               sortIndex: sortIndex,
                               categoryID: parent.categoryID,
                               weekStartDate: parent.weekStartDate)
        step.parentToken = parent.dragToken
        return step
    }
}

extension TodoTree {
    /// 새 단계·새 할 일의 기본 소요시간. 적을 때는 안 묻고, 상세에서 고친다.
    static let defaultStepHours: Double = 0.5
}

// MARK: - 그냥 하면 되는 것

extension TodoTree {
    /// '그냥 하면 되는 것' — 오는 길에 우유 사 오기처럼, 자리를 만들 필요 없이
    /// **잊지만 않으면 되는** 한 줄.
    ///
    /// 별도의 종류 표시가 아니라 **적힌 것이 없는 상태**로 본다: 소요시간 0, 단계 없음.
    /// 종류를 고르게 하면 제일 급하게 적는 줄이 제일 손이 많이 가게 된다 —
    /// 착수 조건 라벨을 걷어냈던 이유와 같다. 그래서 필드를 더하지 않고,
    /// 시간을 적는 순간 저절로 '할 일'로 올라가게 둔다.
    ///
    /// ⚠️ 마감(무지개에 그어 둔 줄)은 다른 스토어에 있어 여기서 못 본다.
    ///    마감이 붙은 줄을 빼는 건 부르는 쪽에서 한다 (→ TodoView.splitErrands).
    func isErrand(_ item: BacklogItem) -> Bool {
        item.durationHours <= 0 && !hasChildren(item)
    }

    /// 시간을 잡지 않는 일의 소요시간. 0이라 주 밀도에 아무것도 얹지 않는다.
    static let errandHours: Double = 0
}
