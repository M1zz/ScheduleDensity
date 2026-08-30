//
//  ScheduleDensityAppSpec.swift
//  ScheduleDensityApp
//

import Foundation
import LeeoKit

enum ScheduleDensityAppSpec: LeeoAppSpec {
    static let appName = "일정 밀도"
    static let developerEmail = "mizzking75@gmail.com"
    // ⚠️ appIdentifier는 앱 번들 ID와 같은 값을 유지한다(com.example.ScheduleDensityApp).
    //    placeholder 도메인처럼 보여도 App Store에 배포된 실제 번들 ID이고,
    //    이 값은 피드백 허브가 기존 레코드를 찾는 키이기도 하다.
    //    "com.example이 남아 있네" 하고 정리하지 말 것 — 양쪽 다 깨진다.
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.example.ScheduleDensityApp")

    /// LeeoKit 3부터는 기본값이 없다 — 모든 앱이 한 번은 선언해야 하는 의무 링크.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/ScheduleDensity/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/ScheduleDensity/")!,
        marketingURL: URL(string: "https://m1zz.github.io/ScheduleDensity/")!
    )

    /// 결제가 없는 앱이다. 페이월·복원·약관 의무도 여기서 따라오지 않는다.
    static let monetization = LeeoMonetization.free
}
