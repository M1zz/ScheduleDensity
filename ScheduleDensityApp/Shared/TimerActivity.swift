//
//  TimerActivity.swift
//  ScheduleDensityApp
//
//  잠금화면·다이나믹 아일랜드에 사는 타이머가 주고받는 것.
//
//  ⚠️ 이 파일은 **앱과 위젯 익스텐션 양쪽 타깃에 든다.** 잠금화면에 그리는 쪽(위젯)과
//     값을 보내는 쪽(앱)이 같은 타입을 알아야 하기 때문이다. 그래서 여기에는 모델도,
//     스토어도, 화면도 두지 않는다 — 오가는 값의 모양 하나뿐이다.
//
//  **1초마다 보내지 않는다.** 잠금화면의 숫자는 `endDate` 하나만 있으면 저 혼자 센다
//  (SwiftUI `Text(timerInterval:)`). 앱이 매 초 값을 밀어 넣으면 배터리만 먹고, 잠긴
//  화면에서는 어차피 그 속도로 갱신되지도 않는다. 그래서 **멈추고·다시 가고·시간을 더할 때**만
//  한 번씩 보낸다.
//

import Foundation
import SwiftUI
import ActivityKit

struct TaskTimerAttributes: ActivityAttributes {
    /// 세는 동안 바뀌는 것.
    struct ContentState: Codable, Hashable {
        /// 무엇을 세고 있나.
        var title: String
        /// 알약·고리에 쓰는 색(hex). 없으면 앱 기본색.
        var colorHex: String?
        var iconName: String

        /// 이대로 가면 끝나는 시각. 잠금화면은 이 값 하나로 스스로 센다.
        var endDate: Date
        /// 고리가 얼마나 찼는지를 재는 시작점.
        var startDate: Date

        /// 가고 있나. 멈춰 있으면 잠금화면도 숫자를 세우고 `pausedRemaining`을 보여준다.
        var isRunning: Bool
        /// 멈춘 순간의 남은 시간(초). 음수면 계획을 넘긴 것이다.
        var pausedRemaining: TimeInterval

        /// 계획을 넘겼나. 가는 중이면 끝 시각이 지났는지로, 멈춰 있으면 남은 시간으로 안다.
        func isOvertime(at now: Date = Date()) -> Bool {
            isRunning ? endDate < now : pausedRemaining < 0
        }

        /// 알약·고리·숫자의 색. **넘긴 것은 빨강** — 앱과 잠금화면이 같은 답을 쓴다.
        var tint: Color {
            if isOvertime() { return .red }
            return colorHex.flatMap { Color(hex: $0) } ?? .accentColor
        }
    }

    /// 무엇에 붙은 타이머인가 (→ `TaskTimer.TimerTarget.token`).
    /// 같은 일을 두 번 시작하려 할 때 이미 떠 있는 것을 알아보는 데 쓴다.
    var token: String
}

// MARK: - 표기

/// 남은 시간을 타이머 숫자로. 두 시간 미만은 분:초(1시간 → `60:00`),
/// 그 위는 시:분:초로 적는다 — `180:00`은 사람이 한눈에 읽지 못한다.
/// 계획을 넘겼으면 앞에 `+`를 달아 초과분을 센다.
///
/// ⚠️ **앱과 잠금화면이 같은 숫자를 적어야 한다.** 이 파일은 두 타깃에 함께 들어 있어서,
///    규칙을 여기 한 벌만 두면 위젯이 복사본을 들 이유가 없다.
///    (맥앱의 같은 이름 함수와도 규칙이 같다 → 무지개 공방 TaskTimer.swift)
func formatCountdown(_ seconds: Double) -> String {
    let over = seconds < 0
    let total = Int(abs(seconds).rounded())
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    let body = abs(seconds) < 7200
        ? String(format: "%d:%02d", total / 60, s)
        : String(format: "%d:%02d:%02d", h, m, s)
    return over ? "+" + body : body
}
