//
//  UsageReporting.swift
//
//  **묻지 않고는 안 보낸다.**
//
//  이 앱의 개인정보 처리방침은 오랫동안 "수집하거나 전송하지 않습니다"였다.
//  그 말을 지키면서 통계를 보내는 방법은 하나뿐이다 — **사용자가 켜야 나간다.**
//  기본값은 꺼짐이고, 안 켜면 네트워크로 한 바이트도 안 나간다.
//
//  ⚠️ 나가는 것은 `UsageStats.metrics` 의 **숫자뿐이다.** 할 일 제목도, 일정 이름도,
//     분류 이름도, 날짜도 안 나간다. 설치를 가리키는 값은 기기·계정과 무관한
//     무작위 UUID 이고, 앱을 지우면 사라진다 (→ LeeoUsageReporter.installID).
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
        LeeoUsageReporter(spec: ScheduleDensityAppSpec.self)
            .reportInBackground(metrics: stats.metrics)
    }

    /// 드물게 일어나는 큰 행동 하나. 고빈도 동작에는 쓰지 않는다 —
    /// 줄마다 레코드를 하나씩 만들면 그건 통계가 아니라 감시다.
    static func logIfAllowed(_ event: String) {
        guard isEnabled else { return }
        LeeoUsageReporter(spec: ScheduleDensityAppSpec.self).logEventInBackground(event)
    }
}
