//
//  AccessibilitySupport.swift
//  ScheduleDensityApp
//
//  화면 여러 곳이 같은 방식으로 따라야 하는 접근성 설정을 한자리에 둔다.
//  자리마다 따로 쓰면 어떤 화면은 투명도를 줄이고 어떤 화면은 그대로인 채로 남는다.
//

import SwiftUI

// MARK: - 바뀐 내용 알려 주기

enum A11yAnnounce {
    /// 화면 밖에서 끝난 일을 VoiceOver 로 읽어 준다 (지웠다 · 끝냈다 · 타이머가 끝났다).
    ///
    /// ⚠️ 목록이 다시 그려지는 순간에 바로 말하면 VoiceOver 가 새 초점을 읽느라 이 말을 삼킨다.
    ///    한 박자 늦춰 말한다.
    @MainActor
    static func post(_ message: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

// MARK: - 투명도 줄이기

/// 바·떠 있는 카드의 반투명 배경. '투명도 줄이기'를 켠 사람에게는 불투명한 배경을 준다 —
/// 뒤로 비치는 무지개 색 위에서 글자가 흐려지는 것이 바로 그 설정을 켠 이유다.
struct AdaptiveMaterialBackground<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let material: Material
    /// 불투명할 때 쓸 색. 바는 배경색, 떠 있는 카드는 한 단 밝은 색이 맞다.
    let opaque: Color
    /// 배경 모양에만 거는 그림자(글자에는 안 번지게). 0 이면 없다.
    var shadowRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content.background {
            Group {
                if reduceTransparency {
                    shape.fill(opaque)
                } else {
                    shape.fill(material)
                }
            }
            .shadow(color: .black.opacity(shadowRadius > 0 ? 0.15 : 0), radius: shadowRadius, y: shadowRadius * 0.4)
        }
    }
}

extension View {
    /// `.background(.bar)` 대신. 투명도 줄이기를 켜면 불투명한 배경이 선다.
    func adaptiveBarBackground() -> some View {
        modifier(AdaptiveMaterialBackground(shape: Rectangle(), material: .bar,
                                            opaque: Color(.systemBackground)))
    }

    /// 떠 있는 카드의 `.regularMaterial` 대신.
    func adaptiveCardBackground(cornerRadius: CGFloat, shadowRadius: CGFloat = 0) -> some View {
        modifier(AdaptiveMaterialBackground(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            material: .regularMaterial,
            opaque: Color(.secondarySystemBackground),
            shadowRadius: shadowRadius))
    }
}
