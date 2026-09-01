//
//  QuickTodoControl.swift
//  TodoWidget
//
//  제어센터 컨트롤 — 누르면 앱이 열리고 목록 맨 위 빈 줄에 커서가 선다.
//
//  적는 것과 앱을 여는 것 사이의 거리가 이 앱에서 제일 자주 밟는 길이다. 떠오른
//  줄은 몇 초 안에 적지 않으면 사라지는데, 그 몇 초가 홈 화면에서 앱을 찾는 데
//  다 쓰인다. 제어센터는 어느 화면에서든 한 번에 내려오므로 그 거리를 없앤다.
//
//  ⚠️ 동작 원리 (실기기 검증이 필요한 자리다):
//  1. 포그라운드 모드 인텐트는 위젯 프로세스가 아니라 **앱 프로세스**에서 실행된다.
//     그래서 같은 이름의 타입이 앱 타깃에도 있어야 한다
//     (→ ScheduleDensityApp/QuickTodoControlIntent.swift). 없으면 눌러도
//     조용히 무시된다 — 에러도 로그도 남지 않는다.
//  2. iOS 26부터 `openAppWhenRun` 은 무시되고 `supportedModes` 가 그 자리를 잇는다.
//     둘 다 적어 18~25와 26 이후를 모두 덮는다.
//  3. 인텐트 시그니처가 바뀌면 **kind 문자열도 올릴 것.** 시스템이 죽은 등록 정보를
//     캐시해서, 이미 추가해 둔 버튼이 옛 인텐트를 가리킨 채 눌러도 아무 일이 없다.
//     (앱은 켤 때마다 `ControlCenter.shared.reloadAllControls()` 로 재등록을 돕는다.)
//  4. 제어센터는 **시뮬레이터에서 믿을 수 없다.** 확인은 실기기에서.
//

import WidgetKit
import SwiftUI
import AppIntents

/// 제어센터 컨트롤용 인텐트 (위젯 타깃 쪽 정의).
/// ⚠️ 앱 타깃의 `AddQuickTodoControlIntent` 와 타입명·동작을 항상 일치시킬 것.
///    실제 실행은 앱 쪽 정의로 이뤄진다.
@available(iOS 18.0, *)
struct AddQuickTodoControlIntent: AppIntent {
    static var title: LocalizedStringResource = "할 일 적기"
    static var description = IntentDescription("‘욕망의 무지개’를 열고 빈 줄에 바로 적습니다.")

    static var openAppWhenRun: Bool { true }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickTodoBridge.requestAdd()
        return .result()
    }
}

@available(iOS 18.0, *)
struct QuickTodoControl: ControlWidget {
    /// ⚠️ 인텐트 시그니처를 고치면 이 문자열도 올릴 것 (위 3번).
    static let kind = "com.example.ScheduleDensityApp.QuickTodoControl.v1"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddQuickTodoControlIntent()) {
                Label("할 일 적기", systemImage: "text.badge.plus")
            }
        }
        .displayName("할 일 적기")
        .description("빈 줄을 열고 바로 적습니다.")
    }
}
