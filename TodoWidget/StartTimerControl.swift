//
//  StartTimerControl.swift
//  TodoWidget
//
//  제어센터 컨트롤 — 누르면 **앱을 열지 않고** 지금 하는 일정의 타이머가 켜진다.
//
//  시간을 빠듯하게 쓸 때는 앱을 찾아 열고 탭을 고르는 몇 초가 아깝다. 제어센터·잠금 화면·
//  동작 버튼은 어느 화면에서든 한 번에 닿으므로, 거기서 눌러 바로 세기 시작한다.
//  숫자는 잠금화면·다이나믹 아일랜드에 선다 (→ TimerLiveActivity.swift).
//
//  ⚠️ 동작 원리는 QuickTodoControl.swift 와 같다. 다른 것은 하나:
//     `LiveActivityIntent` 라서 앱을 **앞에 띄우지 않고** 앱 프로세스에서 돈다.
//     실제 실행은 앱 타깃의 같은 이름 타입(→ ScheduleDensityApp/StartTimerControlIntent.swift)이다.
//     인텐트 시그니처를 고치면 kind 문자열도 올릴 것. 확인은 실기기에서.
//

import WidgetKit
import SwiftUI
import AppIntents

/// 제어센터 컨트롤용 인텐트 (위젯 타깃 쪽 정의).
/// ⚠️ 앱 타깃의 `StartTimerControlIntent` 와 타입명을 항상 일치시킬 것. 실행은 앱 쪽이 한다.
@available(iOS 18.0, *)
struct StartTimerControlIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "타이머 시작"
    static var description = IntentDescription("지금 하는 일정의 타이머를 앱을 열지 않고 켭니다.")

    func perform() async throws -> some IntentResult {
        .result()
    }
}

@available(iOS 18.0, *)
struct StartTimerControl: ControlWidget {
    /// ⚠️ 인텐트 시그니처를 고치면 이 문자열도 올릴 것 (→ QuickTodoControl.swift 3번).
    static let kind = "com.example.ScheduleDensityApp.StartTimerControl.v1"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartTimerControlIntent()) {
                Label("타이머 시작", systemImage: "timer")
            }
        }
        .displayName("타이머 시작")
        .description("지금 하는 일정의 타이머를 앱을 열지 않고 켭니다.")
    }
}
