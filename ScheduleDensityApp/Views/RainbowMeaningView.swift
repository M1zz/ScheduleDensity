//
//  RainbowMeaningView.swift
//  ScheduleDensityApp
//
//  무지개 한 줄이 무슨 뜻인지 알려주는 마무리 화면 (→ MeaningPage.swift).
//  방금 만든 줄을 여기서 다시 그려, "아까 그거"와 설명이 이어지게 한다.
//

import SwiftUI

struct RainbowMeaningView: View {
    /// 방금 만든 일정. 없으면(적다가 취소했으면) 보기용 예시로 그린다.
    let event: Event?
    /// 그 줄에 배정된 색.
    let accent: Color
    var onDone: () -> Void

    var body: some View {
        MeaningPage(
            eyebrow: event == nil ? "무지개 읽는 법" : "방금 그은 한 줄",
            title: "이 한 줄이\n말하고 있는 것",
            accent: accent,
            paragraphs: paragraphs,
            footnote: "칸을 탭하면 내용을 보고, 꾹 누르면 고치거나 지울 수 있어요.",
            diagram: { diagram },
            onDone: onDone
        )
    }

    // MARK: - 그림

    /// 방금 만든 줄을 그대로 다시 그린다. 날짜와 진하기가 실제 화면과 같아야
    /// "아, 아까 그거" 하고 이어진다.
    private var diagram: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 4) {
                ForEach(days, id: \.date) { day in
                    Text(dayLabel(day.date))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(height: 30, alignment: .center)
                }
            }

            VStack(spacing: 4) {
                ForEach(days, id: \.date) { day in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent.opacity(day.isWorkDay ? 1 : 0.2))
                        .frame(width: 52, height: 30)
                }
            }

            HStack(spacing: 8) {
                VerticalBrace()
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 8, height: CGFloat(days.count) * 34 - 4)
                Text("매여 있는\n기간")
                    .font(.system(size: 13))
                    .tracking(-0.2)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
    }

    private struct DayCell {
        let date: Date
        /// 실제로 시간을 쓰는 날인지 (진한 칸).
        let isWorkDay: Bool
    }

    /// 그림에 세울 날들. 길면 앞쪽 여섯 날만 — 뜻을 보이는 데는 그걸로 충분하다.
    private var days: [DayCell] {
        let calendar = Calendar.current
        guard let event else {
            // 취소해서 보여줄 줄이 없을 때의 예시. 첫날과 마지막 날에 손을 대는 모양.
            let today = calendar.startOfDay(for: Date())
            return (0..<4).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
                return DayCell(date: date, isWorkDay: offset == 0 || offset == 3)
            }
        }

        var result: [DayCell] = []
        var current = calendar.startOfDay(for: event.startDate)
        let last = calendar.startOfDay(for: event.effectiveEndDate())
        while current <= last, result.count < 6 {
            result.append(DayCell(date: current, isWorkDay: event.occursOn(date: current)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    // MARK: - 본문

    private var paragraphs: [MeaningParagraph] {
        [
            MeaningParagraph(
                icon: "arrow.up.and.down",
                heading: "세로로 이어진 길이",
                body: "이 일에 매여 있는 기간입니다. 손을 대지 않는 날도 아직 끝나지 않았다면 여전히 나를 붙잡고 있어요. 그 무게가 보이라고 끝까지 이어 칠합니다."
            ),
            MeaningParagraph(
                icon: "square.fill.on.square.fill",
                heading: "진한 칸과 옅은 칸",
                body: "진한 칸은 실제로 시간을 쓰는 날, 옅은 칸은 매여만 있는 날입니다. 스터디가 화요일에만 모여도 끝나는 날까지 계속 옅게 이어지는 이유예요."
            ),
            MeaningParagraph(
                icon: "arrow.left.and.right",
                heading: "가로로 늘어선 칸 수",
                body: "그날 한꺼번에 굴리고 있는 일의 개수입니다. 일곱 칸이 다 차 가면 하나만 어긋나도 그 날 전체가 밀려요."
            )
        ]
    }
}
