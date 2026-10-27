//
//  ProEntitlement.swift
//
//  무지개의 어느 칸(무료 · Plus · Pro)을 쓰는가. **앱과 위젯이 함께 읽는 한 줄짜리 상태.**
//
//  칸은 셋이고 Pro 는 Plus 를 전부 포함한다 (2026-10 요금제 개편).
//   · Plus: 지나온 주를 끝까지 보기 (회수 장부 전체 기간, 일정 통계)
//   · Pro:  Plus 전부 + 위젯, 캘린더 가져오기와 비추기, 일정 공유, 맥 '무지개 공방' Pro
//
//  **선은 맥앱과 같은 문장으로 긋는다** — "오늘을 사는 데 필요한 것은 무료,
//  쌓여야 보이는 것과 밖으로 나가는 것이 Pro" (→ 무지개 공방 `MacEntitlement.swift`).
//  무지개·할 일 쪼개기·두 질문·단계 순서·타이머, 그리고 **맥과 오가는 것**은 전부 무료다.
//  값을 받는 것은 뒤돌아보는 것(Plus: 일정 통계, 2주보다 더 거슬러 보는 회수 장부)과
//  밖으로 나가는 것(Pro: 위젯·캘린더 가져오기·일정 공유)뿐이다.
//
//  ⚠️ **동기화를 팔지 않는다.** 맥 페이월이 "아이폰과 오가기 — 무료"라고 적어 두었는데
//     아이폰이 그것을 팔면, 두 앱을 다 쓰는 사람에게 약속이 깨진다. 게다가 원래 되던 것을
//     막는 셈이라 새로 파는 게 아니라 뺏는 것으로 읽힌다 (맥이 같은 자리에서 데고 되돌렸다).
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
/// 칸. 값이 클수록 더 많이 연다. Pro 는 Plus 를 전부 포함한다.
enum ProTier: Int, Comparable, CaseIterable {
    case free = 0
    case plus = 1
    case pro = 2

    static func < (lhs: ProTier, rhs: ProTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .free: String(localized: "무료")
        case .plus: String(localized: "무지개 Plus")
        case .pro:  String(localized: "무지개 Pro")
        }
    }
}

enum ProFeature: String, CaseIterable, Identifiable {
    case widget
    case calendarImport
    case scheduleShare
    case statistics
    case ledger

    var id: String { rawValue }

    /// **지금 실제로 파는 것들.** 페이월과 설정이 이 목록만 읽는다.
    static var sold: [ProFeature] { allCases }

    /// 무료로도 **써 보고 알 만큼**은 열어 두는 것. 문을 통째로 잠그면 무엇을 사는지
    /// 모른 채 값을 내라는 말이 된다 — 최근 2주는 그냥 보이고 그 앞이 잠긴다.
    /// (맥의 `freeLimits[trendWeeks]`와 같은 수 → 무지개 공방 `WeekBlocksSpec`)
    static let freeWeekCount = 2

    /// 이 기능을 여는 가장 낮은 칸.
    var tier: ProTier {
        switch self {
        case .statistics, .ledger:                    .plus
        case .widget, .calendarImport, .scheduleShare: .pro
        }
    }

    /// 그 칸에서 새로 열리는 것들 (페이월 카드 차례).
    static func opened(by tier: ProTier) -> [ProFeature] { sold.filter { $0.tier == tier } }

    var title: String {
        switch self {
        case .widget:         return String(localized: "홈·잠금 화면 위젯")
        case .calendarImport: return String(localized: "캘린더에서 가져오기")
        case .scheduleShare:  return String(localized: "일정 공유")
        case .statistics:     return String(localized: "일정 통계")
        case .ledger:         return String(localized: "회수 장부 전체 기간")
        }
    }

    var note: String {
        switch self {
        case .widget:         return String(localized: "지금 할 단계와 무지개를 앱을 안 열고도 봅니다.")
        case .calendarImport: return String(localized: "시스템 캘린더의 일정을 무지개로 들여오고 늘 비춥니다.")
        case .scheduleShare:  return String(localized: "내 일정을 읽기 전용으로 나눠 봅니다.")
        case .statistics:     return String(localized: "쌓인 일정을 통째로 들여다봅니다.")
        case .ledger:         return String(localized: "2주보다 앞선 주도 끝까지 거슬러 봅니다.")
        }
    }

    var systemImage: String {
        switch self {
        case .widget:         return "rectangle.3.group"
        case .calendarImport: return "calendar.badge.plus"
        case .scheduleShare:  return "person.2"
        case .statistics:     return "chart.bar.xaxis"
        case .ledger:         return "book.closed"
        }
    }
}

enum ProEntitlement {

