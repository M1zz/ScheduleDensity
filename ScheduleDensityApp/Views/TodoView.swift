//
//  TodoView.swift
//  ScheduleDensityApp
//
//  간단한 Todo 리스트.
//  - 내 할 일: CloudKit을 통해 맥앱 '무지개 공방'의 주간 백로그와 동기화
//  - 공유: CKShare(존 전체 공유)로 초대한 사람들과 실시간 공유
//

import SwiftUI
import SwiftData
import TipKit
import CoreData  // NSPersistentStoreRemoteChange (맥에서 온 계획 변경 감지)

struct TodoView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case mine = "내 할 일"
        case family = "공유"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: [SortDescriptor(\BacklogItem.sortIndex), SortDescriptor(\BacklogItem.createdAt)])
    private var allItems: [BacklogItem]
    @Query(sort: [SortDescriptor(\BacklogCategory.sortIndex), SortDescriptor(\BacklogCategory.createdAt)])
    private var categories: [BacklogCategory]

    @State private var tab: Tab = .mine
    @State private var family = FamilyShareStore.shared
    @State private var newTitle = ""
    @State private var showingFamilyShareNotice = false
    @State private var showingLedger = false
    /// 회수 장부는 값을 받고 여는 것 중 하나다 (→ ProEntitlement.swift).
    @State private var purchases = PurchaseManager.shared
    @State private var showingLedgerPaywall = false
    /// '적기'가 잠겼을 때 내는 페이월 (→ ProFeature.editing).
    @State private var editingPaywall = false
    /// 적는 줄이 열려 있는가. + 를 누르면 열리고, 빈 채로 포커스를 잃으면 닫힌다.
    @State private var isAdding = false
    /// 오른쪽 위 + 를 누를 때마다 하나씩 오른다. 값 자체는 뜻이 없고, 바뀌었다는 것만 신호다.
    /// (버튼은 툴바에, 목록은 ScrollViewReader 안에 있어서 서로 직접 못 부른다.)
    @State private var addRequest = 0
    /// 날짜를 직접 고르는 시트를 띄울 대상.
    @State private var deadlinePickerItem: BacklogItem?
    @State private var pickedDeadline = Date()
    /// 무지개에는 걸려 있는데 아직 할 일로 안 가져온 일들 (이번 주에 걸친 것만).
    @State private var rainbowPending: [Event] = []
    /// 지우기 직전에 세우는 물음 (→ TodoDeletion.swift).
    @State private var deletionRequest: TodoDeletionRequest?
    /// 무지개에서 가져와 단계를 적으러 갈 할 일.
    @State private var pushedTodo: BacklogItem?
    /// 지금 무지개에 그어져 있는 기간 (할 일 dragToken → 시작일·끝나는 날).
    /// 일정 스토어는 다른 컨테이너라 @Query로 못 보므로 읽어 와 캐시한다.
    ///
    /// **목록의 거의 모든 판정이 여기서 나온다** — 오늘 할 일인지, 이번 주 일인지,
    /// 밀렸는지, 아직 백로그인지 (→ `TodoWhen`). 사람이 정하는 것은 상세의 날짜 하나뿐이다.
    @State private var periods: [String: (start: Date, end: Date)] = [:]
    @FocusState private var inputFocused: Bool

    // MARK: 번개 안내 (→ BoltOnboarding.swift)
    //
    // 스와이프에서 글자를 뺐으므로, 그 아이콘이 무슨 뜻인지 말해 줄 자리가
    // 목록 어디에도 없다. 처음 한 번은 앱이 직접 짚어 준다.
    @AppStorage(AppSettingsKey.hasSeenBoltOnboarding) private var hasSeenBoltOnboarding = false
    /// 번개 뜻풀이 한 장을 밀어 넣는 중인가 (→ BoltOnboarding.swift).
    @State private var showingBoltMeaning = false

    private let cal = Calendar(identifier: .iso8601)
    private var weekStart: Date { .currentWeekStart }

    /// 목록 맨 아래 빈 줄의 id — 키보드가 올라올 때 그 줄로 스크롤하기 위해.
    private static let newRowID = "todo.newRow"

    // 목록에는 최상위 할 일만 줄로 세운다. 그 안의 단계는 줄 하나 안에서
    // '지금 할 일'로 접혀 보이고, 전체 흐름은 TodoDetailView에서 본다.

    /// 부모-자식 색인. 한 번 만들어 목록·칩·결산이 함께 쓴다.
    /// ⚠️ **감추는 자리는 여기 하나뿐이다** (→ TodoSharing.swift).
    ///    목록·칩·결산이 전부 이 트리에서 나오므로, 여기서 한 번 거르면 어디에도
    ///    안 샌다. 화면마다 조건을 따로 쓰면 반드시 어딘가는 새어 보인다.
    private var tree: TodoTree { TodoTree(allItems.filter(TodoSharing.isVisible)) }

    /// 필터를 걸기 전의 이번 주 줄들 (밀린 것 + 이번 주).
    /// 칩의 셈은 **언제나 이 집합**으로 낸다 — 걸러진 결과로 세면 필터를 켜는 순간
    /// 다른 칩이 0이 되어 사라지고, 되돌아올 길이 없어진다.
    /// 이번 주에 남은 단계들 — 결산 화면에 넘긴다.
    private var remainingSteps: [(title: String, hours: Double)] {
        let tree = self.tree
        // '그냥 하면 되는 것'은 빼고 센다. 결산은 이번 주에 쓴/쓸 시간을 보는 자리인데,
        // 0시간짜리 줄이 섞이면 세는 개수만 부풀고 시간은 그대로다.
        return unfilteredItems
            .filter { !(tree.isErrand($0) && periods[$0.dragToken] == nil) }
            .map { item in
                let step = tree.currentStep(of: item) ?? item
                return (step.title, step.durationHours)
            }
    }

    private var unfilteredItems: [BacklogItem] {
        let tree = self.tree
        return carryoverItems(tree) + openItems(tree)
    }

    /// 이번 주, 아직 안 한 일.
    private func openItems(_ tree: TodoTree) -> [BacklogItem] {
        tree.roots.filter { !$0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
    }

    /// 이번 주에 완료한 일 (최근 완료가 위).
    private func doneItems(_ tree: TodoTree) -> [BacklogItem] {
        tree.roots
            .filter { $0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// 지난 주에 못 하고 남은 일. 목록에서는 이번 주 것과 한 줄기로 섞인다.
    ///
    /// 앱을 열면 이 줄들의 주차는 이번 주로 끌려온다(→ `pullForwardOverdueWeeks`).
    /// 그래서 여기 걸리는 것은 **아직 안 끌어온 순간의 줄들**뿐이다 — 화면이 뜨는 사이에도
    /// 목록에서 빠지지 않게 남겨 둔다.
    private func carryoverItems(_ tree: TodoTree) -> [BacklogItem] {
        tree.roots.filter {
            !$0.isCompleted && $0.weekStartDate < weekStart && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart)
        }
    }

    /// 공유가 실제로 있을 때만 '공유'를 보여준다.
    /// 공유를 시작하지도, 받은 항목도 없으면 빈 목록 한 칸만 남으므로
    /// 세그먼트째로 감추고 '내 할 일'만 쓴다. 초대 링크로 참여하거나
    /// 공유를 시작하면 그 즉시 다시 나타난다.
    private var showsFamilyTab: Bool {
        family.isSharing || !family.items.isEmpty
    }

    /// 공유가 감춰진 동안에는 어떤 상태가 남아 있어도 '내 할 일'로 본다.
    private var visibleTab: Tab {
        showsFamilyTab ? tab : .mine
    }

    var body: some View {
        NavigationStack {
            Group {
                switch visibleTab {
                case .mine: myList
                case .family: familyList
                }
            }
            .navigationTitle(visibleTab == .mine ? "이번 주 할 일" : "공유 할 일")
            // 세그먼트를 바 아래로 내리면서 제목도 인라인으로 바꾼다.
            // 큰 제목을 그대로 두면 세그먼트 뒤에 깔려 위쪽에 빈 띠만 남는다.
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $deadlinePickerItem) { item in
                deadlinePickerSheet(for: item)
            }
            .toolbar {
                if visibleTab == .mine {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            if purchases.isUnlocked { showingLedger = true }
                            else { showingLedgerPaywall = true }
                        } label: {
                            Image(systemName: purchases.isUnlocked ? "list.clipboard" : "lock")
                        }
                        .accessibilityLabel(purchases.isUnlocked ? "이번 주 결산" : "이번 주 결산, 잠김")
                    }
                }
                if visibleTab == .family {
                    ToolbarItem(placement: .topBarTrailing) { familyShareMenu }
                }
                // 적는 자리는 목록 맨 위에 열린다. 그래서 버튼도 그 바로 위,
                // 오른쪽 끝에 둔다 — 누른 곳과 생긴 곳이 한 눈에 들어와야
                // "눌렀더니 줄이 하나 내려왔다"로 읽힌다.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addRequest += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("할 일 추가")
                }
            }
            // 세그먼트를 네비게이션 바(.principal) 대신 그 아래에 둔다.
            // .principal은 leading/trailing을 뺀 '남은 공간'의 가운데에 놓여서,
            // 공유 탭에서만 나타나는 공유 버튼 때문에 그때만 왼쪽으로 밀렸다.
            // 툴바 밖에 두면 두 탭 모두 항상 화면 정중앙이다.
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    tabPicker
                }
            }
            // 뜻풀이는 덮어 씌우지 않고 밀어 넣는다 (→ BoltOnboarding.swift).
            .navigationDestination(isPresented: $showingBoltMeaning) {
                BoltMeaningView(showsDoneButton: false) { }
            }
        }
        .sheet(isPresented: $showingLedger) {
            WeekLedgerView(weekStart: weekStart, work: remainingSteps)
        }
        .confirmsTodoDeletion($deletionRequest)
        .paywall(for: .ledger, isPresented: $showingLedgerPaywall)
        .paywall(for: .editing, isPresented: $editingPaywall)
        .alert("할 일 공유 시작", isPresented: $showingFamilyShareNotice) {
            Button("공유 시작") {
                Task { await family.startSharing() }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("초대 링크를 받은 사람은 누구나 이 목록에 참여해 함께 읽고 쓸 수 있습니다.\n링크는 함께할 사람에게만 보내주세요.")
        }
        .navigationDestination(item: $pushedTodo) { item in
            TodoDetailView(root: item)
        }
        .task {
            pullForwardOverdueWeeks()
            refreshPeriods()
            refreshRainbowPending()
            syncWidget()
            refreshTipRules()
            await family.refresh()
        }
        .onChange(of: allItems.count) { _, _ in refreshTipRules() }
        // 공유를 중지하거나 나가면 세그먼트가 사라지므로 선택도 '내 할 일'로 되돌린다.
        .onChange(of: showsFamilyTab) { _, shows in
            if !shows { tab = .mine }
        }
        // 제어센터에서 '할 일 적기'를 눌렀다 (→ QuickTodoBridge.swift).
        // 콜드 런치는 이 .task 가, 이미 떠 있으면 아래 알림이 받는다.
        .task { consumeQuickAddRequest() }
        .onReceive(NotificationCenter.default.publisher(for: .quickTodoAddRequested)) { _ in
            consumeQuickAddRequest()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                consumeQuickAddRequest()
                // 맥 '무지개 공방'에서 넘어온 CloudKit 변경도 위젯에 반영한다.
                // 날이 바뀌었을 수 있으므로 주차와 오늘 계획도 다시 맞춘다.
                pullForwardOverdueWeeks()
                refreshPeriods()
                refreshRainbowPending()
                syncWidget()
                Task { await family.refresh() }
            }
        }
        // 맥에서 배정/해제한 결과가 CloudKit으로 내려오면 위젯도 따라 바뀐다.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            syncWidget()
        }
        // 상세에서 날짜를 고치면 '오늘 · 이번 주 · 밀림'이 통째로 다시 답해져야 한다.
        .onReceive(NotificationCenter.default.publisher(for: .todoPeriodDidChange)) { _ in
            withAnimation { refreshPeriods() }
        }
    }

    @ViewBuilder
    private var tabPicker: some View {
        if showsFamilyTab {
            Picker("목록", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    // MARK: - 내 할 일
    //
    // ⚠️ 셈은 목록 아래 한 줄로만 낸다(→ countLine). 여기서 시간을 합치지 말 것 —
    //    합계는 조각과 덩어리를 한 숫자로 접어 서로 환산되는 것처럼 보이게 한다.
    //    15분짜리 넷과 1시간짜리 하나를 더해 "2시간"이라고 적으면, 그 2시간은
    //    어느 쪽으로도 쓸 수 없는 숫자다 (Schulte 2014 · Whillans 2020).

    private var myList: some View {
        let tree = self.tree
        let carryover = carryoverItems(tree)
        let open = openItems(tree)
        // ⚠️ 이번 주 할 일은 **한 줄기**다. 섹션으로 가르지 않는다.
        //
        // 예전에는 '바로 하면 되는 일 / 그냥 하면 되는 것 / 시간을 잡은 일'을 각각 섹션으로
        // 세웠는데, 머리글과 설명이 줄보다 많아졌다. 할 일 다섯 개를 보려고 이름표 세 개를
        // 매번 읽는 꼴이다. 갈라야 하는 건 맞지만, 가르는 일은 **순서와 색**으로 충분하다:
        //
        //   1. 바로 하면 되는 일 — 표시해 둔 것. 청록. 5분이 나면 눈이 여기 먼저 닿는다.
        //   2. 그냥 하면 되는 것 — 시간을 안 잡은 줄. 옅은 회색. 그 아래가 적는 자리다.
        //   3. 시간을 잡은 일   — 바탕색 그대로.
        //   4. 완료           — 맨 아래, 흐리게.
        //
        // 칸 **안**에서는 급한 순으로 선다 — 밀림 → 오늘 → 이번 주 → 그 뒤 → 백로그,
        // 같은 급함이면 번개 먼저 (→ `urgentFirst`). 칸이 '무엇부터 볼까'를 갈랐다면,
        // 이 규칙은 그 칸 안에서 '무엇이 먼저 급한가'를 갈라 준다. 둘 다 없으면 목록은
        // 적은 순 그대로라, 줄이 늘수록 아무 뜻도 없는 순서가 된다.
        //
        // (지난 주에 밀린 일도 같은 이유로 안 가른다 — 주차는 앱이 알아서 이번 주로
        //  끌어오고(→ pullForwardOverdueWeeks), 밀렸다는 사실은 날짜가 말한다.)
        let (allErrands, allMarked, allItems) = splitErrands(carryover + open, tree: tree)
        let errands = urgentFirst(allErrands, tree: tree)
        // 안 쪼갠 일 + 쪼갠 일 안의 '바로' 단계.
        let marked = urgentFirst(allMarked + markedPicks(carryover + open, tree: tree), tree: tree)
        let items = urgentFirst(allItems, tree: tree)
        let done = doneItems(tree)

        return ScrollViewReader { proxy in
        List {
            rainbowPendingSection

            Section {
                // 0. 여기서 적은 것이 아직 맥에 안 간다는 사실을 말한다
                //    (→ TodoAccess.swift). **적는 것은 아무 지장이 없으므로**
                //    막는 말이 아니라 알려 주는 말이다. 그래서 실제로 안 건너간
                //    줄이 있을 때만 뜬다 — 없는데 띄우면 팔려고 세운 벽이 된다.
                if !TodoAccess.canSync, hiddenCount > 0 {
                    readOnlyNotice()
                }

                // 1. 번개 안내. 화면을 덮는 대신 목록의 줄 하나로 선다 —
                //    뒤가 계속 보이고, 그동안 아무거나 할 수 있다 (→ BoltOnboarding.swift).
                if showsBoltHint(items: items, errands: errands) {
                    BoltHintRow(onDetail: { showingBoltMeaning = true },
                                onDismiss: { withAnimation { hasSeenBoltOnboarding = true } })
                        // 연두를 아주 옅게만 깐다. 이 줄이 말하려는 색이 연두라서
                        // 색은 있어야 하지만, 진하면 할 일보다 안내가 먼저 읽힌다.
                        .listRowBackground(Self.hintTint)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // 2. 적는 자리. 평소에는 없고, + 를 누르면 여기 열린다 —
                //    동그라미가 날아와 앉는 자리이자, 방금 적은 줄이 바로 아래에 쌓이는 자리다.
                if isAdding || inputFocused || !newTitle.isEmpty {
                    newTodoRow
                        .listRowBackground(Self.errandTint)
                        // 위에서 한 줄이 밀려 내려오고, 아래 줄들이 그만큼 자리를 내준다.
                        // 움직임만으로 충분하다 — 색을 한 번 더 칠하면 그 줄이 다른 종류의
                        // 줄인가 싶어진다.
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .opacity))
                }

                // 3. 바로 하면 되는 일 — 표시해 둔 줄과 단계. 차례를 안 기다린다.
                ForEach(marked) { item in
                    MarkedRow(item: item,
                              parentTitle: tree.parent(of: item)?.title,
                              root: tree.root(of: item),
                              onDone: { finish(item, tree: tree) })
                        .listRowBackground(Self.markedTint)
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation {
                                    item.setFragmentAnswer(nil, for: .start)
                                    item.setFragmentAnswer(nil, for: .closing)
                                    save()
                                }
                            } label: {
                                Label("표시 거두기", systemImage: "bolt.slash")
                                    .labelStyle(.iconOnly)
                            }
                            .tint(.gray)
                        }
                }

                // 4. 그냥 하면 되는 것 — 시간도 마감도 없는 줄. 잊히는 것이 이 줄의
                //    유일한 실패 방식이라 시간을 잡은 일들 아래에 깔리지 않게 위에 둔다.
                ForEach(errands) { item in
                    TodoRow(item: item,
                            tree: tree,
                            category: category(of: item),
                            when: .backlog,
                            deadline: nil,
                            onAdvance: advance)
                        // 시간을 안 잡은 줄도 번개면 번개다. 칸 이름으로 뭉뚱그리지 않는다 —
                        // '우유 사 오기'는 5분에 집는 줄이고, 화면이 그렇게 보여야 한다.
                        .listRowBackground(isFragment(item, tree: tree) ? Self.markedTint : Self.errandTint)
                        .swipeActions(edge: .leading) { markButton(for: item, tree: tree) }
                        .contextMenu { itemMenu(for: item, tree: tree) }
                }
                .onDelete { delete(errands, at: $0, tree: tree) }

                // 5. 시간을 잡은 일 — 바탕색 그대로.
                ForEach(items) { item in
                    TodoRow(item: item,
                            tree: tree,
                            category: category(of: item),
                            when: when(item),
                            deadline: periods[item.dragToken]?.end,
                            onAdvance: advance)
                        // 앱이 조각으로 본 줄도 같은 연두다. 사용자가 표시한 것과 뜻이 같고
                        // (그냥 집으면 된다), 다른 색을 하나 더 두면 색이 말을 시작한다.
                        .listRowBackground(isFragment(item, tree: tree) ? Self.markedTint : nil)
                        // ⚠️ 스와이프에는 번개 하나만 둔다. '오늘'·'이번 주로'는 상세의
                        //    날짜가 답하고(→ TodoWhen), '시간 잡기'는 상세의 스테퍼가
                        //    답한다. 손끝에서 정할 일이 둘을 넘으면 스와이프는 메뉴가 되고,
                        //    메뉴는 열 때마다 읽어야 한다.
                        .swipeActions(edge: .leading) { markButton(for: item, tree: tree) }
                        .contextMenu { itemMenu(for: item, tree: tree) }
                }
                .onDelete { delete(items, at: $0, tree: tree) }

                // 6. 완료 — 목록에는 줄 하나만 남기고 상세로 넘긴다. 끝난 일은
                //    '없어진 게 아니라는 것'만 확인하면 되는 것이라, 이번 주 목록에서
                //    자리를 차지하면 남은 일이 그만큼 뒤로 밀린다.
                if !done.isEmpty {
                    doneLinkRow(done.count)
                }
            } footer: {
                listFooter(items: items, errands: errands, marked: marked, done: done)
            }
        }
        .listStyle(.insetGrouped)
        // 입력이 목록 안에 있으므로 스크롤로 키보드를 바로 내리면 적다가 끊긴다.
        // 손가락을 따라 내려가게 두고, 다 적었으면 빈 줄에서 엔터로 닫는다.
        .scrollDismissesKeyboard(.interactively)
        // 키보드가 올라오거나 한 줄이 확정되면 빈 줄이 계속 보이게 따라간다.
        .onChange(of: inputFocused) { _, focused in
            if focused {
                scrollToNewRow(proxy)
            } else if newTitle.isEmpty {
                // 빈 채로 손을 뗐으면 다 적은 것이다. 빈 줄을 남겨 두지 않는다.
                isAdding = false
            }
        }
        .onChange(of: allItems.count) { _, _ in
            if inputFocused { scrollToNewRow(proxy) }
        }
        .onChange(of: addRequest) { _, _ in beginAdding(proxy) }
        }
    }

    // MARK: - 번개 안내
    //
    // 스와이프에서 글자를 뺀 대신, 처음 한 번 목록 맨 위에 줄 하나가 선다.
    // 화면을 덮지 않고, 손짓을 작게 재연하고, 실제로 붙이면 사라진다
    // (→ BoltOnboarding.swift).

    /// 안내 줄을 세울 때인가. 빈 목록에서는 밀어 볼 줄이 없고,
    /// 밀 것이 없는 설명은 그냥 읽을 거리다.
    private func showsBoltHint(items: [BacklogItem], errands: [BacklogItem]) -> Bool {
        !hasSeenBoltOnboarding && !(items.isEmpty && errands.isEmpty)
    }

    /// 이 기기에서 적었지만 아직 다른 기기에서 안 보이는 줄의 수.
    /// 안내 줄은 **이 값이 0보다 클 때만** 뜬다 — 없는데 띄우면 팔려고 세운 벽이 된다.
    private var hiddenCount: Int {
        allItems.filter { !$0.isShared && TodoSharing.isMine($0) && !$0.isCompleted }.count
    }

    /// 잠긴 기기라고 말하는 줄. 두 목록이 같은 줄을 쓴다 — 화면마다 다른 말을 하면
    /// 같은 잠금이 다른 잠금처럼 읽힌다.
    ///
    /// - Parameter showsMyListCounts: 내 목록에서만 뜻이 있는 숫자들(받은 상자·안 보이는 줄)을
    ///   함께 보일지. 공유 목록에서는 그 숫자가 이 화면 이야기가 아니라 끈다.
    private func readOnlyNotice(showsMyListCounts: Bool = true) -> some View {
        Button {
            editingPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(TodoAccess.lockedTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.3)
                    Text(TodoAccess.lockedNote)
                        .font(.system(size: 12))
                        .tracking(-0.2)
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // 여기 것이 저기서 안 보인다는 사실을 숫자로 말한다.
                    // "동기화가 고장났나"와 "안 열어서 그렇다"를 가르는 한 줄이다.
                    if showsMyListCounts, hiddenCount > 0 {
                        Text("이 기기의 \(hiddenCount)개는 다른 기기에서 안 보입니다.")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(-0.2)
                            .foregroundStyle(TodoView.nowGreen)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    /// 완료한 것으로 가는 줄. 개수는 여기서도 보인다 — 오늘 뭘 끝냈는지는
    /// 들어가 보지 않고도 알 수 있어야 하고, 그게 이 줄이 하는 일의 절반이다.
    private func doneLinkRow(_ count: Int) -> some View {
        NavigationLink {
            DoneTodosView(weekStart: weekStart)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green.opacity(0.7))
                Text("완료한 것 \(count)개")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.vertical, 4)
        }
        .listRowBackground(Self.doneTint)
    }

    // MARK: - 한 줄 열기
    //
    // 오른쪽 위 + 를 누르면 목록 맨 위에 줄이 하나 **밀려 내려온다**. 위에서 들어와
    // 아래 줄들을 그만큼 내리는 움직임이라, 목록에 한 칸이 새로 생겼다는 것이
    // 설명 없이 읽힌다. 버튼과 그 자리가 같은 쪽 위라 눈이 따라갈 거리도 짧다.

    /// 제어센터에서 온 요청을 거둔다. **플래그를 거두는 곳은 여기 하나뿐이다** —
    /// 콜드 런치의 `.task` 와 이미 떠 있을 때의 알림이 둘 다 도착해도 한 번만 열린다.
    ///
    /// 적는 자리는 '내 할 일'의 목록 맨 위다. 공유 목록을 보고 있었거나 어떤 일의
    /// 상세에 들어가 있었다면 거기부터 걷어낸다 — 눌러서 온 사람이 원한 건
    /// '지금 떠오른 한 줄을 적는 것'이지 화면 구경이 아니다.
    private func consumeQuickAddRequest() {
        guard QuickTodoBridge.consumePendingAdd() else { return }
        pushedTodo = nil
        showingBoltMeaning = false
        tab = .mine
        // 목록이 실제로 그려진 다음에 빈 줄을 밀어 넣어야 스크롤이 걸린다.
        // (→ beginAdding 은 ScrollViewReader 안에서 addRequest 변화를 받는다.)
        addRequest += 1
    }

    /// + 를 눌렀을 때. 줄을 밀어 넣고, 그 줄이 자리를 잡으면 키보드를 올린다.
    private func beginAdding(_ proxy: ScrollViewProxy) {
        // 이미 적고 있으면 다시 열지 않는다. 커서만 되돌려 준다.
        guard !isAdding else {
            inputFocused = true
            scrollToNewRow(proxy)
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            isAdding = true
        }
        Task {
            // 줄이 자리를 잡아야 그리로 스크롤이 걸린다. 한 프레임 기다린다.
            // (목록이 아래로 내려가 있으면 새 줄이 화면 밖에서 생기므로 꼭 데려온다.)
            try? await Task.sleep(for: .milliseconds(30))
            scrollToNewRow(proxy)
            // 줄이 절반쯤 내려왔을 때 키보드를 올린다. 다 끝난 뒤에 올리면 굼떠 보이고,
            // 같이 올리면 화면이 두 군데서 동시에 움직인다.
            try? await Task.sleep(for: .milliseconds(170))
            inputFocused = true
        }
    }

    // 줄의 성질을 말하는 바탕색들. 머리글을 없앤 대신 이것들이 가른다.
    // 옅게 쓰는 게 요점이다 — 알아보기만 하면 되고, 읽을 것은 줄 자체다.
    /// '바로 하면 되는 일'의 색. 연두 — 신호등의 그 색이다. 그냥 가면 된다는 뜻.
    static let nowGreen = Color(hue: 0.26, saturation: 0.72, brightness: 0.66)
    static let markedTint = nowGreen.opacity(0.16)
    /// 안내 줄의 바탕. 번개 칸보다 훨씬 옅다 — 이 줄은 할 일이 아니다.
    static let hintTint = nowGreen.opacity(0.05)
    private static let errandTint = Color.secondary.opacity(0.07)
    private static let doneTint = Color.secondary.opacity(0.03)

    /// 목록 아래 셈. **말이 아니라 기호와 숫자로.**
    ///
    /// 예전에는 "바로 2개 · 그냥 3개 · 시간 잡은 일 5개 · 완료 1개" 한 줄에
    /// 색·스와이프 설명 두 줄이 더 붙어 있었다. 세 줄이 다 같은 크기 같은 회색이라
    /// 정작 세려던 숫자가 글 속에 묻혔다. 여기에는 셀 것만 남긴다.
    /// (색·손짓 설명은 번개 안내 줄이 한 번만 한다 → BoltOnboarding.swift)
    ///
    /// ⚠️ 여기서 시간을 합치지 말 것. 단위가 다른 것을 더하면
    ///    "2시간 벌었는데 왜 아무것도 못 했지"라는 잘못된 죄책감이 생긴다.
    ///    기호가 갈라 세는 그림이라, 합치고 싶은 마음도 덜 생긴다.
    @ViewBuilder
    private func listFooter(items: [BacklogItem],
                            errands: [BacklogItem],
                            marked: [BacklogItem],
                            done: [BacklogItem]) -> some View
    {
        if items.isEmpty && errands.isEmpty && marked.isEmpty && done.isEmpty {
            // 셈줄이 빈 화면의 유일한 글이던 시절이 있었다. 셈이 없어졌으니
            // 여기서는 다음에 뭘 하면 되는지만 말한다.
            Text("오른쪽 위 + 를 눌러 이번 주에 할 일을 적어보세요.")
        } else {
            HStack(spacing: 14) {
                if !marked.isEmpty {
                    countChip("bolt.fill", marked.count, "바로 하면 되는 일", Self.nowGreen)
                }
                if !errands.isEmpty {
                    countChip("circle.dashed", errands.count, "그냥 하면 되는 것", .secondary)
                }
                if !items.isEmpty {
                    countChip("clock", items.count, "시간 잡은 일", .secondary)
                }
                if !done.isEmpty {
                    countChip("checkmark", done.count, "완료", .secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
    }

    /// 기호 하나와 숫자 하나. 기호는 그 줄들이 목록에서 쓰는 것과 같은 것이라
    /// 무엇을 센 건지 위를 보면 안다 — 번개는 바로 하면 되는 일, 점선 원은 적기만 한 줄.
    private func countChip(_ symbol: String, _ count: Int,
                           _ label: String, _ tint: Color) -> some View
    {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text("\(count)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        // 기호는 소리로 안 읽힌다. 세던 말을 여기 그대로 남긴다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(count)개")
    }

    /// **급한 순** — 칸 안에서 줄이 서는 하나의 규칙.
    ///
    /// 칸(바로 하면 되는 일 · 그냥 하면 되는 것 · 시간을 잡은 일)이 '무엇부터 볼까'는 이미
    /// 갈라 놨다. 여기서 정하는 건 그 **칸 안에서 무엇이 먼저 급한가**이고, 재는 자는
    /// **기간 하나**다 — 사람이 상세에 적어 둔 시작일과 끝나는 날 (→ `TodoWhen`).
    ///
    ///   1. 밀림   — 끝나는 날이 지났다. 이미 늦은 일이라 맨 위다.
    ///   2. 오늘   — 기간이 오늘을 덮는다.
    ///   3. 이번 주 — 이번 주에 걸쳤다.
    ///   4. 그 뒤  — 다음 주 이후에 시작한다.
    ///   5. 백로그 — 날짜를 안 정했다.
    ///
    /// 급하기가 같으면 **번개가 먼저**다. 5분이 났을 때 집을 수 있는 줄이 위에 있어야
    /// 그 5분이 쓰인다 — 맨 위 칸이 그렇듯, 여기서도 같은 이유로 앞선다.
    /// 그것도 같으면 **끝나는 날이 가까운 것부터**, 마지막으로 **원래 순서를 지킨다**
    /// (안정 정렬). 볼 때마다 줄이 뒤집히면 어제 어디쯤 있었는지가 안 남고, 목록이 매번
    /// 처음 보는 목록이 된다. (`sorted`는 안정 정렬을 보장하지 않아서 원래 자리를
    /// 마지막 열쇠로 들고 간다.)
    ///
    /// 단계 줄('바로' 칸에 따로 서는 것)은 제 기간이 없다 — 날짜는 그 일 전체에 붙는 것이라
    /// 뿌리를 보고 잰다.
    private func urgentFirst(_ items: [BacklogItem], tree: TodoTree) -> [BacklogItem] {
        func rank(_ item: BacklogItem) -> (Int, Int, Date) {
            let root = tree.root(of: item)
            let period = periods[root.dragToken]
            return (TodoWhen.of(period, weekStart: weekStart).rawValue,
                    isFragment(item, tree: tree) ? 0 : 1,
                    period?.end ?? .distantFuture)
        }
        return items.enumerated()
            .sorted { lhs, rhs in
                let l = rank(lhs.element), r = rank(rhs.element)
                if l.0 != r.0 { return l.0 < r.0 }
                if l.1 != r.1 { return l.1 < r.1 }
                if l.2 != r.2 { return l.2 < r.2 }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// 이 할 일이 언제의 일인가 — 기간 하나로 답한다 (→ `TodoWhen`).
    private func when(_ item: BacklogItem) -> TodoWhen {
        TodoWhen.of(periods[item.dragToken], weekStart: weekStart)
    }

    /// 이 줄을 지금 5분에 집을 수 있는가. 쪼갠 일은 '지금 할 단계'로 판단한다 —
    /// 줄에 서 있는 것이 그 단계이므로, 판정도 같은 것을 봐야 말이 맞는다.
    private func isFragment(_ item: BacklogItem, tree: TodoTree) -> Bool {
        fragmentAdvice(item, tree: tree).isFragment
    }

    private func fragmentAdvice(_ item: BacklogItem, tree: TodoTree) -> StepAdvice {
        let step = tree.currentStep(of: item) ?? item
        return TodoSplitAdvisor.advice(title: step.title,
                                       durationHours: step.durationHours,
                                       pick: step.fragmentPick)
    }

    /// 오른쪽 아래 + . 누르면 적는 줄이 열리고 거기로 따라간다.
    ///
    /// 버튼이 여기 있는 이유는 손이 여기 있기 때문이다. 목록 맨 아래까지 스크롤해서
    /// 빈 줄을 찾아 누르는 동선이 '한 줄 적기'보다 길면, 적으려던 것이 그 사이에 샌다.
    private func scrollToNewRow(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Self.newRowID, anchor: .top)
        }
    }

    // MARK: - 줄을 가르는 규칙

    /// 줄들을 세 자리로 가른다. 순서는 그대로 둔다.
    ///
    /// - `errands` — 아무것도 안 적힌 줄. '그냥 하면 되는 것'.
    /// - `marked` — **사용자가 직접 '맥락 없이 바로'라고 표시한 줄.** 시간이 잡혀 있어도
    ///   여기로 올라온다. 앱의 짐작(낱말·시간)으로는 못 올리고, 사람이 표시한 것만 올린다 —
    ///   이 자리의 값어치는 "여기 있는 건 진짜 바로 된다"는 믿음에서 나온다.
    /// - `rest` — 시간을 잡은 일.
    ///
    /// 마감이 붙은 줄은 아무리 시간이 0이어도 그냥 하면 되는 것이 아니다 —
    /// 이미 무지개에 줄이 그어져 오늘부터 그 날까지 나를 붙잡고 있기 때문이다.
    private func splitErrands(_ items: [BacklogItem], tree: TodoTree)
        -> (errands: [BacklogItem], marked: [BacklogItem], rest: [BacklogItem])
    {
        var errands: [BacklogItem] = []
        var marked: [BacklogItem] = []
        var rest: [BacklogItem] = []
        for item in items {
            let lane = tree.lane(of: item, hasDeadline: periods[item.dragToken] != nil)
            switch lane {
            case .now where !tree.hasChildren(item):
                // 안 쪼갠 일은 통째로 위 칸으로 올라간다.
                marked.append(item)
            case .now:
                // 쪼갠 일은 제자리에 남는다 — 그 안의 '바로' 단계만 위 칸에 따로 선다.
                rest.append(item)
            case .errand:
                errands.append(item)
            case .planned:
                rest.append(item)
            }
        }
        return (errands, marked, rest)
    }

    /// 맨 위 칸에 설 것들 — **단계도 포함해서** 모은다.
    ///
    /// 한 일의 단계 중에도 그냥 하면 되는 것이 섞여 있다. '자료 링크 하나 챙기기'는
    /// 그 일이 아무리 큰 일이어도 5분에 닫힌다. 그런 단계는 순서를 기다릴 이유가 없으므로
    /// 차례와 상관없이 여기 올라와, 5분이 났을 때 그냥 집힌다.
    private func markedPicks(_ roots: [BacklogItem], tree: TodoTree) -> [BacklogItem] {
        var result: [BacklogItem] = []
        for root in roots where !root.isCompleted {
            if tree.hasChildren(root) {
                result += tree.leaves(of: root).filter { !$0.isCompleted && $0.isMarkedNow }
            }
        }
        return result
    }

    /// '바로 하면 되는 일'로 표시하거나 거둔다. 표시는 **그 줄 자체**에 붙는다 —
    /// 쪼갠 일이면 지금 할 단계에.
    private func setMarked(_ value: Bool, for item: BacklogItem, tree: TodoTree) {
        // 쪼갠 일이면 지금 할 단계에 붙인다. 다 끝났으면 붙일 단계가 없으므로 아무것도 안 한다 —
        // 여기서 묶음 자체에 답을 쓰면 그 자리(labelRaw)에 있는 단계 순서를 지운다
        // (→ BacklogItem+StepOrder.swift).
        let target: BacklogItem
        if tree.hasChildren(item) {
            guard let step = tree.currentStep(of: item) else { return }
            target = step
        } else {
            target = item
        }
        withAnimation {
            target.setFragmentAnswer(value ? true : nil, for: .start)
            target.setFragmentAnswer(value ? true : nil, for: .closing)
            save()
            // 한 번 붙여 봤으면 안내는 제 할 일을 다 했다. 읽었는지가 아니라
            // 해봤는지로 끝난다 (→ BoltOnboarding.swift).
            //
            // ⚠️ '번개가 붙은 줄이 있는지'로 재지 말 것. 앱을 열 때 @Query가 채워지며
            //    개수가 0에서 오르는데, 그걸 손짓으로 읽으면 이미 번개를 쓰는 사람에게는
            //    안내가 뜨자마자 사라진다 — 설정에서 '다시 보기'를 눌러도 마찬가지다.
            if value { hasSeenBoltOnboarding = true }
        }
    }

    /// 표시해 둔 단계 하나를 끝낸다. 차례가 아니어도 끝낼 수 있다 —
    /// 조각에 집어 넣으라고 위로 올려 둔 것이니 순서를 다시 강요하면 앞뒤가 안 맞는다.
    private func finish(_ step: BacklogItem, tree: TodoTree) {
        withAnimation {
            tree.setCompleted(step, true)
            save()
        }
    }

    /// **번개를 붙이고 거둔다.** 스와이프 한 번.
    ///
    /// 이 표시는 앱의 짐작이 아니라 **사람이 직접 하는 말**이다 — "이건 맥락 없이 바로
    /// 된다". 그래서 어느 줄에서든 할 수 있어야 한다. 예전에는 롱 프레스 메뉴 안에만
    /// 있었고 그것도 시간을 잡은 줄에만 떴다. 붙일 수 있다는 걸 알 방법이 없었다.
    ///
    /// 쪼갠 일에서는 지금 할 단계에 붙는다 (→ `setMarked`).
    @ViewBuilder
    private func markButton(for item: BacklogItem, tree: TodoTree) -> some View {
        let marked = tree.markedStep(of: item) != nil
        Button {
            setMarked(!marked, for: item, tree: tree)
        } label: {
            // 손짓 하나에 뜻 하나. 글자를 붙이면 스와이프가 읽을 거리가 되고,
            // 읽을 거리가 되면 손이 멈춘다. 번개 하나면 충분하다 —
            // 이름은 VoiceOver가 읽고, 오래 누르면 메뉴에 그대로 있다.
            Label(marked ? "표시 거두기" : "바로 하면 됨",
                  systemImage: marked ? "bolt.slash" : "bolt.fill")
                .labelStyle(.iconOnly)
        }
        .tint(marked ? .gray : Self.nowGreen)
    }

    // MARK: - 공유 할 일

    private var familyList: some View {
        ScrollViewReader { proxy in
        List {
            if let message = family.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            let open = family.items.filter { !$0.isCompleted }
            let done = family.items.filter { $0.isCompleted }

            // 함께 보는 목록도 같은 규칙이다 — 잠긴 기기는 **보기만** 한다.
            // 내 목록에서 하던 말을 여기서도 그대로 한다 (→ TodoAccess.swift).
            if !TodoAccess.canSync, hiddenCount > 0 {
                Section { readOnlyNotice(showsMyListCounts: false) }
            }

            Section {
                ForEach(open) { todo in
                    FamilyTodoRow(todo: todo) { t in
                        toggleShared(t)
                    }
                }
                .onDelete(perform: sharedDeleteAction(from: open))

                if family.isSharing || !family.items.isEmpty {
                    newTodoRow
                }
            } header: {
                if !open.isEmpty { Text("할 일 · \(open.count)개") }
            } footer: {
                if family.mode == .owner && family.shareURL != nil {
                    Text("초대 링크를 받은 사람은 누구나 참여할 수 있어요. 링크는 함께할 사람에게만 보내주세요.")
                }
            }

            if !done.isEmpty {
                Section("완료 · \(done.count)개") {
                    ForEach(done) { todo in
                        FamilyTodoRow(todo: todo) { t in
                            toggleShared(t)
                        }
                    }
                    .onDelete(perform: sharedDeleteAction(from: done))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: inputFocused) { _, focused in
            if focused { scrollToNewRow(proxy) }
        }
        .onChange(of: family.items.count) { _, _ in
            if inputFocused { scrollToNewRow(proxy) }
        }
        .refreshable { await family.refresh() }
        .overlay {
            if family.items.isEmpty && !family.isSharing {
                if !family.iCloudAvailable {
                    ContentUnavailableView(
                        "iCloud 로그인이 필요합니다",
                        systemImage: "icloud.slash",
                        description: Text("설정에서 iCloud에 로그인하면 다른 사람과 할 일을 공유할 수 있습니다.")
                    )
                } else if family.isBusy {
                    ProgressView()
                } else {
                    ContentUnavailableView(
                        "아직 함께 보는 목록이 없습니다",
                        systemImage: "person.2",
                        description: Text("오른쪽 위 공유 버튼으로 함께할 사람을 초대하거나,\n상대가 보낸 초대 링크를 눌러 참여하세요.")
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        }
    }

    /// 함께 보는 목록에서 체크하기. 내 목록의 줄을 누르는 것과 같다.
    private func toggleShared(_ todo: FamilyTodo) {
        Task { await family.toggle(todo) }
    }

    /// 함께 보는 목록에서 지우기.
    private func sharedDeleteAction(from source: [FamilyTodo]) -> (IndexSet) -> Void {
        return { offsets in
            let victims = offsets.map { source[$0] }
            Task { for v in victims { await family.delete(v) } }
        }
    }

    private var familyShareMenu: some View {
        Menu {
            switch family.mode {
            case .participant:
                Button(role: .destructive) {
                    Task { await family.leave() }
                } label: {
                    Label("공유 나가기", systemImage: "rectangle.portrait.and.arrow.right")
                }
            default:
                if let url = family.shareURL {
                    ShareLink(item: url) {
                        Label("초대 링크 보내기", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        Task { await family.stopSharing() }
                    } label: {
                        Label("공유 중지", systemImage: "person.2.slash")
                    }
                } else {
                    Button {
                        showingFamilyShareNotice = true
                    } label: {
                        Label("할 일 공유 시작", systemImage: "person.2.badge.plus")
                    }
                }
            }
            Button {
                Task { await family.refresh() }
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: family.isSharing ? "person.2.fill" : "person.2")
        }
        .disabled(!family.iCloudAvailable)
    }

    // MARK: - 목록 맨 아래 빈 줄
    //
    // 입력을 하단 바에서 목록 안으로 들여왔다. 바에 적으면 '폼을 채워 제출하는' 느낌이고,
    // 줄에 적으면 '목록에 한 줄 더 얹는' 느낌이 된다. 엔터를 치면 그 줄이 확정되고
    // 빈 줄이 다시 와서 계속 이어 적을 수 있다. 빈 줄에서 엔터를 치면 다 적었다고 보고
    // 키보드를 내린다.

    private var newTodoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)

            // 여기서는 **할 일 이름만** 받는다.
            // 착수 조건·분류·데드라인을 적는 줄에 같이 붙여 두면, 한 줄 적으려다
            // 매번 세 가지를 정하게 된다. 그건 적는 속도를 죽이고, 정작 정해야 할 때는
            // 아무 생각 없이 지난 값을 그냥 흘려보낸다. 정하는 자리는 상세 화면이다.
            TextField(tab == .mine ? "할 일 추가" : "공유 할 일 추가", text: $newTitle)
                .focused($inputFocused)
                .submitLabel(.return)
                .onSubmit(add)
        }
        .padding(.vertical, 2)
        .id(Self.newRowID)
    }

    // MARK: - 무지개에서 넘어온 일

    /// 무지개에 줄은 그어져 있는데 아직 할 일로 안 가져온 일들.
    ///
    /// 무지개에 있는데 할 일에는 아무것도 없으면, 이번 주에 뭘 해야 하는지가 안 보인다.
    /// 여기 세워 두고, 누르면 단계로 쪼개어 이번 주 할 일로 데려온다.
    @ViewBuilder
    private var rainbowPendingSection: some View {
        if !rainbowPending.isEmpty {
            // 이번 주에 걸친 일정이 스무 개라면 그건 목록이 아니라 벽이다.
            // 급한 몇 개만 세우고, 나머지는 마감이 다가오면 저절로 올라온다.
            let shown = Array(rainbowPending.prefix(Self.rainbowPendingLimit))
            let hidden = rainbowPending.count - shown.count
            Section {
                ForEach(shown) { event in
                    Button {
                        // 누르면 **새 할 일이 생긴다.**
                        guard let item = TodoEventBridge.shared.makeTodo(for: event) else { return }
                        refreshRainbowPending()
                        refreshPeriods()
                        pushedTodo = item
                    } label: {
                        rainbowPendingRow(event)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Label("무지개에 걸려 있는 일", systemImage: "rainbow")
            } footer: {
                if hidden > 0 {
                    Text("이번 주에 걸쳐 있는 일정입니다. 누르면 단계로 쪼개어 이번 주 할 일로 가져옵니다.\n마감이 더 먼 일정 \(hidden)개는 때가 되면 여기 올라옵니다.")
                } else {
                    Text("이번 주에 걸쳐 있는 일정입니다. 누르면 단계로 쪼개어 이번 주 할 일로 가져옵니다.")
                }
            }
        }
    }

    /// 한 번에 세우는 최대 개수.
    private static let rainbowPendingLimit = 4

    private func rainbowPendingRow(_ event: Event) -> some View {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: event.effectiveEndDate())
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: end).day ?? 0

        return HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 18))
                .foregroundStyle(.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .lineLimit(2)
                Text("\(shortDate(event.startDate)) ~ \(shortDate(end)) · 하루 \(hourText(event.hoursPerDay))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(days <= 0 ? "오늘까지" : "D-\(days)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(days <= 3 ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func hourText(_ hours: Double) -> String {
        hours == hours.rounded() ? String(format: "%.0f시간", hours) : String(format: "%.1f시간", hours)
    }

    // MARK: - 데드라인 묻기

    /// 흔한 마감들. 날짜 고르기까지 가지 않고 한 번에 끝나도록.
    private struct DeadlineChoice {
        let label: String
        let date: () -> Date
    }

    private static let deadlineChoiceRows: [[DeadlineChoice]] = [
        [
            DeadlineChoice(label: "오늘", date: { Calendar.current.startOfDay(for: Date()) }),
            DeadlineChoice(label: "내일", date: { Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }),
            DeadlineChoice(label: "이번 주", date: { Date.endOfThisWeek })
        ],
        [
            DeadlineChoice(label: "2주 뒤", date: { Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date() }),
            DeadlineChoice(label: "한 달 뒤", date: { Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date() })
        ]
    ]

    private func deadlinePickerSheet(for item: BacklogItem) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 흔한 마감은 달력까지 가지 않고 한 번에 끝난다.
                // (예전에는 이 칩들이 적자마자 화면 아래에서 튀어나와 답을 재촉했다.
                //  물음을 없애는 대신 칩은 여기 남긴다 — 정하러 온 사람에게는 여전히 빠르다.)
                VStack(spacing: 8) {
                    ForEach(Self.deadlineChoiceRows, id: \.first?.label) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.label) { choice in
                                Button {
                                    setDeadline(choice.date(), for: item)
                                    deadlinePickerItem = nil
                                } label: {
                                    Text(choice.label)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                DatePicker("데드라인", selection: $pickedDeadline,
                           in: Calendar.current.startOfDay(for: Date())...,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Text("오늘부터 이 날까지 무지개에 한 줄이 그어집니다.\n실제로 시간을 쓰는 날은 무지개에서 칸을 눌러 고칠 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("‘\(item.title)’ 데드라인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { deadlinePickerItem = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("정하기") {
                        setDeadline(pickedDeadline, for: item)
                        deadlinePickerItem = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func itemMenu(for item: BacklogItem, tree: TodoTree) -> some View {
        // '오늘로 배정'도 '시간 잡기'도 여기 없다. 언제 할 일인지는 상세의 날짜가
        // (→ TodoWhen), 얼마나 걸리는지는 상세의 스테퍼가 답한다. 같은 것을 정하는
        // 문이 둘이면 어느 쪽이 진짜인지 매번 고르게 된다.
        // 여기 남은 '데드라인'은 그 날짜를 한 손으로 잡는 지름길이다 — 오늘부터 그 날까지.
        Button {
            beginDeadlinePick(for: item)
        } label: {
            Label(periods[item.dragToken] == nil ? "데드라인 정하기" : "데드라인 바꾸기",
                  systemImage: "flag.checkered")
        }
        // 지금 할 단계를 '맥락 없이 바로 되는 것'으로 표시한다. 표시한 줄은 위 칸에 모인다.
        //
        // ⚠️ 예전에는 시간이 0인 줄에서는 이 항목을 감췄다 — 이미 '그냥 하면 되는 것'
        //    칸에 있으니 뜻이 겹친다고 봤다. 그런데 겹치는 건 앱의 짐작이고, 이 표시는
        //    사람이 직접 하는 말이다. 감추면 "왜 여기선 못 붙이지"가 된다. 이제 늘 뜬다.
        let marked = tree.markedStep(of: item) != nil
        Button {
            setMarked(!marked, for: item, tree: tree)
        } label: {
            Label(marked ? "'바로' 표시 거두기" : "바로 하면 되는 일로 표시",
                  systemImage: marked ? "bolt.slash" : "bolt.fill")
        }
        if periods[item.dragToken] != nil {
            Button {
                Task {
                    await TodoEventBridge.shared.clearRainbow(for: item)
                    refreshPeriods()
                }
            } label: {
                Label("무지개에서 빼기", systemImage: "rainbow")
            }
        }
        if tree.hasChildren(item), tree.lastDoneStep(of: item) != nil {
            Button {
                withAnimation {
                    tree.rewind(item)
                    save()
                }
            } label: {
                Label("이전 단계로 되돌리기", systemImage: "arrow.uturn.backward")
            }
        }
        categoryMenu(for: item)
    }

    @ViewBuilder
    private func categoryMenu(for item: BacklogItem) -> some View {
        Menu("카테고리 지정") {
            Button {
                item.categoryID = nil
                save()
            } label: {
                Label("미분류", systemImage: item.categoryID == nil ? "checkmark" : "circle")
            }
            ForEach(categories) { c in
                Button {
                    item.categoryID = c.uuid
                    save()
                } label: {
                    Label(c.name, systemImage: item.categoryID == c.uuid ? "checkmark" : c.iconName)
                }
            }
        }
        Button(role: .destructive) {
            askToDelete(item, tree: tree)
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
    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else {
            inputFocused = false
            return
        }

        if tab == .family {
            Task { await family.add(title: title) }
        } else {
            let maxIndex = allItems.map(\.sortIndex).max() ?? -1
            withAnimation {
                // 적을 때는 아무것도 정하지 않는다 — 시간도, 마감도.
                //
                // 예전에는 여기서 기본 30분이 붙고 곧바로 "언제까지예요?"가 떴다.
                // 그러면 '오는 길에 우유'처럼 제일 급하게 적는 줄이 제일 손이 많이 간다:
                // 안 쓸 30분을 이번 주에 얹고, 뜬 물음을 X로 닫아야 우유가 된다.
                // 순서를 뒤집는다 — 적으면 그냥 '그냥 하면 되는 것'이고,
                // 시간이 필요해지면 그때 왼쪽으로 밀어 잡는다.
                let fresh = BacklogItem(title: title,
                                        durationHours: TodoTree.errandHours,
                                        sortIndex: maxIndex + 1,
                                        weekStartDate: weekStart)
                // 어느 자리에서 났고, 그때 함께 쓸 수 있었는지를 줄에 새긴다
                // (→ TodoSharing.swift).
                TodoSharing.stamp(fresh)
                context.insert(fresh)
                save()
            }
        }
        newTitle = ""
        // 팁·필터 줄이 나타나며 목록이 다시 그려지면 포커스가 풀릴 수 있다.
        // 다음 런루프에 다시 잡아, 이어서 계속 적을 수 있게 한다.
        inputFocused = true
        DispatchQueue.main.async { inputFocused = true }
    }

    /// 탭 = 지금 할 일 하나를 끝낸다. 단계가 있으면 다음 단계로 넘어가고,
    /// 마지막 단계였다면 할 일 전체가 완료된다. 단계가 없는 할 일은 그냥 체크.
    private func advance(_ item: BacklogItem, tree: TodoTree) {
        withAnimation {
            if item.isCompleted {
                // 완료된 줄을 다시 누르면 마지막 단계만 되돌린다.
                if tree.rewind(item) == nil {
                    tree.setCompleted(item, false)
                }
            } else {
                tree.advance(item)
            }
            save()
        }
    }

    /// 할 일을 지운다. **미는 것도 메뉴에서 누르는 것도 같은 물음을 지난다** —
    /// 한쪽만 조용히 지우면 어느 손짓이 되돌릴 수 없는 것인지 알 수 없게 된다.
    private func delete(_ items: [BacklogItem], at offsets: IndexSet, tree: TodoTree) {
        guard let index = offsets.first else { return }
        askToDelete(items[index], tree: tree)
    }

    /// 무엇이 함께 없어지는지 세어서 묻고, 답하면 지운다 (→ TodoDeletion.swift).
    private func askToDelete(_ item: BacklogItem, tree: TodoTree) {
        deletionRequest = TodoDeletionRequest(
            title: "'\(item.title)' 삭제",
            message: TodoDeletion.message(for: item,
                                          tree: tree,
                                          hasRainbowLine: periods[item.dragToken] != nil)
        ) {
            let result = await TodoDeletion.delete(item,
                                                   tree: tree,
                                                   allItems: allItems,
                                                   context: context)
            if case .success = result {
                withAnimation {
                    refreshPeriods()
                    refreshRainbowPending()
                }
                syncWidget()
            }
            return result
        }
    }

    private func save() {
        try? context.save()
        syncWidget()
    }


    /// **안 끝난 채 주를 넘긴 일을 이번 주로 끌어온다.**
    ///
    /// 예전에는 사람이 줄마다 '이번 주로'를 밀어 옮겼다. 그런데 안 끝난 일이 지난 주에
    /// 남아 있어야 할 이유가 없다 — 그건 여전히 **지금** 할 일이고, 목록에도 이미 섞여
    /// 서 있었다. 옮기는 손짓은 뜻을 더하지 않고 손만 하나 더 쓰게 했다.
    ///
    /// 주차(`weekStartDate`)는 이제 결산이 "이번 주에 무엇을 했나"를 세는 자리로만 쓴다.
    /// 완료한 일은 건드리지 않는다 — 지난 주에 끝낸 것은 지난 주의 셈이다.
    private func pullForwardOverdueWeeks() {
        let tree = TodoTree(allItems)
        let stale = tree.roots.filter { !$0.isCompleted && $0.weekStartDate < weekStart
                                        && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
        guard !stale.isEmpty else { return }
        for root in stale {
            // 단계도 부모와 한 덩어리로 같이 옮긴다.
            for node in tree.subtree(of: root) { node.weekStartDate = weekStart }
        }
        try? context.save()
    }

    /// 팁이 언제 뜰지 정하는 값들을 최신으로 맞춘다 (→ TodoTips.swift).
    private func refreshTipRules() {
        let tree = TodoTree(allItems)
        if tree.roots.contains(where: { tree.children(of: $0).count >= 2 }) { ShareSplitTip.hasSplit = true }
    }

    /// 무지개에 그어져 있는 기간들을 다시 읽고, 오늘 계획을 거기 맞춘다.
    /// 목록의 '오늘·이번 주·밀림' 판정이 전부 이 한 벌에서 나온다 (→ `TodoWhen`).
    private func refreshPeriods() {
        periods = TodoEventBridge.shared.periodsByToken()
    }

    /// 무지개에만 있고 할 일에는 아직 없는 일들을 다시 읽는다.
    private func refreshRainbowPending() {
        withAnimation { rainbowPending = TodoEventBridge.shared.pendingFromRainbow(weekStart: weekStart) }
    }

    // MARK: - 데드라인

    /// 날짜를 직접 고르는 시트를 연다. 이미 정해져 있으면 그 날짜에서 시작한다.
    private func beginDeadlinePick(for item: BacklogItem) {
        pickedDeadline = periods[item.dragToken]?.end ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        deadlinePickerItem = item
    }

    /// 데드라인을 정하고, 오늘부터 그 날까지 무지개에 한 줄을 긋는다.
    private func setDeadline(_ date: Date, for item: BacklogItem) {
        let hours = TodoTree(allItems).totalHours(of: item)
        guard TodoEventBridge.shared.drawRainbow(for: item, deadline: date, hours: hours) else { return }
        refreshPeriods()
        refreshRainbowPending()
    }

    /// 홈·잠금 화면 위젯이 읽는 스냅샷을 다시 굽는다.
    private func syncWidget() {
        TodoWidgetSync.refresh(context: context)
    }
}

// MARK: - 행

struct TodoRow: View {
    let item: BacklogItem
    let tree: TodoTree
    let category: BacklogCategory?
    /// 언제의 일인가 — 상세에 적어 둔 기간 하나로 판정한 것 (→ `TodoWhen`).
    let when: TodoWhen
    /// 무지개에 그어 둔 줄의 끝나는 날. 없으면 아직 날짜를 안 정한 일.
    let deadline: Date?
    /// 탭 = 지금 할 일 하나 끝내기.
    let onAdvance: (BacklogItem, TodoTree) -> Void

    private var hasSteps: Bool { tree.hasChildren(item) }
    private var currentStep: BacklogItem? { tree.currentStep(of: item) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onAdvance(item, tree)
            } label: {
                checkIcon
            }
            .buttonStyle(.plain)

            NavigationLink {
                TodoDetailView(root: item)
            } label: {
                content
                    // 글자에만 탭이 먹으면 제목이 짧을수록 누를 자리가 좁아진다.
                    // 줄 폭을 다 차지하게 한 뒤 그 사각형 전체를 탭 영역으로 삼는다
                    // (frame 없이 contentShape만 걸면 글자만 한 영역이 그대로 남는다).
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
        }
    }

    /// 단계가 있으면 '체크'가 아니라 '다음으로 넘긴다'는 뜻이라 모양을 달리한다.
    @ViewBuilder
    private var checkIcon: some View {
        if item.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)
        } else if hasSteps, advice.isFragment {
            // 조각인 단계를 하고 있는 중 — 도넛 안에 번개를 넣어 둘 다 말한다.
            // (어디까지 왔나 + 지금 것은 그냥 집어도 되나)
            ZStack {
                StepDonut(done: tree.doneLeafCount(of: item),
                          total: tree.leafCount(of: item),
                          fragments: fragmentSlices)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TodoView.nowGreen)
            }
            .frame(width: 24, height: 24)
        } else if advice.isFragment {
            Image(systemName: "bolt.circle")
                .font(.system(size: 22))
                .foregroundStyle(TodoView.nowGreen)
        } else if hasSteps {
            // 몇 번째인지는 **원을 단계 수만큼 자른 도넛**이 말한다. 예전에는 '3/4' 같은 글자를
            // 줄에 얹었는데, 그 크기의 숫자는 지나가면서 안 읽힌다. 지나온 칸이 차 있는
            // 그림은 읽는 게 아니라 보인다.
            StepDonut(done: tree.doneLeafCount(of: item),
                      total: tree.leafCount(of: item),
                      fragments: fragmentSlices)
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.secondary)
        }
    }

    /// 조각인 단계들이 도넛의 몇 번째 칸인가.
    ///
    /// 왼쪽 그림 하나가 "어디까지 왔나"에 더해 **"5분이 나면 어느 칸을 집을 수 있나"**까지
    /// 말하게 하는 값이다. 아직 차례가 아닌 칸이라도 연두면, 그 일 안에 짧게 집을 게
    /// 남아 있다는 뜻이 목록에서 그대로 보인다.
    private var fragmentSlices: Set<Int> {
        var result: Set<Int> = []
        for (index, leaf) in tree.leaves(of: item).enumerated() {
            let advice = TodoSplitAdvisor.advice(title: leaf.title,
                                                 durationHours: leaf.durationHours,
                                                 pick: leaf.fragmentPick)
            if advice.isFragment { result.insert(index) }
        }
        return result
    }

    /// 한 줄은 '지금 할 일' 하나만 말한다.
    ///
    /// 단계로 쪼갠 할 일은 지금 할 단계가 곧 지금 할 일이라, 줄에는 그 단계 이름만 선다.
    /// 그게 무슨 일의 일부인지는 눌러 들어가면 네비게이션 타이틀이 말해준다.
    /// 시간은 왼쪽 링이 진행을, 헤더가 총량을 이미 말하므로 줄에서는 뺐다.
    private var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 쪼갠 할 일은 단계 이름만 서 있으면 이게 무슨 일의 일부인지 알 수 없다.
            // 그렇다고 할 일 이름을 크게 세우면 '지금 할 것'이 뒤로 밀린다.
            // 그래서 할 일 이름을 위에 작게 얹어 길 안내로만 쓴다.
            if let parentTitle {
                Text(parentTitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Text(displayTitle)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)

                if !item.isCompleted, let badge = when.badge { whenBadge(badge) }
                if let deadline, !item.isCompleted, when != .overdue { deadlineBadge(deadline) }
                if let category {
                    Circle()
                        .fill(category.displayColor)
                        .frame(width: 10, height: 10)
                        .accessibilityLabel(category.name)
                }
                Spacer(minLength: 0)
            }

        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    /// 줄에 설 이름. 남은 단계가 있으면 그 단계, 아니면 할 일 자신.
    private var displayTitle: String { (currentStep ?? item).title }

    /// 단계를 하고 있을 때만, 그게 무슨 일의 일부인지.
    ///
    /// ⚠️ `currentStep`은 자식이 없으면 **자기 자신**을 돌려준다. 그것만 보고 판단하면
    ///    안 쪼갠 줄이 제 이름을 위아래로 두 번 세운다.
    private var parentTitle: String? {
        guard hasSteps, currentStep != nil else { return nil }
        return item.title
    }

    /// 줄에 서 있는 그 단계에 대한 판정. (이름이 그것이므로 판정도 그것이어야 한다)
    private var advice: StepAdvice {
        let step = currentStep ?? item
        return TodoSplitAdvisor.advice(title: step.title,
                                       durationHours: step.durationHours,
                                       pick: step.fragmentPick)
    }

    /// 도넛은 그림이라 소리로는 안 읽힌다. 몇 번째인지를 말로 한 번 더 적는다.
    private var rowAccessibilityLabel: String {
        var text = displayTitle
        // 순서대로면 "3단계 중 2번째", 아무거나면 "3개 중 1개 끝".
        if hasSteps, let phrase = tree.stepProgressPhrase(of: item) {
            text = "\(item.title), \(phrase), \(displayTitle)"
        }
        if advice.isFragment { text += ", 5분에 집을 수 있음" }
        return text
    }

    /// 남은 날을 세어 보여준다. 날짜보다 "며칠 남았나"가 먼저 와닿는다.
    private func deadlineBadge(_ deadline: Date) -> some View {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: Date()),
                                           to: calendar.startOfDay(for: deadline)).day ?? 0
        // 지난 날짜는 여기서 세지 않는다 — 그건 '밀림' 배지가 이미 말했다.
        let text = days <= 0 ? "오늘까지" : "D-\(days)"
        // 사흘 안쪽이면 색으로 먼저 말한다.
        let tint: Color = days <= 0 ? .red : (days <= 3 ? .orange : .secondary)
        return Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
            .accessibilityLabel("데드라인 \(text)")
    }

    /// 날짜가 말하는 것 한 마디 — '오늘'이거나 '밀림'이거나. 나머지는 아무 말도 안 붙는다
    /// (→ `TodoWhen.badge`). 이번 주 일에까지 배지를 달면 모든 줄에 배지가 생긴다.
    private func whenBadge(_ text: String) -> some View {
        let tint: Color = when == .overdue ? .red : .orange
        return Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.15)))
    }
}

/// 맨 위 칸의 한 줄. 할 일 자신일 수도 있고, 큰 일 안의 단계 하나일 수도 있다.
///
/// 여기서 원을 누르면 **그 줄이 끝난다.** 큰 일의 단계라면 차례를 건너뛰고 그것만 닫힌다 —
/// 조각에 집으라고 올려 둔 것이라, 순서를 다시 요구하면 올려 둔 뜻이 없어진다.
private struct MarkedRow: View {
    let item: BacklogItem
    /// 이게 무슨 일의 단계인지. 단계가 아니면 nil.
    let parentTitle: String?
    /// 눌러 들어갈 곳 — 단계여도 그 일의 상세로 간다.
    let root: BacklogItem
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 원 안에 번개. 이 줄이 무슨 줄인지를 왼쪽 끝에서 한 번 더 말한다 —
            // 색만으로는 흑백 모드·색각 이상에서 사라진다.
            Button(action: onDone) {
                Image(systemName: "bolt.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(TodoView.nowGreen)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.title) 끝내기")

            NavigationLink {
                TodoDetailView(root: root)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    if let parentTitle {
                        Text(parentTitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Text(item.title)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 2)
    }
}

private struct FamilyTodoRow: View {
    let todo: FamilyTodo
    let onToggle: (FamilyTodo) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle(todo)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(todo.isCompleted ? .green : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

/// 새로 열린 입력 줄의 자리 (목록 좌표계). 잉크가 그 자리에서 번지게 하려고 잰다.
