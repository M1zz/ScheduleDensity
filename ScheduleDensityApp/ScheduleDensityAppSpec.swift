//
//  ScheduleDensityAppSpec.swift
//  ScheduleDensityApp
//

import Foundation
import LeeoKit

enum ScheduleDensityAppSpec: LeeoAppSpec {
    static let appName = "일정 밀도"
    static let developerEmail = "leeo@kakao.com"
    // ⚠️ appIdentifier는 앱 번들 ID와 같은 값을 유지한다(com.example.ScheduleDensityApp).
    //    placeholder 도메인처럼 보여도 App Store에 배포된 실제 번들 ID이고,
    //    이 값은 피드백 허브가 기존 레코드를 찾는 키이기도 하다.
    //    "com.example이 남아 있네" 하고 정리하지 말 것 — 양쪽 다 깨진다.
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.example.ScheduleDensityApp")

    /// 백업 금고(LeeoVault)가 함께 담는 앱 그룹 — 위젯과 나눠 쓰는 할 일.
    static let appGroups = ["group.com.devkoan.ScheduleDensity"]

    /// 소개·개인정보 페이지의 언어별 뿌리.
    /// 한국어는 `docs/`, 영어는 `docs/en/`, 번체 중국어는 `docs/zh-Hant/` 에 있다 (GitHub Pages).
    /// ⚠️ 여기 값은 **App Store Connect 의 지원 URL·개인정보 처리방침 URL 과 같아야 한다.**
    ///    현지화마다 칸이 따로 있고, 심사자는 그 칸의 주소를 연다.
    private static var siteRoot: String {
        let base = "https://m1zz.github.io/ScheduleDensity/"
        let language = Locale(identifier: Locale.preferredLanguages.first ?? "en").language
        switch language.languageCode?.identifier {
        case "ko":
            return base
        // 대만(zh-TW)·홍콩(zh-HK)도 여기로 온다 — 지역만 적힌 식별자도 스크립트는 Hant 로 채워진다.
        // 간체(zh-Hans)는 앱이 번역돼 있지 않아 영어로 뜨므로 페이지도 영어로 보낸다.
        case "zh" where language.script?.identifier == "Hant":
            return base + "zh-Hant/"
        default:
            return base + "en/"
        }
    }

