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

    /// 적을 때 고른 착수 조건(`TodoLabel.rawValue`). nil이면 아직 안 고른 것 = 시간으로 짐작한다.
    /// 속성이 '얼마나 걸리나'였던 시절의 값도 `TodoLabel.resolve`가 받아 준다.
    var labelRaw: String? = nil

    init(title: String,
         durationHours: Double = 1,
         sortIndex: Int = 0,
         categoryID: String? = nil,
         weekStartDate: Date = Date.currentWeekStart,
         label: TodoLabel? = nil)
    {
        self.title = title
        self.labelRaw = label?.rawValue
        self.durationHours = durationHours
        self.sortIndex = sortIndex
        self.dragToken = UUID().uuidString
        self.categoryID = categoryID
        self.weekStartDate = weekStartDate
    }
}
