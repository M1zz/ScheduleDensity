//
//  UsageReporting.swift
//
//  **묻지 않고는 안 보낸다.**
//
//  이 앱의 개인정보 처리방침은 오랫동안 "수집하거나 전송하지 않습니다"였다.
//  그 말을 지키면서 통계를 보내는 방법은 하나뿐이다 — **사용자가 켜야 나간다.**
//  기본값은 꺼짐이고, 안 켜면 네트워크로 한 바이트도 안 나간다.
//
//  ⚠️ 나가는 것은 두 가지다 — `UsageStats.metrics` 의 **숫자**, 그리고 페이월에서
//     벌어진 일을 가리키는 **앱이 미리 정해 둔 낱말** 한 줄 (→ UsageAnalytics.swift).
//     할 일 제목도, 일정 이름도, 분류 이름도, 날짜도 안 나간다.
//     결제 쪽에서 나가는 것은 **"이 설치가 Pro 를 샀는가" 0/1 한 비트뿐**이다
//     (→ `entitlementMetrics`). 결제 수단·영수증·금액은 앱이 아예 모른다.
//     설치를 가리키는 값은 기기·계정과 무관한 무작위 UUID 이고, 앱을 지우면 사라진다
//     (→ LeeoUsageReporter.installID).
//
//  ⚠️ 이 파일을 고쳐 무언가를 더 보내게 될 때는 **docs/privacy.html 도 같이 고친다.**
//     앱이 하는 일과 써 붙인 말이 어긋나면 그건 심사 문제 이전에 거짓말이다.
//

import Foundation
import LeeoKit

enum UsageReporting {

    private static let enabledKey = "usage.reportingEnabled"
    private static let askedKey = "usage.reportingAsked"

    private static var defaults: UserDefaults { .standard }

    /// 개발자에게도 보낼 것인가. **기본은 꺼짐이다.**
    static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set {
            defaults.set(newValue, forKey: enabledKey)
            defaults.set(true, forKey: askedKey)
            // 안 보내기로 했으면 들고 있을 이유도 없다. 적어 둔 날짜까지 버린다.
            if !newValue { UsageDiary.forgetEverything() }
        }
    }

    /// 한 번이라도 답한 적이 있는가. 아직이면 화면에서 먼저 물어본다.
    static var hasAnswered: Bool { defaults.bool(forKey: askedKey) }

    /// 앱을 켤 때. 켜 두었으면 스냅샷을 갱신한다.
    /// 보내는 간격은 LeeoUsageReporter 가 12시간으로 막아 두어 매번 나가지 않는다.
    static func reportIfAllowed(_ stats: UsageStats) {
        guard isEnabled else { return }
        var metrics = stats.metrics
        metrics.merge(entitlementMetrics()) { _, new in new }
        LeeoUsageReporter(spec: ScheduleDensityAppSpec.self)
            .reportInBackground(metrics: metrics)
    }

    /// 이 설치가 Pro 를 샀는가. **팔기 시작한 뒤에만** 나간다.
    ///
    /// 허브(FeedbackHubViewer)가 유료·무료 고객을 가르는 근거다. 규약 이름은
    /// `flag.isPaid` 이고, 이 앱은 결제 말고 열리는 길이 없으므로 접근 권한도 같은
    /// 값이다 — 그래서 한 비트만 보낸다(`flag.isComped`·`flag.isTrial` 은 이 앱에
    /// 해당 제도가 없어서 안 보낸다. 없는 것을 0 으로 보내면 "체험자가 0명"이 되어
    /// 제도가 없다는 사실과 구분되지 않는다).
    ///
    /// **두 경우에는 한 줄도 안 보낸다. 둘 다 0 과 다른 말이기 때문이다:**
    ///
    /// - 아직 안 팔 때(`sellsPro == false`). 0 을 보내면 허브는 "아무도 안 샀다"로
    ///   읽는데 진실은 "살 수가 없다"다. 전환율이 0% 로 찍히고, 그 숫자를 보고
    ///   가격이나 문구를 고치게 된다.
    /// - 영수증을 아직 안 물어봤을 때(`cachedPurchase == nil`). 한 번 늦은 조회가
    ///   산 사람을 무료로 만들면 안 된다 — `ProEntitlement.cachedPurchase` 가
    ///   세 상태인 까닭이 그것이다. 허브는 안 온 값을 0 이 아니라 **모름**으로 센다.
    ///
    /// ⚠️ 나가는 것은 0/1 한 비트뿐이다. 결제 수단·영수증·금액은 앱이 아예 모르고,
    ///    `docs/privacy.html` 6항이 그렇게 적혀 있다. 여기서 더 보내게 되면 그 글도
    ///    같이 고친다.
    private static func entitlementMetrics() -> [String: Double] {
        guard ProEntitlement.sellsPro,
              let purchased = ProEntitlement.cachedPurchase else { return [:] }
        return ["flag.isPaid": purchased ? 1 : 0]
    }

    /// 드물게 일어나는 큰 행동 하나. 고빈도 동작에는 쓰지 않는다 —
    /// 줄마다 레코드를 하나씩 만들면 그건 통계가 아니라 감시다.
    static func logIfAllowed(_ event: String) {
        guard isEnabled else { return }
        LeeoUsageReporter(spec: ScheduleDensityAppSpec.self).logEventInBackground(event)
    }
}
