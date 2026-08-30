//
//  FragmentMark.swift
//
//  "이걸 5분에 집어도 되나"를 화면에서 말하는 조각들.
//
//  이름표를 다시 만드는 게 아니다. 예전 '착수 조건' 칩은 모든 줄에 붙어서
//  서로를 가렸고, '바로 15분'이라는 말이 무슨 뜻인지도 안 통했다. 여기서는
//  - **조각에만** 색이 붙는다 (나머지는 회색 한 줄 이유만),
//  - 판정의 근거는 묻는 문장 그대로 보여준다 (→ FragmentQuestionRows).
//

import SwiftUI

/// 단계 한 줄에 붙는 표식. 조각일 때만 눈에 띈다.
struct FragmentMark: View {
    let advice: StepAdvice
    /// 목록(할 일 줄)에서는 이유까지 붙이면 두 줄이 된다.
    var showsReason: Bool = true

    var body: some View {
        if advice.isFragment {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("5분에 집기")
                    .font(.caption2.weight(.semibold))
                if userSet {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(Color.teal)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.teal.opacity(0.15)))
            .accessibilityLabel("조각. 5분이 나면 집을 수 있는 단계")
        } else if showsReason, let reason = advice.reason {
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityLabel("\(advice.kind.label). \(reason)")
        }
    }

    private var userSet: Bool {
        advice.start.isUserSet || advice.closing.isUserSet
    }
}

/// 두 질문을 그대로 묻고, 앱이 적어 둔 답을 보여준다. 사용자는 틀린 것만 뒤집는다.
///
/// 묻기는 하지만 **적을 때는 안 묻는다.** 이 줄들이 사는 곳은 단계를 들여다보러
/// 들어온 시트 안이고, 답은 이미 채워져 있다. 고르지 않고 나가도 아무 일이 없다.
struct FragmentQuestionRows: View {
    let title: String
    let hours: Double
    @Binding var pick: FragmentPick

    private var advice: StepAdvice {
        TodoSplitAdvisor.advice(title: title, durationHours: hours, pick: pick)
    }

    var body: some View {
        ForEach(FragmentQuestion.allCases) { question in
            row(question)
        }

        if pick.isSet {
            Button("앱 판정으로 되돌리기") { pick = .none }
                .font(.footnote)
        }
    }

    private func row(_ question: FragmentQuestion) -> some View {
        let answer = advice.answer(to: question)
        return VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
                .font(.subheadline.weight(.semibold))

            Picker(question.text, selection: binding(for: question)) {
                Text("예").tag(true)
                Text("아니오").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: answer.isUserSet ? "hand.point.up.left.fill" : "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
                Text(answer.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(question.why)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    /// 고른 값이 앱 판정과 같으면 답을 저장하지 않는다 — 같은 답을 굳이 사용자 것으로
    /// 굳혀 두면, 나중에 시간을 고쳐도 판정이 안 따라와서 화면이 거짓말을 하게 된다.
    private func binding(for question: FragmentQuestion) -> Binding<Bool> {
        Binding(
            get: { advice.answer(to: question).isYes },
            set: { value in
                let appAnswer = TodoSplitAdvisor.advice(title: title,
                                                        durationHours: hours,
                                                        pick: .none)
                    .answer(to: question).isYes
                pick.set(value == appAnswer ? nil : value, for: question)
            }
        )
    }
}

/// 단계 수만큼 자른 도넛. 지나온 칸이 차 있다.
///
/// 목록에서 '몇 번째인가'를 말하는 유일한 자리다. 글자로 적어봤지만(예: `3/4`)
/// 그 크기의 숫자는 지나가면서 안 읽혔다. 칸이 차 있는 그림은 읽는 게 아니라 보인다.
struct StepDonut: View {
    /// 끝낸 단계 수.
    let done: Int
    /// 전체 단계 수.
    let total: Int

    /// 이보다 잘게 자르면 칸이 아니라 점선으로 보인다. 그때는 그냥 한 줄로 채운다.
    private static let maxSlices = 12

    var body: some View {
        ZStack {
            if total > Self.maxSlices {
                Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.02, Double(done) / Double(max(total, 1))))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    slice(index)
                }
            }
        }
        // 12시부터 시계 방향으로 차오른다.
        .rotationEffect(.degrees(-90))
        .padding(1.5)
    }

    private func slice(_ index: Int) -> some View {
        let span = 1.0 / Double(max(total, 1))
        // 칸 사이를 조금 띄워야 '몇 칸'인지가 세어진다.
        let gap = min(0.02, span * 0.18)
        let isDone = index < done
        let isCurrent = index == done
        return Circle()
            .trim(from: Double(index) * span + gap / 2,
                  to: Double(index + 1) * span - gap / 2)
            .stroke(isDone ? Color.accentColor
                    : (isCurrent ? Color.orange : Color.secondary.opacity(0.28)),
                    style: StrokeStyle(lineWidth: isCurrent ? 3.5 : 3, lineCap: .butt))
    }
}
