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
    /// 적으면서 고르는 라벨. 고르기 전에는 추가할 수 없다 — 예상 시간을 반드시 받기 위해서.
    @State private var newLabel: TodoLabel? = nil
    /// 목록에서 한 종류만 보고 싶을 때. nil이면 전체.
    @State private var filterLabel: TodoLabel? = nil
    @State private var showingFamilyShareNotice = false
    @FocusState private var inputFocused: Bool

    private let cal = Calendar(identifier: .iso8601)
    private var weekStart: Date { .currentWeekStart }

    // 목록에는 최상위 할 일만 줄로 세운다. 그 안의 단계는 줄 하나 안에서
    // '지금 할 일'로 접혀 보이고, 전체 흐름은 TodoDetailView에서 본다.

    /// 이번 주, 아직 안 한 일.
    private func openItems(_ tree: TodoTree) -> [BacklogItem] {
        tree.roots
            .filter { !$0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .filter { matchesFilter($0, tree) }
    }

    /// 라벨 필터. 단계가 있으면 '지금 할 단계'의 라벨로 본다 —
    /// 지금 5분이 났을 때 집을 수 있는지는 그 단계가 결정하기 때문이다.
    private func matchesFilter(_ item: BacklogItem, _ tree: TodoTree) -> Bool {
        guard let filterLabel else { return true }
        return (tree.currentStep(of: item) ?? item).label == filterLabel
    }

    /// 이번 주에 완료한 일 (최근 완료가 위).
    private func doneItems(_ tree: TodoTree) -> [BacklogItem] {
        tree.roots
            .filter { $0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// 지난 주에 못 하고 남은 일.
    private func carryoverItems(_ tree: TodoTree) -> [BacklogItem] {
        tree.roots
            .filter { !$0.isCompleted && $0.weekStartDate < weekStart && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .filter { matchesFilter($0, tree) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .mine: myList
                case .family: familyList
                }
            }
            .navigationTitle(tab == .mine ? "이번 주 할 일" : "공유 할 일")
            // 세그먼트를 바 아래로 내리면서 제목도 인라인으로 바꾼다.
            // 큰 제목을 그대로 두면 세그먼트 뒤에 깔려 위쪽에 빈 띠만 남는다.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if tab == .family {
                    ToolbarItem(placement: .topBarTrailing) { familyShareMenu }
                }
            }
            // 세그먼트를 네비게이션 바(.principal) 대신 그 아래에 둔다.
            // .principal은 leading/trailing을 뺀 '남은 공간'의 가운데에 놓여서,
            // 공유 탭에서만 나타나는 공유 버튼 때문에 그때만 왼쪽으로 밀렸다.
            // 툴바 밖에 두면 두 탭 모두 항상 화면 정중앙이다.
            .safeAreaInset(edge: .top, spacing: 0) { tabPicker }
            .safeAreaInset(edge: .bottom) { inputBar }
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

    private var tabPicker: some View {
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

    // MARK: - 내 할 일

    private var myList: some View {
        let tree = TodoTree(allItems)
        let carryover = carryoverItems(tree)
        let open = openItems(tree)
        let done = doneItems(tree)

        return List {
            if hasAnyItem {
                if FragmentFilterTip().shouldDisplay {
                    TipView(FragmentFilterTip())
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 0, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                labelFilterBar
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !carryover.isEmpty {
                Section("지난 주에 못 한 일") {
                    ForEach(carryover) { item in
                        TodoRow(item: item,
                                tree: tree,
                                category: category(of: item),
                                isAssignedToday: assignedToday.contains(item.title),
                                onAdvance: advance)
                            .swipeActions(edge: .leading) {
                                Button {
                                    // 단계도 부모와 한 덩어리로 같이 옮긴다.
                                    for node in tree.subtree(of: item) { node.weekStartDate = weekStart }
                                    save()
                                } label: {
                                    Label("이번 주로", systemImage: "arrow.uturn.left")
                                }
                                .tint(.blue)
                                todayButton(for: item, tree: tree)
                            }
                            .contextMenu { itemMenu(for: item, tree: tree) }
                    }
                    .onDelete { delete(carryover, at: $0, tree: tree) }
                }
            }

            Section {
                ForEach(open) { item in
                    TodoRow(item: item,
                            tree: tree,
                            category: category(of: item),
                            isAssignedToday: assignedToday.contains(item.title),
                            onAdvance: advance)
                        .swipeActions(edge: .leading) { todayButton(for: item, tree: tree) }
                        .contextMenu { itemMenu(for: item, tree: tree) }
                }
                .onDelete { delete(open, at: $0, tree: tree) }
            } header: {
                if !open.isEmpty {
                    Text("이번 주 · \(open.count)개 · \(formatDuration(open.reduce(0) { $0 + tree.totalHours(of: $1) }))")
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
        // 키보드는 스크롤로 내린다. 여기에 TapGesture를 걸면 행의 NavigationLink가
        // 그 제스처에 먹혀 상세(단계) 화면으로 들어가지 못한다.
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if open.isEmpty && done.isEmpty && carryover.isEmpty {
                if let filterLabel {
                    ContentUnavailableView(
                        "‘\(filterLabel.name)’인 일이 없습니다",
                        systemImage: filterLabel.symbol,
                        description: Text("위 라벨에서 ‘전체’를 누르면 다시 다 보입니다.")
                    )
                    .allowsHitTesting(false)
                } else {
                    ContentUnavailableView(
                        "할 일이 없습니다",
                        systemImage: "checklist",
                        description: Text("아래 입력창에 할 일을 추가하세요.\n맥앱 '무지개 공방'과 자동으로 동기화됩니다.")
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - 공유 할 일

    private var familyList: some View {
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
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(TapGesture().onEnded { inputFocused = false })
        .refreshable { await family.refresh() }
        .overlay {
            if family.items.isEmpty {
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
                        "공유 할 일이 없습니다",
                        systemImage: "person.2",
                        description: Text(family.isSharing
                                          ? "아래 입력창에 할 일을 추가하세요."
                                          : "오른쪽 위 공유 버튼으로 함께할 사람을 초대하거나,\n상대가 보낸 초대 링크를 눌러 참여하세요.")
                    )
                    .allowsHitTesting(false)
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

    // MARK: - 입력 바

    private var inputBar: some View {
        VStack(spacing: 0) {
            // 라벨을 고르는 순간 예상 시간도 함께 정해진다.
            // 시간을 따로 묻지 않고도 모든 할 일이 시간을 갖게 하는 자리다.
            if tab == .mine && !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                labelPicker
            }

            HStack(spacing: 10) {
                if tab == .mine {
                    newCategoryMenu
                } else {
                    Image(systemName: "person.2")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                }

                TextField(tab == .mine ? "할 일 추가" : "공유 할 일 추가", text: $newTitle)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit(add)

                Button(action: add) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                }
                .disabled(!canAdd)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    /// 제목만으로는 추가할 수 없다 — 얼마나 걸릴 일인지(라벨)를 반드시 고르게 한다.
    private var canAdd: Bool {
        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return tab == .family || newLabel != nil
    }

    /// 라벨 고르기 줄. 고르기 전에는 왜 골라야 하는지 한 줄로 말해준다.
    private var labelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 처음 쓰는 사람에게만 한 번. 닫으면 다시 안 뜬다.
            TipView(LabelPickTip())
                .padding(.horizontal, 14)

            Text(newLabel.map(\.hint) ?? "얼마나 걸릴 일인가요?")
                .font(.caption)
                .foregroundStyle(newLabel == nil ? Color.orange : Color.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TodoLabel.allCases) { label in
                        Button {
                            newLabel = label
                            LabelPickTip.hasPicked = true
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

    /// 라벨로 목록을 걸러 보는 줄 — "지금 10분 났는데 뭐 하지"에 답하는 자리.
    private var labelFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    filterLabel = nil
                } label: {
                    Text("전체")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(filterLabel == nil ? Color.white : Color.secondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(filterLabel == nil ? Color.accentColor : Color.secondary.opacity(0.12)))
                }
                .buttonStyle(.plain)

                ForEach(TodoLabel.allCases) { label in
                    Button {
                        filterLabel = (filterLabel == label) ? nil : label
                    } label: {
                        TodoLabelChip(label: label, isSelected: filterLabel == label)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
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
                .frame(width: 30, height: 30)
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

    /// 필터를 걸기 전 기준으로 이번 주·지난 주에 뭔가 있는지.
    private var hasAnyItem: Bool {
        TodoTree(allItems).roots.contains { !$0.isCompleted && $0.weekStartDate <= weekStart }
    }

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        if tab == .family {
            Task { await family.add(title: title) }
        } else {
            // 라벨 = 예상 시간. 이 시간이 이 할 일의 100%가 되고,
            // 안에서 단계를 나누면 단계들이 이 시간을 나눠 갖는다.
            guard let label = newLabel else { return }
            let maxIndex = allItems.map(\.sortIndex).max() ?? -1
            context.insert(BacklogItem(title: title,
                                       durationHours: label.defaultHours,
                                       sortIndex: maxIndex + 1,
                                       categoryID: newCategoryID,
                                       weekStartDate: weekStart,
                                       label: label))
            save()
        }
        newTitle = ""
        inputFocused = true
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
        FragmentFilterTip.itemCount = tree.roots.filter { !$0.isCompleted }.count
        if allItems.contains(where: { $0.labelRaw != nil }) { LabelPickTip.hasPicked = true }
        if tree.roots.contains(where: { tree.children(of: $0).count >= 2 }) { ShareSplitTip.hasSplit = true }
        if allItems.contains(where: { $0.isManualWeight }) { LockedShareTip.hasLocked = true }
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
            }
        }
    }

    /// 이 줄을 눌러 들어가면 무엇이 있는지 알려주는 표시.
    /// 단계가 없으면 '단계 나누기'라고 말해줘야 들어가 볼 생각이 든다.
    private var stepsAffordance: some View {
        HStack(spacing: 3) {
            Image(systemName: hasSteps ? "list.bullet.indent" : "plus.circle")
                .font(.system(size: 10))
            Text(hasSteps ? "\(tree.leafCount(of: item))단계" : "단계 나누기")
                .font(.caption2)
        }
        .foregroundStyle(hasSteps ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill((hasSteps ? Color.accentColor : Color.secondary).opacity(0.12)))
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

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)

            if hasSteps {
                if let step = currentStep {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                        Text(step.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        // 지금 할 단계가 어떤 타입인지 — "10분 났는데 뭐 하지"에 답한다.
                        TodoLabelChip(label: step.label, hours: step.durationHours)
                    }
                }

                HStack(spacing: 8) {
                    ProgressView(value: tree.progress(of: item))
                        .tint(item.isCompleted ? .green : .accentColor)
                        .frame(maxWidth: 120)
                    Text("\(Int((tree.progress(of: item) * 100).rounded()))%")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let number = tree.currentStepNumber(of: item) {
                        Text("\(tree.leafCount(of: item))단계 중 \(number)번째")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 6) {
                // 단계가 없는 할 일은 자기 라벨이 곧 '이건 어떤 일인가'다.
                if !hasSteps {
                    TodoLabelChip(label: item.label, hours: tree.totalHours(of: item))
                }
                stepsAffordance
                if isAssignedToday { todayBadge }
                if let category {
                    HStack(spacing: 4) {
                        Circle().fill(category.displayColor).frame(width: 7, height: 7)
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if hasSteps {
                    Text("전체 \(formatDuration(tree.totalHours(of: item)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var todayBadge: some View {
        Text("오늘")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
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
