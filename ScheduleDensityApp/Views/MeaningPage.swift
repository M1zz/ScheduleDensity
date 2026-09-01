//
//  MeaningPage.swift
//  ScheduleDensityApp
//
//  "이게 무슨 뜻이냐면" 한 장 — 무지개와 할 일 쪼개기가 함께 쓰는 마무리 화면.
//
//  이런 설명은 손을 쓰는 경험이 **끝난 뒤에** 온다. 도중에 끼면 손이 멈추고,
//  화면 위에 카드로 띄우면 뒤의 내용이 계속 눈을 잡아당겨 세 문단이 읽히지 않는다.
//  그래서 전체 화면으로 받고, 자간·행간·문단 사이를 넉넉히 벌려 읽는 데만 집중하게 한다.
//

import SwiftUI

/// 문단 하나 — 아이콘, 소제목, 본문.
struct MeaningParagraph: Identifiable {
    let icon: String
    let heading: String
    let body: String

    var id: String { heading }
}

/// 마무리 설명 한 장의 틀.
/// 가운데 그림만 화면마다 다르고, 글자 다루는 방식은 어디서나 같아야 한다.
struct MeaningPage<Diagram: View>: View {
    /// 제목 위 작은 머리말.
    let eyebrow: String
    /// 큰 제목. 줄바꿈은 직접 넣는다 — 어디서 끊기는지가 읽는 속도를 정한다.
    let title: String
    let accent: Color
    let paragraphs: [MeaningParagraph]
    /// 버튼 위 한 줄 덧붙임. 없으면 비운다.
    var footnote: String? = nil
    var buttonTitle: String = "알겠어요"
    /// 아래 버튼을 다는지. 밀어 넣은 화면(뒤로 가기가 이미 있는 자리)에서는 뺀다 —
    /// 같은 일을 하는 문이 두 개면 어느 쪽이 진짜인지 매번 고르게 된다.
    var showsDoneButton: Bool = true
    @ViewBuilder var diagram: () -> Diagram
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(eyebrow)
                        .font(.footnote.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(accent)
                        .padding(.bottom, 10)

                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.9)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 36)

                    diagram()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 40)

                    ForEach(Array(paragraphs.enumerated()), id: \.element.id) { index, item in
                        paragraph(item)
                            .padding(.bottom, index == paragraphs.count - 1 ? 0 : 30)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 44)
                .padding(.bottom, 32)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            footer
        }
        .background(Color(.systemBackground))
    }

    private func paragraph(_ item: MeaningParagraph) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 20)
                Text(item.heading)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.4)
            }

            Text(item.body)
                .font(.system(size: 16))
                .tracking(-0.25)
                .lineSpacing(8)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                // 소제목의 글자 시작선에 본문을 맞춘다. 아이콘 아래로 흘러내리면 단이 두 개로 보인다.
                .padding(.leading, 29)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let footnote {
                Text(footnote)
                    .font(.system(size: 13))
                    .tracking(-0.2)
                    .lineSpacing(4)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsDoneButton {
                Button(action: onDone) {
                    Text(buttonTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(accent)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, showsDoneButton ? 12 : 20)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// 여러 칸이 '한 덩어리'임을 말하는 세로 중괄호.
struct VerticalBrace: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.maxX
        let mid = rect.midY
        let inset = rect.minX

        path.move(to: CGPoint(x: inset, y: rect.minY))
        path.addLine(to: CGPoint(x: x, y: rect.minY + 6))
        path.addLine(to: CGPoint(x: x, y: mid - 6))
        path.addLine(to: CGPoint(x: inset, y: mid))
        path.addLine(to: CGPoint(x: x, y: mid + 6))
        path.addLine(to: CGPoint(x: x, y: rect.maxY - 6))
        path.addLine(to: CGPoint(x: inset, y: rect.maxY))
        return path
    }
}
