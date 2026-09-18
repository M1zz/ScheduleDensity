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

    /// 소개·개인정보 페이지의 언어별 뿌리.
    /// 한국어는 `docs/`, 영어는 `docs/en/` 에 있다 (GitHub Pages).
    /// ⚠️ 여기 두 값은 **App Store Connect 의 지원 URL·개인정보 처리방침 URL 과 같아야 한다.**
    ///    현지화마다 칸이 따로 있고, 심사자는 그 칸의 주소를 연다.
    private static var siteRoot: String {
        let language = Locale.preferredLanguages.first ?? "en"
        let isKorean = Locale(identifier: language).language.languageCode?.identifier == "ko"
        return isKorean ? "https://m1zz.github.io/ScheduleDensity/"
                        : "https://m1zz.github.io/ScheduleDensity/en/"
    }

    /// LeeoKit 3부터는 기본값이 없다 — 모든 앱이 한 번은 선언해야 하는 의무 링크.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: siteRoot + "privacy.html")!,
        supportURL: URL(string: siteRoot)!,
        marketingURL: URL(string: siteRoot)!
    )

    /// **무료로 쓰다가, 쌓여야 보이는 것과 밖으로 나가는 것을 Pro로 파는 앱이다.**
    ///
    /// 맥앱 '무지개 공방'과 **같은 문장, 같은 사다리**다 — 연간(7일 체험) · 평생 · 월간.
    /// 1.1.x에서 4,900원에 한 번 사는 상품을 팔았고, 그 구매자는 평생 Pro로 인정한다
    /// (`entitlementIDs`에 옛 상품이 함께 들어 있다 → ProEntitlement.legacyProductID).
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
                // 무료로도 **써 보고 알 만큼**은 연다: 최근 2주 장부·통계는 그냥 보인다.
                freeLimits: [Gate.ledgerWeeks: ProFeature.freeWeekCount,
                             Gate.statisticsWeeks: ProFeature.freeWeekCount],
                // 잠기는 자리는 페이월이 늘어놓는 목록 그 자체다. 두 군데에 따로 적으면
                // 반드시 어긋나므로 `ProFeature.sold` 하나에서 받아 온다.
                proOnly: Set(ProFeature.sold.map(\.rawValue))),
            // 위젯과 함께 읽는 그 통. 권한 한 줄이 실제로 여기 적힌다.
            cacheSuiteName: ProEntitlement.appGroupID))

    /// 게이트 열쇠말. 문자열을 여기저기 흩어 적으면 오타 하나로 조용히 안 잠긴다.
    enum Gate {
        /// 회수 장부를 몇 주까지 거슬러 보는가 (무료는 2주).
        static let ledgerWeeks = "ledgerWeeks"
        /// 일정 통계를 몇 주까지 거슬러 보는가 (무료는 2주).
        static let statisticsWeeks = "statisticsWeeks"
    }

    /// 페이월·피드백에서 벌어진 일을 허브로 흘려보내는 싱크.
    /// **동의한 사람의 것만 나간다** (→ UsageAnalytics.swift, UsageReporting.swift).
    static let analytics: any LeeoAnalytics = ConsentedUsageAnalytics()
}
