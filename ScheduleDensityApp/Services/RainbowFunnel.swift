//
//  RainbowFunnel.swift
//  ScheduleDensityApp
//
//  **설치한 사람이 어디까지 와 보고 떠나는가.**
//
//  설치 → 첫 할 일 → 첫 단계 쪼개기 → 첫 무지개 일정 → 페이월 → 결제.
//  허브에는 사용 통계(일 단위 숫자)만 있어서, "할 일은 적는데 단계를 안 쪼갠다" 같은
//  끊긴 자리를 볼 수 없었다. 단계마다 **처음 닿은 순간 한 번만** 이벤트를 남긴다.
//
//  ⚠️ **새로 설치한 사람만 센다.** 이 버전 전에 쓰던 사람이 처음 할 일을 하나 더 적었다고
//     '첫 할 일'이 찍히면 설치 없는 퍼널이 생긴다. 설치 단계를 지난 기기만 다음 단계를 남긴다.
//  ⚠️ 나가는 길은 `LeeoAnalyticsCenter` → `ConsentedUsageAnalytics` 다. 사용 통계를 끈 사람에게서는
//     아무것도 나가지 않는다(단계 도장은 기기 안에만 찍힌다).
//  ⚠️ 이벤트 이름은 단계마다 고정이다. 바꾸면 허브에서 옛 숫자와 이어지지 않는다.
//

import Foundation
import LeeoKit

enum RainbowFunnel {

    enum Stage: String, CaseIterable {
        case install
        case firstTodo = "first_todo"
        case firstStep = "first_step"
        case firstEvent = "first_event"
        case paywallShown = "paywall_shown"
        case purchased

        /// 허브에 남는 이름.
        var eventName: String { "funnel_\(rawValue)" }
    }

    private static let keyPrefix = "funnel.reached."

    /// 설치 단계. 앱이 뜰 때마다 불러도 된다 — 처음 연 기기에서만 한 번 남는다.
    /// - Parameter isFirstLaunch: 이번이 이 기기에서 처음 연 것인가 (`LeeoEngagement.launchCount <= 1`).
    static func noteLaunch(isFirstLaunch: Bool, defaults: UserDefaults = .standard,
                           track: (LeeoEvent) -> Void = LeeoAnalyticsCenter.track) {
        guard isFirstLaunch else { return }
        reach(.install, defaults: defaults, track: track)
    }

    /// 한 단계에 닿았다. 처음일 때만 이벤트를 남기고, 남겼으면 true.
    @discardableResult
    static func reach(_ stage: Stage, defaults: UserDefaults = .standard,
                      track: (LeeoEvent) -> Void = LeeoAnalyticsCenter.track) -> Bool {
        guard shouldRecord(stage, reached: reachedStages(defaults)) else { return false }
        defaults.set(true, forKey: keyPrefix + stage.rawValue)
        track(.custom(name: stage.eventName, parameters: [:]))
        return true
    }

    /// 이 기기가 지나온 단계들.
    static func reachedStages(_ defaults: UserDefaults = .standard) -> Set<Stage> {
        Set(Stage.allCases.filter { defaults.bool(forKey: keyPrefix + $0.rawValue) })
    }

    /// 남길지 정한다 (순수 함수 — 시험이 같은 입력으로 확인한다).
    /// 이미 닿은 단계는 다시 남기지 않고, 설치를 지나지 않은(이 버전 전에 설치한) 기기는 설치 말고는 남기지 않는다.
    static func shouldRecord(_ stage: Stage, reached: Set<Stage>) -> Bool {
        if reached.contains(stage) { return false }
        return stage == .install || reached.contains(.install)
    }
}
