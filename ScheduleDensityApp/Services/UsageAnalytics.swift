//
//  UsageAnalytics.swift
//
//  **페이월과 피드백에서 무슨 일이 벌어졌나**를 허브로 흘려보내는 자리.
//
//  LeeoKit 은 이벤트의 **이름만** 정해 두고(→ `LeeoEvent`), 어디로 보낼지는 앱이 꽂는
//  싱크에 맡긴다. 그 싱크가 이것이다. 하는 일은 두 가지뿐 —
//    ① 동의했는가를 먼저 묻고 (→ UsageReporting.swift)
//    ② 이벤트 하나를 문자열 한 줄로 눌러 담아 허브의 `UsageEvent` 로 보낸다.
//
//  ⚠️ **동의 없이는 한 줄도 안 나간다.** `UsageReporting.isEnabled` 는 기본이 꺼짐이고,
//     이 싱크는 그 값을 통과하지 못하면 아무 일도 하지 않는다. 페이월 이벤트라고
//     예외를 두지 않는다 — 돈이 걸린 숫자일수록 몰래 가져가면 안 된다.
//
//  ⚠️ `LeeoKit.bootstrap(_:)` 은 **부르지 않는다.** 그 한 줄은 편하지만 크래시 진단
//     (MetricKit)과 사용현황 스냅샷을 동의와 무관하게 켜 버린다. 이 앱은 개인정보
//     처리방침에 "켜야만 나간다"고 써 붙였으므로, 싱크만 손으로 등록한다
//     (→ ScheduleDensityApp.init).
//

import Foundation
import LeeoKit

/// 동의한 사람의 것만 허브로 보내는 분석 싱크.
struct ConsentedUsageAnalytics: LeeoAnalytics {

    func track(_ event: LeeoEvent) {
        // 여기서도 한 번 막고, `logIfAllowed` 안에서 또 막는다. 문이 둘이라 번거로운 게
        // 아니라, 이 두 곳 중 하나가 나중에 느슨해져도 나머지 하나가 남는다.
        guard UsageReporting.isEnabled else { return }
        UsageReporting.logIfAllowed(Self.label(for: event))
    }

    /// 이벤트 하나를 이름 한 줄로 눌러 담는다.
    ///
    /// 허브의 `UsageEvent` 는 이름 한 칸만 가진다. 그래서 **그 이벤트를 다른 이벤트와
    /// 가르는 값 하나만** 뒤에 붙인다. 값은 전부 열거형에서 나오는 정해진 낱말이라
    /// 사용자가 적은 글자가 섞여 들어갈 길이 없다.
    ///
    /// 상품 ID 는 일부러 안 붙인다. 파는 것이 '무지개 Pro' 하나뿐이라 언제나 같은 값이고,
    /// 같은 값을 매번 붙이면 이름만 길어지고 세는 데는 아무 도움이 안 된다.
    static func label(for event: LeeoEvent) -> String {
        switch event {
        case .paywallShown(let reason):
            // 어느 잠긴 자리에서 들어왔는가. 페이월의 전환율은 이 값으로 갈라 봐야
            // 뜻이 있다 — 위젯 때문에 온 사람과 통계 때문에 온 사람은 다른 사람이다.
            return join("paywall_shown", reason)
        case .gateBlocked(let key):
            return join("gate_blocked", key)
        case .purchaseStarted:
            return "purchase_started"
        case .purchaseCompleted:
            return "purchase_completed"
        case .purchaseFailed(_, let reason):
            // 취소인지, 승인 대기인지, 진짜 실패인지를 가른다. 셋을 뭉치면
            // "안 팔린다"만 남고 "왜 안 팔리는가"가 사라진다.
            return join("purchase_failed", reason)
        case .purchaseRestored(let restored):
            // 되찾았는지 아닌지가 곧 결과다. 못 찾은 복원이 많으면 그건 지원 문제다.
            return restored ? "purchase_restored" : "purchase_restore_empty"
        case .feedbackSubmitted(let type):
            return join("feedback_submitted", type)
        case .satisfactionPromptShown, .reviewRequested:
            return event.name
        case .custom:
            return event.name
        }
    }

    private static func join(_ name: String, _ value: String?) -> String {
        guard let value, !value.isEmpty else { return name }
        return "\(name):\(value)"
    }
}
