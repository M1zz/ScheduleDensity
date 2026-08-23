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
    // 할 일 하나를 100%로 놓고 그 안을 '일이 되어야 하는 순서대로' 쪼갠 단계들.
    // 단계도 같은 BacklogItem이고, 부모의 dragToken을 parentToken으로 들고 있다.
    // 순서는 sortIndex, 비중은 부모의 예상 시간을 나눠 가진 비율이다 → TodoTree.swift
    // 시간은 위에서 아래로 내려간다: 상위 할 일의 durationHours가 100%이고,
    // 단계들은 그 시간을 나눠 갖는다(기본 N분의 1). 합은 언제나 부모의 시간이다.
    // CloudKit 라이트웨이트 마이그레이션을 위해 옵셔널 + 기본값 nil.

    /// 상위 할 일의 dragToken. nil이면 최상위 할 일(= 그 자체가 100%).
    var parentToken: String? = nil

    /// 사용자가 이 단계의 비중을 직접 정했는가.
    /// true면 형제들이 몫을 다시 나눌 때 이 단계는 건드리지 않는다(자동 N분의 1에서 빠진다).
    var isManualWeight: Bool = false

    /// 적을 때 고른 라벨(`TodoLabel.rawValue`). nil이면 아직 안 고른 것 = 예상 시간으로 짐작한다.
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
