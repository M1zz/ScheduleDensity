//
//  BoltOnboarding.swift
//  ScheduleDensityApp
//
//  번개(⚡︎)가 무슨 뜻이고 어떻게 붙이는지를 **목록 안에서** 알려 준다.
//
//  스와이프에서 글자를 뺐다. 손짓 하나에 뜻 하나만 두면 목록은 가벼워지지만,
//  그 아이콘이 무슨 뜻인지 말해 줄 자리가 없어진다. 그렇다고 화면을 어둡게 덮고
//  카드를 띄우면 — 배우기 전에 먼저 **치워야 할 것**이 하나 생긴다. 손짓 하나
//  가르치자고 화면을 멈춰 세우는 건 값이 안 맞는다.
//
//  그래서 안내는 목록의 **줄 하나**로 산다 (→ BoltHintRow):
//    - 덮지 않는다. 뒤의 할 일이 계속 보이고, 그동안 아무거나 할 수 있다.
//    - 손짓을 말로 적지 않고 **작게 재연한다.** 미는 그림을 보면 밀어 보게 된다.
//    - '다음' 버튼이 없다. 실제로 한 줄에 번개를 붙이면 그때 스스로 물러난다.
//
//  왜 그런 표시가 있는지(뜻)는 눌러서 들어가는 한 장으로 (→ BoltMeaningView).
//  잊었을 때 다시 펴 볼 자리는 설정에 둔다 (→ SettingsView).
//

import SwiftUI

// MARK: - 목록 안 안내 줄

/// 할 일 목록 맨 위에 한 번 서는 줄. 번개 붙이는 손짓을 작게 재연한다.
///
/// 스스로 물러나는 조건은 **한 줄이라도 붙였을 때**다 (→ TodoView.markedNowCount).
/// 읽었는지가 아니라 해봤는지로 끝난다.
struct BoltHintRow: View {
    /// '자세히'를 눌렀을 때. 뜻풀이 한 장은 부르는 쪽이 밀어 넣는다.
    var onDetail: () -> Void
    /// 닫기를 눌렀을 때. 안 해보고 지나가는 길도 있어야 한다.
    var onDismiss: () -> Void

    /// 재연 중인 손짓의 진행. 줄이 밀려 있는 상태인지.
    @State private var slid = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 밀려 나가는 거리. 번개 칸이 딱 드러날 만큼만.
    private static let travel: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            demo
            Text("‘지금 바로 되는 일’에 붙이는 표시예요. 붙인 줄은 차례를 안 기다리고 이 위에 모입니다.")
                .font(.system(size: 12.5))
                .tracking(-0.2)
                .lineSpacing(3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .onAppear(perform: startDemo)
    }

    // MARK: 머리줄 — 무엇을 하라는 말인지 한 줄, 그리고 나가는 두 문

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TodoView.nowGreen)

            Text("오른쪽으로 밀면 번개")
                .font(.system(size: 14.5, weight: .semibold))
                .tracking(-0.3)

            Spacer(minLength: 8)

            // 자세한 뜻은 눌러서 들어간다. 여기서 세 문단을 펴면 목록이 읽을 거리가 된다.
            Button(action: onDetail) {
                Text("자세히")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(TodoView.nowGreen)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("안내 닫기")
        }
    }

    // MARK: 재연 — 줄 하나가 천천히 밀리고, 왼쪽에서 번개가 나온다

    private var demo: some View {
        ZStack(alignment: .leading) {
            // 밀린 자리에서 드러나는 초록 번개.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(TodoView.nowGreen)
                .frame(width: Self.travel - 6, height: 30)
                .overlay(
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .opacity(slid ? 1 : 0)

            // 밀리는 줄. 미는 손가락은 줄에 얹혀 같이 움직인다 —
            // 따로 놀면 '줄이 저절로 간다'로 읽힌다.
            Text("우유 사 오기")
                .font(.system(size: 12.5))
                .tracking(-0.2)
                .foregroundStyle(.secondary)
                // 손가락이 앉을 자리를 왼쪽에 비워 둔다. 글자 위에 얹히면 둘 다 안 읽힌다.
                .padding(.leading, 30)
                .padding(.trailing, 10)
                .frame(height: 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(alignment: .leading) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.5))
                        .offset(x: 8, y: 10)
                }
                .offset(x: slid ? Self.travel : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("할 일 줄을 오른쪽으로 밀면 번개 버튼이 나옵니다")
    }

    /// 한 번 보고 마는 그림이 아니라, 눈이 돌아왔을 때 다시 보여야 한다.
    /// 다만 **느리게** — 목록 위에서 빠르게 깜빡이는 것은 광고처럼 읽힌다.
    private func startDemo() {
        guard !reduceMotion else {
            slid = true
            return
        }
        withAnimation(.easeInOut(duration: 1.2).delay(0.6).repeatForever(autoreverses: true)) {
            slid = true
        }
    }
}

