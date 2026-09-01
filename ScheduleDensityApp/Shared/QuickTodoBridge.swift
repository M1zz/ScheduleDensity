//
//  QuickTodoBridge.swift
//  ScheduleDensityApp
//
//  제어센터에서 누른 '할 일 적기'가 앱의 빈 줄까지 건너오는 통로.
//
//  ⚠️ 컨트롤 인텐트는 위젯 프로세스가 아니라 **앱 프로세스**에서 실행된다
//     (`supportedModes(.foreground)`). 그래서 같은 이름의 인텐트가 앱 타깃에도
//     있어야 하고(→ QuickTodoControlIntent.swift), 위젯 타깃의 정의는
//     컨트롤 UI가 참조하는 짝이다(→ TodoWidget/QuickTodoControl.swift).
//     둘이 함께 쓰는 통로가 이 파일이라, **양쪽 타깃에 모두 들어간다.**
//
//  건너오는 길은 두 갈래다:
//    - **App Group의 보류 플래그** — 앱이 꺼져 있다가 켜지는 콜드 런치용.
//      켜질 때 화면이 그 플래그를 보고 빈 줄을 연다.
//    - **NotificationCenter** — 앱이 이미 떠 있을 때 바로 반응하라고.
//
//  플래그는 Bool 하나이고 **거두는 곳은 한 군데뿐**이라(→ TodoView), 두 갈래가
//  모두 도착해도 빈 줄은 한 번만 열린다.
//

import Foundation

enum QuickTodoBridge {
    /// ⚠️ 위젯과 같은 상자여야 한다 (→ TodoWidgetBridge.appGroupID).
    static var defaults: UserDefaults? { UserDefaults(suiteName: TodoWidgetBridge.appGroupID) }

    private static let pendingKey = "pendingQuickTodoAdd"

    /// 제어센터에서 눌렀다. 콜드 런치와 이미 떠 있는 화면, 양쪽 모두에 건다.
    @MainActor
    static func requestAdd() {
        defaults?.set(true, forKey: pendingKey)
        NotificationCenter.default.post(name: .quickTodoAddRequested, object: nil)
    }

    /// 아직 안 거둔 요청이 있는가. **거두지는 않는다** — 탭을 옮기는 쪽이 엿볼 때 쓴다.
    static var hasPendingAdd: Bool {
        defaults?.bool(forKey: pendingKey) == true
    }

    /// 요청을 거둔다. 있었으면 true. 거두는 곳은 빈 줄을 여는 한 군데뿐이어야 한다 —
    /// 여러 곳에서 거두면 어느 쪽이 먼저 왔는지에 따라 줄이 열리다 말다 한다.
    @discardableResult
    static func consumePendingAdd() -> Bool {
        guard hasPendingAdd else { return false }
        defaults?.set(false, forKey: pendingKey)
        return true
    }
}

extension Notification.Name {
    /// 제어센터 컨트롤이 눌렸다. 이미 떠 있는 할 일 목록이 받는다.
    static let quickTodoAddRequested = Notification.Name("quickTodoAddRequested")
}
