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
    @State private var newTitle = ""
    /// 새 단계의 속성. 목록 화면의 빈 줄과 같은 키를 써서, 어디서 적든 지난번 값이 따라온다.
    @State private var editing: BacklogItem?
    @State private var editingTitle = ""
    /// 무지개에 그어질 기간.
    /// 더 쪼개러 들어갈 단계. 그 단계가 제 상세 화면의 주인이 되어 다시 쪼개진다.
    @State private var pushedStep: BacklogItem?
    @State private var periodStart = Date()
    @State private var periodEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    /// 지금 무지개에 줄이 그어져 있는지.
    @State private var hasPeriod = false

    // 처음 한 번만 — 쪼개는 법을 직접 해보게 한다 (→ TodoSplitOnboarding.swift).
    @AppStorage(AppSettingsKey.hasSeenSplitOnboarding) private var hasSeenSplitOnboarding = false
    @State private var guide: SplitGuideStep?
    @State private var showingSplitMeaning = false
    /// 분류를 만들고 고치는 시트 (→ CategoryManagerView.swift).
    @State private var showingCategoryManager = false
    /// 이름·소요시간·기간·분류를 정하는 시트. 카드를 눌러야 열린다 —
    /// 한 번 정하고 나면 일하는 내내 볼 것이 아니라서 화면에 깔아 두지 않는다.
    @State private var showingSettings = false
    /// 쪼개기 도우미 — 목록에 펼쳐 두지 않고 눌러서 연다.
    @State private var showingSplitHelper = false
    /// 시트 안 '세부 단계' 빈 줄. 목록의 빈 줄과 상태를 나눠 쓰면 두 줄이 서로 커서를 뺏는다.
    @State private var sheetStepTitle = ""
    @FocusState private var inputFocused: Bool
    @FocusState private var sheetStepFocused: Bool

    private var tree: TodoTree { TodoTree(allItems) }

    /// 단계 목록 맨 아래 빈 줄의 id — 키보드가 올라올 때 그 줄로 스크롤하기 위해.
    private static let newRowID = "step.newRow"
    private static let headerRowID = "step.header"

    private var rows: [(item: BacklogItem, depth: Int)] {
        // 최상위 할 일 자체는 헤더가 보여주므로 목록에는 그 아래만 그린다.
        Array(tree.flattened(from: root).dropFirst())
    }

    /// 구성 전체에 대한 조언 (조각 시간 연구 기반).
    private var hints: [SplitHint] {
        let tree = self.tree
        let leaves = tree.hasChildren(root) ? tree.leaves(of: root) : []
        return TodoSplitAdvisor.hints(rootTitle: root.title,
                                      steps: leaves.map { ($0.title, $0.durationHours, $0.fragmentPick) })
    }

    var body: some View {
        ScrollViewReader { proxy in
        List {
            // 맨 위는 **요약 카드 하나**다. 이 일이 지금 어디까지 왔는지가 주인공이고,
            // 정해 둔 것(시간·기간·분류)은 그 아래 작은 칩으로 조용히 선다.
            //
            // 예전에는 이름·소요시간·시작/끝·분류를 펼친 채로 맨 위에 두었다. 정할 때는
            // 맞는 자리였는데, 한 번 정하고 나면 일하는 내내 그 다섯 줄을 지나야 단계가
            // 나왔다. 정하는 일은 처음 한 번이고 들여다보는 일은 매번이다 — 매번 오는 것이
            // 위에 서야 한다. 고치는 자리는 카드를 눌러 시트로 온다.
            Section { summaryCard.id(Self.headerRowID) }

            // 팁은 한 번에 하나만. 둘 다 뜨면 단계를 보러 들어온 화면이
            // 설명 카드 두 장으로 덮인다. 이 할 일에 대한 조언을 먼저 내고,
            // 그걸 닫은 뒤에 비중 규칙을 한 번 설명한다.
            if !rows.isEmpty {
                if showsSplitHint { splitHintTip } else { shareSplitTip }
            }
            // 단계가 아직 없어도 이 섹션은 그린다 — 그 안의 빈 줄이 '첫 단계를 적는 자리'다.
            stepsSection
            // 뼈대는 계속 둔다. 적다 말고 "다음에 뭐가 오지?" 할 때 되짚을 자리가 있어야 한다.
            // 다만 **펼쳐 두지는 않는다** — 아래를 참고하는 일은 가끔이고, 그 네 줄이 늘
            // 깔려 있으면 내가 적은 단계와 뼈대가 한 화면에서 섞여 보인다.
            templateButton
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
        .sheet(isPresented: $showingSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showingSplitHelper) {
            splitHelperSheet
        }
        .fullScreenCover(isPresented: $showingSplitMeaning) {
            SplitMeaningView { showingSplitMeaning = false }
        }
        .task { startGuideIfNeeded() }
        }
        .navigationTitle(root.title)
        .navigationBarTitleDisplayMode(.inline)
        // 단계를 또 쪼개는 자리는 **그 단계의 상세 화면**이다. 같은 화면이 한 층 아래로
        // 다시 열리므로, 세 번째 층도 네 번째 층도 같은 손짓으로 이어진다.
        .navigationDestination(item: $pushedStep) { step in
            TodoDetailView(root: step)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
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
            // 묶음은 시간도 조각 판정도 제 것이 없다 — 시간은 아래 단계들의 합이고,
            // 판정은 그 안의 단계들이 답한다. 그래서 묶음에서는 이름과 자리만 고친다.
            // (묶음의 labelRaw 자리는 단계 순서가 쓰고 있어, 여기서 판정을 쓰면 그걸 지운다.)
            StepEditSheet(item: item,
                          isGroup: tree.hasChildren(item),
                          // 끌어서 옮기는 게 본길이지만, 손이 미끄러지는 자리이기도 하고
                          // 끌기 자체가 안 되는 상황(스위치 컨트롤 등)도 있다.
                          // 자리를 한 칸씩 옮기는 길은 여기 남겨 둔다.
                          siblingPosition: siblingPosition(of: item),
                          onMoveUp: { move(item, by: -1) },
                          onMoveDown: { move(item, by: 1) }) { save() }
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
        // 기간을 정하는 문이 카드로 옮겨왔으므로, 기간 차례에도 카드를 짚는다.
        case .header, .period:   target = Self.headerRowID
        case .intro, .writeStep: target = Self.newRowID
        }
        withAnimation {
            proxy.scrollTo(target, anchor: (step == .header || step == .period) ? .top : .center)
        }
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

    // MARK: - 요약 카드

    /// 이 일이 지금 어디까지 왔고, 무엇으로 정해져 있는지 — 한 장으로.
    ///
    /// 누르면 이름·소요시간·기간·분류를 정하는 시트가 열린다(→ `settingsSheet`).
    /// 정하는 일은 처음 한 번이고 들여다보는 일은 매번이다. 그래서 매번 오는 것(단계가
    /// 어디까지 왔나 · 지금 뭘 하면 되나)이 카드의 큰 자리를 쓰고, 한 번 정한 것들은
    /// 아래 작은 칩으로 물러난다. 아직 아무것도 안 정한 일은 빈 카드로 서서
    /// "눌러서 정하라"고만 말한다 — 처음 들어온 사람에게 서식 다섯 줄을 들이밀지 않는다.
    ///
    /// 예전에는 이름·소요시간·시작/끝·분류가 펼친 채로 맨 위에 있었다. 정할 때는 맞는
    /// 자리였지만, 정하고 난 뒤에는 단계를 보러 올 때마다 지나야 하는 벽이 됐다.
    private var summaryCard: some View {
        let stepCount = tree.leafCount(of: root)
        let doneCount = tree.doneLeafCount(of: root)

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                showingSettings = true
            } label: {
                cardFace(stepCount: stepCount, doneCount: doneCount)
            }
            .buttonStyle(.plain)
            .accessibilityHint("눌러서 이름·소요시간·기간·분류 고치기")

            // 지금 할 단계에 경고가 있으면 그것만 팁으로. (다른 줄에는 안 깐다)
            // 카드를 누르는 자리 **밖**에 둔다 — 팁에도 손댈 곳이 있어서, 안에 있으면
            // 팁을 닫으려다 설정 시트가 열린다.
            if let step = tree.currentStep(of: root),
               !tree.hasChildren(step),
               let warning = TodoSplitAdvisor.advice(title: step.title,
                                                     durationHours: step.durationHours,
                                                     pick: step.fragmentPick).warning {
                TipView(StepWarningTip(warning: warning))
            }
        }
        .padding(.vertical, 4)
        // 안내가 기간을 짚을 때도 이 카드를 짚는다 — 기간으로 가는 문이 여기라서.
        .spotlightAnchor(guide == .header || guide == .period)
        .task {
            editingTitle = root.title
            if let period = TodoEventBridge.shared.period(for: root) {
                periodStart = period.start
                periodEnd = period.end
                hasPeriod = true
            }
        }
    }

    /// 카드에서 **누르는 면**. 여기 있는 것은 전부 '보는 것'이고, 손대는 것은 시트에 있다.
    private func cardFace(stepCount: Int, doneCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(root.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Image(systemName: "square.and.pencil")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

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
                }
                ProgressView(value: tree.progress(of: root))
                    .tint(doneCount == stepCount ? .green : .accentColor)
            }

            // ⚠️ `currentStep`은 자식이 없으면 **자기 자신**을 돌려준다. 안 쪼갠 일에서
            //    그것만 보고 세우면 카드가 제 이름을 위아래로 두 번 적는다 —
            //    "제목 / 지금 단계 / 같은 제목". 쪼갠 일에만 이 자리가 있다.
            if tree.hasChildren(root), let step = tree.currentStep(of: root) {
                // 지금 할 단계. 기호 하나로는 '지금 할 것'이라는 뜻이 안 읽혀서 말로 적는다.
                // 순서가 없는 묶음에서는 '단계'가 아니라 '집을 것'이다 — 앱이 조각인 것을
                // 앞에 세웠을 뿐, 차례가 아니다.
                VStack(alignment: .leading, spacing: 6) {
                    Text(root.stepOrder == .free ? "지금 집을 것" : "지금 단계")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))

                    Text(step.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if tree.hasChildren(root) {
                Label("모든 단계를 마쳤습니다", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            if isBlank(stepCount: stepCount) {
                // 빈 카드. 아무것도 안 정한 일에 칩 세 개가 "안 잡음 · 없음 · 미분류"로
                // 서 있으면, 정하라는 말이 아니라 못 한 것 셋으로 읽힌다.
                Text("눌러서 소요시간·기간·분류를 정하세요")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                settingChips
            }
        }
        .contentShape(Rectangle())
    }

    /// 이름 말고는 아무것도 안 정했고 단계도 없는가 — 그러면 카드는 빈 카드로 선다.
    private func isBlank(stepCount: Int) -> Bool {
        stepCount == 0 && !hasPeriod && root.durationHours <= 0 && root.categoryID == nil
    }

    /// 한 번 정하고 나면 다시 볼 일이 드문 것들. 작게, 한 줄로.
    private var settingChips: some View {
        let hours = tree.hasChildren(root) ? tree.totalHours(of: root) : root.durationHours
        return HStack(spacing: 6) {
            chip(icon: "clock",
                 text: hours <= 0 ? "시간 안 잡음" : formatDuration(hours),
                 tint: .secondary,
                 dim: hours <= 0)
            if !isSubStep {
                chip(icon: "rainbow",
                     text: periodChipText,
                     tint: .accentColor,
                     dim: !hasPeriod)
            }
            if let category = category(of: root) {
                chip(icon: category.iconName, text: category.name, tint: category.displayColor, dim: false)
            } else {
                chip(icon: "tag", text: "미분류", tint: .secondary, dim: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// 무지개 칩은 '언제의 일인가'를 말한다 — 목록의 배지와 같은 말이어야 한다
    /// (→ `TodoWhen`). 날짜 두 개는 시트에서 본다.
    private var periodChipText: String {
        switch currentWhen {
        case .backlog: return "날짜 없음"
        case .overdue: return "밀림"
        case .today: return "오늘"
        case .thisWeek, .later:
            let calendar = Calendar.current
            let left = calendar.dateComponents([.day],
                                               from: calendar.startOfDay(for: Date()),
                                               to: calendar.startOfDay(for: periodEnd)).day ?? 0
            return left <= 0 ? "오늘까지" : "D-\(left)"
        }
    }

    private func chip(icon: String, text: String, tint: Color, dim: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(dim ? Color.secondary.opacity(0.7) : tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.secondary.opacity(dim ? 0.07 : 0.12)))
    }

    // MARK: - 이 할 일 (목록에서 못 정한 것들을 여기서 정한다)

    /// 정하는 자리. 카드를 눌러야 열린다.
    ///
    /// 화면에 깔아 두지 않는 이유는 하나다 — 기간·시간·분류는 **처음 한 번** 정하는 것이고,
    /// 그 뒤로 이 화면에 오는 이유는 단계다. 매번 오는 것 위에 한 번 쓰는 것을 얹으면
    /// 일하는 내내 그것을 지나야 한다.
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                settingsSection
                sheetStepsSection
            }
            .navigationTitle("이 할 일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        commitTitle()
                        showingSettings = false
                    }
                }
            }
            // 분류를 만드는 시트는 **이 시트 위**에서 열려야 한다. 아래 화면에 붙여 두면
            // 이 시트에 덮여 열리지 않는다.
            .sheet(isPresented: $showingCategoryManager) {
                // 이 화면은 이미 할 일 스토어에서 돌고 있으므로 컨테이너를 따로 안 붙인다.
                CategoryManagerView()
            }
        }
    }

    /// 시트 맨 아래에서 이어 적는 세부 단계.
    ///
    /// 기간을 정하다 보면 "그래서 뭐부터 하지"가 이어서 떠오른다. 창을 닫고 다시 아래로
    /// 스크롤해 적게 하면 그 사이에 샌다. 붙는 자리는 상세 화면의 '단계' 목록과 하나다 —
    /// 여기서는 맨 바깥 단계만 이어 적고, 순서 바꾸기·하위 단계는 거기서 한다.
    private var sheetStepsSection: some View {
        let steps = tree.children(of: root)
        return Section {
            ForEach(steps) { step in
                HStack(spacing: 10) {
                    Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(step.isCompleted ? Color.green : Color.secondary)
                    Text(step.title)
                        .strikethrough(step.isCompleted)
                        .foregroundStyle(step.isCompleted ? Color.secondary : Color.primary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(formatDuration(tree.totalHours(of: step)))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .onDelete { offsets in
                for index in offsets { remove(steps[index]) }
            }

            HStack(spacing: 10) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
                TextField("세부 단계", text: $sheetStepTitle)
                    .focused($sheetStepFocused)
                    .submitLabel(.return)
                    .onSubmit(addSheetStep)
            }
        } header: {
            Text("세부 단계")
        } footer: {
            Text(steps.isEmpty
                 ? "이 일을 이루는 단계를 위 빈 줄에 순서대로 적어보세요. 엔터를 치면 다음 줄로 이어집니다."
                 : "시간은 아래에서 위로 쌓여 이 할 일의 소요시간이 됩니다.\n순서 바꾸기·하위 단계는 상세 화면의 ‘단계’에서 합니다.")
        }
    }

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

            // 5분에 집을 수 있는 일인가 — **사람이 직접 하는 말**이다. 앱도 제목과 시간을
            // 보고 짐작하지만(→ TodoSplitAdvisor), 짐작이 틀렸을 때 사람이 답할 자리가
            // 있어야 한다. 쪼갠 일에서는 지금 할 단계에 붙는다.
            Toggle(isOn: markedBinding) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(TodoView.nowGreen)
                    Text("바로 하면 되는 일")
                }
            }

            // 날짜는 **그 일 전체**에 붙는다. 단계를 열고 들어온 화면에서는 안 묻는다 —
            // 단계마다 기간이 생기면 무지개에 한 일이 여러 줄로 그어지고,
            // '언제 할 일인가'의 답이 한 일 안에서 갈라진다 (→ TodoWhen).
            if !isSubStep { periodRows }
            categoryPicker
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
            Divider()
            // 만드는 자리는 고르는 자리 안에 있어야 한다. 분류를 정하려다 '없네'를
            // 알게 되는 것이므로, 여기서 설정까지 다녀오게 하면 하려던 일을 잊는다.
            Button {
                showingCategoryManager = true
            } label: {
                Label(categories.isEmpty ? "분류 만들기" : "분류 만들기·고치기",
                      systemImage: "tag")
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

    /// '바로 하면 되는 일' 표시. 켜면 목록 맨 위 칸에 서고, 차례를 안 기다린다.
    ///
    /// 표시가 붙는 자리는 **그 줄 자체**다 — 쪼갠 일이면 지금 할 단계에.
    /// (묶음에 직접 쓰면 그 자리(`labelRaw`)에 있는 단계 순서를 지운다
    /// → BacklogItem+StepOrder.swift)
    private var markedBinding: Binding<Bool> {
        Binding(
            get: { tree.markedStep(of: root) != nil },
            set: { on in
                let target: BacklogItem
                if tree.hasChildren(root) {
                    guard let step = tree.currentStep(of: root) else { return }
                    target = step
                } else {
                    target = root
                }
                withAnimation {
                    target.setFragmentAnswer(on ? true : nil, for: .start)
                    target.setFragmentAnswer(on ? true : nil, for: .closing)
                    save()
                }
            }
        )
    }

    /// 이 화면의 주인이 더 큰 일의 **한 단계**인가. (더 쪼개러 들어온 화면)
    /// 날짜처럼 일 전체에 붙는 것은 여기서 묻지 않는다.
    private var isSubStep: Bool { tree.parent(of: root) != nil }

    /// **이 일이 언제의 일인가.** 시작일과 끝나는 날, 그 하나로 정한다.
    ///
    /// 목록의 '오늘 · 이번 주 · 밀림'은 전부 이 날짜에서 나온다 (→ `TodoWhen`).
    /// 예전에는 목록 스와이프에 '오늘'과 '이번 주로'가 따로 있었다. 오늘인지는 맥 계획
    /// 블록이, 이번 주인지는 할 일의 주차가 들고 있어서 같은 것을 두 군데서 말한 셈이고,
    /// 둘이 어긋나면 화면이 어느 쪽이 맞는지 답하지 못했다. 이제 답하는 자리는 여기 하나다.
    ///
    /// 아무것도 안 정하면 백로그다 — 갓 적은 일은 전부 여기서 시작한다.
    @ViewBuilder
    private var periodRows: some View {
        HStack {
            Text("언제")
            Spacer()
            Text(whenSummary)
                .foregroundStyle(whenTint)
        }

        // 자주 쓰는 두 답은 버튼 하나로. 날짜를 두 번 굴려 오늘을 고르게 하면
        // '오늘 할 일'이라고 적는 데 손이 넷 든다.
        HStack(spacing: 8) {
            whenChip("오늘", isOn: currentWhen == .today) {
                setPeriod(start: Date(), end: Date())
            }
            whenChip("이번 주", isOn: currentWhen == .thisWeek) {
                // 이번 주 일요일까지. 끝나는 날이 이 일이 언제 일인지를 정한다 (→ TodoWhen).
                setPeriod(start: Date(), end: Date.endOfThisWeek)
            }
            whenChip("안 정함", isOn: !hasPeriod) {
                TodoEventBridge.shared.clearRainbow(for: root)
                hasPeriod = false
            }
            Spacer(minLength: 0)
        }
        .buttonStyle(.plain)

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

    /// 지금 이 할 일이 서 있는 자리. 날짜 두 줄을 읽지 않고도 한눈에 답이 보여야 한다.
    private var currentWhen: TodoWhen {
        TodoWhen.of(hasPeriod ? (periodStart, periodEnd) : nil)
    }

    private var whenSummary: String {
        switch currentWhen {
        case .backlog: return "백로그"
        case .today: return "오늘"
        case .thisWeek: return "이번 주"
        case .later: return "다음 주 뒤"
        case .overdue: return "밀림"
        }
    }

    private var whenTint: Color {
        switch currentWhen {
        case .overdue: return .red
        case .today: return .orange
        case .thisWeek: return .primary
        case .later, .backlog: return .secondary
        }
    }

    private func whenChip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isOn ? Color.accentColor.opacity(0.15)
                                                : Color.secondary.opacity(0.12)))
        }
    }

    /// 날짜를 한 번에 정한다. 안 그어져 있던 일도 여기서 그어진다 —
    /// '오늘'을 눌렀는데 무지개에 안 올라가면 눌러도 아무 일이 없는 것처럼 보인다.
    private func setPeriod(start: Date, end: Date) {
        periodStart = start
        periodEnd = max(start, end)
        commitPeriod(force: true)
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

    // MARK: - 쪼개기 도우미 (눌러서 보는 뼈대)

    /// 목록 아래 한 줄. 누르면 모달이 열린다.
    ///
    /// 예전에는 뼈대 네 줄이 단계 목록 아래에 늘 펼쳐져 있었다. 되짚을 때는 좋았지만,
    /// 내가 적은 단계와 남이 준 보기가 한 화면에 나란히 서서 어디까지가 내 것인지
    /// 매번 다시 읽어야 했다. 참고는 필요할 때만 여는 것이 맞다.
    private var templateButton: some View {
        Section {
            Button {
                showingSplitHelper = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("쪼개기 도우미")
                            .foregroundStyle(.primary)
                        Text("어떤 순서로 쪼개면 되는지 보기")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
    }

    /// 뼈대를 **촘촘하게** 펼쳐 놓는 자리. 목록에서는 네 줄로 줄여 보여줬지만,
    /// 여기서는 그 네 마디가 왜 그 순서인지까지 적는다 — 순서만 보고 따라 적으면
    /// 남의 일에 맞춘 이름 넷이 되고, 이유를 알면 내 일의 이름이 나온다.
    private var splitHelperSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("일은 네 마디로 굴러갑니다")
                        .font(.title3.weight(.semibold))
                    Text("정하고 → 펼치고 → 몰입해서 → 바로.\n앞 마디가 안 끝나면 뒤 마디는 열리지 않습니다. 막혀 있을 때는 대개 지금 마디가 아니라 **그 앞 마디**가 안 끝나 있는 것입니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(Array(TodoSplitAdvisor.template(for: root.title).enumerated()), id: \.offset) { index, step in
                        helperRow(index: index, step: step)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        helperNote(icon: "bolt.fill", tint: TodoView.nowGreen,
                                   title: "5분에 집을 수 있는 마디를 하나는 두세요",
                                   body: "2번(펼치기)과 4번(마무리)이 대개 그렇습니다. 짬이 났을 때 집을 게 하나도 없으면, 그 일은 큰 시간이 날 때까지 아무 일도 안 일어납니다.")
                        helperNote(icon: "clock", tint: .secondary,
                                   title: "한 마디는 한 자리에서 닫히는 크기로",
                                   body: "두 시간을 넘기면 하다 말게 됩니다. 넘을 것 같으면 그 마디를 다시 쪼개세요 — 단계를 길게 누르면 그 단계만 따로 쪼갤 수 있습니다.")
                        helperNote(icon: "pencil", tint: .accentColor,
                                   title: "그대로 옮겨 적지는 마세요",
                                   body: "이 네 줄을 한 번에 넣어주는 버튼이 있었는데, 남의 일에 맞춘 이름 넷을 지우고 고치는 게 처음부터 적는 것보다 오래 걸렸습니다. 순서만 빌리고 이름은 내 말로 적으세요.")
                    }
                }
                .padding(20)
            }
            .navigationTitle("쪼개기 도우미")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { showingSplitHelper = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func helperRow(index: Int, step: TodoSplitAdvisor.TemplateStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(step.title)
                        .font(.body.weight(.semibold))
                    if let mark = helperMark(for: index) {
                        Image(systemName: mark.icon)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(mark.tint)
                    }
                }
                Text(step.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 그 마디가 대개 조각인지 덩어리인지. 뼈대는 고정된 네 줄이라 자리로 안다
    /// (→ `TodoSplitAdvisor.template`). 줄이 늘면 표식 없이 그냥 선다.
    private func helperMark(for index: Int) -> (icon: String, tint: Color)? {
        switch index {
        case 1, 3: return ("bolt.fill", TodoView.nowGreen)   // 펼치기 · 마무리 = 조각
        case 2: return ("moon.zzz", .indigo)                 // 실제로 하기 = 몰입
        default: return nil
        }
    }

    private func helperNote(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
                        // 순서가 없는 묶음 안에서는 '지금 차례'라는 게 없다.
                        // 앱이 앞에 세운 것이라도 화살표를 달지 않는다 —
                        // 기다릴 차례가 없는데 차례처럼 보이면 그게 거짓말이 된다.
                        isCurrent: row.item.dragToken == currentStepToken
                            && tree.parent(of: row.item)?.stepOrder != .free,
                        hasChildren: tree.hasChildren(row.item),
                        progress: tree.progress(of: row.item),
                        share: share(of: row.item, total: totalLeafHours),
                        // 잎(실제로 하는 단계)만 판정한다. 묶음은 그 안의 단계들이 답한다.
                        advice: tree.hasChildren(row.item)
                            ? nil
                            : TodoSplitAdvisor.advice(title: row.item.title,
                                                      durationHours: row.item.durationHours,
                                                      pick: row.item.fragmentPick),
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
                            // 묶음에는 제 시간도 판정도 없다. 거기서 고치는 건 이름이다.
                            Label(tree.hasChildren(row.item) ? "이름" : "시간·조각 판정",
                                  systemImage: "slider.horizontal.3")
                        }
                        .tint(.blue)
                    }
                    // 롱 프레스 = **이 단계를 더 쪼개러 들어가기.**
                    //
                    // 단계를 적다 보면 그중 하나가 여전히 덩어리인 것이 보인다. 그때
                    // 필요한 건 그 줄 아래 한 칸을 더 적는 게 아니라, 그 단계를 **제 일로
                    // 놓고** 다시 쪼개는 것이다. 그래서 여기서 그 단계의 상세로 들어간다.
                    //
                    // ⚠️ 롱 프레스를 이 메뉴가 가져가므로 **끌어서 순서 바꾸기가 막힌다.**
                    //    그래서 위로/아래로를 메뉴 안에 같이 둔다 — 순서를 바꾸는 길이
                    //    사라지면 안 된다. (스와이프의 이름·삭제·하위 단계는 그대로다.)
                    .contextMenu {
                        Button {
                            pushedStep = row.item
                        } label: {
                            Label("더 쪼개기", systemImage: "square.split.2x1")
                        }
                        Divider()
                        Button {
                            move(row.item, by: -1)
                        } label: {
                            Label("위로", systemImage: "arrow.up")
                        }
                        Button {
                            move(row.item, by: 1)
                        } label: {
                            Label("아래로", systemImage: "arrow.down")
                        }
                    }
                    // 메뉴는 눈으로 여는 것이라 VoiceOver로는 잘 안 잡힌다.
                    // 위로/아래로를 접근성 동작으로도 남긴다 (로터의 '동작').
                    .accessibilityAction(named: "위로") { move(row.item, by: -1) }
                    .accessibilityAction(named: "아래로") { move(row.item, by: 1) }
                    .accessibilityAction(named: "더 쪼개기") { pushedStep = row.item }
            }
            .onMove(perform: moveRows)

            // 단계들 바로 아래 빈 줄. 여기에 적고 엔터를 치면 다음 줄로 이어진다.
            newStepRow
                // 적는 줄은 언제나 단계들 맨 아래다. 끌어서 그 위로 보낼 수 없다.
                .moveDisabled(true)
        } header: {
            Text("단계")
        } footer: {
            if rows.isEmpty {
                Text("이 일을 이루는 단계를 위 빈 줄에 순서대로 적어보세요.\n적어 두면 각 단계가 조각인지 덩어리인지는 앱이 먼저 답해 둡니다. 틀렸으면 그 단계를 왼쪽으로 밀어 고치면 됩니다.")
            } else if rows.count > 1 {
                Text("길게 눌러 끌면 순서가 바뀝니다.")
            }
        }
    }

    // ⚠️ '순서대로 / 아무거나'를 **고르는 자리는 없앴다.**
    //
    // 쪼갠 단계가 서로를 기다리는지를 묶음마다 묻던 메뉴가 단계 머리글에 있었는데,
    // 단계를 적으러 온 사람에게 그건 먼저 답해야 할 질문이 아니었다. 대부분의 일은
    // 적은 순서가 곧 하는 순서이고, 아니어도 위에서부터 집으면 그만이다.
    //
    // 값(`BacklogItem.stepOrder`)과 그것을 읽는 쪽(→ TodoTree.currentStep,
    // availableSteps)은 그대로 둔다. 이미 '아무거나'로 정해 둔 묶음이 있는 사람에게
    // 그 뜻이 갑자기 뒤집히면 안 되기 때문이다. 새로 정하는 길만 닫혀 있다.

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

    /// 빈 줄은 언제나 맨 바깥 단계에 붙는다.
    ///
    /// 한 단계를 더 쪼개는 자리는 여기가 아니라 **그 단계의 상세 화면**이다
    /// (롱 프레스 → `pushedStep`). 적는 자리를 하나로 두면 빈 줄이 어디에
    /// 붙는지 매번 확인하지 않아도 된다.
    private var newStepRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)

            TextField("세부 단계", text: $newTitle)
                .focused($inputFocused)
                .submitLabel(.return)
                .onSubmit(addStep)
        }
        .padding(.vertical, 2)
        .spotlightAnchor(guide == .writeStep)
        .id(Self.newRowID)
    }

    // MARK: - 동작

    private func category(of item: BacklogItem) -> BacklogCategory? {
        guard let id = item.categoryID else { return nil }
        return categories.first { $0.uuid == id }
    }

    /// 단계 한 줄을 실제로 만들어 붙인다. 목록의 빈 줄과 시트의 빈 줄이 같이 쓴다.
    /// 빈 제목이면 아무것도 안 하고 false.
    @discardableResult
    private func appendStep(titled raw: String, under parent: BacklogItem) -> Bool {
        let title = raw.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return false }

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
        return true
    }

    /// 빈 줄에서 엔터 = 다 적었다는 뜻이라 키보드를 내린다.
    /// 그 외에는 한 줄을 확정하고, 다시 빈 줄에 커서를 둔 채 이어 적게 한다.
    private func addStep() {
        guard appendStep(titled: newTitle, under: root) else {
            inputFocused = false
            return
        }
        newTitle = ""
        // 팁이 뜨거나 섹션이 바뀌면서 포커스가 풀릴 수 있다. 다음 런루프에 다시 잡는다.
        inputFocused = true
        DispatchQueue.main.async { inputFocused = true }
    }

    /// 시트 안 빈 줄. 여기서는 언제나 맨 바깥 단계로 붙는다.
    private func addSheetStep() {
        guard appendStep(titled: sheetStepTitle, under: root) else {
            sheetStepFocused = false
            return
        }
        sheetStepTitle = ""
        sheetStepFocused = true
        DispatchQueue.main.async { sheetStepFocused = true }
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
    /// 끌어서 놓은 자리로 단계를 옮긴다.
    ///
    /// **형제끼리만 옮긴다.** 목록은 트리를 평평하게 펴서 그린 것이라, 끌어 놓은 자리
    /// 하나로는 '그 줄 다음'인지 '그 줄 안으로'인지를 가릴 수가 없다. 둘을 가르려면
    /// 가로 위치까지 봐야 하고, 그러면 손이 조금만 흔들려도 단계가 남의 묶음 안으로
    /// 들어가 버린다. 그래서 놓은 자리는 **가장 가까운 형제 경계**로 붙는다 —
    /// 다른 묶음의 하위 단계 위에 놓아도 그 묶음 앞이나 뒤로 갈 뿐, 안으로는 안 들어간다.
    ///
    /// 묶음을 끌면 그 아래 단계들도 같이 간다. 매달린 자리(`parentToken`)는 안 건드리고
    /// 형제들의 `sortIndex`만 다시 매기기 때문이다.
    private func moveRows(from source: IndexSet, to destination: Int) {
        let tree = self.tree
        let rows = self.rows
        guard let sourceFlat = source.first, rows.indices.contains(sourceFlat) else { return }
        let moved = rows[sourceFlat].item
        guard let parent = tree.parent(of: moved) else { return }

        var siblings = tree.children(of: parent)
        guard let from = siblings.firstIndex(where: { $0.dragToken == moved.dragToken }) else { return }

        // 평평한 목록의 자리를 형제 사이의 자리로 옮긴다.
        // 앞에 놓인 형제가 몇인지 세면 그게 곧 들어갈 칸이다('이 앞에 넣는다'는 같은 셈법).
        let siblingFlat = siblings.compactMap { sibling in
            rows.firstIndex { $0.item.dragToken == sibling.dragToken }
        }
        let to = siblingFlat.filter { $0 < destination }.count

        // 제자리면 아무것도 안 한다. 제 하위 단계 위에 놓은 경우도 여기서 걸린다
        // (하위 단계는 형제가 아니라 안 세어지므로 to == from + 1 이 된다).
        guard to != from, to != from + 1 else { return }

        siblings.move(fromOffsets: IndexSet(integer: from), toOffset: to)
        for (i, sibling) in siblings.enumerated() { sibling.sortIndex = i }
        withAnimation { save() }
    }

    /// 형제들 사이의 자리. 최상위(부모 없음)면 nil.
    private func siblingPosition(of item: BacklogItem) -> (index: Int, total: Int)? {
        let tree = self.tree
        guard let parent = tree.parent(of: item) else { return nil }
        let siblings = tree.children(of: parent)
        guard let index = siblings.firstIndex(where: { $0.dragToken == item.dragToken }) else { return nil }
        return (index + 1, siblings.count)
    }

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
    /// 두 질문의 판정. 묶음 단계면 nil.
    let advice: StepAdvice?
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
                } else if let advice {
                    // 표식은 한 자리에만. 예전처럼 모든 줄에 이름표를 붙이면
                    // 붙은 것끼리 서로를 가려서 아무것도 안 읽힌다.
                    FragmentMark(advice: advice)
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
    /// 이 줄이 아래 단계를 거느린 묶음인가. 묶음이면 시간·조각 판정을 감춘다.
    let isGroup: Bool
    /// 형제들 사이에서 몇 번째인가 (1부터)와 형제 수. 끝에서는 그 방향 버튼을 막는다.
    let siblingPosition: (index: Int, total: Int)?
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var hours: Double = TodoTree.defaultStepHours
    /// 두 질문에 사용자가 직접 답한 것. 시트를 취소하면 같이 버려진다.
    @State private var pick: FragmentPick = .none

    /// 지금 화면에 적힌 값으로 다시 낸 판정. **저장된 값이 아니라 편집 중인 값을 본다** —
    /// 스테퍼를 올리는 순간 두 번째 답이 '아니오'로 넘어가는 게 이 화면이 가르치는 전부다.
    private var advice: StepAdvice {
        TodoSplitAdvisor.advice(title: title, durationHours: hours, pick: pick)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("단계 이름", text: $title)
                }

                if let position = siblingPosition, position.total > 1 {
                    Section {
                        Button {
                            onMoveUp()
                            dismiss()
                        } label: {
                            Label("위로", systemImage: "arrow.up")
                        }
                        .disabled(position.index <= 1)

                        Button {
                            onMoveDown()
                            dismiss()
                        } label: {
                            Label("아래로", systemImage: "arrow.down")
                        }
                        .disabled(position.index >= position.total)
                    } header: {
                        Text("자리")
                    } footer: {
                        Text("같은 층에서 \(position.total)개 중 \(position.index)번째입니다.\n목록에서 길게 눌러 끌어도 됩니다.")
                    }
                }

                if !isGroup {
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

                    Section {
                        FragmentQuestionRows(title: title, hours: hours, pick: $pick)
                    } header: {
                        Text("이걸 5분에 집어도 되나")
                    } footer: {
                        // 두 답이 합쳐져서 무엇이 되는지를 한 줄로 닫아준다.
                        // 답만 두 개 남겨 두면 "그래서 어쩌라고"가 된다.
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: advice.isFragment ? "bolt.fill" : "clock")
                                .font(.caption)
                                .foregroundStyle(advice.isFragment ? Color.teal : Color.secondary)
                            Text(advice.verdict)
                                .foregroundStyle(advice.isFragment ? Color.teal : Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isGroup ? "묶음" : "단계")
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
                pick = item.fragmentPick
            }
        }
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        item.title = trimmed
        // 묶음의 시간·판정은 쓰지 않는다. 시간은 아래 단계들의 합으로 그때그때 계산되고
        // (→ TodoTree.totalHours), 판정 자리(labelRaw)는 순서가 쓰고 있다.
        if !isGroup {
            item.durationHours = hours
            item.fragmentPick = pick
        }
        onSave()
        dismiss()
    }
}
