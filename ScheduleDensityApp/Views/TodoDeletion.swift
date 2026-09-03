//
//  TodoDeletion.swift
//
//  **할 일을 지우기 전에 묻고, 지울 때는 딸린 것까지 함께 지운다.**
//
//  지우는 자리가 넷인데 하는 일이 서로 달랐다:
//
//    목록 스와이프        하위 단계 O   무지개 줄 O   확인 X
//    길게 눌러 '삭제'     하위 단계 X   무지개 줄 X   확인 X   ← 여기가 문제였다
//    상세의 스와이프      하위 단계 O   무지개 줄 X   확인 X
//    완료 목록의 스와이프  하위 단계 O   무지개 줄 X   확인 X
//
//  '삭제'만 누르면 하위 단계가 고아로 남고 무지개에 그어 둔 줄도 그대로 남았다.
//  그 줄은 iOS 쪽 일정 스토어에만 있는 것이라 **맥에서는 안 보이고 아이폰에만 보인다.**
//  "지웠는데 계속 나오는" 것이 이것이다.
//
//  ⚠️ 순서는 **무지개 줄 먼저, 할 일은 그 다음이다.** 일정 삭제와 같은 이유다 —
//     저쪽을 못 지웠는데 할 일만 지우면 무엇 때문에 그어진 줄인지조차 안 남는다
//     (→ EventDeletion.swift, ScheduleViewModel.deleteEvent).
//

import SwiftUI
import SwiftData

enum TodoDeletion {

    /// 할 일 하나와 **그 아래 단계 전부**, 그리고 그 일 때문에 그어 둔 무지개 줄을 지운다.
    /// 네 자리가 전부 이 함수 하나를 지난다.
    @MainActor
    static func delete(_ item: BacklogItem,
                       tree: TodoTree,
                       allItems: [BacklogItem],
                       context: ModelContext) async -> Result<Void, Error> {

        // 1. 무지개 줄부터. 실패하면 할 일은 건드리지 않는다.
        if case .failure(let error) = await TodoEventBridge.shared.clearRainbow(for: item) {
            return .failure(error)
        }

        // 2. 할 일과 그 아래 단계 전부.
        let parent = tree.parent(of: item)
        let victims = Set(tree.subtree(of: item).map(\.dragToken))
        for node in tree.subtree(of: item) { context.delete(node) }
        if let parent {
            // 시간은 남은 단계들의 합이라 저절로 줄어든다. 완료 상태만 다시 굴려 준다.
            let updated = TodoTree(allItems.filter { !victims.contains($0.dragToken) })
            updated.rollUp(from: parent)
        }

        do {
            try context.save()
        } catch {
            return .failure(error)
        }
        return .success(())
    }

    /// 물어볼 말을 짓는다. **무엇이 함께 없어지는지 세어서 말한다** —
    /// "정말 삭제하시겠습니까"는 아무것도 알려주지 않는다.
    @MainActor
    static func message(for item: BacklogItem, tree: TodoTree, hasRainbowLine: Bool) -> String {
        let steps = max(tree.subtree(of: item).count - 1, 0)
        var lines = ["되돌릴 수 없습니다."]
        if steps > 0 { lines.insert("이 안의 단계 \(steps)개도 함께 지웁니다.", at: 0) }
        if hasRainbowLine { lines.append("무지개에 그어 둔 줄도 함께 없어집니다.") }
        return lines.joined(separator: "\n")
    }
}

/// 지우기 직전에 화면이 세워 두는 물음.
struct TodoDeletionRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let perform: () async -> Result<Void, Error>
}

extension View {
    /// 할 일 삭제 확인. 네 자리가 같은 말을 하도록 여기 한 곳에서 낸다.
    func confirmsTodoDeletion(_ request: Binding<TodoDeletionRequest?>) -> some View {
        modifier(TodoDeletionConfirm(request: request))
    }
}

private struct TodoDeletionConfirm: ViewModifier {

    @Binding var request: TodoDeletionRequest?
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .alert(request?.title ?? "할 일 삭제",
                   isPresented: Binding(get: { request != nil },
                                        set: { if !$0 { request = nil } }),
                   presenting: request) { asked in
                Button("삭제", role: .destructive) {
                    let perform = asked.perform
                    Task {
                        if case .failure(let error) = await perform() {
                            failure = error.localizedDescription
                        }
                    }
                }
                Button("취소", role: .cancel) { }
            } message: { asked in
                Text(asked.message)
            }
            .alert("지우지 못했습니다",
                   isPresented: Binding(get: { failure != nil },
                                        set: { if !$0 { failure = nil } }),
                   presenting: failure) { _ in
                Button("확인", role: .cancel) { }
            } message: { reason in
                Text("무지개에 그어 둔 줄을 못 지워서 할 일도 그대로 두었습니다. 한쪽만 지우면 남은 줄이 어디서 온 것인지 알 수 없게 됩니다.\n\n\(reason)")
            }
    }
}
