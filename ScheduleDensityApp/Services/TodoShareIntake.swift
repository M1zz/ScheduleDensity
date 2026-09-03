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
        // ⚠️ 잠긴 기기에서는 **상자를 비우지 않는다.**
        //
        // 공유로 넘어온 줄은 새로 적는 것이라 잠금이 걸려야 맞다. 그런데 여기서
        // 비우고 버리면 넘긴 것이 흔적도 없이 사라진다 — 값을 받는 게 아니라
        // 잃어버리는 것으로 보인다. 상자에 그대로 두면 열었을 때 다음 실행에서
        // 통째로 들어온다. 기다리고 있다는 말은 목록이 한다
        // (→ TodoView.readOnlyNotice, TodoShareInbox.pendingCount).

        let drafts = TodoShareInbox.drain()
        guard !drafts.isEmpty else { return 0 }

        // 새로 들어온 줄은 목록 **맨 위**에 붙는다.
        //
        // 밖에서 공유해 넣는 순간에는 앱을 보고 있지 않다. 나중에 앱을 열었을 때
        // 아래에 붙어 있으면 스크롤을 내려야 보이고, 그 사이 무엇이 새로 들어왔는지도
        // 알 수 없다. 직접 적을 때와 달리 '방금 적었다'는 기억이 없기 때문에,
        // 자리가 대신 말해줘야 한다.
        let existing = (try? context.fetch(FetchDescriptor<BacklogItem>()))?.map(\.sortIndex) ?? []
        // 받은 순서를 유지한 채 통째로 기존 줄들 위에 얹는다.
        var nextIndex = (existing.min() ?? 0) - drafts.count

        for draft in drafts {
            // 시간도 마감도 정하지 않은 채로 들어온다 = '그냥 하면 되는 것'.
            // 공유로 밀어 넣는 줄은 계획이 아니라 "잊지 말자"에 가깝고,
            // 시간이 필요해지면 목록에서 왼쪽으로 밀어 잡으면 된다.
            context.insert(BacklogItem(title: draft.title,
                                       durationHours: TodoTree.errandHours,
                                       sortIndex: nextIndex,
                                       weekStartDate: .currentWeekStart))
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
