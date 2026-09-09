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

    /// **무료로 쓰다가 한 번 사면 열리는 앱이다** (→ ProEntitlement.swift).
    ///
    /// 오랫동안 여기가 `.free` 였는데, 1.1.0부터 '무지개 Pro'를 실제로 팔기 시작한 뒤에도
    /// 이 한 줄만 옛말을 하고 있었다. 계약이 거짓말을 하면 Preflight 도, 포트폴리오도,
    /// 이 앱을 무료 앱으로 센다. 파는 것이 있으면 여기 적는다.
    ///
    /// ⚠️ 선언일 뿐 동작이 바뀌지는 않는다. 이 앱의 페이월과 영수증 확인은 계속
    ///    `PaywallView`·`PurchaseManager` 가 한다 — LeeoKit 의 `LeeoStore` 를 쓰지 않는다.
    static let monetization = LeeoMonetization.freemium(
        LeeoPurchaseConfig(
            productIDs: [ProEntitlement.productID],
            // 잠기는 자리는 페이월이 늘어놓는 목록 그 자체다. 두 군데에 따로 적으면
            // 반드시 어긋나므로 `ProFeature.sold` 하나에서 받아 온다.
            gate: LeeoGatePolicy(proOnly: Set(ProFeature.sold.map(\.rawValue))),
            // 위젯과 함께 읽는 그 통. 권한 한 줄이 실제로 여기 적힌다.
            cacheSuiteName: ProEntitlement.appGroupID))

    /// 페이월·피드백에서 벌어진 일을 허브로 흘려보내는 싱크.
    /// **동의한 사람의 것만 나간다** (→ UsageAnalytics.swift, UsageReporting.swift).
    static let analytics: any LeeoAnalytics = ConsentedUsageAnalytics()
}