    /// LeeoKit 3부터는 기본값이 없다 — 모든 앱이 한 번은 선언해야 하는 의무 링크.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: siteRoot + "privacy.html")!,
        supportURL: URL(string: siteRoot)!,
        marketingURL: URL(string: siteRoot)!
    )

    /// **무료로 쓰다가, 쌓여야 보이는 것은 Plus, 밖으로 나가는 것은 Pro로 파는 앱이다.**
    ///
    /// 맥앱 '무지개 공방'과 **같은 사다리**다. 무료 · Plus · Pro, 유료 칸마다 연 구독과 평생.
    /// 1.1.x에서 4,900원에 한 번 사는 상품을 팔았고, 그 구매자는 평생 Pro로 인정한다
    /// (Pro 평생이 바로 그 상품이다 → ProEntitlement.proLifetimeID).
    /// 칸마다 무엇이 열리는지는 `ProFeature.tier` 한 곳에 있다.
    ///
    /// ⚠️ **여기 선언했다고 팔기 시작하는 게 아니다.** 실제로 파는지는
    ///    `ProEntitlement.sellsPro`가 정한다. 상품이 App Store Connect에 서기 전에 켜면
    ///    아무도 못 사는 채로 Pro 기능만 잠긴다.
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: ProEntitlement.productIDs,
            // 자체 약관이 없으므로 애플 표준 사용권 계약(EULA)을 건다.
            // 구독을 파는 앱의 심사 필수 항목이다.
            termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            entitlementIDs: ProEntitlement.entitlementIDs,
            gate: LeeoGatePolicy(
                // 무료로도 **써 보고 알 만큼**은 연다: 최근 2주 장부는 그냥 보인다.
                // ⚠️ 여기 적은 것은 **실제로 구현된 것만**이다. 통계에도 2주 창을 열 생각이지만,
                //    코드가 아직 통째로 잠그므로 적지 않는다 — 계약이 거짓말을 하면
                //    Preflight도 포트폴리오도 이 앱을 잘못 센다.
                freeLimits: [Gate.ledgerWeeks: ProFeature.freeWeekCount],
                // 잠기는 자리는 페이월이 늘어놓는 목록 그 자체다. 두 군데에 따로 적으면
                // 반드시 어긋나므로 `ProFeature.sold` 하나에서 받아 온다.
                proOnly: Set(ProFeature.sold.map(\.rawValue))),
            // 위젯과 함께 읽는 그 통. 권한 한 줄이 실제로 여기 적힌다.
            cacheSuiteName: ProEntitlement.appGroupID,
            // 선물하기 (Pro · Plus). 보내는 사람이 소모성 선물 상품을 사면, 허브 공개 DB 의 오퍼 코드 묶음에서
            // 한 장을 가져와 App Store 사용 링크로 건넨다. 받는 사람은 링크를 누르고 "사용" 한 번 —
            // 그 칸 평생을 여는 것은 **App Store 다**(지침 3.1.1).
            // ⚠️ 앱이 만든 코드로 권한을 여는 길은 만들지 않는다(클립키보드가 3.1.1 로 거절됐다).
            // ⚠️ 선물 상품은 productIDs · entitlementIDs 에 넣지 않는다. 넣으면 선물을 산 사람이 그 칸이 된다.
            // ⚠️ 묶음은 FeedbackHub ▸ 인앱 구입 ▸ 선물 코드 묶음에서 채운다. 비어 있으면 산 사람이 "준비 중" 에서 기다린다.
            gift: giftConfig,
            moreGifts: moreGiftConfigs,
            // 개발자 응원 팁. Pro 를 다 가진 사람이 고마울 때 조금 더 낸다(→ TodoTipMoments).
            tipJar: LeeoTipJarConfig(productIDs: ProEntitlement.tipProductIDs)))

    /// Pro 선물. 받는 사람에게 Pro 평생(`proLifetimeID`)이 오퍼 코드로 열린다. 묶음 열쇠는 번들 ID(예전 묶음 그대로).
    static let giftConfig = LeeoGiftConfig(
        productID: ProEntitlement.giftProductID,
        grantsProductID: ProEntitlement.proLifetimeID,
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        sellsGifts: true
    )

    /// Plus 선물. 받는 사람에게 Plus 평생(`plusLifetimeID`)이 열린다. 묶음은 Pro 와 따로다(`poolKey`).
    static let moreGiftConfigs = [LeeoGiftConfig(
        productID: ProEntitlement.plusGiftProductID,
        grantsProductID: ProEntitlement.plusLifetimeID,
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        sellsGifts: true,
        tierName: "Plus",
        poolKey: ProEntitlement.plusGiftPoolKey
    )]

    /// 게이트 열쇠말. 문자열을 여기저기 흩어 적으면 오타 하나로 조용히 안 잠긴다.
    enum Gate {
        /// 회수 장부를 몇 주까지 거슬러 보는가 (무료는 2주 → WeekLedgerView.isFree).
        static let ledgerWeeks = "ledgerWeeks"
    }

    /// 페이월·피드백에서 벌어진 일을 허브로 흘려보내는 싱크.
    /// **동의한 사람의 것만 나간다** (→ UsageAnalytics.swift, UsageReporting.swift).
    static let analytics: any LeeoAnalytics = ConsentedUsageAnalytics()

    // '함께 쓰는 앱' 화면 (LeeoFamily). 이 앱은 맥 '무지개 공방'과 같은 목록을 나눠 쓰는 짝이라,
    // 그 앱을 다른 앱들보다 먼저 — 이야기보다도 먼저 — 세운다 (→ MacCompanionView.swift).
    static let familyID: String? = "rainbow-ios"
    static let familyFeatured = ["rainbow-mac"]
}
