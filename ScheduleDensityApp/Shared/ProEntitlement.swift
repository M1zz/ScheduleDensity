//
//  ProEntitlement.swift
//
//  '무지개 Pro'를 샀는가. **앱과 위젯이 함께 읽는 한 줄짜리 상태.**
//
//  **선은 맥앱과 같은 문장으로 긋는다** — "오늘을 사는 데 필요한 것은 무료,
//  쌓여야 보이는 것과 밖으로 나가는 것이 Pro" (→ 무지개 공방 `MacEntitlement.swift`).
//  무지개·할 일 쪼개기·두 질문·단계 순서·타이머, 그리고 **맥과 오가는 것**은 전부 무료다.
//  Pro가 여는 것은 밖으로 나가는 것(위젯·캘린더 가져오기·일정 공유)과 뒤돌아보는 것
//  (일정 통계, 2주보다 더 거슬러 보는 회수 장부)뿐이다.
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

    var title: String {
        switch self {
        case .widget:         return String(localized: "홈·잠금 화면 위젯")
        case .calendarImport: return String(localized: "캘린더에서 가져오기")
        case .scheduleShare:  return String(localized: "일정 공유")
        case .statistics:     return String(localized: "일정 통계")
        case .ledger:         return String(localized: "회수 장부")
        }
    }

    var note: String {
        switch self {
        case .widget:         return String(localized: "지금 할 단계와 무지개를 앱을 안 열고도 봅니다.")
        case .calendarImport: return String(localized: "시스템 캘린더의 일정을 무지개로 들여옵니다.")
        case .scheduleShare:  return String(localized: "내 일정을 읽기 전용으로 나눠 봅니다.")
        case .statistics:     return String(localized: "쌓인 일정을 통째로 들여다봅니다.")
        case .ledger:         return String(localized: "이번 주에 무엇을 되찾았는지 셉니다.")
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

    /// **Pro를 팔기 시작했는가.**
    ///
    /// 개발 빌드에서는 켠다 — `Products.storekit`의 가짜 스토어로 페이월과 구매 흐름을
    /// 끝까지 굴려 볼 수 있어야 한다. 출시 빌드는 App Store Connect에 상품(연간·월간 구독,
    /// 평생 이용권)을 만들고 **심사에 함께 올리는 판에서** 켠다.
    ///
    /// ⚠️ 상품이 콘솔에 없는데 출시 빌드에서 켜면, 아무도 못 사는 자물쇠만 선다.
    ///    (맥의 같은 스위치 → 무지개 공방 `MacEntitlement.sellsPro`)
    static var sellsPro: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    /// App Store Connect의 상품 ID.
    /// ⚠️ 콘솔에 만든 것·`Products.storekit`에 적은 것과 **글자 하나까지 같아야 한다.**
    /// 연간·월간은 같은 구독 그룹('무지개 Pro')에 넣어야 서로 갈아탈 수 있다.
    static let yearlyID = "com.example.ScheduleDensityApp.pro.yearly"
    static let monthlyID = "com.example.ScheduleDensityApp.pro.monthly"
    static let lifetimeID = "com.example.ScheduleDensityApp.pro.lifetime"

    /// 페이월에 세우는 차례 — 연간(체험) → 평생 → 월간.
    static let productIDs = [yearlyID, lifetimeID, monthlyID]

    /// **1.1.x에서 4,900원에 팔던 한 번 사는 상품.**
    /// 그때 산 사람은 **평생 Pro로 인정한다.** 값을 치른 것이 판을 바꿨다고 사라지면 안 된다.
    /// (맥이 옛 '함께 쓰기' 구매자에게 한 것과 같다 → `WeekBlocksSpec.legacySyncProductID`)
    static let legacyProductID = "com.example.ScheduleDensityApp.pro"

    /// 이 중 하나라도 있으면 Pro다.
    static let entitlementIDs = Set(productIDs + [legacyProductID])

    /// 위젯과 함께 쓰는 자리. 스냅샷이 오가는 통과 같다.
    static let appGroupID = "group.com.devkoan.ScheduleDensity"

    /// **잠긴 위젯을 누르면 가는 곳.**
    ///
    /// ⚠️ 홈 화면에 위젯을 직접 올린 사람은 이미 살 마음이 있는 사람이다. 그런데 잠긴
    ///    위젯이 평소 딥링크를 그대로 들고 있어서, 눌러도 할 일 목록만 열렸다 —
    ///    무엇이 잠겼는지도, 어디서 여는지도 말해 주지 않는 막다른 길이었다.
    ///    (설정은 무지개 탭 → 톱니 → 스크롤, 서너 번을 더 눌러야 나온다.)
    static let paywallDeepLink = URL(string: "rainbow://paywall/widget")!

    private static let purchasedKey = "pro.purchased"

    private static var defaults: UserDefaults {
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

    /// 이 기능들을 써도 되는가.
    ///
    /// 근거는 **App Store 영수증 하나뿐이다.** 산 사람은 열리고, 안 산 사람은 잠긴다.
    /// 여기 다른 조건을 더하지 않는다 — 전에 '쓰던 사람은 열어 둔다'는 유예가 있었는데,
    /// 그걸 판단하려고 로컬 데이터 개수를 셌고, 그 스토어가 CloudKit 미러라
    /// **동기화 타이밍이 결제 여부를 흔들었다.** 조건이 둘이 되는 순간 그렇게 된다.
    static var isUnlocked: Bool {
#if DEBUG
        if unlockedInDebug { return true }
#endif
        return cachedPurchase ?? false
    }

    /// 캐시에 적혀 있는 답. **nil은 '안 샀다'가 아니라 '아직 애플에게 안 물어봤다'** 이다.
    ///
    /// ⚠️ `UserDefaults.bool(forKey:)`는 이 둘을 똑같이 false로 돌려준다. 그 차이를 잃으면,
    ///    영수증 조회가 한 번 늦거나 실패한 순간 **산 사람이 잠긴다** — 위젯 셋이 한꺼번에
    ///    자물쇠로 바뀌고, 설정은 '무료 버전'이라고 단정한다. 그래서 세 상태로 둔다.
    ///    (맥의 같은 장치 → 무지개 공방 `MacEntitlement.cachedPurchase`)
    static var cachedPurchase: Bool? {
        defaults.object(forKey: purchasedKey) as? Bool
    }

    /// 애플에게 물어본 적이 있는가. 아직이면 화면은 '무료'라고 단정하지 않는다.
    static var isKnown: Bool { cachedPurchase != nil }

    /// 영수증 확인 결과를 적는다.
    ///
    /// ⚠️ `PurchaseManager`만 부른다. 여기 적힌 한 줄이 곧 열림/잠김이고,
    ///    화면은 그것을 비추는 `PurchaseManager.isUnlocked`를 본다. 밖에서 직접
    ///    고치면 화면에 알려 줄 사람이 없어 설정만 낡은 말을 하게 된다.
    static func setPurchased(_ value: Bool) {
        // 위젯과 함께 쓰는 통이라 쓰는 일이 공짜가 아니다. 값이 그대로면 두고 간다.
        guard cachedPurchase != value else { return }
        defaults.set(value, forKey: purchasedKey)
    }

    // MARK: - 유예는 없다
    //
    // 1.0.9까지 무료였고 1.1.0부터 판다. 전에는 '쓰던 사람은 그대로 열어 둔다'는 유예를
    // 두고, 그 자격을 **로컬에 데이터가 있는가**로 추측했다. 그 추측이 문제였다 —
    // 할 일 스토어는 CloudKit 미러라 개수가 언제 0을 벗어나는지가 동기화에 달려 있어서,
    // 같은 사람이 실행할 때마다 다른 답이 나올 수 있었다. 게다가 판정은 한 번만 하고
    // 도장을 찍어 버려서, 한 번 어긋나면 되돌릴 길이 없었다.
    //
    // 무료였던 앱이 유료가 된 것뿐이다. 열림/잠김의 조건은 하나면 된다 — **샀는가.**
}
