//
//  ScheduleDensityAppSpec.swift
//  ScheduleDensityApp
//

import Foundation
import LeeoKit

enum ScheduleDensityAppSpec: LeeoAppSpec {
    static let appName = "일정 밀도"
    static let developerEmail = "mizzking75@gmail.com"
    // ⚠️ appIdentifier는 의도적으로 구 번들 ID(com.example.ScheduleDensityApp)를 유지한다.
    //    앱 번들 ID는 1.0.5에서 com.devkoan.ScheduleDensityApp으로 바뀌었지만, 이 값은
    //    피드백 허브가 기존에 쌓인 레코드를 찾는 키라서 바꾸면 과거 피드백과 연결이 끊긴다.
    //    "com.example이 남아 있네" 하고 정리하지 말 것.
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.example.ScheduleDensityApp")
}