    // ⚠️ **'맥과 함께 쓰기'는 팔지 않는다.** 1.1.x에서 잠깐 팔았다가, 맥이 같은 것을 팔려다
    //    "되던 걸 막는 것"이라며 무료로 되돌렸고 맥 페이월은 지금 그것을 무료 항목으로 광고한다.
    //    두 앱이 서로 다른 말을 하면 두 앱을 다 쓰는 사람에게서 신뢰를 잃는다. 다시 팔지 말 것.

    /// **유료 칸을 팔기 시작했는가.**
    ///
    /// ⚠️ 상품이 콘솔에 없는데 출시 빌드에서 켜면, 아무도 못 사는 자물쇠만 선다.
    ///    이 빌드를 제출하기 전에 ASC에 아래 판매 상품이 모두 '제출 준비 완료'로 서 있어야 한다.
    ///    (맥의 같은 스위치 → 무지개 공방 `MacEntitlement.sellsPro`)
    static var sellsPro: Bool { true }

    // MARK: - 상품 ID
    //
    // ⚠️ 콘솔에 만든 것·`Products.storekit`에 적은 것과 **글자 하나까지 같아야 한다.**
    //    연 구독 둘(Plus · Pro)은 같은 구독 그룹에 넣어야 서로 갈아탈 수 있다(Pro 가 높은 단계).

    /// Plus 연 구독.
    static let plusYearlyID = "com.example.ScheduleDensityApp.plus.annual"
    /// Plus 평생.
    static let plusLifetimeID = "com.example.ScheduleDensityApp.plus"
    /// Pro 연 구독. ⚠️ `…pro.yearly` 가 아니다. 그 ID는 ASC에서 "이미 다른 구독에서 사용 중"이라 못 쓴다(2026-09-30).
    static let proYearlyID = "com.example.ScheduleDensityApp.pro.annual"
    /// Pro 평생. **1.1.x에서 4,900원에 팔던 그 상품이다.** 그때 산 사람은 따로 챙기지 않아도 평생 Pro다.
    static let proLifetimeID = "com.example.ScheduleDensityApp.pro"
    /// Plus 평생을 산 사람이 Pro 평생으로 올리는 값.
    static let upgradeID = "com.example.ScheduleDensityApp.pro.upgrade"
    /// 구독 중인 사람의 졸업가 Pro 평생 (→ LeeoGraduation).
    static let graduateID = "com.example.ScheduleDensityApp.pro.graduate"
    /// Pro 월 구독. **판매는 멈췄고 권한은 그대로다.** 구독자는 끝날 때까지 Pro.
    static let monthlyID = "com.example.ScheduleDensityApp.pro.monthly"

    /// 페이월이 불러올 상품. 판매를 멈춘 월 구독은 없다.
    ///
    /// ⚠️ 언제나 평생 패스 상품은 여기 넣지 않는다. 패스는 `LeeoForeverPass` 가 따로 판정한다.
    static var productIDs: [String] {
        sellsPro ? [plusYearlyID, plusLifetimeID, proYearlyID, proLifetimeID, upgradeID, graduateID]
                 : [proLifetimeID]
    }

    /// **상품마다 여는 칸.** 연 구독은 같은 칸의 평생과 같은 권한, 올리기 · 졸업은 Pro 평생이다.
    /// 판매를 멈춘 상품도 여기서는 빼지 않는다. 산 사람의 권한은 그대로 둔다.
    static let tierByProduct: [String: ProTier] = [
        plusYearlyID: .plus,
        plusLifetimeID: .plus,
        proYearlyID: .pro,
        proLifetimeID: .pro,
        upgradeID: .pro,
        graduateID: .pro,
        monthlyID: .pro,
    ]

    /// 이 중 하나라도 있으면 유료 칸이 열린다.
    static var entitlementIDs: Set<String> { Set(tierByProduct.keys) }

    /// 평생 상품(끝나지 않는 것).
    static let lifetimeIDs: Set<String> = [plusLifetimeID, proLifetimeID, upgradeID, graduateID]

    /// 자동 갱신 구독 (구독 졸업을 제안할 대상).
    static let subscriptionIDs: Set<String> = [plusYearlyID, proYearlyID, monthlyID]

    /// 이 상품이 여는 칸. 권한이 아닌 상품이면 nil.
    static func tier(of productID: String) -> ProTier? { tierByProduct[productID] }

    /// 꼭 이 칸을 여는 상품들. 맥과 나누는 표에 그 칸의 끝나는 날을 적을 때 쓴다.
    static func productIDs(opening tier: ProTier) -> Set<String> {
        Set(tierByProduct.filter { $0.value == tier }.keys)
    }

    /// **가진 상품들과 패스가 여는 칸.** 가장 높은 것을 쓴다.
    /// - Parameter foreverPass: 언제나 평생 패스가 열려 있으면 가장 높은 칸(Pro)이다.
    static func tier(owning productIDs: Set<String>, foreverPass: Bool = false) -> ProTier {
        if foreverPass { return .pro }
        return productIDs.compactMap(tier(of:)).max() ?? .free
    }

