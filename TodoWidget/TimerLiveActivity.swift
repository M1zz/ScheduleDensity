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
            lockScreen(context.state, stale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            // 끝 시각(데드라인)을 지나면 시스템이 '묵었다'(isStale)며 다시 그린다 (→ TaskTimer: staleDate = 끝 시각).
            // 그때 '끝났습니다'로 넘어간다 — 앱이 주머니 속이어도. 앱이 다시 깨면 걷는다.
            let stale = context.isStale
            let tint = Self.tint(state, stale: stale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(state.title, systemImage: state.iconName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(state, stale: stale, size: 16)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    caption(state, stale: stale)
                }
            } compactLeading: {
                Image(systemName: state.isRunning ? state.iconName : "pause.fill")
                    .foregroundStyle(tint)
            } compactTrailing: {
                countdown(state, stale: stale, size: 13)
                    // '8:59:59'도 들어가는 폭. 좁으면 시간 단위 타이머가 '…'로 잘린다.
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: state.isRunning ? "timer" : "pause.fill")
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }

    // MARK: 잠금화면

    @ViewBuilder
    private func lockScreen(_ state: TaskTimerAttributes.ContentState, stale: Bool) -> some View {
        let tint = Self.tint(state, stale: stale)
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
                caption(state, stale: stale)
            }
            Spacer(minLength: 6)
            countdown(state, stale: stale, size: 26)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func caption(_ state: TaskTimerAttributes.ContentState, stale: Bool) -> some View {
        Group {
            if !state.isRunning {
                Text("멈춤")
            } else if !Self.isOver(state, stale: stale) {
                Text("\(Text(state.endDate, style: .time))에 끝남")
            } else {
                Text("끝났습니다")
            }
        }
        .font(.system(size: 12, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// 가고 있으면 잠금화면이 스스로 센다. 멈춰 있으면 그 순간의 숫자를 세워 둔다.
    @ViewBuilder
    private func countdown(_ state: TaskTimerAttributes.ContentState, stale: Bool, size: CGFloat) -> some View {
        let tint = Self.tint(state, stale: stale)
        Group {
            if state.isRunning {
                // ⚠️ 구간은 **시작 → 끝**이다. 예전에는 `끝...max(끝, 지금+1초)`를 넘겨서, 끝이 아직 멀면
                //    폭이 0인 구간이 되어 숫자가 0:00에 선 채 움직이지 않았다.
                // 데드라인을 지나면 0에 선다. 넘긴 시간은 세지 않는다 — 끝은 일정이 정한 것이다.
                if Self.isOver(state, stale: stale) {
                    Text(verbatim: formatCountdown(0, style: Self.style(state)))
                } else {
                    // ⚠️ 아래 끝은 **지금보다 앞**이어야 한다. 아직 안 온 일정을 고르면 startDate가 미래라,
                    //    그 구간을 그대로 넘기면 시작 전까지 숫자가 일정 길이에 선 채 움직이지 않았다.
                    //    끝 시각(데드라인)까지 세는 타이머이므로 지금부터 줄어야 한다.
                    let lower = min(state.startDate, Date())
                    Text(timerInterval: lower...max(state.endDate, lower.addingTimeInterval(1)),
                         countsDown: true,
                         showsHours: state.showsHours ?? true)
                }
            } else {
                Text(verbatim: formatCountdown(state.pausedRemaining, style: Self.style(state)))
            }
        }
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .foregroundStyle(tint)
    }

    private static func style(_ state: TaskTimerAttributes.ContentState) -> CountdownStyle {
        (state.showsHours ?? true) ? .hours : .minutes
    }

    /// 계획을 넘겼나. 가는 중이면 시스템이 '묵었다'고 알려 준 것까지 본다.
    private static func isOver(_ state: TaskTimerAttributes.ContentState, stale: Bool) -> Bool {
        (state.isRunning && stale) || state.isOvertime()
    }

    private static func tint(_ state: TaskTimerAttributes.ContentState, stale: Bool) -> Color {
        isOver(state, stale: stale) ? .secondary : state.tint
    }
}
