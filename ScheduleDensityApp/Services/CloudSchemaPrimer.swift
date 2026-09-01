//
//  CloudSchemaPrimer.swift
//  ScheduleDensityApp
//
//  **모델에 있는 모든 필드를 CloudKit 스키마에 만들어 둔다.** (디버그 전용)
//
//  CloudKit은 **값이 실제로 쓰인 필드만** 만든다. 옵셔널 필드에 한 번도 값을 안 넣으면
//  스키마에 그 칸이 안 생기고, Development → Production 배포에도 안 실려 간다.
//  그러면 출시 뒤 사용자가 그 값을 **처음 넣는 순간** 서버가 모르는 필드라며 거절하고,
//  거절 하나가 미러링 초기화를 통째로 실패시켜 동기화가 멈춘다. 조용히, 그 사람에게만.
//
//    var needsBroadcast: Bool = false   → false 도 값이라 칸이 생긴다
//    var deadline: Date? = nil          → nil 이면 안 보내서 칸이 안 생긴다  ⚠️
//
//  손으로 기능을 하나씩 다 써 보는 것으로는 이걸 못 막는다. 빠뜨리기 쉽고,
//  빠뜨린 것은 눈에 안 보인다. 그래서 **모든 옵셔널에 값을 채운 표본을 한 벌 만들어
//  올리고, 올라간 것을 확인한 뒤 지운다.** 레코드는 지워도 스키마는 남는다.
//
//  ⚠️ 디버그 빌드에서만, Development 환경에서만 쓸 것. 표본이 잠깐 목록에 보였다
//     사라진다. Production에서는 애초에 필드가 자동 생성되지 않으므로 소용도 없다.
//

#if DEBUG

import Foundation
import SwiftData

enum CloudSchemaPrimer {

    /// 표본임을 한눈에 알아보게 하는 이름. 지우다 실패해도 사용자가 알아본다.
    static let marker = "⟨스키마 표본 · 지워도 됩니다⟩"

    struct Report {
        var created: Int
        var deleted: Int
        var note: String
    }

    /// 모든 모델의 모든 필드에 값을 채운 표본을 만들었다가 지운다.
    ///
    /// - Parameter settleSeconds: 만들고 지우기까지 기다리는 시간. 그 사이에 내보내기가
    ///   돌아야 스키마가 생긴다. 너무 짧으면 지워진 뒤에 올라가 아무 칸도 안 생긴다.
    @MainActor
    static func prime(_ context: ModelContext, settleSeconds: UInt64 = 25) async -> Report {
        let now = Date()
        let week = Date.currentWeekStart

        // ── 모든 옵셔널에 값을 넣는다. 이게 이 파일의 존재 이유다. ──────────
        let category = BacklogCategory(name: marker, colorName: "blue",
                                       iconName: "tag", sortIndex: 9_999)
        category.isBroadcast = true

        let item = BacklogItem(title: marker, durationHours: 1, sortIndex: 9_999,
                               categoryID: category.uuid, weekStartDate: week)
        item.completedAt = now
        item.parentToken = "schema-sample-parent"
        item.labelRaw = "schema-sample-label"
        item.needsBroadcast = true
        item.deadline = now
        item.broadcastRecipient = "sample"
        item.handoffForm = "sample"
        item.earliestDate = now
        item.latestDate = now
        item.openVariable = "sample"
        item.variableResolveDate = now
        item.noSignalRuleAgreed = true
        item.broadcastContractVerified = true
        item.sentCheckpointsRaw = "sample"

        let block = PlanBlock(day: .mon, timeBand: .morning, durationHours: 1,
                              title: marker, successCriteria: "sample",
                              deliverable: "sample", weekStartDate: week)
        block.reviewStatusRaw = "sample"
        block.reviewNote = "sample"
        block.reviewedAt = now
        block.needsBroadcast = true
        block.deadline = now
        block.broadcastRecipient = "sample"
        block.handoffForm = "sample"
        block.earliestDate = now
        block.latestDate = now
        block.openVariable = "sample"
        block.variableResolveDate = now
        block.noSignalRuleAgreed = true
        block.broadcastContractVerified = true
        block.sentCheckpointsRaw = "sample"

        for model in [category as any PersistentModel, item, block] {
            context.insert(model)
        }
        do {
            try context.save()
        } catch {
            return Report(created: 0, deleted: 0, note: "표본을 못 만들었습니다: \(error)")
        }

        // 내보내기가 돌 시간을 준다. 이 사이에 서버에 칸이 생긴다.
        try? await Task.sleep(nanoseconds: settleSeconds * 1_000_000_000)

        // ── 치운다. 스키마는 남는다. ────────────────────────────────────────
        var deleted = 0
        for model in [category as any PersistentModel, item, block] {
            context.delete(model)
            deleted += 1
        }
        try? context.save()

        let sent = CloudSyncLog.shared.exporting
        let note: String
        if let sent, sent.succeeded {
            note = "올라갔습니다. 이제 콘솔에서 Development → Production 배포."
        } else if let sent, let why = sent.error {
            note = "내보내기가 실패했습니다 — \(why)"
        } else {
            note = "아직 내보내기 결과가 없습니다. 잠시 뒤 '동기화 진단'을 다시 보세요."
        }
        return Report(created: 3, deleted: deleted, note: note)
    }
}

#endif
