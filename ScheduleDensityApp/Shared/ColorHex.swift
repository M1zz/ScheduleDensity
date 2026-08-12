import SwiftUI

// 앱 타깃과 위젯 익스텐션이 함께 컴파일하는 파일.
// 위젯은 스냅샷에 담긴 hex 문자열만 받으므로 팔레트 전체(Theme.swift)가 아니라
// 이 변환기만 있으면 된다.

extension Color {
    /// "#RRGGBB" / "#AARRGGBB" / "#RGB" hex 문자열에서 Color 생성.
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
