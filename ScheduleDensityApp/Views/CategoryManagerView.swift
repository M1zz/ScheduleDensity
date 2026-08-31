//
//  CategoryManagerView.swift
//
//  분류를 만들고 고치는 자리.
//
//  분류는 고를 수는 있는데 만들 데가 없었다 — 처음 쓰는 사람에게는 고를 것이 하나도 없는
//  메뉴만 열렸다. 만드는 자리는 **고르는 자리 안**에 있어야 한다. 지금 분류를 정하려다
//  '없네'를 알게 되는 것이므로, 그 자리를 떠나 설정까지 다녀오게 하면 하려던 일을 잊는다.
//  그래서 분류 메뉴 맨 아래에서도 열고(→ TodoDetailView), 설정에서도 연다(→ SettingsView).
//
//  ⚠️ `BacklogCategory`는 할 일 스토어(`WeekBlocksTodos`, CloudKit)에 있다.
//     무지개 탭의 설정은 일정 스토어에서 돌기 때문에, 거기서 열 때는 컨테이너를
//     따로 붙여줘야 한다 (→ `SettingsView`의 시트).
//

import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\BacklogCategory.sortIndex), SortDescriptor(\BacklogCategory.createdAt)])
    private var categories: [BacklogCategory]

    /// 지금 고치고 있는 분류. nil이면 시트가 닫혀 있고, 새로 만드는 중이면 `isAdding`.
    @State private var editing: BacklogCategory?
    @State private var isAdding = false
    /// 지우려는 분류 — 쓰고 있는 할 일이 있으면 몇 개인지 먼저 말해준다.
    @State private var deleting: BacklogCategory?
    /// 옆에 선 숫자를 눌렀을 때 — 그 숫자가 무엇인지 펼쳐 보여줄 분류.
    @State private var inspecting: BacklogCategory?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        row(category)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleting = category
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                    }
                    .onMove(perform: move)
                } header: {
                    Text("분류")
                } footer: {
                    if categories.isEmpty {
                        Text("아직 만든 분류가 없습니다. 아래에서 하나 만들어 보세요.")
                    } else {
                        Text("눌러서 고치고, 왼쪽으로 밀어 지웁니다. 길게 눌러 끌면 순서가 바뀝니다.\n오른쪽 숫자는 이 분류를 쓰는 할 일 수입니다 — 눌러 보면 무엇무엇인지 나옵니다.")
                    }
                }

                Section {
                    Button {
                        isAdding = true
                    } label: {
                        Label("분류 만들기", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("분류")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(item: $editing) { category in
                // 고칠 때는 그 자리에서 값이 바뀌므로 돌려받을 게 없다.
                CategoryEditSheet(category: category) { _ in save() }
            }
            .sheet(item: $inspecting) { category in
                CategoryItemsView(category: category)
            }
            .sheet(isPresented: $isAdding) {
                CategoryEditSheet(category: nil, nextSortIndex: nextSortIndex) { new in
                    if let new { context.insert(new) }
                    save()
                }
            }
            .alert("분류 삭제", isPresented: Binding(
                get: { deleting != nil },
                set: { if !$0 { deleting = nil } }
            ), presenting: deleting) { category in
                Button("취소", role: .cancel) { deleting = nil }
                Button("삭제", role: .destructive) { remove(category) }
            } message: { category in
                let count = itemCount(using: category)
                Text(count == 0
                     ? "‘\(category.name)’을(를) 지웁니다."
                     : "‘\(category.name)’을(를) 지우면 이 분류를 쓰던 할 일 \(count)개가 미분류로 바뀝니다.\n할 일 자체는 지워지지 않습니다.")
            }
        }
    }

    /// 한 줄에 손댈 곳이 둘이다: **이름 쪽은 고치기**, **숫자 쪽은 그 숫자의 내역**.
    ///
    /// 숫자를 따로 누를 수 있게 둔 이유 — 이 셈에는 완료한 것과 지난 주에서 넘어온 것,
    /// 큰 일 안의 단계까지 들어간다(단계는 분류를 부모에게서 물려받는다). 그래서 이번 주
    /// 목록에 보이는 줄 수와 어긋나는 순간이 오고, 그때 "그럼 이 숫자가 뭔데"를 묻게 된다.
    /// 답이 같은 줄 안에 있어야 한다 — 세어보러 화면을 떠나게 하면 지우기가 무서워진다.
    private func row(_ category: BacklogCategory) -> some View {
        let count = itemCount(using: category)
        return HStack(spacing: 12) {
            Button {
                editing = category
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 15))
                        .foregroundStyle(category.displayColor)
                        .frame(width: 26)
                    Text(category.name)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(category.name), 눌러서 고치기")

            // 쓰고 있는 할 일이 몇인지. 지울지 말지를 여기서 판단한다.
            if count > 0 {
                Button {
                    inspecting = category
                } label: {
                    HStack(spacing: 4) {
                        Text("\(count)")
                            .font(.footnote)
                            .monospacedDigit()
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(category.name), 할 일 \(count)개. 눌러서 내역 보기")
            }

            Button {
                editing = category
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 동작

    private var nextSortIndex: Int { (categories.map(\.sortIndex).max() ?? -1) + 1 }

    /// 이 분류를 쓰고 있는 할 일 수. 지울 때 뭘 잃는지 먼저 말해주려고 센다.
    private func itemCount(using category: BacklogCategory) -> Int {
        let id = category.uuid
        let descriptor = FetchDescriptor<BacklogItem>(
            predicate: #Predicate { $0.categoryID == id })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// 분류를 지우면서, 그걸 쓰던 할 일들의 연결도 같이 끊는다.
    ///
    /// 끊지 않으면 어디에도 없는 uuid가 할 일에 남는다. 화면에는 '미분류'로 보이지만
    /// 값은 남아 있어, 나중에 우연히 같은 uuid가 생기면 엉뚱한 분류로 되살아난다.
    private func remove(_ category: BacklogCategory) {
        let id = category.uuid
        let descriptor = FetchDescriptor<BacklogItem>(
            predicate: #Predicate { $0.categoryID == id })
        for item in (try? context.fetch(descriptor)) ?? [] {
            item.categoryID = nil
        }
        context.delete(category)
        deleting = nil
        save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, category) in ordered.enumerated() { category.sortIndex = i }
        withAnimation { save() }
    }

    private func save() {
        try? context.save()
        // 분류의 색·이름은 위젯 줄에도 찍힌다. 고쳤으면 거기도 따라가야 한다.
        TodoWidgetSync.refresh(context: context)
    }
}

// MARK: - 하나 만들기·고치기

private struct CategoryEditSheet: View {
    /// nil이면 새로 만드는 중.
    let category: BacklogCategory?
    var nextSortIndex: Int = 0
    /// 고치는 중이면 nil을 돌려주고(제자리에서 이미 고쳐졌다), 새로 만든 것이면 그것을 돌려준다.
    let onCommit: (BacklogCategory?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorName = "blue"
    @State private var iconName = "tag"

    private var isNew: Bool { category == nil }
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        // 지금 고르고 있는 것이 어떻게 보이는지. 색과 기호를 따로 고르면
                        // 합쳐진 모습을 상상해야 하는데, 그럴 필요 없이 여기 있다.
                        Image(systemName: iconName)
                            .font(.system(size: 17))
                            .foregroundStyle(paletteColor(colorName))
                            .frame(width: 28)
                        TextField("분류 이름", text: $name)
                    }
                } header: {
                    Text("이름")
                }

                Section {
                    // 색은 무지개 팔레트 그대로다 — 일정과 같은 7색을 쓴다.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(Rainbow.spectrum, id: \.name) { swatch in
                            Button {
                                colorName = swatch.name
                            } label: {
                                Circle()
                                    .fill(Color(hex: swatch.hex) ?? .accentColor)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if colorName == swatch.name {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(colorLabel(swatch.name))
                            .accessibilityAddTraits(colorName == swatch.name ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("색")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(categoryIconOptions, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 17))
                                    .frame(width: 34, height: 34)
                                    .foregroundStyle(iconName == icon ? Color.white : Color.primary)
                                    .background {
                                        Circle().fill(iconName == icon
                                                      ? paletteColor(colorName)
                                                      : Color.secondary.opacity(0.12))
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                            .accessibilityAddTraits(iconName == icon ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("기호")
                }
            }
            .navigationTitle(isNew ? "새 분류" : "분류 고치기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { commit() }
                        .disabled(trimmed.isEmpty)
                }
            }
            .onAppear {
                guard let category else { return }
                name = category.name
                colorName = category.colorName
                iconName = category.iconName
            }
        }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        if let category {
            category.name = trimmed
            category.colorName = colorName
            category.iconName = iconName
            onCommit(nil)
        } else {
            onCommit(BacklogCategory(name: trimmed,
                                     colorName: colorName,
                                     iconName: iconName,
                                     sortIndex: nextSortIndex))
        }
        dismiss()
    }

    /// 색 동그라미는 소리로 안 읽힌다. 이름을 우리말로 적어준다.
    private func colorLabel(_ name: String) -> String {
        switch name {
        case "red":    return "빨강"
        case "orange": return "주황"
        case "yellow": return "노랑"
        case "green":  return "초록"
        case "blue":   return "파랑"
        case "indigo": return "남색"
        case "purple": return "보라"
        default:       return name
        }
    }
}

// MARK: - 그 숫자가 무엇인지

/// 분류 줄 옆의 숫자를 눌렀을 때 열리는 자리. 같은 셈을 **그대로 펼쳐** 놓는다.
///
/// 셈의 규칙은 하나뿐이다 — `categoryID`가 이 분류인 항목 전부(→ `CategoryManagerView.itemCount`).
/// 그래서 완료한 것도, 지난 주에서 넘어온 것도, 큰 일 안의 단계도 들어간다
/// (단계는 분류를 부모에게서 물려받는다 → `TodoTree`). 이번 주 목록에 보이는 줄 수와
/// 어긋나 보이는 건 그 때문이고, 어긋남을 설명 없이 두면 숫자가 못 믿을 것이 된다.
///
/// ⚠️ 여기 칸들의 합은 **언제나 그 숫자와 같아야 한다.** 그래서 '이번 주·지난 주·다음 주 이후·완료'로
///    빠짐없이 가른다. 보기 좋으라고 한 칸이라도 빼면, 설명하러 만든 화면이 설명을 어긴다.
private struct CategoryItemsView: View {
    let category: BacklogCategory

    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\BacklogItem.sortIndex), SortDescriptor(\BacklogItem.createdAt)])
    private var allItems: [BacklogItem]

    private let cal = Calendar(identifier: .iso8601)
    private var weekStart: Date { .currentWeekStart }

    /// 이 분류를 쓰는 항목 전부. 셈과 같은 규칙이어야 하므로 조건은 이것 하나뿐이다.
    private var mine: [BacklogItem] { allItems.filter { $0.categoryID == category.uuid } }

    private var thisWeek: [BacklogItem] {
        mine.filter { !$0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
    }
    private var carried: [BacklogItem] {
        mine.filter { !$0.isCompleted && $0.weekStartDate < weekStart && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .sorted { $0.weekStartDate > $1.weekStartDate }
    }
    private var later: [BacklogItem] {
        mine.filter { !$0.isCompleted && $0.weekStartDate > weekStart && !cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .sorted { $0.weekStartDate < $1.weekStartDate }
    }
    private var done: [BacklogItem] {
        mine.filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                if mine.isEmpty {
                    Section {
                        Text("이 분류를 쓰는 할 일이 아직 없습니다.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    section("이번 주", items: thisWeek)
                    section("지난 주에서 넘어온 것", items: carried)
                    section("다음 주 이후", items: later)
                    section("완료", items: done)

                    Section {
                        HStack {
                            Text("합계")
                            Spacer()
                            Text("\(mine.count)개")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("분류 목록 옆의 숫자가 이 합계입니다. 완료한 것과 지난 주에서 넘어온 것, 큰 일 안의 단계까지 함께 셉니다.\n이 분류를 지우면 위 할 일들이 ‘미분류’로 바뀌고, 할 일 자체는 그대로 남습니다.")
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    /// 빈 칸은 아예 그리지 않는다. 다만 어느 칸도 조건에서 빠지지는 않는다(위 ⚠️).
    @ViewBuilder
    private func section(_ title: String, items: [BacklogItem]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    itemRow(item)
                }
            } header: {
                HStack {
                    Text(title)
                    Spacer()
                    Text("\(items.count)개").monospacedDigit()
                }
            }
        }
    }

    private func itemRow(_ item: BacklogItem) -> some View {
        let tree = TodoTree(allItems)
        // 단계는 제 이름만 서 있으면 무슨 일의 일부인지 알 수 없다. 셈에 들어간 이유가
        // 바로 '부모의 분류를 물려받아서'이므로, 그 부모를 위에 작게 적어 둔다.
        let parentTitle = tree.parent(of: item)?.title
        return VStack(alignment: .leading, spacing: 3) {
            if let parentTitle {
                Text(parentTitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(trailingText(item))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(item, parentTitle: parentTitle))
    }

    /// 완료한 것은 언제 끝냈는지, 남은 것은 어느 주의 것인지. 숫자가 커진 이유가 대개 이 둘이다.
    private func trailingText(_ item: BacklogItem) -> String {
        if item.isCompleted, let at = item.completedAt {
            return shortDate(at) + " 완료"
        }
        if item.isCompleted { return "완료" }
        return shortDate(item.weekStartDate) + " 주"
    }

    private func accessibilityLabel(_ item: BacklogItem, parentTitle: String?) -> String {
        var text = item.title
        if let parentTitle { text = "\(parentTitle)의 단계, " + text }
        return text + ", " + trailingText(item)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
