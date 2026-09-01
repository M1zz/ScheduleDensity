//
//  QuickTodoControlIntent.swift
//  ScheduleDensityApp
//
//  제어센터 '할 일 적기' 컨트롤의 인텐트 — **앱 타깃 쪽 정의.**
//
//  ⚠️ 위젯 타깃(TodoWidget/QuickTodoControl.swift)에 **같은 이름의 타입**이 있다.
//     포그라운드 모드 인텐트는 시스템이 위젯 프로세스가 아니라 앱 프로세스에서
//     실행하므로, 앱 타깃에 이 타입이 없으면 컨트롤을 눌러도 **아무 일도 안 일어난다**
//     (에러도 로그도 없이 조용히 무시된다). 인터랙티브 위젯 인텐트를 앱·익스텐션
//     양쪽에 넣는 관행과 같은 이유다.
//
//     둘의 타입명·supportedModes·하는 일을 **항상 같이** 고칠 것.
//

import AppIntents
import Foundation

@available(iOS 18.0, *)
struct AddQuickTodoControlIntent: AppIntent {
    static var title: LocalizedStringResource = "할 일 적기"
    static var description = IntentDescription("‘욕망의 무지개’를 열고 빈 줄에 바로 적습니다.")

    // iOS 26부터 openAppWhenRun 은 무시된다 — supportedModes 가 대체.
    // 두 벌을 다 두어 18~25와 26 이후를 모두 덮는다.
    static var openAppWhenRun: Bool { true }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        // 콜드 런치용 보류 플래그와, 이미 떠 있는 목록용 알림을 함께 건다
        // (→ QuickTodoBridge.swift. 거두는 곳은 한 군데뿐이라 멱등이다).
        QuickTodoBridge.requestAdd()
        return .result()
    }
}
