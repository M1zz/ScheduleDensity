//
//  TodoSplitOnboarding.swift
//  ScheduleDensityApp
//
//  할 일 하나를 단계로 쪼개는 법을 처음 한 번만 짚어주는 안내.
//
//  쪼개기는 이 앱에서 제일 배우기 어려운 동작이다. 빈 화면에 "단계를 적으세요"라고만
//  두면 사람들은 비중(%)이나 순서를 고민하다 아무것도 못 적는다. 실제로 고를 것은
//  '지금 시작할 수 있나' 하나뿐이라는 걸, 직접 한 줄 적어 보면서 알게 한다.
//

import SwiftUI

// MARK: - 안내 단계

enum SplitGuideStep: Int, CaseIterable {
    /// 첫 안내 카드.
    case intro
    /// 빈 줄에 첫 단계를 적는다.
    case writeStep
    /// 언제부터 언제까지인지 정한다 — 그게 무지개에 한 줄로 그어진다.
    case period
    /// '지금 할 단계'가 어디에 서는지.
    case header

    var next: SplitGuideStep? { SplitGuideStep(rawValue: rawValue + 1) }

    /// 카드에 붙는 순서 표시. 첫 안내는 세지 않는다.
    var order: (index: Int, total: Int)? {
        guard self != .intro else { return nil }
        return (rawValue, SplitGuideStep.allCases.count - 1)
    }

    var icon: String {
        switch self {
        case .intro:     return "arrow.triangle.branch"
        case .writeStep: return "text.line.first.and.arrowtriangle.forward"
        case .period:    return "rainbow"
        case .header:    return "chart.bar.fill"
        }
    }

    var title: String {
        switch self {
        case .intro:     return "덩어리를 쪼개 볼까요"
        case .writeStep: return "첫 단계를 한 줄"
        case .period:    return "언제부터 언제까지"
        case .header:    return "지금 할 단계가 맨 위에"
        }
    }

    var message: String {
        switch self {
        case .intro:
            return "‘보고서 쓰기’ 같은 덩어리는 손이 안 나갑니다. 어디서 시작할지가 안 정해져 있어서예요.\n일이 굴러가는 순서대로 몇 줄 쪼개 두면, 짬이 났을 때 집을 게 생깁니다."
        case .writeStep:
            return "하얗게 표시된 빈 줄에 첫 단계를 적고 엔터를 쳐 보세요. 엔터를 치면 그 줄이 확정되고 빈 줄이 다시 옵니다.\n막막하면 아래 ‘쪼개기 도우미’에 일이 굴러가는 순서가 있어요. 보고 내 말로 옮겨 적으면 됩니다."
        case .period:
            return "맨 위 카드를 눌러 이 일이 언제부터 언제까지인지 정해 주세요.\n정하면 그 기간이 무지개에 한 줄로 그어집니다 — 끝나는 날까지 계속 나를 붙잡고 있는 시간이니까요."
        case .header:
            return "맨 위에는 지금 할 단계 하나만 섭니다. 그게 지금 손대야 하는 일이에요.\n나머지는 아래 목록에서 순서대로 기다립니다."
        }
    }
}

// MARK: - 마무리 화면

/// 왜 쪼개야 하는지 — 손을 다 쓰고 난 뒤에 전체 화면으로 받는다 (→ MeaningPage.swift).
struct SplitMeaningView: View {
    var onDone: () -> Void

    var body: some View {
        MeaningPage(
            eyebrow: "방금 쪼갠 일",
            title: "왜 이렇게까지\n쪼개나면",
            accent: .accentColor,
            paragraphs: paragraphs,
            footnote: "단계는 언제든 다시 적고, 순서도 바꿀 수 있어요.",
            diagram: { diagram },
            onDone: onDone
        )
    }

    private var diagram: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 48)
                .overlay(
                    Text("보고서 쓰기")
                        .font(.system(size: 15, weight: .medium))
                        .tracking(-0.3)
                        .foregroundStyle(.secondary)
                )

            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                ForEach(Array(sampleSteps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 10) {
                        Text(step)
                            .font(.system(size: 15))
                            .tracking(-0.3)
                        Spacer(minLength: 8)
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .frame(maxWidth: 320)
    }

    private var sampleSteps: [String] {
        ["무엇을 쓸지 정하기", "자료 모아 펼치기", "초안 쓰기", "오탈자 훑기"]
    }


    private var paragraphs: [MeaningParagraph] {
        [
            MeaningParagraph(
                icon: "square.split.2x2",
                heading: "5분 열두 번은 한 시간이 아니다",
                body: "조각 시간은 총량으로 환산되지 않습니다. 그래서 ‘짬이 나면 바로 집을 수 있는 단계’가 따로 있어야 해요. 그게 없으면 하루에 생긴 조각은 전부 흘러갑니다."
            ),
            MeaningParagraph(
                icon: "rainbow",
                heading: "기간은 무지개에 남는다",
                body: "언제부터 언제까지인지 정해 두면 그 기간이 무지개에 한 줄로 그어집니다. 오늘 손을 안 대는 날도, 끝나지 않았다면 여전히 나를 붙잡고 있으니까요."
            ),
            MeaningParagraph(
                icon: "checkmark.circle",
                heading: "단계는 ‘닫히는’ 크기로",
                body: "끝내지 못하고 넘어간 일은 다음 시간까지 따라와 흐립니다. 한 자리에서 닫히는 크기로 잘라 두면, 넘어갈 때 머리에 남는 게 없어요."
            )
        ]
    }
}
