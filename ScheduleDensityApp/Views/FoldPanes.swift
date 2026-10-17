//
//  FoldPanes.swift
//  ScheduleDensityApp
//
//  아이폰 듀오를 폈을 때 탭마다 접힌 선 양쪽에 무엇이 서는가.
//  자리 셈 · 시트 가드 · 탭 막대는 LeeoKit Fold 모듈이 하고, 여기는 이 앱의 짝만 정한다.
//  시안: docs/product/process/screen-blueprint.html (욕망의 무지개 듀오 시안)
//
//  - 할 일:  왼쪽 이번 주 할 일 | 오른쪽 고른 일의 단계(`TodoDetailView`)
//  - 무지개: 왼쪽 무지개 격자   | 오른쪽 고른 날의 하루(`DayTab`)
//  - 공유:   왼쪽 공유받은 일정 | 오른쪽 내 하루
//  세로로 펴면 같은 짝이 아래 | 위로 선다(손은 아래, 눈은 위).
//
//  ⚠️ 하루 탭은 펼치면 무지개 탭의 오른쪽 판이 된다. 그래서 펼친 탭 막대에는 셋만 선다.
//  ⚠️ 줄을 누르면 지금은 상세로 **밀려 들어간다**(목록이 사라진다). 펴면 밀지 않고 오른쪽만 바꾼다
//     — 그 갈림은 `TodoDetailLink` 한 곳에서 한다. 줄마다 `NavigationLink` 를 직접 쓰지 말 것.
//

import SwiftUI
import SwiftData
import LeeoKit

// MARK: - 고른 할 일

/// 펼친 화면에서 오른쪽 판에 열린 할 일. 할 일 목록과 오른쪽 판이 함께 본다.
///
/// 접으면 `TodoView` 가 이 값을 받아 상세로 밀어 넣는다 — 보던 것을 잃지 않는다.
@MainActor
@Observable
final class FoldTodoSelection {
    static let shared = FoldTodoSelection()
    var root: BacklogItem?
    private init() {}

    func isOpen(_ item: BacklogItem) -> Bool {
        root?.persistentModelID == item.persistentModelID
    }
}

/// 줄에서 상세로 가는 길. 접혀 있으면 `NavigationLink` 그대로 밀고,
/// 펼쳐져 있으면 오른쪽 판에 연다.
struct TodoDetailLink<Label: View>: View {
    @Environment(\.foldLayout) private var fold
    let root: BacklogItem
    @ViewBuilder let label: () -> Label

    var body: some View {
        if fold.isUnfolded {
            let selection = FoldTodoSelection.shared
            let isOpen = selection.isOpen(root)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { selection.root = root }
            } label: {
                HStack(spacing: 8) {
                    label()
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
                .background {
                    if isOpen {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.14))
                            .padding(.horizontal, -8)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? .isSelected : [])
        } else {
            NavigationLink {
                TodoDetailView(root: root)
            } label: {
                label()
            }
        }
    }
}

// MARK: - 오른쪽 판

/// 할 일 탭의 결과 쪽. 고른 일이 있으면 그 단계, 없으면 오늘 하루.
///
/// 아직 아무것도 고르지 않았을 때 빈 판을 두지 않는다 — 할 일을 고르기 전에
/// "오늘 비는 시간이 있나"가 먼저 보이는 편이 낫다(시안의 세로 화면 위 판).
struct FoldTodoResultPane: View {
    @Bindable var schedule: ScheduleViewModel
    @State private var today = Calendar.current.startOfDay(for: Date())
    private var selection: FoldTodoSelection { .shared }

    var body: some View {
        Group {
            // 지운 할 일을 붙들고 있으면 상세가 빈 모델을 그린다. 지워졌으면 오늘로 돌아간다.
            if let root = selection.root, root.modelContext != nil, !root.isDeleted {
                NavigationStack {
                    TodoDetailView(root: root)
                }
                .id(root.persistentModelID)
            } else {
                DayTab(viewModel: schedule, date: $today)
            }
        }
        // 오른쪽 판 안에서는 접히지 않은 화면처럼 민다(상세 안의 줄은 그 판 안에서 밀려 들어간다).
        .environment(\.foldLayout, .single)
    }
}

// MARK: - 탭 막대

extension AppTab {
    /// 펼쳤을 때 고르는 쪽 판 바닥에 서는 칸. 하루는 무지개의 오른쪽 판이 되므로 빠진다.
    static func foldTabItems(showsShare: Bool) -> [FoldTabBar<AppTab>.Item] {
        var items: [FoldTabBar<AppTab>.Item] = [
            .init(value: .todo, title: String(localized: "할 일"), symbol: "checklist"),
            .init(value: .rainbow, title: String(localized: "무지개"), symbol: "rainbow"),
        ]
        if showsShare {
            items.append(.init(value: .share, title: String(localized: "공유"), symbol: "person.2.circle"))
        }
        return items
    }
}

// MARK: - 하루 탭

extension View {
    /// 펼쳤을 때 하루 탭에 있었다면 무지개 탭으로 옮긴다. 하루는 그 오른쪽 판에 그대로 서 있다.
    /// 접으면 그대로 무지개에 남는다 — 펴고 접는 사이에 보던 날은 `dayTabDate` 하나라 잃지 않는다.
    func foldDayTabRedirect(selectedTab: Binding<AppTab>) -> some View {
        modifier(FoldDayTabRedirect(selectedTab: selectedTab))
    }
}

private struct FoldDayTabRedirect: ViewModifier {
    @Environment(\.foldLayout) private var fold
    @Binding var selectedTab: AppTab

    func body(content: Content) -> some View {
        content.onChange(of: fold.isUnfolded, initial: true) { _, unfolded in
            if unfolded, selectedTab == .day { selectedTab = .rainbow }
        }
    }
}
