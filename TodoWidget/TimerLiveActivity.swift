//
//  TimerLiveActivity.swift
//  TodoWidget
//
//  잠금화면과 다이나믹 아일랜드에 사는 타이머.
//
//  **여기서는 시간을 세지 않는다.** 앱이 건네는 것은 끝나는 시각 하나이고(→ TimerActivity.swift),
//  숫자는 `Text(timerInterval:)`이 저 혼자 센다. 잠긴 화면은 앱이 밀어 넣는 속도로 다시 그려지지
//  않으므로, 1초마다 값을 보내면 배터리만 먹고 숫자는 여전히 띄엄띄엄 뛴다.
//
//  멈춰 있을 때만 숫자를 세운다 — 안 가는 타이머가 계속 줄어드는 것처럼 보이면 안 된다.
//

import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.2, *)
struct TaskTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskTimerAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let tint = Self.tint(state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(state.title, systemImage: state.iconName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(state, size: 16)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    caption(state)
                }
            } compactLeading: {
                Image(systemName: state.isRunning ? state.iconName : "pause.fill")
                    .foregroundStyle(tint)
            } compactTrailing: {
                countdown(state, size: 13)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: state.isRunning ? "timer" : "pause.fill")
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }

    // MARK: 잠금화면

    @ViewBuilder
    private func lockScreen(_ state: TaskTimerAttributes.ContentState) -> some View {
        let tint = Self.tint(state)
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.18))
                Image(systemName: state.isRunning ? state.iconName : "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                caption(state)
            }
            Spacer(minLength: 6)
            countdown(state, size: 26)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func caption(_ state: TaskTimerAttributes.ContentState) -> some View {
        Group {
            if !state.isRunning {
                Text("멈춤")
            } else if state.endDate > Date() {
                Text("\(Text(state.endDate, style: .time))에 끝남")
            } else {
                Text("계획을 넘겼습니다")
            }
        }
        .font(.system(size: 12, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// 가고 있으면 잠금화면이 스스로 센다. 멈춰 있으면 그 순간의 숫자를 세워 둔다.
    @ViewBuilder
    private func countdown(_ state: TaskTimerAttributes.ContentState, size: CGFloat) -> some View {
        let tint = Self.tint(state)
        Group {
            if state.isRunning {
                Text(timerInterval: state.endDate...max(state.endDate, Date().addingTimeInterval(1)),
                     countsDown: true)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(verbatim: Self.paused(state.pausedRemaining))
            }
        }
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(tint)
    }

    private static func tint(_ state: TaskTimerAttributes.ContentState) -> Color {
        // 계획을 넘겼으면 빨강. 가는 중에는 끝 시각이 지났는지로 안다.
        let over = state.isRunning ? state.endDate < Date() : state.isOvertime
        if over { return .red }
        return state.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
    }

    /// 멈춰 있을 때 세워 둘 숫자. 앱의 `formatCountdown`과 같은 규칙이다.
    private static func paused(_ seconds: TimeInterval) -> String {
        let over = seconds < 0
        let total = Int(abs(seconds).rounded())
        let body = abs(seconds) < 7200
            ? String(format: "%d:%02d", total / 60, total % 60)
            : String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        return over ? "+" + body : body
    }
}