    /// Plus · Pro 평생을 갖고 있는가. Pro 평생 단추가 올리기 상품을 팔지, 패스를 올리기 값으로 팔지 가른다.
    static func ownsLifetime(_ tier: ProTier, in productIDs: Set<String>) -> Bool {
        productIDs.contains { lifetimeIDs.contains($0) && self.tier(of: $0) == tier }
    }

    /// 위젯과 함께 쓰는 자리. 스냅샷이 오가는 통과 같다.
    static let appGroupID = "group.com.devkoan.ScheduleDensity"

    /// **잠긴 위젯을 누르면 가는 곳.**
    ///
    /// ⚠️ 홈 화면에 위젯을 직접 올린 사람은 이미 살 마음이 있는 사람이다. 그런데 잠긴
    ///    위젯이 평소 딥링크를 그대로 들고 있어서, 눌러도 할 일 목록만 열렸다.
    ///    무엇이 잠겼는지도, 어디서 여는지도 말해 주지 않는 막다른 길이었다.
    static let paywallDeepLink = URL(string: "rainbow://paywall/widget")!

    /// 칸을 적는 자리.
    private static let tierKey = "pro.tier"
    /// 칸을 나누기 전(1.1.14까지)의 한 줄. true 는 Pro 였다. 읽기만 한다.
    private static let legacyPurchasedKey = "pro.purchased"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

#if DEBUG
    /// **Xcode에서 돌릴 때 열어 둘 것인가.** 배포 빌드에는 이 줄이 아예 없다.
    ///
    /// 개발 중에는 진짜 영수증을 받을 길이 사실상 없다. 스킴에 로컬 StoreKit 설정이
    /// 붙어 있으면 App Store에서 코드로 받은 권한이 **보이지도 않고**, 시뮬레이터는
    /// 애초에 진짜 계정으로 살 수 없다. 그래서 개발 빌드는 그냥 열어 둔다.
    ///
    /// ⚠️ **잠긴 화면을 보려면 이 한 줄을 false 로 바꾼다.** 페이월과 안내 줄은
    ///    이 앱이 파는 것의 얼굴이라, 가끔은 잠근 채로 봐야 한다.
    static let unlockedInDebug = true
#endif

    /// 지금 쓰는 칸.
    ///
    /// 근거는 **App Store 영수증(과 그것을 옮겨 적은 패스 · 맥의 표)뿐이다.** 여기 다른 조건을
    /// 더하지 않는다. 전에 '쓰던 사람은 열어 둔다'는 유예를 로컬 데이터 개수로 판단했는데,
    /// 그 스토어가 CloudKit 미러라 **동기화 타이밍이 결제 여부를 흔들었다.**
    static var tier: ProTier {
#if DEBUG
        if unlockedInDebug { return .pro }
#endif
        return cachedTier ?? .free
    }

    /// 이 기능을 써도 되는가.
    static func allows(_ feature: ProFeature) -> Bool { tier >= feature.tier }

    /// 캐시에 적혀 있는 답. **nil은 '무료'가 아니라 '아직 애플에게 안 물어봤다'** 이다.
    ///
    /// ⚠️ 그 차이를 잃으면 영수증 조회가 한 번 늦거나 실패한 순간 **산 사람이 잠긴다.**
    ///    위젯이 한꺼번에 자물쇠로 바뀌고, 설정은 '무료 버전'이라고 단정한다.
    ///    (맥의 같은 장치 → 무지개 공방 `MacEntitlement.cachedPurchase`)
    static var cachedTier: ProTier? {
        if let raw = defaults.object(forKey: tierKey) as? Int { return ProTier(rawValue: raw) }
        // 칸을 나누기 전에 적힌 한 줄. 그때는 Pro 하나뿐이었다.
        if let purchased = defaults.object(forKey: legacyPurchasedKey) as? Bool { return purchased ? .pro : .free }
        return nil
    }

    /// 애플에게 물어본 적이 있는가. 아직이면 화면은 '무료'라고 단정하지 않는다.
    static var isKnown: Bool { cachedTier != nil }

    /// 영수증 확인 결과를 적는다.
    ///
    /// ⚠️ `PurchaseManager`만 부른다. 화면은 그것을 비추는 `PurchaseManager.tier`를 본다.
    static func setTier(_ value: ProTier) {
        // 위젯과 함께 쓰는 통이라 쓰는 일이 공짜가 아니다. 값이 그대로면 두고 간다.
        guard defaults.object(forKey: tierKey) as? Int != value.rawValue else { return }
        defaults.set(value.rawValue, forKey: tierKey)
    }

    // MARK: - 유예는 없다
    //
    // 1.0.9까지 무료였고 1.1.0부터 판다. 열림/잠김의 조건은 하나면 된다: **무엇을 샀는가.**
}
