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
    @State private var editing: BacklogItem?
    @State private var editingTitle = ""
    /// 무지개에 그어질 기간.
    @State private var periodStart = Date()
    @State private var periodEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    /// 지금 무지개에 줄이 그어져 있는지.
    @State private var hasPeriod = false

    // 처음 한 번만 — 쪼개는 법을 직접 해보게 한다 (→ TodoSplitOnboarding.swift).
    @AppStorage(AppSettingsKey.hasSeenSplitOnboarding) private var hasSeenSplitOnboarding = false
    @State private var guide: SplitGuideStep?
    @State private var showingSplitMeaning = false
    @FocusState private var inputFocused: Bool

    private var tree: TodoTree { TodoTree(allItems) }

    /// 단계 목록 맨 아래 빈 줄의 id — 키보드가 올라올 때 그 줄로 스크롤하기 위해.
    private static let newRowID = "step.newRow"
    private static let headerRowID = "step.header"
    private static let periodRowID = "step.period"

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
        ScrollViewReader { proxy in
        List {
            // 이름·시간·기간·분류가 맨 위다. 이 화면에 들어오는 이유가 그걸 정하려는 것이고,
            // 목록에서는 이름만 받으므로 여기가 유일하게 정할 수 있는 자리다.
            settingsSection

            Section { headerCard.id(Self.headerRowID) }

            // 팁은 한 번에 하나만. 둘 다 뜨면 단계를 보러 들어온 화면이
            // 설명 카드 두 장으로 덮인다. 이 할 일에 대한 조언을 먼저 내고,
            // 그걸 닫은 뒤에 비중 규칙을 한 번 설명한다.
            if !rows.isEmpty {
                if showsSplitHint { splitHintTip } else { shareSplitTip }
            }
            // 단계가 아직 없어도 이 섹션은 그린다 — 그 안의 빈 줄이 '첫 단계를 적는 자리'다.
            stepsSection
            // 뼈대는 계속 둔다. 적다 말고 "다음에 뭐가 오지?" 할 때 되짚을 자리가 있어야 한다.
            templateSection
        }
        .onChange(of: inputFocused) { _, focused in
            if focused { scrollToNewRow(proxy) }
        }
        .onChange(of: rows.count) { _, count in
            if inputFocused { scrollToNewRow(proxy) }
            // 한 줄이라도 적었으면 그 다음을 짚어준다. 다 적을 때까지 카드가 붙어 있으면 잔소리가 된다.
            if guide == .writeStep, count > 0 { advanceGuide(to: .period) }
        }
        .overlayPreferenceValue(SpotlightAnchorKey.self) { anchors in
            GeometryReader { geo in
                if let step = guide {
                    SpotlightCoachOverlay(
                        hole: geo.spotlightRect(anchors)?.insetBy(dx: -8, dy: -6),
                        containerSize: geo.size,
                        icon: step.icon,
                        title: guideTitle(step),
                        message: step.message,
                        // 짚어주는 자리를 보면서 바로 만질 수 있어야 한다.
                        passesTouches: step != .intro
                    ) {
                        switch step {
                        case .intro:
                            Button("나중에") { endGuide(showMeaning: false) }
                                .buttonStyle(.bordered)
                            Button("해볼게요") { advanceGuide(to: .writeStep, proxy: proxy) }
                                .buttonStyle(.borderedProminent)
                        default:
                            Spacer()
                            Button("그만 볼래요") { endGuide(showMeaning: false) }
                                .font(.footnote)
                            if let next = step.next {
                                Button("다음") { advanceGuide(to: next, proxy: proxy) }
                                    .buttonStyle(.borderedProminent)
                            } else {
                                Button("다 됐어요") { endGuide(showMeaning: true) }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSplitMeaning) {
            SplitMeaningView { showingSplitMeaning = false }
        }
        .task { startGuideIfNeeded() }
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

    // MARK: - 쪼개는 법 안내

    /// 아직 단계가 하나도 없는 할 일에 처음 들어왔을 때만 뜬다. 그때가 배울 순간이라서.
    private func startGuideIfNeeded() {
        guard !hasSeenSplitOnboarding, guide == nil, rows.isEmpty else { return }
        hasSeenSplitOnboarding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { guide = .intro }
        }
    }

    private func guideTitle(_ step: SplitGuideStep) -> String {
        guard let order = step.order else { return step.title }
        return "\(order.index)/\(order.total) · \(step.title)"
    }

    private func advanceGuide(to step: SplitGuideStep, proxy: ScrollViewProxy? = nil) {
        withAnimation { guide = step }
        guard let proxy else { return }
        // 짚어주는 자리가 화면 밖이면 설명만 뜨고 정작 그 자리는 안 보인다.
        let target: String
        switch step {
        case .header:            target = Self.headerRowID
        case .period:            target = Self.periodRowID
        case .intro, .writeStep: target = Self.newRowID
        }
        withAnimation { proxy.scrollTo(target, anchor: step == .header ? .top : .center) }
    }

    private func endGuide(showMeaning: Bool) {
        withAnimation { guide = nil }
        if showMeaning { showingSplitMeaning = true }
    }

    /// 이 단계가 전체에서 차지하는 몫. 아래에 단계가 또 있으면 그 합으로 잰다.
    private func share(of item: BacklogItem, total: Double) -> Double? {
        guard total > 0 else { return nil }
        let hours = tree.hasChildren(item) ? tree.totalHours(of: item) : item.durationHours
        return hours / total
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

        return VStack(alignment: .leading, spacing: 12) {
            // 단계가 하나뿐이면 "0/1 단계"와 진행 막대는 아무것도 안 알려준다.
            if stepCount > 1 {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(doneCount)/\(stepCount)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(doneCount == stepCount ? Color.green : Color.accentColor)
                    Text("단계")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let category = category(of: root) {
                        Circle()
                            .fill(category.displayColor)
                            .frame(width: 12, height: 12)
                            .accessibilityLabel(category.name)
                    }
                }
                ProgressView(value: tree.progress(of: root))
                    .tint(doneCount == stepCount ? .green : .accentColor)
            }

            if let step = tree.currentStep(of: root) {
                // 지금 할 단계. 시간은 오른쪽에 한 번, 언제 하면 되는지는 아래에 한 번.
                // (예전에는 칩·설명·남은 몫이 같은 말을 세 번 했다.)
                VStack(alignment: .leading, spacing: 6) {
                    // 기호 하나로는 이게 '지금 할 것'이라는 뜻이 안 읽힌다. 말로 적는다.
                    Text("지금 단계")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(step.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
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

        }
        .padding(.vertical, 4)
        .spotlightAnchor(guide == .header)
        .task {
            editingTitle = root.title
            if let period = TodoEventBridge.shared.period(for: root) {
                periodStart = period.start
                periodEnd = period.end
                hasPeriod = true
            }
        }
    }

    // MARK: - 이 할 일 (목록에서 못 정한 것들을 여기서 정한다)

    /// 목록의 빈 줄은 이름만 받는다. 착수 조건·분류·데드라인은 적을 때가 아니라
    /// **들여다볼 때** 정하는 게 맞다 — 한 줄 적으려다 매번 세 가지를 고르게 되면
    /// 적는 속도가 죽고, 정작 정해야 할 때는 지난 값을 아무 생각 없이 흘려보낸다.
    @ViewBuilder
    private var settingsSection: some View {
        Section {
            TextField("할 일 이름", text: $editingTitle)
                .onSubmit(commitTitle)
                // 글자마다 저장하면 위젯 갱신까지 매 타건마다 돈다. 손이 멈추면 저장한다.
                .task(id: editingTitle) {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    commitTitle()
                }

            // 단계로 쪼갠 뒤에는 이 할 일의 시간이 단계들의 합이라 여기서 정할 것이 없다.
            if !tree.hasChildren(root) {
                // 0부터 시작한다. 0은 '아직 안 정함'이 아니라 **시간을 잡지 않겠다**는
                // 뜻이고, 그 줄은 목록에서 '그냥 하면 되는 것'으로 맨 위에 선다.
                // 여기서 0을 못 고르면 목록의 스와이프로만 갈 수 있는 상태가 생긴다.
                Stepper(value: Binding(get: { root.durationHours },
                                       set: { root.durationHours = max(0, $0); save() }),
                        in: 0...8, step: 0.25) {
                    HStack {
                        Text("소요시간")
                        Spacer()
                        Text(root.durationHours <= 0 ? "안 잡음" : formatDuration(root.durationHours))
                            .monospacedDigit()
                            .foregroundStyle(root.durationHours <= 0 ? Color.teal : Color.secondary)
                    }
                }
            }

            periodRows
                .spotlightAnchor(guide == .period)
                .id(Self.periodRowID)
            categoryPicker
        } header: {
            Text("이 할 일")
        }

    }

    private var categoryPicker: some View {
        Menu {
            Button {
                root.categoryID = nil
                save()
            } label: {
                Label("미분류", systemImage: root.categoryID == nil ? "checkmark" : "circle")
            }
            ForEach(categories) { c in
                Button {
                    root.categoryID = c.uuid
                    save()
                } label: {
                    Label(c.name, systemImage: root.categoryID == c.uuid ? "checkmark" : c.iconName)
                }
            }
        } label: {
            HStack {
                Text("분류")
                    .foregroundStyle(.primary)
                Spacer()
                if let category = category(of: root) {
                    Circle()
                        .fill(category.displayColor)
                        .frame(width: 10, height: 10)
                    Text(category.name)
                        .foregroundStyle(.secondary)
                } else {
                    Text("미분류")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 이 일이 언제부터 언제까지인지. 정하면 무지개에 그대로 한 줄이 그어진다.
    @ViewBuilder
    private var periodRows: some View {
        DatePicker("시작", selection: $periodStart, displayedComponents: .date)
            .onChange(of: periodStart) { _, newValue in
                if newValue > periodEnd { periodEnd = newValue }
                commitPeriod()
            }

        DatePicker("끝", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
            .onChange(of: periodEnd) { _, _ in commitPeriod() }

        HStack {
            Image(systemName: "rainbow")
                .foregroundStyle(.tint)
            Text(hasPeriod ? periodSummary : "아직 무지개에 없어요")
                .font(.subheadline)
                .foregroundStyle(hasPeriod ? .secondary : .tertiary)
            Spacer()
            if hasPeriod {
                Button("빼기") {
                    TodoEventBridge.shared.clearRainbow(for: root)
                    hasPeriod = false
                }
                .font(.subheadline)
            } else {
                Button("무지개에 긋기") { commitPeriod(force: true) }
                    .font(.subheadline)
            }
        }
    }

    private var periodSummary: String {
        let calendar = Calendar.current
        let days = (calendar.dateComponents([.day],
                                            from: calendar.startOfDay(for: periodStart),
                                            to: calendar.startOfDay(for: periodEnd)).day ?? 0) + 1
        let left = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: Date()),
                                           to: calendar.startOfDay(for: periodEnd)).day ?? 0
        return left <= 0 ? "무지개에 \(days)일 · 오늘까지" : "무지개에 \(days)일 · D-\(left)"
    }

    /// 날짜를 고치면 그 즉시 무지개에 반영한다. 아직 안 그은 일은 '긋기'를 눌러야 생긴다 —
    /// 상세를 열었다는 이유만으로 모든 할 일이 무지개에 올라오면 안 된다.
    private func commitPeriod(force: Bool = false) {
        guard hasPeriod || force else { return }
        let hours = tree.totalHours(of: root)
        TodoEventBridge.shared.drawRainbow(for: root, from: periodStart, to: periodEnd, hours: hours)
        hasPeriod = true
    }

    /// 이름을 고치면 무지개에 그어 둔 줄의 이름도 따라간다.
    private func commitTitle() {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != root.title else { return }
        root.title = trimmed
        TodoEventBridge.shared.renameRainbow(for: root)
        save()
    }

    // MARK: - 쪼개기 도우미 (보기용 뼈대)

    /// 내 단계가 아니라 '참고할 순서'다. 실제 단계 목록과 헷갈리지 않게
    /// 글자를 한 단 낮추고 흐리게 둔다.
    @ViewBuilder
    private var templateSection: some View {
        Section {
            ForEach(Array(TodoSplitAdvisor.template(for: root.title).enumerated()), id: \.offset) { _, step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(step.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(step.note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 3)
            }
        } header: {
            Text("쪼개기 도우미")
        } footer: {
            // 이 뼈대는 '보기'다. 한 번에 네 줄을 밀어 넣는 버튼이 있었는데,
            // 남의 일에 맞춘 이름 넷이 통째로 들어오면 그걸 지우고 고치는 게
            // 처음부터 적는 것보다 오래 걸렸다. 순서만 보여주고 적는 건 사람이 한다.
            Text("일이 굴러가는 순서입니다 — 정하고 → 펼치고 → 몰입해서 → 바로.\n그대로 따를 필요는 없어요. 위 빈 줄에 내 말로 적으면 됩니다.")
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
        // 몫을 재는 분모는 잎(실제로 하는 단계)들의 합이다. 중간 묶음까지 더하면 두 번 센다.
        let totalLeafHours = tree.leaves(of: root).reduce(0) { $0 + $1.durationHours }
        return Section {
            ForEach(rows, id: \.item.id) { row in
                StepRow(item: row.item,
                        depth: row.depth,
                        isCurrent: row.item.dragToken == currentStepToken,
                        hasChildren: tree.hasChildren(row.item),
                        progress: tree.progress(of: row.item),
                        share: share(of: row.item, total: totalLeafHours),
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
        .spotlightAnchor(guide == .writeStep)
        .id(Self.newRowID)
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
                                     sortIndex: tree.nextSortIndex(under: parent))
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
    /// 이 단계가 이 할 일 전체에서 차지하는 몫(0...1). 잎이 아니면 nil.
    let share: Double?
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

            // 이 단계가 전체에서 얼마나 되는지. 시간을 직접 적게 된 뒤로는
            // 이 숫자가 "어디를 쪼개야 하나"를 바로 말해준다.
            if let share {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                    Text(formatDuration(item.durationHours))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
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
    @State private var hours: Double = TodoTree.defaultStepHours

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("단계 이름", text: $title)
                }
                Section {
                    Stepper(value: $hours, in: 0.25...8, step: 0.25) {
                        HStack {
                            Text("소요시간")
                            Spacer()
                            Text(formatDuration(hours))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("한 자리에서 닫히는 크기로 잘라 두세요. 두 시간을 넘으면 하다 말게 됩니다.")
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
                hours = item.durationHours
            }
        }
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        item.title = trimmed
        item.durationHours = hours
        onSave()
        dismiss()
    }
}