// MARK: - 뜻풀이 한 장

/// 번개가 무슨 뜻이고 어떻게 쓰는지 — 안내 줄의 '자세히'에서, 그리고 설정에서
/// (→ MeaningPage.swift). 덮어 씌우는 대신 **밀어 넣는다.**
struct BoltMeaningView: View {
    var eyebrow: String = "할 일 목록의 번개"
    var buttonTitle: String = "알겠어요"
    /// 밀어 넣은 화면에서는 뒤로 가기가 이미 있으므로 아래 버튼을 뺀다.
    var showsDoneButton: Bool = true
    var onDone: () -> Void

    var body: some View {
        MeaningPage(
            eyebrow: eyebrow,
            title: "번개는\n‘지금 바로’ 라는 뜻",
            accent: TodoView.nowGreen,
            paragraphs: paragraphs,
            footnote: "번개를 붙인다고 마감이나 걸린 시간이 바뀌지는 않아요. 어디에 서는지만 달라집니다.",
            buttonTitle: buttonTitle,
            showsDoneButton: showsDoneButton,
            diagram: { diagram },
            onDone: onDone
        )
        .navigationTitle("번개")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 그림 — 미는 손짓과 그 결과를 한 눈에

    private var diagram: some View {
        VStack(spacing: 14) {
            // 오른쪽으로 밀린 줄. 왼쪽에서 초록 번개가 나온다.
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(TodoView.nowGreen)
                    .frame(width: 46, height: 44)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                HStack(spacing: 8) {
                    Text("우유 사 오기")
                        .font(.system(size: 15))
                        .tracking(-0.3)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.leading, 6)
            }

            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)

            // 붙인 줄이 올라가 서는 자리.
            VStack(spacing: 6) {
                laneRow("우유 사 오기", marked: true)
                laneRow("자료 모아 펼치기", marked: true)
                laneRow("보고서 초안 쓰기", marked: false)
            }
        }
        .frame(maxWidth: 320)
    }

    private func laneRow(_ title: String, marked: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: marked ? "bolt.fill" : "circle")
                .font(.system(size: marked ? 12 : 13, weight: .semibold))
                .foregroundStyle(marked ? TodoView.nowGreen : Color.secondary.opacity(0.5))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 15))
                .tracking(-0.3)
                .foregroundStyle(marked ? .primary : .secondary)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(marked ? TodoView.markedTint : Color(.secondarySystemBackground))
        )
    }

    // MARK: 글

    private var paragraphs: [MeaningParagraph] {
        [
            MeaningParagraph(
                icon: "bolt.fill",
                heading: "앱의 짐작이 아니라 내가 하는 말",
                body: "번개는 ‘이건 준비 없이 바로 된다’고 내가 직접 붙이는 표시입니다. 5분 열두 번은 한 시간이 아니라서, 짬에 집을 수 있는 일은 따로 표시해 두어야 흘러가지 않아요."
            ),
            MeaningParagraph(
                icon: "hand.draw",
                heading: "붙이고 거두는 건 오른쪽으로 밀기",
                body: "할 일 줄을 오른쪽으로 밀면 번개가 나옵니다. 붙인 줄을 다시 밀면 회색 번개가 나오고, 누르면 거둬집니다. 단계로 쪼갠 일이면 지금 할 단계에 붙어요."
            ),
            MeaningParagraph(
                icon: "arrow.up.to.line",
                heading: "표시한 줄은 맨 위로",
                body: "번개를 붙인 줄은 차례와 상관없이 목록 맨 위 연두 칸에 섭니다. 짬이 났을 때 목록을 훑지 않고 맨 위만 봐도 되도록요."
            )
        ]
    }
}
