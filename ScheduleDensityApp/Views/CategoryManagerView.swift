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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        Button {
                            editing = category
                        } label: {
                            row(category)
                        }
                        .buttonStyle(.plain)
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
                        Text("눌러서 고치고, 왼쪽으로 밀어 지웁니다. 길게 눌러 끌면 순서가 바뀝니다.")
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

    private func row(_ category: BacklogCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 15))
                .foregroundStyle(category.displayColor)
                .frame(width: 26)
            Text(category.name)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            // 쓰고 있는 할 일이 몇인지. 지울지 말지를 여기서 판단한다.
            let count = itemCount(using: category)
            if count > 0 {
                Text("\(count)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), 할 일 \(itemCount(using: category))개")
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
