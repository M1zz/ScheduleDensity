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
    @State private var newCategoryID: String? = nil
    /// 빈 줄에 지금 적히면 붙을 속성(= 착수 조건). 고르지 않아도 지난번 값이 그대로 따라와서,
    /// 적고 엔터만 쳐도 한 줄이 확정된다. 시간은 속성이 데려온다.
    @AppStorage("todo.newLabel") private var newLabelRaw: String = TodoLabel.ready.rawValue
    @State private var showingFamilyShareNotice = false
    @FocusState private var inputFocused: Bool

    private let cal = Calendar(identifier: .iso8601)
    private var weekStart: Date { .currentWeekStart }

    /// 목록 맨 아래 빈 줄의 id — 키보드가 올라올 때 그 줄로 스크롤하기 위해.
    private static let newRowID = "todo.newRow"

    // 목록에는 최상위 할 일만 줄로 세운다. 그 안의 단계는 줄 하나 안에서
    // '지금 할 일'로 접혀 보이고, 전체 흐름은 TodoDetailView에서 본다.

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
            .toolbar {
                if visibleTab == .family {
                    ToolbarItem(placement: .topBarTrailing) { familyShareMenu }
                }
                // 목록이 길 때 맨 아래 빈 줄까지 스크롤하지 않아도 되도록.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        inputFocused = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("할 일 추가")
                }
            }
            // 세그먼트를 네비게이션 바(.principal) 대신 그 아래에 둔다.
            // .principal은 leading/trailing을 뺀 '남은 공간'의 가운데에 놓여서,
            // 공유 탭에서만 나타나는 공유 버튼 때문에 그때만 왼쪽으로 밀렸다.
            // 툴바 밖에 두면 두 탭 모두 항상 화면 정중앙이다.
            .safeAreaInset(edge: .top, spacing: 0) { tabPicker }
        }
        .alert("할 일 공유 시작", isPresented: $showingFamilyShareNotice) {
            Button("공유 시작") {
                Task { await family.startSharing() }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("초대 링크를 받은 사람은 누구나 이 목록에 참여해 함께 읽고 쓸 수 있습니다.\n링크는 함께할 사람에게만 보내주세요.")
        }
        .task {
            refreshAssignedToday()
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

    private var myList: some View {
        let tree = TodoTree(allItems)
        let carryover = carryoverItems(tree)
        let open = openItems(tree)
        // 지난 주에 밀린 일과 이번 주 일을 한 줄기로 세운다. 밀린 것이 위로 온다.
        // 섹션을 갈라 놓으면 '지난 주에 못 한 일'이라는 이름표를 매번 읽어야 했다 —
        // 밀렸다는 사실은 옮길 때만 필요하고, 그건 스와이프에 남겨 뒀다.
        let items = carryover + open
        let carried = Set(carryover.map(\.dragToken))
        let done = doneItems(tree)

        return ScrollViewReader { proxy in
        List {
            Section {
                ForEach(items) { item in
                    TodoRow(item: item,
                            tree: tree,
                            category: category(of: item),
                            isAssignedToday: assignedToday.contains(item.title),
                            onAdvance: advance)
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
                        }
                        .contextMenu { itemMenu(for: item, tree: tree) }
                }
                .onDelete { delete(items, at: $0, tree: tree) }

                // 줄들 바로 아래에 빈 줄 하나. 여기에 적는다.
                newTodoRow
            } header: {
                if !items.isEmpty {
                    Text("\(items.count)개 · \(formatDuration(items.reduce(0) { $0 + tree.totalHours(of: $1) }))")
                }
            } footer: {
                if items.isEmpty {
                    Text("위 빈 줄에 바로 적으면 이번 주 할 일이 됩니다. 엔터를 치면 한 줄이 확정되고 빈 줄이 다시 옵니다.\n맥앱 '무지개 공방'과 자동으로 동기화됩니다.")
                }
            }

            if !done.isEmpty {
                Section("완료 · \(done.count)개") {
                    ForEach(done) { item in
                        TodoRow(item: item,
                                tree: tree,
                                category: category(of: item),
                                isAssignedToday: false,
                                onAdvance: advance)
                    }
                    .onDelete { delete(done, at: $0, tree: tree) }
                }
            }
        }
        .listStyle(.insetGrouped)
        // 입력이 목록 안에 있으므로 스크롤로 키보드를 바로 내리면 적다가 끊긴다.
        // 손가락을 따라 내려가게 두고, 다 적었으면 빈 줄에서 엔터로 닫는다.
        .scrollDismissesKeyboard(.interactively)
        // 키보드가 올라오거나 한 줄이 확정되면 빈 줄이 계속 보이게 따라간다.
        .onChange(of: inputFocused) { _, focused in
            if focused { scrollToNewRow(proxy) }
        }
        .onChange(of: allItems.count) { _, _ in
            if inputFocused { scrollToNewRow(proxy) }
        }
        }
    }

    private func scrollToNewRow(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Self.newRowID, anchor: .bottom)
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

            TextField(tab == .mine ? "할 일 추가" : "공유 할 일 추가", text: $newTitle)
                .focused($inputFocused)
                .submitLabel(.return)
                .onSubmit(add)

            if tab == .mine {
                // 분류를 만들어 둔 사람에게만 보여준다 — 안 쓰는 사람의 줄까지 복잡해지지 않게.
                if !categories.isEmpty { newCategoryMenu }
                newLabelMenu
            }
        }
        .padding(.vertical, 2)
        .id(Self.newRowID)
    }

    /// 이 줄을 지금 시작할 수 있는지. 손대지 않으면 지난번에 고른 값이 따라오므로,
    /// 적고 엔터만 쳐도 추가된다. 시간은 고른 속성이 데려온다.
    @ViewBuilder
    private var newLabelMenu: some View {
        // 처음 쓰는 사람에게만 한 번, 적기 시작한 뒤에 이 칩이 무엇인지 알려준다.
        // 빈 줄에 그냥 두면 앱을 켜자마자 아무것도 안 했는데 설명부터 받는 꼴이 된다.
        if newTitle.isEmpty {
            labelMenu
        } else {
            labelMenu.popoverTip(LabelPickTip())
        }
    }

    private var labelMenu: some View {
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
            TodoLabelChip(label: draftLabel, hours: draftLabel.defaultHours)
        }
    }

    /// 지금 빈 줄에 적히면 붙을 라벨.
    private var draftLabel: TodoLabel {
        TodoLabel.resolve(newLabelRaw) ?? .ready
    }

    private var newCategoryMenu: some View {
        let current = categories.first { $0.uuid == newCategoryID }
        return Menu {
            Button {
                newCategoryID = nil
            } label: {
                Label("미분류", systemImage: newCategoryID == nil ? "checkmark" : "circle")
            }
            ForEach(categories) { c in
                Button {
                    newCategoryID = c.uuid
                } label: {
                    Label(c.name, systemImage: newCategoryID == c.uuid ? "checkmark" : c.iconName)
                }
            }
        } label: {
            Image(systemName: current?.iconName ?? "tag")
                .font(.system(size: 16))
                .foregroundStyle(current?.displayColor ?? Color.secondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill((current?.displayColor ?? Color.secondary).opacity(0.15)))
        }
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
            // 속성 = 착수 조건. 시간은 속성이 데려오고, 안에서 단계를 나누면
            // 상위 시간은 단계들의 합으로 다시 계산된다 (아래에서 위로).
            let label = draftLabel
            let maxIndex = allItems.map(\.sortIndex).max() ?? -1
            withAnimation {
                context.insert(BacklogItem(title: title,
                                           durationHours: label.defaultHours,
                                           sortIndex: maxIndex + 1,
                                           categoryID: newCategoryID,
                                           weekStartDate: weekStart,
                                           label: label))
                save()
            }
            LabelPickTip.hasPicked = true
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
            for node in tree.subtree(of: items[index]) { context.delete(node) }
        }
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
        if allItems.contains(where: { $0.labelRaw != nil }) { LabelPickTip.hasPicked = true }
        if tree.roots.contains(where: { tree.children(of: $0).count >= 2 }) { ShareSplitTip.hasSplit = true }
    }

    /// 오늘 배정된 제목 집합을 다시 읽는다.
    private func refreshAssignedToday() {
        assignedToday = WeekBlocksStore.shared.titlesAssigned()
    }

    /// 홈·잠금 화면 위젯이 읽는 스냅샷을 다시 굽는다.
    private func syncWidget() {
        TodoWidgetSync.refresh(context: context)
    }
}

// MARK: - 행

private struct TodoRow: View {
    let item: BacklogItem
    let tree: TodoTree
    let category: BacklogCategory?
    /// 오늘 계획 블록으로 올라가 있는지 (맥 타임라인·무지개에 표시되는 상태).
    let isAssignedToday: Bool
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
        } else if hasSteps {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(0.02, tree.progress(of: item)))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 22, height: 22)
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
        HStack(spacing: 8) {
            Text(displayTitle)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                .lineLimit(2)

            if isAssignedToday { todayBadge }
            if let category {
                Circle()
                    .fill(category.displayColor)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(category.name)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    /// 줄에 설 이름. 남은 단계가 있으면 그 단계, 아니면 할 일 자신.
    private var displayTitle: String { (currentStep ?? item).title }

    private var todayBadge: some View {
        Text("오늘")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.orange.opacity(0.15)))
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
