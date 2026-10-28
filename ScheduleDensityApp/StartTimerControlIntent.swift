//
//  StartTimerControlIntent.swift
//  ScheduleDensityApp
//
//  제어센터 '타이머 시작' 컨트롤의 인텐트 — **앱 타깃 쪽 정의.**
//
//  앱을 열지 않고 켠다. `LiveActivityIntent` 라서 시스템이 **앱 프로세스를 뒤에서** 깨워
//  여기 `perform` 을 돌리고, 그 자리에서 라이브 액티비티를 띄울 수 있다.
//  앞에 띄우지 않으므로 화면은 지금 보던 그대로이고, 숫자는 잠금화면·아일랜드에 선다.
//
//  ⚠️ 위젯 타깃(TodoWidget/StartTimerControl.swift)에 **같은 이름의 타입**이 있다.
//     실행은 이쪽 정의로 이뤄진다 (→ QuickTodoControlIntent.swift 와 같은 까닭).
//     둘의 타입명·하는 일을 **항상 같이** 고칠 것.
//

import AppIntents
import Foundation

@available(iOS 18.0, *)
struct StartTimerControlIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "타이머 시작"
    static var description = IntentDescription("지금 하는 일정의 타이머를 앱을 열지 않고 켭니다.")

    @MainActor
    func perform() async throws -> some IntentResult {
        // 앱 안의 '일정 고르기'와 같은 차례다: 지금 하는 것, 없으면 곧 올 것.
        // 끝은 언제 켜든 그 일정의 끝 시각이다 (→ TimerStarter).
        let clock = ScheduleClockStore.shared
        clock.reload()
        let now = Date()
        guard let slot = clock.current(at: now)
                ?? clock.slots.filter({ $0.start > now }).min(by: { $0.start < $1.start })
        else { throw NoSlot() }

        // 같은 일정을 이미 세고 있으면 그대로 둔다 — 다시 켜도 끝 시각은 같다.
        if !TaskTimer.shared.isTiming(slot.id) {
            TimerStarter.start(slot: slot, from: now)
        }
        return .result()
    }

    /// 셀 일정이 없다. 조용히 넘기면 눌러도 안 듣는 단추처럼 보인다.
    struct NoSlot: Error, CustomLocalizedStringResourceConvertible {
        var localizedStringResource: LocalizedStringResource { "지금이나 곧 올 일정이 없어요." }
    }
}
