import SwiftUI

// MARK: - 무지개 공방 디자인 토큰
//
// iOS 앱 '욕망의 무지개'(ScheduleDensity)와 컬러를 통일하기 위한 토큰.
// 팔레트는 iOS `ScheduleViewModel.laneColors`(Apple 시스템 색)와 1:1로 맞춘다.

extension Color {
    /// "#RRGGBB" / "#AARRGGBB" / "#RGB" hex 문자열에서 Color 생성. (iOS와 동일 구현)
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: return nil
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

/// iOS `laneColors`와 동일한 7색 무지개 팔레트 (Apple 시스템 색).
enum Rainbow {
    static let red    = "#FF3B30"   // systemRed
    static let orange = "#FF9500"   // systemOrange
    static let yellow = "#FFCC00"   // systemYellow
    static let green  = "#34C759"   // systemGreen
    static let blue   = "#007AFF"   // systemBlue (= 앱 액센트)
    static let indigo = "#5856D6"   // systemIndigo
    static let purple = "#AF52DE"   // systemPurple

    /// 스펙트럼 순서 (이름, hex). 컬러 피커가 이 순서로 무지개를 보여준다.
    static let spectrum: [(name: String, hex: String)] = [
        ("red", red), ("orange", orange), ("yellow", yellow),
        ("green", green), ("blue", blue), ("indigo", indigo), ("purple", purple),
    ]
}

/// 밀도 색 스케일 — iOS `densityColor(for:)`와 동일 (0 회색 → 초록 → 파랑 → 주황 → 빨강).
/// macOS에서 향후 밀도 시각화를 붙일 때 iOS와 같은 의미 체계를 쓰기 위한 헬퍼.
func densityColor(_ level: Int) -> Color {
    switch level {
    case ..<1:  return Color(hex: "#8E8E93") ?? .gray   // systemGray
    case 1:     return Color(hex: Rainbow.green) ?? .green
    case 2:     return Color(hex: Rainbow.blue) ?? .blue
    case 3:     return Color(hex: Rainbow.orange) ?? .orange
    default:    return Color(hex: Rainbow.red) ?? .red
    }
}
