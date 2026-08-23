//
//  TodoDetailView.swift
//  ScheduleDensityApp
//
//  할 일 하나를 '들여다보는' 화면 — 그 안의 단계(뎁스)를 순서대로 보여주고 편집한다.
//
//  할 일 전체가 몇 시간인지를 먼저 정하고(그게 100%), 단계들이 그 시간을 나눠 갖는다.
//  기본은 N분의 1이고, 한 단계를 직접 조정하면 나머지가 남은 몫을 다시 나눠
//  합계는 언제나 100%가 된다. 계산은 TodoTree.swift(공유)에 있다.
//
//  화면은 '라벨 먼저'다 — 적을 때 고른 라벨(지금 바로 / 앉아서 한 번 / 집중 한 판 …)을
//  크게 보여준다. 조언은 화면에 깔지 않고 전부 TipKit으로 낸다 (→ TodoTips.swift) —
//  필요한 때 한 번 뜨고, 닫으면 다시 안 뜬다.
//

import SwiftUI
import SwiftData
import TipKit

struct TodoDetailView: View {
    /// 100%에 해당하는 최상위 할 일.
    let root: BacklogItem

    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\BacklogItem.sortIndex), SortDescriptor(\BacklogItem.createdAt)])
    private var allItems: [BacklogItem]
    @Query(sort: [SortDescriptor(\BacklogCategory.sortIndex), SortDescriptor(\BacklogCategory.createdAt)])
    private var categories: [BacklogCategory]

    /// 새 단계를 붙일 자리. 기본은 최상위 할 일 바로 아래.
    @State private var addTarget: BacklogItem?
    @State private var newTitle = ""
    /// 새 단계의 라벨. nil이면 '자동' — 형제들과 N분의 1로 나눠 갖는다.
    @State private var newLabel: TodoLabel?
    @State private var editing: BacklogItem?
    @FocusState private var inputFocused: Bool

    private var tree: TodoTree { TodoTree(allItems) }

    private var rows: [(item: BacklogItem, depth: Int)] {
        // 최상위 할 일 자체는 헤더가 보여주므로 목록에는 그 아래만 그린다.
        Array(tree.flattened(from: root).dropFirst())
    }

    /// 구성 전체에 대한 조언 (조각 시간 연구 기반).
    private var hints: [SplitHint] {
        let tree = self.tree
        let leaves = tree.hasChildren(root) ? tree.leaves(of: root) : []
        return TodoSplitAdvisor.hints(rootTitle: root.title,
                                      steps: leaves.map { ($0.title, $0.durationHours) })
    }

    var body: some View {
        List {
            Section { headerCard }

            if rows.isEmpty {
                emptyGuide
            } else {
                splitHintTip
                stepsSection
            }
        }
        .navigationTitle(root.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addTarget = nil
                    inputFocused = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("단계 추가")
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) { inputBar }
        .sheet(item: $editing) { item in
            StepEditSheet(item: item) { save() }
        }
    }

    private var currentStepToken: String? {
        tree.currentStep(of: root)?.dragToken
    }

    // MARK: - 헤더 (100% = 이 일 전체)

    private var headerCard: some View {
        let progress = tree.progress(of: root)
        let total = tree.totalHours(of: root)
        let done = tree.doneHours(of: root)
        let stepCount = tree.hasChildren(root) ? tree.leafCount(of: root) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(progress >= 1 ? Color.green : Color.accentColor)
                Spacer()
                if let category = category(of: root) {
                    HStack(spacing: 5) {
                        Circle().fill(category.displayColor).frame(width: 8, height: 8)
                        Text(category.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(value: progress)
                .tint(progress >= 1 ? .green : .accentColor)

            if let step = tree.currentStep(of: root) {
                HStack(spacing: 6) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(step.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                    Spacer()
                    if let number = tree.currentStepNumber(of: root), stepCount > 0 {
                        Text("\(stepCount)단계 중 \(number)번째")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } else if stepCount > 0 {
                Label("모든 단계를 마쳤습니다", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            // 지금 할 단계에 경고가 있으면 그것만 팁으로. (다른 줄에는 안 깐다)
            if let step = tree.currentStep(of: root),
               !tree.hasChildren(step),
               let warning = TodoSplitAdvisor.advice(title: step.title,
                                                     durationHours: step.durationHours).warning {
                TipView(StepWarningTip(warning: warning))
            }

            // 이 일 전체가 몇 시간인가 = 100%. 단계들은 이 시간을 나눠 갖는다.
            HStack(spacing: 8) {
                totalHoursMenu(current: total)
                Text(stepCount > 0 ? "= 100%, 단계 \(stepCount)개가 나눠 가짐" : "= 100%")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                if stepCount > 0 {
                    Text("\(formatDuration(done)) 완료")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 전체 예상 시간을 고치는 메뉴. 바꾸면 단계들이 비율을 지킨 채 같이 늘고 준다.
    private func totalHoursMenu(current: Double) -> some View {
        Menu {
            Section("이 일 전체 예상") {
                ForEach(TodoLabel.allCases) { label in
                    Button {
                        setRootHours(label.defaultHours, label: label)
                    } label: {
                        Label("\(label.name) · \(formatDuration(label.defaultHours))",
                              systemImage: label.symbol)
                    }
                }
            }
            Section("더 크게") {
                ForEach([6.0, 8.0, 12.0], id: \.self) { h in
                    Button(formatDuration(h)) { setRootHours(h, label: nil) }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: root.label.symbol)
                    .font(.caption2)
                Text(formatDuration(current))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(root.label.tint)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(root.label.tint.opacity(0.14)))
        }
    }

    // MARK: - 단계가 아직 없을 때

    @ViewBuilder
    private var emptyGuide: some View {
        Section {
            Button {
                inputFocused = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Label("첫 단계 추가하기", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                    Text("이 일을 이루는 단계를 순서대로 적어보세요.\n단계들은 전체 \(formatDuration(tree.totalHours(of: root)))를 N분의 1로 나눠 갖습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }

        Section {
            ForEach(Array(TodoSplitAdvisor.template(for: root.title).enumerated()), id: \.offset) { _, step in
                HStack(alignment: .top, spacing: 10) {
                    TodoLabelChip(label: TodoLabel.nearest(toHours: step.hours))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.callout.weight(.medium))
                        Text(step.note).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }

            Button {
                applyTemplate()
            } label: {
                Label("이 뼈대로 4단계 만들기", systemImage: "wand.and.stars")
            }
        } header: {
            Text("쪼개기 도우미")
        } footer: {
            Text("결정은 덩어리에서 끝내고, 준비와 마감은 조각으로. 전체 \(formatDuration(tree.totalHours(of: root)))를 이 비율대로 나눠 갖습니다.")
        }
    }

    // MARK: - 단계 목록

    private var stepsSection: some View {
        let tree = self.tree
        return Section {
            // 비중이 어떻게 굴러가는지는 여기서 한 번만 설명한다.
            if ShareSplitTip().shouldDisplay {
                TipView(ShareSplitTip())
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(rows, id: \.item.id) { row in
                StepRow(item: row.item,
                        depth: row.depth,
                        percent: tree.weightInRoot(of: row.item),
                        isCurrent: row.item.dragToken == currentStepToken,
                        hasChildren: tree.hasChildren(row.item),
                        progress: tree.progress(of: row.item),
                        onToggle: { toggle(row.item) })
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            remove(row.item)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        Button {
                            editing = row.item
                        } label: {
                            Label("비중·이름", systemImage: "slider.horizontal.3")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            addTarget = row.item
                            inputFocused = true
                        } label: {
                            Label("하위 단계", systemImage: "arrow.turn.down.right")
                        }
                        .tint(.indigo)
                    }
                    .contextMenu { rowMenu(row.item) }
            }
        } header: {
            HStack {
                Text("단계 · 합쳐서 100%")
                Spacer()
                Button {
                    withAnimation {
                        tree.splitEvenly(under: root)
                        save()
                    }
                } label: {
                    Label("N분의 1로", systemImage: "equal.square")
                        .font(.caption)
                }
            }
        } footer: {
            // 자물쇠 설명도 팁으로 — 실제로 하나 잠근 뒤에만 뜬다.
            TipView(LockedShareTip())
                .padding(.top, 6)
        }
    }

    // MARK: - 조언 (전부 TipKit)

    /// 구성 전체에 대한 조언 중 지금 가장 중요한 하나만 팁으로 낸다.
    /// 경고가 있으면 경고를, 없으면 잘 쪼갰다는 확인을. 닫으면 그 종류는 다시 안 뜬다.
    @ViewBuilder
    private var splitHintTip: some View {
        if let hint = topHint, SplitHintTip(hint: hint).shouldDisplay {
            Section {
                TipView(SplitHintTip(hint: hint))
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private var topHint: SplitHint? {
        let all = hints
        return all.first { $0.tone == .caution } ?? all.first
    }

    // MARK: - 단계 추가 입력 바

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let target = addTarget, target.dragToken != root.dragToken {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right").font(.caption2)
                    Text("‘\(target.title)’ 아래에 추가")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        addTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                labelPicker
            }

            HStack(spacing: 10) {
                TextField("다음에 할 단계", text: $newTitle)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit(addStep)

                Button(action: addStep) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    /// 새 단계의 몫을 고르는 줄. 기본은 '자동' = 형제들과 N분의 1.
    private var labelPicker: some View {
        let parent = addTarget ?? root
        let evenShare = tree.totalHours(of: parent) / Double(tree.children(of: parent).count + 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text(newLabel.map { "이 단계에 \(formatDuration($0.defaultHours))를 떼어 줍니다. 나머지 단계가 남은 몫을 나눠 가집니다." }
                 ?? "자동으로 N분의 1 — 이 단계는 \(formatDuration(evenShare))쯤이 됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        newLabel = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "equal.square").font(.caption2)
                            Text("자동 N분의 1").font(.caption.weight(.medium))
                        }
                        .foregroundStyle(newLabel == nil ? Color.white : Color.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(newLabel == nil ? Color.accentColor : Color.secondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    ForEach(TodoLabel.allCases) { label in
                        Button {
                            newLabel = label
                        } label: {
                            TodoLabelChip(label: label,
                                          hours: label.defaultHours,
                                          isSelected: newLabel == label)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 2)
            }
        }
        .padding(.top, 8)
    }

    /// 쪼개기 도우미의 기본 뼈대를 그대로 단계로 만든다.
    /// 뼈대의 시간은 '비율의 씨앗'이다 — 전체 예상 시간을 그 비율대로 나눠 갖는다.
    private func applyTemplate() {
        let tree = self.tree
        var index = tree.nextSortIndex(under: root)
        var made: [BacklogItem] = []
        for step in TodoSplitAdvisor.template(for: root.title) {
            let node = TodoTree.makeStep(under: root,
                                         title: step.title,
                                         sortIndex: index,
                                         seedHours: step.hours,
                                         label: TodoLabel.nearest(toHours: step.hours))
            // 뼈대는 일부러 정해둔 비율이므로 자동 재분배에서 빠진다.
            node.isManualWeight = true
            context.insert(node)
            made.append(node)
            index += 1
        }
        let updated = TodoTree(allItems + made)
        updated.rollUp(from: root)
        updated.fit(under: root)   // 씨앗 비율을 전체 예상 시간에 맞춰 늘리거나 줄인다
        save()
    }

    @ViewBuilder
    private func rowMenu(_ item: BacklogItem) -> some View {
        Button {
            addTarget = item
            inputFocused = true
        } label: {
            Label("하위 단계 추가", systemImage: "arrow.turn.down.right")
        }
        Button {
            editing = item
        } label: {
            Label("비중·이름 고치기", systemImage: "slider.horizontal.3")
        }
        if item.isManualWeight {
            Button {
                withAnimation {
                    tree.releaseManual(item)
                    save()
                }
            } label: {
                Label("자동 분배로 되돌리기", systemImage: "lock.open")
            }
        }
        Button {
            move(item, by: -1)
        } label: {
            Label("위로", systemImage: "arrow.up")
        }
        Button {
            move(item, by: 1)
        } label: {
            Label("아래로", systemImage: "arrow.down")
        }
        Divider()
        Button(role: .destructive) {
            remove(item)
        } label: {
            Label("삭제", systemImage: "trash")
        }
    }

    // MARK: - 동작

    private func category(of item: BacklogItem) -> BacklogCategory? {
        guard let id = item.categoryID else { return nil }
        return categories.first { $0.uuid == id }
    }

    /// 이 일 전체의 예상 시간을 바꾼다. 아래 단계들은 비율을 지킨 채 함께 조정된다.
    private func setRootHours(_ hours: Double, label: TodoLabel?) {
        withAnimation {
            if let label { root.labelRaw = label.rawValue }
            tree.setTotalHours(root, to: hours)
            save()
        }
    }

    private func addStep() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let parent = addTarget ?? root

        let step = TodoTree.makeStep(under: parent,
                                     title: title,
                                     sortIndex: tree.nextSortIndex(under: parent),
                                     label: newLabel)
        context.insert(step)

        // 새로 만든 단계까지 넣어 트리를 다시 세운다 (@Query가 갱신되기 전이라도 계산이 맞도록).
        let updated = TodoTree(allItems + [step])
        // 라벨을 골랐으면 그 시간만큼 떼어 주고, 아니면 형제들과 N분의 1.
        updated.giveInitialShare(step, hours: newLabel?.defaultHours)
        if updated.children(of: parent).count >= 2 { ShareSplitTip.hasSplit = true }
        // 새 단계는 아직 안 한 일이므로 부모가 완료 상태였다면 풀린다.
        updated.rollUp(from: step)
        save()

        newTitle = ""
        newLabel = nil
        inputFocused = true
    }

    private func toggle(_ item: BacklogItem) {
        withAnimation {
            tree.setCompleted(item, !item.isCompleted)
            save()
        }
    }

    private func remove(_ item: BacklogItem) {
        let tree = self.tree
        let parent = tree.parent(of: item)
        let victims = Set(tree.subtree(of: item).map(\.dragToken))
        withAnimation {
            for node in tree.subtree(of: item) { context.delete(node) }
            if let parent {
                // 지운 뒤의 트리로 다시 계산해, 남은 단계들이 빈 몫을 비율대로 나눠 갖게 한다.
                let updated = TodoTree(allItems.filter { !victims.contains($0.dragToken) })
                updated.rollUp(from: parent)
                updated.fit(under: parent)
            }
            save()
        }
    }

    /// 형제들 사이에서 순서를 한 칸 옮긴다.
    private func move(_ item: BacklogItem, by offset: Int) {
        let tree = self.tree
        guard let parent = tree.parent(of: item) else { return }
        var siblings = tree.children(of: parent)
        guard let index = siblings.firstIndex(where: { $0.dragToken == item.dragToken }) else { return }
        let target = index + offset
        guard siblings.indices.contains(target) else { return }
        siblings.swapAt(index, target)
        for (i, sibling) in siblings.enumerated() { sibling.sortIndex = i }
        withAnimation { save() }
    }

    private func save() {
        try? context.save()
        TodoWidgetSync.refresh(context: context)
    }
}

// MARK: - 단계 한 줄

private struct StepRow: View {
    let item: BacklogItem
    let depth: Int
    /// 최상위 할 일 전체에서 이 단계가 차지하는 비중 (0...1).
    let percent: Double
    let isCurrent: Bool
    let hasChildren: Bool
    let progress: Double
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // 들여쓰기로 뎁스를 보여준다.
            if depth > 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1)
                    .padding(.leading, CGFloat(depth - 2) * 14)
                    .padding(.vertical, 2)
            }

            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : (isCurrent ? "arrowtriangle.right.circle.fill" : "circle"))
                    .font(.system(size: 22))
                    .foregroundStyle(item.isCompleted ? .green : (isCurrent ? .orange : Color.secondary))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(isCurrent ? .body.weight(.semibold) : .body)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)

                HStack(spacing: 6) {
                    TodoLabelChip(label: item.label, hours: item.durationHours)
                    if item.isManualWeight {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                if hasChildren {
                    ProgressView(value: progress)
                        .tint(progress >= 1 ? .green : .accentColor)
                        .frame(maxWidth: 160)
                }

            }

            Spacer()

            // 비중 — 이 화면에서 가장 크게 읽혀야 하는 숫자.
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(percentText)%")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.isCompleted ? .green : item.label.tint)
                shareBar
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isCurrent ? Color.orange.opacity(0.08) : nil)
    }

    /// 비중을 눈으로 보는 막대 — 숫자보다 이게 먼저 읽힌다.
    private var shareBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 52, height: 5)
            Capsule()
                .fill(item.isCompleted ? Color.green : item.label.tint)
                .frame(width: max(4, 52 * min(1, percent)), height: 5)
        }
    }

    /// 0.5% 미만이라도 0%로 보이지 않게 소수 한 자리까지 쓴다.
    private var percentText: String {
        let value = percent * 100
        if value > 0 && value < 1 { return String(format: "%.1f", value) }
        return String(Int(value.rounded()))
    }
}

// MARK: - 라벨 칩

extension TodoLabel {
    /// 라벨의 색. iOS·맥이 같은 색을 쓰도록 라벨마다 하나씩 못 박아 둔다.
    var tint: Color {
        switch self {
        case .now:     return .green
        case .sit:     return .teal
        case .focus:   return .indigo
        case .block:   return .purple
        case .halfDay: return .orange
        }
    }
}

/// 목록·상세·입력창 어디서나 같은 모양으로 쓰는 라벨 칩.
/// `hours`를 주면 실제로 배정된 시간을 함께 보여준다 (라벨 기본값과 다를 수 있다).
struct TodoLabelChip: View {
    let label: TodoLabel
    var hours: Double? = nil
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: label.symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(label.name)
                .font(.caption.weight(.medium))
            if let hours {
                Text(formatDuration(hours))
                    .font(.caption2)
                    .monospacedDigit()
                    .opacity(0.75)
            }
        }
        .foregroundStyle(isSelected ? Color.white : label.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(isSelected ? label.tint : label.tint.opacity(0.13)))
    }
}

/// 조각/덩어리 배지의 색과 문구. iOS·맥이 같은 규칙을 쓰도록 한 곳에 모은다.
enum ChunkBadge {
    static func color(_ kind: ChunkKind) -> Color {
        switch kind {
        case .fragment: return .green
        case .short:    return .blue
        case .block:    return .indigo
        }
    }

    static func text(for title: String, hours: Double) -> String {
        TodoSplitAdvisor.advice(title: title, durationHours: hours).kind.label
    }

    static func color(for title: String, hours: Double) -> Color {
        color(TodoSplitAdvisor.advice(title: title, durationHours: hours).kind)
    }
}

// MARK: - 단계 수정 시트

private struct StepEditSheet: View {
    let item: BacklogItem
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allItems: [BacklogItem]

    @State private var title: String = ""
    /// 부모 안에서 이 단계가 차지할 비중 (%).
    @State private var percent: Double = 50
    @State private var label: TodoLabel = .focus
    /// 자동(N분의 1)에 맡길지, 직접 정할지.
    @State private var isManual: Bool = false

    private var tree: TodoTree { TodoTree(allItems) }
    private var parent: BacklogItem? { tree.parent(of: item) }
    /// 형제가 없으면 이 단계가 곧 부모 전부라 비중을 조정할 여지가 없다.
    private var hasSiblings: Bool {
        guard let parent else { return false }
        return tree.children(of: parent).count > 1
    }
    private var parentHours: Double { parent.map { tree.totalHours(of: $0) } ?? item.durationHours }
    /// 지금 슬라이더가 가리키는 실제 시간.
    private var previewHours: Double { parentHours * percent / 100 }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("단계 이름", text: $title)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TodoLabel.allCases) { option in
                                Button {
                                    label = option
                                } label: {
                                    TodoLabelChip(label: option, isSelected: label == option)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("라벨")
                } footer: {
                    Text(label.hint)
                }

                if hasSiblings {
                    Section {
                        Toggle("자동으로 N분의 1", isOn: Binding(
                            get: { !isManual },
                            set: { isManual = !$0 }
                        ))

                        if isManual {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(Int(percent.rounded()))%")
                                        .font(.title3.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(label.tint)
                                    Text(formatDuration(previewHours))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Slider(value: $percent, in: 5...100, step: 5)
                                    .tint(label.tint)
                                Text("나머지 \(Int((100 - percent).rounded()))%는 다른 단계들이 나눠 가집니다.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("비중")
                    } footer: {
                        Text(isManual
                             ? "직접 정한 비중은 다른 단계를 고쳐도 그대로 유지됩니다."
                             : "형제 단계들과 남은 몫을 똑같이 나눠 가집니다.")
                    }
                } else {
                    Section {
                        LabeledContent("비중", value: "100%")
                        LabeledContent("예상 시간", value: formatDuration(parentHours))
                    } footer: {
                        Text("단계가 하나뿐이라 이 단계가 곧 상위 일의 100%입니다. 시간을 바꾸려면 상위 일의 전체 예상 시간을 고치세요.")
                    }
                }
            }
            .navigationTitle("단계 고치기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { apply() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() {
        title = item.title
        label = item.label
        isManual = item.isManualWeight
        let total = parentHours
        percent = total > 0 ? min(100, max(5, item.durationHours / total * 100)) : 100
    }

    private func apply() {
        let tree = self.tree
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.labelRaw = label.rawValue

        if parent == nil {
            // 최상위 할 일 — 이 시간이 곧 100%다.
            tree.setTotalHours(item, to: previewHours)
        } else if !hasSiblings {
            tree.fit(under: parent!)
        } else if isManual {
            tree.setWeight(item, to: percent / 100)
            LockedShareTip.hasLocked = true
        } else if item.isManualWeight {
            tree.releaseManual(item)
        }
        onSave()
        dismiss()
    }
}
