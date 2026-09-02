//
//  ProEntitlement.swift
//
//  '모두 열기'를 샀는가. **앱과 위젯이 함께 읽는 한 줄짜리 상태.**
//
//  유료로 가른 것은 **곁다리**뿐이다 — 밖으로 나가는 것(위젯·캘린더 가져오기·일정 공유)과
//  뒤돌아보는 것(일정 통계·회수 장부). 이 앱이 하는 일의 본체 — 무지개, 할 일 쪼개기,
//  두 질문, 단계 순서 — 는 전부 무료다. 값을 받겠다고 핵심을 잠그면 앱이 무엇인지가 흐려진다.
//
//  StoreKit은 여기 없다. 위젯 익스텐션은 결제를 조회할 수 없고 조회할 이유도 없으므로,
//  구매 여부는 앱이 App Group에 한 줄로 구워두고 위젯은 그것만 읽는다
//  (스냅샷을 그렇게 넘기는 것과 같은 방식 → TodoWidgetSnapshot.swift).
//  실제 영수증 확인은 앱 쪽 `PurchaseManager`가 하고, 그 결과를 여기에 적는다.
//
//  ⚠️ 이 한 줄은 편의를 위한 거울이지 권한의 근거가 아니다. 앱은 켜질 때마다
//     `Transaction.currentEntitlements`로 다시 확인하고 이 값을 덮어쓴다.
//

import Foundation

/// 값을 받고 여는 것들. 목록은 페이월과 설정 화면이 함께 읽는다 —
/// 무엇이 열리는지 두 군데에 따로 적으면 반드시 어긋난다.
enum ProFeature: String, CaseIterable, Identifiable {
    /// 이 기기에서 적은 할 일이 맥으로 건너가기 (→ TodoAccess.swift).
    /// **적는 것 자체는 값을 안 받는다.**
    case editing
    case widget
    case calendarImport
    case scheduleShare
    case statistics
    case ledger

    var id: String { rawValue }

    /// **지금 실제로 파는 것들.** 페이월과 설정이 이 목록만 읽는다.
    ///
    /// 아직 안 파는 것을 목록에 올리면, 산 사람이 "돈을 냈는데 이건 왜 안 열리지"로
    /// 읽는다. 판매 스위치가 꺼져 있는 항목은 여기서 빠진다 (→ TodoAccess.swift).
    static var sold: [ProFeature] {
        allCases.filter { $0 != .editing || ProEntitlement.sellsSync }
    }

    var title: String {
        switch self {
        case .editing:        return "맥과 함께 쓰기"
        case .widget:         return "홈·잠금 화면 위젯"
        case .calendarImport: return "캘린더에서 가져오기"
        case .scheduleShare:  return "일정 공유"
        case .statistics:     return "일정 통계"
        case .ledger:         return "회수 장부"
        }
    }

    var note: String {
        switch self {
        case .editing:        return "여기서 적은 할 일이 맥에서도 보입니다. 적는 것 자체는 무료입니다."
        case .widget:         return "지금 할 단계와 무지개를 앱을 안 열고도 봅니다."
        case .calendarImport: return "시스템 캘린더의 일정을 무지개로 들여옵니다."
        case .scheduleShare:  return "내 일정을 읽기 전용으로 나눠 봅니다."
        case .statistics:     return "쌓인 일정을 통째로 들여다봅니다."
        case .ledger:         return "이번 주에 무엇을 되찾았는지 셉니다."
        }
    }

    var systemImage: String {
        switch self {
        case .editing:        return "arrow.left.arrow.right"
        case .widget:         return "rectangle.3.group"
        case .calendarImport: return "calendar.badge.plus"
        case .scheduleShare:  return "person.2"
        case .statistics:     return "chart.bar.xaxis"
        case .ledger:         return "book.closed"
        }
    }
}

enum ProEntitlement {

    /// **'맥과 함께 쓰기'를 팔기 시작했는가.** false인 동안에는 모두 함께 쓴다.
    ///
    /// ⚠️ 파는 것은 **적기가 아니라 건너가기**다. 적는 것은 이 앱의 본체라 잠그지
    ///    않는다 — 잠그면 새로 깐 사람이 첫 화면에서 한 줄도 못 적고, 앱이 무엇인지
    ///    알기도 전에 값부터 치르라는 말이 된다 (→ TodoAccess.swift).
    ///
    /// 위젯도 이 파일을 함께 쓰므로 스위치가 여기 있다.
    static let sellsSync = true

    /// App Store Connect의 비소모성 상품 ID. 한 번 사면 끝이다(구독 아님).
    static let productID = "com.example.ScheduleDensityApp.pro"

    /// 위젯과 함께 쓰는 자리. 스냅샷이 오가는 통과 같다.
    static let appGroupID = "group.com.devkoan.ScheduleDensity"

    private static let purchasedKey = "pro.purchased"
    private static let grandfatheredKey = "pro.grandfathered"
    private static let grandfatherCheckedKey = "pro.grandfatherChecked"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// 이 기능들을 써도 되는가.
    static var isUnlocked: Bool {
        defaults.bool(forKey: purchasedKey) || defaults.bool(forKey: grandfatheredKey)
    }

    /// 산 게 아니라 원래 쓰던 사람이라 열려 있는 상태.
    static var isGrandfathered: Bool {
        defaults.bool(forKey: grandfatheredKey) && !defaults.bool(forKey: purchasedKey)
    }

    /// 영수증 확인 결과를 적는다. 앱만 부른다.
    static func setPurchased(_ value: Bool) {
        defaults.set(value, forKey: purchasedKey)
    }

    // MARK: - 원래 쓰던 사람은 그대로 둔다
    //
    // 이 다섯 가지는 1.0.9까지 **무료로 배포돼 있었다.** 업데이트 한 번으로 쓰던 기능이
    // 잠기면 그건 값을 받는 게 아니라 뺏는 것이다. 그래서 이 버전을 처음 켤 때
    // 이미 데이터가 있는 기기는 영구히 열어 둔다. 새로 받는 사람부터 값을 받는다.
    //
    // ⚠️ 이 유예를 원하지 않으면 `grandfathersExistingUsers`를 false로 두면 된다.
    //    딱 이 한 줄이 그 정책 전부다.

    static let grandfathersExistingUsers = true

    /// 이 버전 첫 실행 때 딱 한 번. `hasExistingData`는 '이 앱을 이미 쓰고 있었는가' —
    /// 일정이든 할 일이든 하나라도 적혀 있으면 참이다.
    static func grandfatherIfNeeded(hasExistingData: Bool) {
        guard grandfathersExistingUsers else { return }
        guard !defaults.bool(forKey: grandfatherCheckedKey) else { return }
        defaults.set(true, forKey: grandfatherCheckedKey)
        guard hasExistingData else { return }
        defaults.set(true, forKey: grandfatheredKey)
    }
}
