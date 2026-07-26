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
}
