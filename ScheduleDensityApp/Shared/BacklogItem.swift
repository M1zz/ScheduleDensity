import Foundation
import SwiftData

@Model
final class BacklogItem {
    var title: String = ""
    var durationHours: Double = 1
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    // Stable string token used to identify the item during drag-and-drop.
    var dragToken: String = UUID().uuidString
    /// 연결된 BacklogCategory.uuid (없으면 nil = 미분류).
    var categoryID: String? = nil
    /// 이 할 일이 속한 주 (월요일 00:00). 지난 주에 못 한 항목 구분에 사용.
    var weekStartDate: Date = Date.currentWeekStart
    /// iOS Todo에서 체크한 완료 상태. 완료되면 맥 백로그 그리드에서는 숨긴다.
    var isCompleted: Bool = false
    var completedAt: Date? = nil

    // MARK: - 뎁스(단계)
    //
    // 할 일 하나를 '일이 되어야 하는 순서대로' 쪼갠 단계들.
    // 단계도 같은 BacklogItem이고, 부모의 dragToken을 parentToken으로 들고 있다.
    // 순서는 sortIndex. 시간은 아래에서 위로 쌓인다 — 단계마다 착수 조건을 고르면
    // 그 속성이 시간을 데려오고, 상위 할 일의 시간은 단계들의 합이다 → TodoTree.swift
    // CloudKit 라이트웨이트 마이그레이션을 위해 옵셔널 + 기본값 nil.

    /// 상위 할 일의 dragToken. nil이면 최상위 할 일.
    var parentToken: String? = nil

    /// ⚠️ 더 이상 쓰지 않는다. 비중(%)으로 단계를 나누던 시절의 필드로,
    ///    이미 배포된 사용자·맥앱과 공유하는 CloudKit 스키마에 들어 있어 지우지 못한다.
    ///    (지우면 라이트웨이트 마이그레이션이 깨진다.) 읽지도 쓰지도 말 것.
    var isManualWeight: Bool = false

    /// '착수 조건'(바로/펼치고/몰입해서…)으로 단계를 나누던 시절의 필드.
    ///    이미 배포된 사용자·맥앱과 공유하는 CloudKit 스키마에 들어 있어 지우지 못한다.
    ///    (지우면 라이트웨이트 마이그레이션이 깨진다.)
    ///
    ///    ⚠️ 직접 읽거나 쓰지 말 것. 지금은 **두 질문에 사용자가 직접 답한 것**을 담는
    ///    자리로 다시 쓰고 있고, 접두어(`pick:`)로 옛 값과 구분한다.
    ///    → BacklogItem+Fragment.swift 의 `fragmentPick`으로만 드나든다.
    var labelRaw: String? = nil


    // MARK: - 전파 계약 (맥 '무지개 공방' 전용 기능)
    //
    // ⚠️ **이 앱은 이 값들을 쓰지 않는다. 그런데 반드시 있어야 한다.**
    //
    // 맥과 iOS가 **같은 CloudKit 스토어 하나**를 공유하므로(→ WeekBlocksStore),
    // 레코드의 모양이 양쪽에서 같아야 한다. iOS 모델에 이 칸들이 없으면 이 앱이
    // 저장할 때마다 맥이 적어 둔 계약(대상·두 날짜·넘길 형태·이미 보낸 시점)이
    // 날아갈 수 있고, 무엇이 날아갔는지 이 앱은 알지도 못한다.
    //
    // 그래서 **저장 프로퍼티만** 맥과 똑같이 둔다. 계산·화면은 맥에만 있다
    // (→ 무지개 공방/WeekBlocks/BroadcastContract.swift).
    // 맥에서 필드가 늘면 여기도 같이 늘려야 한다.
    var needsBroadcast: Bool = false
    var deadline: Date? = nil
    var broadcastAudienceRaw: String = "decisionMaker"
    var broadcastRecipient: String = ""
    var handoffForm: String = ""
    var earliestDate: Date? = nil
    var latestDate: Date? = nil
    var broadcastConfidenceRaw: String = "medium"
    var openVariable: String = ""
    var variableResolveDate: Date? = nil
    var noSignalRuleAgreed: Bool = false
    var broadcastContractVerified: Bool = false
    var sentCheckpointsRaw: String = ""

    init(title: String,
         durationHours: Double = 1,
         sortIndex: Int = 0,
         categoryID: String? = nil,
         weekStartDate: Date = Date.currentWeekStart)
    {
        self.title = title
        self.durationHours = durationHours
        self.sortIndex = sortIndex
        self.dragToken = UUID().uuidString
        self.categoryID = categoryID
        self.weekStartDate = weekStartDate
    }
}
