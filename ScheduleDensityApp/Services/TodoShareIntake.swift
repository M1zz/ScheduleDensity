//
//  TodoShareIntake.swift
//  ScheduleDensityApp
//
//  공유 익스텐션이 App Group에 쌓아둔 '받은 상자'를 비워 실제 할 일로 만든다.
//  앱이 켜지거나 포그라운드로 돌아올 때 한 번씩 부른다 (→ ScheduleDensityApp.swift).
//

import Foundation
import SwiftData

@MainActor
enum TodoShareIntake {
    /// 상자를 비워 이번 주 할 일로 넣는다.
    /// - Returns: 실제로 들어간 개수. 0이면 아무 일도 없었다는 뜻이다.
    @discardableResult
    static func drain(into context: ModelContext) -> Int {
        let drafts = TodoShareInbox.drain()
        guard !drafts.isEmpty else { return 0 }

        // 새로 들어온 줄은 목록 맨 아래에 붙는다 — 직접 적었을 때와 같은 자리.
        var nextIndex = (try? context.fetch(FetchDescriptor<BacklogItem>()))?
            .map(\.sortIndex).max().map { $0 + 1 } ?? 0

        for draft in drafts {
            let label = TodoLabel.resolve(draft.labelRaw) ?? .ready
            context.insert(BacklogItem(title: draft.title,
                                       durationHours: label.defaultHours,
                                       sortIndex: nextIndex,
                                       weekStartDate: .currentWeekStart,
                                       label: label))
            nextIndex += 1
        }

        do {
            try context.save()
        } catch {
            // 저장에 실패하면 상자는 이미 비운 뒤라 되돌릴 수 없다.
            // 흔치 않은 경우라 로그만 남기고 넘어간다 (사용자에게는 줄이 안 생긴 것으로 보인다).
            print("⚠️ [Share] 받은 할 일 저장 실패: \(error)")
            return 0
        }
        TodoWidgetSync.refresh(context: context)
        return drafts.count
    }
}
