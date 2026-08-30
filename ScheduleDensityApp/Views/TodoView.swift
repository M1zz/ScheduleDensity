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
    /// 오늘 계획으로 배정된 할 일 제목들. WeekBlocks store는 다른 컨테이너라
    /// @Query로 못 보므로 직접 읽어 와 캐시한다.
    @State private var assignedToday: Set<String> = []
    @State private var newTitle = ""
    @State private var showingFamilyShareNotice = false
    @State private var showingLedger = false
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
    /// 무지개에서 가져와 단계를 적으러 갈 할 일.
    @State private var pushedTodo: BacklogItem?
    /// 지금 무지개에 그어져 있는 데드라인 (할 일 dragToken → 종료일).
    /// 일정 스토어는 다른 컨테이너라 @Query로 못 보므로 읽어 와 캐시한다.
    @State private var deadlines: [String: Date] = [:]
    @FocusState private var inputFocused: Bool

    private let cal = Calendar(identifier: .iso8601)
    private var weekStart: Date { .currentWeekStart }

    /// 목록 맨 아래 빈 줄의 id — 키보드가 올라올 때 그 줄로 스크롤하기 위해.
    private static let newRowID = "todo.newRow"

    // 목록에는 최상위 할 일만 줄로 세운다. 그 안의 단계는 줄 하나 안에서
    // '지금 할 일'로 접혀 보이고, 전체 흐름은 TodoDetailView에서 본다.

    /// 부모-자식 색인. 한 번 만들어 목록·칩·결산이 함께 쓴다.
    private var tree: TodoTree { TodoTree(allItems) }

    /// 필터를 걸기 전의 이번 주 줄들 (밀린 것 + 이번 주).
    /// 칩의 셈은 **언제나 이 집합**으로 낸다 — 걸러진 결과로 세면 필터를 켜는 순간
    /// 다른 칩이 0이 되어 사라지고, 되돌아올 길이 없어진다.
    /// 이번 주에 남은 단계들 — 결산 화면에 넘긴다.
    private var remainingSteps: [(title: String, hours: Double)] {
        let tree = self.tree
        // '그냥 하면 되는 것'은 빼고 센다. 결산은 이번 주에 쓴/쓸 시간을 보는 자리인데,
        // 0시간짜리 줄이 섞이면 세는 개수만 부풀고 시간은 그대로다.
        return unfilteredItems
            .filter { !(tree.isErrand($0) && deadlines[$0.dragToken] == nil) }
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

    /// 지난 주에 못 하고 남은 일. 목록에서는 이번 주 것과 한 줄기로 섞이고,
    /// '이번 주로 옮기기' 스와이프가 붙는지만 달라진다.
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
                            showingLedger = true
                        } label: {
                            Image(systemName: "list.clipboard")
                        }
                        .accessibilityLabel("이번 주 결산")
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
        }
        .sheet(isPresented: $showingLedger) {
            WeekLedgerView(weekStart: weekStart, work: remainingSteps)
        }
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
            refreshAssignedToday()
            refreshDeadlines()
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // 맥 '무지개 공방'에서 넘어온 CloudKit 변경도 위젯에 반영한다.
                refreshAssignedToday()
                refreshDeadlines()
                refreshRainbowPending()
                syncWidget()
                Task { await family.refresh() }
            }
        }
        // 맥에서 배정/해제한 결과가 CloudKit으로 내려오면 배지도 따라 바뀐다.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            refreshAssignedToday()
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
        // (지난 주에 밀린 일도 같은 이유로 안 가른다 — 밀렸다는 사실은 옮길 때만 필요하고,
        //  그건 스와이프에 남겨 뒀다.)
        let (allErrands, allMarked, allItems) = splitErrands(carryover + open, tree: tree)
        let errands = allErrands
        // 안 쪼갠 일 + 쪼갠 일 안의 '바로' 단계.
        let marked = allMarked + markedPicks(carryover + open, tree: tree)
        let items = allItems
        let carried = Set(carryover.map(\.dragToken))
        let done = doneItems(tree)

        return ScrollViewReader { proxy in
        List {
            rainbowPendingSection

            Section {
                // 0. 적는 자리. 평소에는 없고, + 를 누르면 여기 열린다 —
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

                // 1. 바로 하면 되는 일 — 표시해 둔 줄과 단계. 차례를 안 기다린다.
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
                            }
                            .tint(.gray)
                        }
                }

                // 2. 그냥 하면 되는 것 — 시간도 마감도 없는 줄. 잊히는 것이 이 줄의
                //    유일한 실패 방식이라 시간을 잡은 일들 아래에 깔리지 않게 위에 둔다.
                ForEach(errands) { item in
                    TodoRow(item: item,
                            tree: tree,
                            category: category(of: item),
                            isAssignedToday: false,
                            deadline: nil,
                            onAdvance: advance)
                        // 시간을 안 잡은 줄도 번개면 번개다. 칸 이름으로 뭉뚱그리지 않는다 —
                        // '우유 사 오기'는 5분에 집는 줄이고, 화면이 그렇게 보여야 한다.
                        .listRowBackground(isFragment(item, tree: tree) ? Self.markedTint : Self.errandTint)
                        .swipeActions(edge: .leading) {
                            errandButton(for: item, tree: tree)
                        }
                        .contextMenu { itemMenu(for: item, tree: tree) }
                }
                .onDelete { delete(errands, at: $0, tree: tree) }

                // 3. 시간을 잡은 일 — 바탕색 그대로.
                ForEach(items) { item in
                    TodoRow(item: item,
                            tree: tree,
                            category: category(of: item),
                            isAssignedToday: assignedToday.contains(item.title),
                            deadline: deadlines[item.dragToken],
                            onAdvance: advance)
                        // 앱이 조각으로 본 줄도 같은 연두다. 사용자가 표시한 것과 뜻이 같고
                        // (그냥 집으면 된다), 다른 색을 하나 더 두면 색이 말을 시작한다.
                        .listRowBackground(isFragment(item, tree: tree) ? Self.markedTint : nil)
                        .swipeActions(edge: .leading) {
                            if carried.contains(item.dragToken) {
                                Button {
                                    // 단계도 부모와 한 덩어리로 같이 옮긴다.
                                    for node in tree.subtree(of: item) { node.weekStartDate = weekStart }
                                    save()
                                } label: {
                                    Label("이번 주로", systemImage: "arrow.uturn.left")
                                }
                                .tint(.blue)
                            }
                            todayButton(for: item, tree: tree)
                            errandButton(for: item, tree: tree)
                        }
                        .contextMenu { itemMenu(for: item, tree: tree) }
                }
                .onDelete { delete(items, at: $0, tree: tree) }

                // 4. 완료 — 목록에는 줄 하나만 남기고 상세로 넘긴다. 끝난 일은
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
    private static let markedTint = nowGreen.opacity(0.16)
    private static let errandTint = Color.secondary.opacity(0.07)
    private static let doneTint = Color.secondary.opacity(0.03)

    /// 목록 아래 한 줄. 머리글을 없앴으니 셈과 안내도 여기 한 번에 모은다.
    @ViewBuilder
    private func listFooter(items: [BacklogItem],
                            errands: [BacklogItem],
                            marked: [BacklogItem],
                            done: [BacklogItem]) -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            // ⚠️ 여기서 시간을 합치지 말 것. 단위가 다른 것을 더하면
            //    "2시간 벌었는데 왜 아무것도 못 했지"라는 잘못된 죄책감이 생긴다.
            Text(countLine(items: items, errands: errands, marked: marked, done: done))
            Text("연두는 5분이 나면 그냥 집어도 되는 줄입니다. 회색은 시간을 안 잡은 줄.\n왼쪽으로 밀면 시간 잡기·오늘·바로 표시.")
        }
    }

    private func countLine(items: [BacklogItem],
                           errands: [BacklogItem],
                           marked: [BacklogItem],
                           done: [BacklogItem]) -> String
    {
        var parts: [String] = []
        if !marked.isEmpty { parts.append("바로 \(marked.count)개") }
        if !errands.isEmpty { parts.append("그냥 \(errands.count)개") }
        parts.append("시간 잡은 일 \(items.count)개")
        if !done.isEmpty { parts.append("완료 \(done.count)개") }
        return parts.joined(separator: " · ")
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
            let lane = tree.lane(of: item, hasDeadline: deadlines[item.dragToken] != nil)
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
        let target = tree.hasChildren(item) ? (tree.currentStep(of: item) ?? item) : item
        withAnimation {
            target.setFragmentAnswer(value ? true : nil, for: .start)
            target.setFragmentAnswer(value ? true : nil, for: .closing)
            save()
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

    /// 스와이프 한 번으로 두 칸 사이를 오간다.
    ///
    /// 시간을 0으로 만드는 것이 곧 표시다 — 따로 종류 필드를 두지 않는다.
    /// 단계로 쪼갠 일은 이미 시간이 아래에서 쌓여 올라오므로 대상이 아니고,
    /// 마감이 붙은 일은 무지개에서 먼저 빼야 한다.
    @ViewBuilder
    private func errandButton(for item: BacklogItem, tree: TodoTree) -> some View {
        if !tree.hasChildren(item), deadlines[item.dragToken] == nil {
            let isErrand = tree.isErrand(item)
            Button {
                withAnimation {
                    if isErrand {
                        item.durationHours = TodoTree.defaultStepHours
                    } else {
                        item.durationHours = TodoTree.errandHours
                        // 시간이 0이 된 일을 오늘 계획에 세워 둘 수는 없다.
                        if assignedToday.contains(item.title) {
                            setAssignedToday(false, for: item, tree: tree)
                        }
                    }
                    save()
                }
            } label: {
                Label(isErrand ? "시간 잡기" : "그냥 하기",
                      systemImage: isErrand ? "clock" : "bolt")
            }
            .tint(isErrand ? .indigo : .teal)
        }
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

            Section {
                ForEach(open) { todo in
                    FamilyTodoRow(todo: todo) { t in
                        Task { await family.toggle(t) }
                    }
                }
                .onDelete { offsets in
                    let victims = offsets.map { open[$0] }
                    Task { for v in victims { await family.delete(v) } }
                }

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
                            Task { await family.toggle(t) }
                        }
                    }
                    .onDelete { offsets in
                        let victims = offsets.map { done[$0] }
                        Task { for v in victims { await family.delete(v) } }
                    }
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
                        guard let item = TodoEventBridge.shared.makeTodo(for: event) else { return }
                        refreshRainbowPending()
                        refreshDeadlines()
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

    /// 스와이프용 '오늘' 토글 버튼.
    @ViewBuilder
    private func todayButton(for item: BacklogItem, tree: TodoTree) -> some View {
        let assigned = assignedToday.contains(item.title)
        Button {
            setAssignedToday(!assigned, for: item, tree: tree)
        } label: {
            Label(assigned ? "오늘 취소" : "오늘",
                  systemImage: assigned ? "calendar.badge.minus" : "calendar.badge.plus")
        }
        .tint(assigned ? .gray : .orange)
    }

    @ViewBuilder
    private func itemMenu(for item: BacklogItem, tree: TodoTree) -> some View {
        let assigned = assignedToday.contains(item.title)
        Button {
            setAssignedToday(!assigned, for: item, tree: tree)
        } label: {
            Label(assigned ? "오늘 배정 취소" : "오늘 할 일로 배정",
                  systemImage: assigned ? "calendar.badge.minus" : "calendar.badge.plus")
        }
        Button {
            beginDeadlinePick(for: item)
        } label: {
            Label(deadlines[item.dragToken] == nil ? "데드라인 정하기" : "데드라인 바꾸기",
                  systemImage: "flag.checkered")
        }
        if !tree.hasChildren(item), deadlines[item.dragToken] == nil {
            let isErrand = tree.isErrand(item)
            Button {
                withAnimation {
                    if isErrand {
                        item.durationHours = TodoTree.defaultStepHours
                    } else {
                        item.durationHours = TodoTree.errandHours
                        if assignedToday.contains(item.title) {
                            setAssignedToday(false, for: item, tree: tree)
                        }
                    }
                    save()
                }
            } label: {
                Label(isErrand ? "시간 잡기" : "그냥 하면 되는 것으로",
                      systemImage: isErrand ? "clock" : "bolt")
            }
        }
        // 지금 할 단계를 '맥락 없이 바로 되는 것'으로 표시한다. 표시한 줄은 위 칸에 모인다.
        if !tree.isErrand(item) || deadlines[item.dragToken] != nil {
            let marked = tree.markedStep(of: item) != nil
            Button {
                setMarked(!marked, for: item, tree: tree)
            } label: {
                Label(marked ? "'바로' 표시 거두기" : "바로 하면 되는 일로 표시",
                      systemImage: marked ? "bolt.slash" : "bolt.fill")
            }
        }
        if deadlines[item.dragToken] != nil {
            Button {
                TodoEventBridge.shared.clearRainbow(for: item)
                refreshDeadlines()
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
            context.delete(item)
            save()
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
                context.insert(BacklogItem(title: title,
                                           durationHours: TodoTree.errandHours,
                                           sortIndex: maxIndex + 1,
                                           weekStartDate: weekStart))
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

    /// 할 일을 지우면 그 안의 단계도 함께 지운다.
    private func delete(_ items: [BacklogItem], at offsets: IndexSet, tree: TodoTree) {
        for index in offsets {
            // 할 일이 사라지면 그 일 때문에 그어 둔 무지개 줄도 남을 이유가 없다.
            TodoEventBridge.shared.clearRainbow(for: items[index])
            for node in tree.subtree(of: items[index]) { context.delete(node) }
        }
        refreshDeadlines()
        save()
    }

    private func save() {
        try? context.save()
        syncWidget()
    }

    /// 할 일을 오늘 계획 블록으로 올리거나 내린다.
    /// 성공하면 맥 '무지개 공방' 타임라인과 iOS 무지개(밀도) 화면 양쪽에 반영된다.
    /// 계획 블록의 제목은 항상 최상위 할 일 제목이다 — 단계가 넘어가도 배지와
    /// 배정 취소가 계속 맞아떨어져야 하기 때문. 대신 올리는 **시간**은 오늘 실제로 할
    /// 만큼, 즉 지금 할 단계의 예상 시간을 쓴다.
    private func setAssignedToday(_ assign: Bool, for item: BacklogItem, tree: TodoTree) {
        let store = WeekBlocksStore.shared
        let hours = tree.currentStep(of: item)?.durationHours ?? tree.totalHours(of: item)
        let ok = assign
            ? store.assign(title: item.title, durationHours: hours)
            : store.unassign(title: item.title)

        guard ok else {
            // iCloud 미로그인 등으로 계획 스토어를 못 열면 조용히 실패한다.
            // 배지가 켜지지 않는 것으로 사용자에게 드러난다.
            print("⚠️ [Todo] 오늘 배정 \(assign ? "실패" : "취소 실패"): \(item.title)")
            return
        }
        withAnimation { refreshAssignedToday() }
        syncWidget()
    }

    /// 팁이 언제 뜰지 정하는 값들을 최신으로 맞춘다 (→ TodoTips.swift).
    private func refreshTipRules() {
        let tree = TodoTree(allItems)
        if tree.roots.contains(where: { tree.children(of: $0).count >= 2 }) { ShareSplitTip.hasSplit = true }
    }

    /// 오늘 배정된 제목 집합을 다시 읽는다.
    private func refreshAssignedToday() {
        assignedToday = WeekBlocksStore.shared.titlesAssigned()
    }

    /// 무지개에 그어져 있는 데드라인들을 다시 읽는다.
    private func refreshDeadlines() {
        deadlines = TodoEventBridge.shared.deadlinesByToken()
    }

    /// 무지개에만 있고 할 일에는 아직 없는 일들을 다시 읽는다.
    private func refreshRainbowPending() {
        withAnimation { rainbowPending = TodoEventBridge.shared.pendingFromRainbow(weekStart: weekStart) }
    }

    // MARK: - 데드라인

    /// 날짜를 직접 고르는 시트를 연다. 이미 정해져 있으면 그 날짜에서 시작한다.
    private func beginDeadlinePick(for item: BacklogItem) {
        pickedDeadline = deadlines[item.dragToken] ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        deadlinePickerItem = item
    }

    /// 데드라인을 정하고, 오늘부터 그 날까지 무지개에 한 줄을 긋는다.
    private func setDeadline(_ date: Date, for item: BacklogItem) {
        let hours = TodoTree(allItems).totalHours(of: item)
        guard TodoEventBridge.shared.drawRainbow(for: item, deadline: date, hours: hours) else { return }
        refreshDeadlines()
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
    /// 오늘 계획 블록으로 올라가 있는지 (맥 타임라인·무지개에 표시되는 상태).
    let isAssignedToday: Bool
    /// 무지개에 그어 둔 줄의 끝나는 날. 없으면 아직 마감이 없는 일.
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
                          total: tree.leafCount(of: item))
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
                      total: tree.leafCount(of: item))
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.secondary)
        }
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

                if isAssignedToday { todayBadge }
                if let deadline, !item.isCompleted { deadlineBadge(deadline) }
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
        if hasSteps, let number = tree.currentStepNumber(of: item) {
            text = "\(item.title), \(tree.leafCount(of: item))단계 중 \(number)번째, \(displayTitle)"
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

    private var todayBadge: some View {
        Text("오늘")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.orange.opacity(0.15)))
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
