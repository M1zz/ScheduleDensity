//
//  TodoLabelChip.swift
//  ScheduleDensityApp
//
//  라벨(= 예상 시간) 하나를 그리는 칩. 앱과 공유 익스텐션이 함께 컴파일한다 —
//  공유 시트 위 작은 창에서도 목록과 똑같은 칩으로 시간을 고르게 하기 위해서다.
//  (그래서 SwiftData·TipKit에 기대지 않는다. import는 SwiftUI 하나뿐.)
//

import SwiftUI

extension TodoLabel {
    /// 속성의 색. iOS·맥이 같은 색을 쓰도록 하나씩 못 박아 둔다.
    /// '기다림'만 회색이다 — 내 시간을 쓰지 않는 유일한 속성이라 한눈에 갈라 보여야 한다.
    var tint: Color {
        switch self {
        case .ready:   return .green
        case .setup:   return .teal
        case .deep:    return .indigo
        case .decide:  return .orange
        case .waiting: return .gray
        }
    }
}

/// 목록·상세·입력창 어디서나 같은 모양으로 쓰는 라벨 칩.
///
/// 두 가지 크기로 쓴다.
/// - `.time` (목록의 줄): 아이콘 + 이름 + 시간.
/// - `.full` (가로로 늘어놓고 고르는 자리): 같되 조금 더 넉넉하게.
///
/// 속성이 '얼마나 걸리나'일 때는 줄에서 시간만 보여줬다. 지금은 속성이
/// '지금 시작할 수 있나'를 말하므로 이름이 곧 알맹이다 — 시간은 딸려 오는 값이라
/// 뒤에 붙인다. '기다림'은 내 시간을 안 쓰므로 시간 자리를 비운다.
/// - `.full` (가로로 늘어놓고 고르는 자리): 아이콘 + 이름 + 시간. 여기서 이름을
///   한 번 익히면 목록의 색·아이콘이 그대로 읽힌다. 줄 안에 끼워 넣으면
///   폭이 모자라 두 줄로 접히므로, 줄에서는 쓰지 않는다.
///
/// 이름을 뺀 자리는 접근성 라벨이 대신 읽어준다.
struct TodoLabelChip: View {
    enum Style { case time, full }

    let label: TodoLabel
    var hours: Double? = nil
    /// 이 조건에 해당하는 단계가 몇 개인지. 목록 위 '갈라 센 칩'에서만 쓴다.
    /// 개수와 시간을 한 칩에 같이 두는 이유는, 그 둘이 **이 조건 안에서만** 짝이 맞기
    /// 때문이다. 칩 밖으로 나가는 순간 다른 조건의 숫자와 더해질 자리가 생긴다.
    var count: Int? = nil
    var isSelected: Bool = false
    var style: Style = .time

    /// 시간이 따로 안 넘어오면 속성의 기본 시간을 쓴다.
    private var shownHours: Double { hours ?? label.defaultHours }
    /// '기다림'은 내 시간을 안 쓰므로 시간을 적지 않는다.
    private var showsHours: Bool { label.costsMyTime && shownHours > 0 }

    private var accessibilityText: String {
        var parts = [label.name]
        if let count { parts.append("\(count)개") }
        if showsHours { parts.append(formatDuration(shownHours)) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: label.symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(label.name)
                .font(.subheadline.weight(.semibold))
            if let count {
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            if showsHours {
                Text(formatDuration(shownHours))
                    .font(.subheadline)
                    .monospacedDigit()
                    .opacity(0.75)
            }
        }
        .lineLimit(1)
        // ⚠️ 칩은 어떤 자리에서도 쪼그라들지 않는다.
        //    줄 오른쪽 끝처럼 폭이 모자란 자리에 놓이면 SwiftUI가 글자를 세로로 접어 버린다
        //    ("1시간" → "1 / 시 / 간"). 칩은 제 폭을 그대로 요구하고,
        //    자리를 양보하는 건 옆의 제목이어야 한다.
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(isSelected ? Color.white : label.tint)
        .padding(.horizontal, style == .full ? 12 : 10)
        .padding(.vertical, style == .full ? 7 : 5)
        .background(Capsule().fill(isSelected ? label.tint : label.tint.opacity(0.14)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

