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

    /// 결제가 없는 앱이다. 페이월·복원·약관 의무도 여기서 따라오지 않는다.
    static let monetization = LeeoMonetization.free
}
