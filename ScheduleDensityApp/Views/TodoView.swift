//
//  TodoView.swift
//  ScheduleDensityApp
//
//  간단한 Todo 리스트.
//  - 내 할 일: CloudKit을 통해 맥앱 '무지개 공방'의 주간 백로그와 동기화
//  - 가족: CKShare(존 전체 공유)로 가족 구성원끼리 실시간 공유
//

import SwiftUI
import SwiftData

struct TodoView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case mine = "내 할 일"
        case family = "가족"
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
    @State private var newCategoryID: String? = nil
    @State private var showingFamilyShareNotice = false
    @FocusState private var inputFocused: Bool

    private let cal = Calendar(identifier: .iso8601)
    private var weekStart: Date { .currentWeekStart }

    /// 이번 주, 아직 안 한 일.
    private var openItems: [BacklogItem] {
        allItems.filter { !$0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
    }

    /// 이번 주에 완료한 일 (최근 완료가 위).
    private var doneItems: [BacklogItem] {
        allItems
            .filter { $0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// 지난 주에 못 하고 남은 일.
    private var carryoverItems: [BacklogItem] {
        allItems.filter { !$0.isCompleted && $0.weekStartDate < weekStart && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .mine: myList
                case .family: familyList
                }
            }
            .navigationTitle(tab == .mine ? "이번 주 할 일" : "가족 할 일")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("목록", selection: $tab) {
                        ForEach(Tab.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                if tab == .family {
                    ToolbarItem(placement: .topBarTrailing) { familyShareMenu }
                }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
        }
        .alert("가족 공유 시작", isPresented: $showingFamilyShareNotice) {
            Button("공유 시작") {
                Task { await family.startSharing() }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("초대 링크를 받은 사람은 누구나 이 목록에 참여해 함께 읽고 쓸 수 있습니다.\n링크는 가족에게만 보내주세요.")
        }
        .task { await family.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await family.refresh() }
            }
        }
    }

    // MARK: - 내 할 일

    private var myList: some View {
        List {
            if !carryoverItems.isEmpty {
                Section("지난 주에 못 한 일") {
                    ForEach(carryoverItems) { item in
                        TodoRow(item: item, category: category(of: item), onToggle: toggle)
                            .swipeActions(edge: .leading) {
                                Button {
                                    item.weekStartDate = weekStart
                                    save()
                                } label: {
                                    Label("이번 주로", systemImage: "arrow.uturn.left")
                                }
                                .tint(.blue)
                            }
                    }
                    .onDelete { delete(carryoverItems, at: $0) }
                }
            }

            Section {
                ForEach(openItems) { item in
                    TodoRow(item: item, category: category(of: item), onToggle: toggle)
                        .contextMenu { categoryMenu(for: item) }
                }
                .onDelete { delete(openItems, at: $0) }
            } header: {
                if !openItems.isEmpty {
                    Text("이번 주 · \(openItems.count)개 · \(formatDuration(openItems.reduce(0) { $0 + $1.durationHours }))")
                }
            }

            if !doneItems.isEmpty {
                Section("완료 · \(doneItems.count)개") {
                    ForEach(doneItems) { item in
                        TodoRow(item: item, category: category(of: item), onToggle: toggle)
                    }
                    .onDelete { delete(doneItems, at: $0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(TapGesture().onEnded { inputFocused = false })
        .overlay {
            if openItems.isEmpty && doneItems.isEmpty && carryoverItems.isEmpty {
                ContentUnavailableView(
                    "할 일이 없습니다",
                    systemImage: "checklist",
                    description: Text("아래 입력창에 할 일을 추가하세요.\n맥앱 '무지개 공방'과 자동으로 동기화됩니다.")
                )
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 가족 할 일

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
                    Text("초대 링크를 받은 사람은 누구나 참여할 수 있어요. 링크는 가족에게만 보내주세요.")
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
                        description: Text("설정에서 iCloud에 로그인하면 가족과 할 일을 공유할 수 있습니다.")
                    )
                } else if family.isBusy {
                    ProgressView()
                } else {
                    ContentUnavailableView(
                        "가족 할 일이 없습니다",
                        systemImage: "person.2",
                        description: Text(family.isSharing
                                          ? "아래 입력창에 할 일을 추가하세요."
                                          : "오른쪽 위 공유 버튼으로 가족을 초대하거나,\n가족이 보낸 초대 링크를 눌러 참여하세요.")
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
                        Label("가족 공유 시작", systemImage: "person.2.badge.plus")
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

            TextField(tab == .mine ? "할 일 추가" : "가족 할 일 추가", text: $newTitle)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit(add)

            Button(action: add) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
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

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        if tab == .family {
            Task { await family.add(title: title) }
        } else {
            let maxIndex = allItems.map(\.sortIndex).max() ?? -1
            context.insert(BacklogItem(title: title,
                                       durationHours: 1,
                                       sortIndex: maxIndex + 1,
                                       categoryID: newCategoryID,
                                       weekStartDate: weekStart))
            save()
        }
        newTitle = ""
        inputFocused = true
    }

    private func toggle(_ item: BacklogItem) {
        withAnimation {
            item.isCompleted.toggle()
            item.completedAt = item.isCompleted ? Date() : nil
            save()
        }
    }

    private func delete(_ items: [BacklogItem], at offsets: IndexSet) {
        for index in offsets {
            context.delete(items[index])
        }
        save()
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - 행

private struct TodoRow: View {
    let item: BacklogItem
    let category: BacklogCategory?
    let onToggle: (BacklogItem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isCompleted ? .green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                if let category {
                    HStack(spacing: 4) {
                        Circle().fill(category.displayColor).frame(width: 7, height: 7)
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(formatDuration(item.durationHours))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
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
