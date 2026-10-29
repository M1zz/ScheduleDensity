//
//  DoneTodosView.swift
//  ScheduleDensityApp
//
//  이번 주에 끝낸 일들.
//
//  할 일 목록에서 완료한 줄을 다 세워 두면, 주 중반부터는 끝난 일이 남은 일보다
//  많아진다. 남은 일을 보러 온 사람이 매번 끝난 일을 스크롤로 지나가야 한다.
//  그래서 목록에는 줄 하나("완료한 것 N개")만 남기고 실물은 여기 둔다.
//  여기서 하는 일은 두 가지뿐이다 — 없어진 게 아니라는 것을 확인하는 것,
//  잘못 체크한 줄을 되돌리는 것.
//

import SwiftUI
import SwiftData
import LeeoKit

struct DoneTodosView: View {
    /// 지우기 직전에 세우는 물음 (→ TodoDeletion.swift).
    @State private var deletionRequest: TodoDeletionRequest?
    let weekStart: Date

    @Environment(\.modelContext) private var context


    @Query(sort: [SortDescriptor(\BacklogItem.sortIndex), SortDescriptor(\BacklogItem.createdAt)])
    private var allItems: [BacklogItem]

    private let cal = Calendar(identifier: .iso8601)

    /// 이번 주에 끝낸 최상위 할 일들. 최근에 끝낸 것이 위 —
    /// 방금 잘못 체크한 줄을 되돌리러 오는 것이 이 화면의 주된 용무다.
    private var done: [BacklogItem] {
        TodoTree(allItems).roots
            .filter { $0.isCompleted && cal.isDate($0.weekStartDate, inSameDayAs: weekStart) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            Section {
                ForEach(done) { item in
                    row(item)
                }
                .onDelete(perform: delete)
            } footer: {
                if done.isEmpty {
                    Text("이번 주에 끝낸 일이 아직 없습니다.")
                } else {
                    Text("줄을 누르면 마지막 단계가 되돌아옵니다. 왼쪽으로 밀면 지웁니다.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("완료한 것")
        .navigationBarTitleDisplayMode(.inline)
        .confirmsTodoDeletion($deletionRequest)
    }

    private func row(_ item: BacklogItem) -> some View {
        Button {
            rewind(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .foregroundStyle(.secondary)
                        .strikethrough(color: .secondary.opacity(0.5))
                    if let at = item.completedAt {
                        Text(at.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    /// 마지막 단계만 되돌린다. 단계가 없는 할 일은 통째로 미완료가 된다.
    private func rewind(_ item: BacklogItem) {
        let tree = TodoTree(allItems)
        withAnimation {
            if tree.rewind(item) == nil {
                tree.setCompleted(item, false)
            }
            save()
        }
    }

    /// 끝낸 것을 지운다. 목록에서 지우는 것과 같은 물음을 지난다
    /// (→ TodoDeletion.swift). 전에는 여기서만 무지개 줄을 안 지웠다.
    private func delete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let tree = TodoTree(allItems)
        let item = done[index]
        deletionRequest = TodoDeletionRequest(
            title: String(localized: "'\(item.title)' 삭제"),
            message: TodoDeletion.message(for: item, tree: tree, hasRainbowLine: false)
        ) {
            let result = await TodoDeletion.delete(item,
                                                   tree: tree,
                                                   allItems: allItems,
                                                   context: context)
            if case .success = result { TodoWidgetSync.refresh(context: context) }
            return result
        }
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - 고마운 순간 (팁 부탁)

/// 이 앱이 그 사람에게 도움이 됐다는 것이 **숫자로 보이는 순간** — 지금까지 끝낸 할 일 수.
/// 할 일 목록에서 줄 하나를 막 끝낸 자리('완료한 것' 줄 아래)에 카드가 선다(→ TodoView).
/// 얼마나 드물게 묻는지는 LeeoKit 의 규칙(`LeeoTipAskPolicy`)이 정한다.
enum RainbowTipMoments {
    /// 끝낸 최상위 할 일 수. 큰 것부터.
    static let done = [300, 100, 30]

    /// 넘어선 순간, **인상적인 것부터**.
    static func reached(done count: Int) -> [LeeoTipMoment] {
        done.filter { count >= $0 }.map { threshold in
            LeeoTipMoment(id: "done.\(threshold)",
                          message: String(localized: "지금까지 할 일 \(count)개를 끝냈어요",
                                          comment: "Tip ask card: how many to-dos the person has finished so far"))
        }
    }
}
