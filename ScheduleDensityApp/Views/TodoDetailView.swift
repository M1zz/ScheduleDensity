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
    /// 새 단계의 속성. 목록 화면의 빈 줄과 같은 키를 써서, 어디서 적든 지난번 값이 따라온다.
    @AppStorage("todo.newLabel") private var newLabelRaw: String = TodoLabel.ready.rawValue
    @State private var editing: BacklogItem?
    @FocusState private var inputFocused: Bool

    private var tree: TodoTree { TodoTree(allItems) }

    /// 단계 목록 맨 아래 빈 줄의 id — 키보드가 올라올 때 그 줄로 스크롤하기 위해.
    private static let newRowID = "step.newRow"

    private var rows: [(item: BacklogItem, depth: Int)] {
        // 최상위 할 일 자체는 헤더가 보여주므로 목록에는 그 아래만 그린다.
        Array(tree.flattened(from: root).dropFirst())
    }

    /// 구성 전체에 대한 조언 (조각 시간 연구 기반).
    private var hints: [SplitHint] {
        let tree = self.tree
        let leaves = tree.hasChildren(root) ? tree.leaves(of: root) : []
        return TodoSplitAdvisor.hints(rootTitle: root.title,
                                      steps: leaves.map { ($0.title, $0.durationHours, $0.label) })
    }

    var body: some View {
        ScrollViewReader { proxy in
        List {
            Section { headerCard }

            // 팁은 한 번에 하나만. 둘 다 뜨면 단계를 보러 들어온 화면이
            // 설명 카드 두 장으로 덮인다. 이 할 일에 대한 조언을 먼저 내고,
            // 그걸 닫은 뒤에 비중 규칙을 한 번 설명한다.
            if !rows.isEmpty {
                if showsSplitHint { splitHintTip } else { shareSplitTip }
            }
            // 단계가 아직 없어도 이 섹션은 그린다 — 그 안의 빈 줄이 '첫 단계를 적는 자리'다.
            stepsSection
            // 뭘 적어야 할지 막막할 때만 뼈대를 권한다. 빈 줄 아래에 둔다.
            if rows.isEmpty { templateSection }
        }
        .onChange(of: inputFocused) { _, focused in
            if focused { scrollToNewRow(proxy) }
        }
        .onChange(of: rows.count) { _, _ in
            if inputFocused { scrollToNewRow(proxy) }
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
        // 입력이 목록 안에 있으므로 스크롤로 키보드를 바로 내리면 적다가 끊긴다.
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $editing) { item in
            StepEditSheet(item: item) { save() }
        }
    }

    private func scrollToNewRow(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Self.newRowID, anchor: .bottom)
        }
    }

    private var currentStepToken: String? {
        tree.currentStep(of: root)?.dragToken
    }

    // MARK: - 헤더

    /// 이 일이 지금 어디까지 왔고, 다음에 뭘 하면 되는지.
    ///
    /// 예전에는 여기에 '전체 예상 시간 = 100%'를 두고 단계들이 그 시간을 나눠 갖게 했다.
    /// 사람이 답할 수 없는 물음이었다 — 쪼개면서 "이건 전체의 몇 %지?"를 정할 방법이 없다.
    /// 지금은 반대다: 단계마다 착수 조건만 고르고, 시간은 아래에서 위로 저절로 쌓인다.
    private var headerCard: some View {
        let stepCount = tree.leafCount(of: root)
        let doneCount = tree.doneLeafCount(of: root)
        let remaining = tree.tally(of: [root])

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if stepCount > 0 {
                    Text("\(doneCount)/\(stepCount)")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(doneCount == stepCount ? Color.green : Color.accentColor)
                    Text("단계")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let category = category(of: root) {
                    Circle()
                        .fill(category.displayColor)
                        .frame(width: 12, height: 12)
                        .accessibilityLabel(category.name)
                }
            }

            if stepCount > 0 {
                ProgressView(value: tree.progress(of: root))
                    .tint(doneCount == stepCount ? .green : .accentColor)
            }

            if let step = tree.currentStep(of: root) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                        Text(step.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TodoLabelChip(label: step.label, hours: step.durationHours)
                    }
                    // 속성이 말해야 하는 건 '무슨 종류냐'가 아니라 '언제 하면 되냐'다.
                    Label(step.label.whenToDo, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(step.label.tint)
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

            // 남은 몫은 **착수 조건별로 갈라서** 적는다.
            // 예전에는 "다 하면 2시간"처럼 하나로 접었는데, 그 2시간 안에는 조각 넷과
            // 덩어리 하나가 섞여 있었다. 서로 환산되지 않는 것을 더해 놓으면
            // "2시간 벌었는데 왜 아무것도 못 했지"가 된다 (→ TodoTree.tally).
            if !remaining.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("남은 몫")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(remaining) { t in
                                TodoLabelChip(label: t.label, hours: t.hours, count: t.count)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 단계가 아직 없을 때 (쪼개기 도우미)

    @ViewBuilder
    private var templateSection: some View {
        Section {
            ForEach(Array(TodoSplitAdvisor.template(for: root.title).enumerated()), id: \.offset) { _, step in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(step.title)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TodoLabelChip(label: step.label)
                    }
                    Text(step.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Button {
                applyTemplate()
            } label: {
                Label("이 뼈대로 4단계 만들기", systemImage: "wand.and.stars")
            }
        } header: {
            Text("쪼개기 도우미")
        } footer: {
            Text("일이 굴러가는 순서입니다 — 정하고 → 펼치고 → 몰입해서 → 바로.\n그대로 만든 뒤 이름과 속성은 얼마든지 고칠 수 있습니다.")
        }
    }

    // MARK: - 단계 목록

    /// 비중이 어떻게 굴러가는지는 한 번만 설명한다.
    /// 단계 섹션 밖에 둔다 — 적는 도중에 입력 줄 위로 행이 끼어들면 포커스가 풀린다.
    @ViewBuilder
    private var shareSplitTip: some View {
        if ShareSplitTip().shouldDisplay {
            Section {
                TipView(ShareSplitTip())
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private var stepsSection: some View {
        let tree = self.tree
        return Section {
            ForEach(rows, id: \.item.id) { row in
                StepRow(item: row.item,
                        depth: row.depth,
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
                            Label("속성·이름", systemImage: "slider.horizontal.3")
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

            // 단계들 바로 아래 빈 줄. 여기에 적고 엔터를 치면 다음 줄로 이어진다.
            newStepRow
        } header: {
            Text("단계")
        } footer: {
            if rows.isEmpty {
                Text("이 일을 이루는 단계를 위 빈 줄에 순서대로 적어보세요.\n각 단계에는 ‘지금 시작할 수 있나’만 골라 주면 시간은 따라옵니다.")
            }
        }
    }

    // MARK: - 조언 (전부 TipKit)

    /// 구성 전체에 대한 조언 중 지금 가장 중요한 하나만 팁으로 낸다.
    /// 경고가 있으면 경고를, 없으면 잘 쪼갰다는 확인을. 닫으면 그 종류는 다시 안 뜬다.
    /// 이 할 일에 대한 조언을 지금 낼 수 있는가.
    private var showsSplitHint: Bool {
        guard let hint = topHint else { return false }
        return SplitHintTip(hint: hint).shouldDisplay
    }

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

    // MARK: - 단계 목록 맨 아래 빈 줄
    //
    // 하단 입력 바를 목록 안으로 들여왔다. 바에 적으면 '폼을 채워 제출하는' 느낌이고,
    // 줄에 적으면 '단계를 한 줄씩 적어 내려가는' 느낌이 된다. 엔터를 치면 그 줄이
    // 확정되고 빈 줄이 다시 와서 계속 이어 적을 수 있다.

    /// 빈 줄이 놓일 깊이. 하위 단계를 적는 중이면 그 부모보다 한 칸 안쪽에 놓여,
    /// 어디에 붙는 줄인지 들여쓰기만 보고도 안다.
    private var newStepDepth: Int {
        guard let addTarget else { return 1 }
        return (rows.first { $0.item.dragToken == addTarget.dragToken }?.depth ?? 1) + 1
    }

    private var newStepRow: some View {
        HStack(spacing: 10) {
            if newStepDepth > 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1)
                    .padding(.leading, CGFloat(newStepDepth - 2) * 14)
                    .padding(.vertical, 2)
            }

            Image(systemName: "circle.dashed")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)

            TextField(addTarget == nil ? "세부 단계" : "‘\(addTarget!.title)’의 하위 단계",
                      text: $newTitle)
                .focused($inputFocused)
                .submitLabel(.return)
                .onSubmit(addStep)

            newShareMenu

            if addTarget != nil {
                // 하위로 파고들었다가 다시 맨 바깥 단계로 돌아오는 길.
                Button {
                    addTarget = nil
                } label: {
                    Image(systemName: "arrow.turn.left.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("맨 바깥 단계로")
            }
        }
        .padding(.vertical, 2)
        .id(Self.newRowID)
    }

    /// 이 단계를 지금 시작할 수 있는지. 쪼갤 때 고르는 건 이것 하나뿐이다.
    /// 지난번에 고른 값이 따라오므로, 적고 엔터만 쳐도 한 줄이 확정된다.
    private var newShareMenu: some View {
        Menu {
            Picker("지금 시작할 수 있나요?", selection: $newLabelRaw) {
                ForEach(TodoLabel.allCases) { label in
                    Label(label.costsMyTime
                          ? "\(label.name) · \(formatDuration(label.defaultHours))"
                          : label.name,
                          systemImage: label.symbol)
                        .tag(label.rawValue)
                }
            }
        } label: {
            TodoLabelChip(label: draftLabel)
        }
    }

    /// 지금 빈 줄에 적히면 붙을 속성.
    private var draftLabel: TodoLabel { TodoLabel.resolve(newLabelRaw) ?? .ready }

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
                                         label: step.label)
            context.insert(node)
            made.append(node)
            index += 1
        }
        let updated = TodoTree(allItems + made)
        updated.rollUp(from: root)
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
            Label("속성·이름 고치기", systemImage: "slider.horizontal.3")
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

    /// 빈 줄에서 엔터 = 다 적었다는 뜻이라 키보드를 내린다.
    /// 그 외에는 한 줄을 확정하고, 다시 빈 줄에 커서를 둔 채 이어 적게 한다.
    private func addStep() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else {
            inputFocused = false
            return
        }
        let parent = addTarget ?? root

        let step = TodoTree.makeStep(under: parent,
                                     title: title,
                                     sortIndex: tree.nextSortIndex(under: parent),
                                     label: draftLabel)
        context.insert(step)

        // 새로 만든 단계까지 넣어 트리를 다시 세운다 (@Query가 갱신되기 전이라도 계산이 맞도록).
        // 시간은 손댈 게 없다 — 위쪽 숫자는 이 단계가 더해지면서 저절로 커진다.
        let updated = TodoTree(allItems + [step])
        if updated.children(of: parent).count >= 2 { ShareSplitTip.hasSplit = true }
        // 새 단계는 아직 안 한 일이므로 부모가 완료 상태였다면 풀린다.
        updated.rollUp(from: step)
        withAnimation { save() }

        newTitle = ""
        // 팁이 뜨거나 섹션이 바뀌면서 포커스가 풀릴 수 있다. 다음 런루프에 다시 잡는다.
        inputFocused = true
        DispatchQueue.main.async { inputFocused = true }
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
                // 시간은 남은 단계들의 합이라 저절로 줄어든다. 완료 상태만 다시 굴려 준다.
                let updated = TodoTree(allItems.filter { !victims.contains($0.dragToken) })
                updated.rollUp(from: parent)
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

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(isCurrent ? .body.weight(.semibold) : .body)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasChildren {
                    ProgressView(value: progress)
                        .tint(progress >= 1 ? .green : .accentColor)
                        .frame(maxWidth: 160)
                }
            }

            Spacer(minLength: 8)

            // 이 단계를 지금 시작할 수 있는지 — 줄에서 가장 크게 읽혀야 하는 것.
            // (예전에는 이 자리에 '전체의 몇 %'가 있었다. 아무도 그 숫자로 결정하지 않았다.)
            TodoLabelChip(label: item.label, hours: item.durationHours)
        }
        .padding(.vertical, 4)
        .listRowBackground(isCurrent ? Color.orange.opacity(0.08) : nil)
    }
}

// MARK: - 단계 수정 시트

private struct StepEditSheet: View {
    let item: BacklogItem
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var label: TodoLabel = .ready

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
                                    TodoLabelChip(label: option,
                                                  isSelected: label == option,
                                                  style: .full)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("지금 시작할 수 있나요?")
                } footer: {
                    Text(label.hint)
                }
            }
            .navigationTitle("단계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { commit() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                title = item.title
                label = item.label
            }
        }
    }

    /// 속성을 바꾸면 시간도 그 속성의 것으로 따라간다 — 고르는 건 하나뿐이라는 약속을 지킨다.
    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        item.title = trimmed
        item.labelRaw = label.rawValue
        item.durationHours = label.defaultHours
        onSave()
        dismiss()
    }
}
