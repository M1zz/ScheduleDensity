//
//  ArabicLocale.swift
//
//  **아랍어 화면의 숫자와 달력.**
//
//  기기 지역을 그대로 따르면 아랍어 화면에서 숫자가 ١٢٣ 과 123 으로 섞인다 —
//  날짜 · 개수는 지역 설정을 따라 ١٢٣ 으로, 번역문에 적힌 '5분' 같은 숫자는 123 으로 나온다.
//  사우디 지역이면 날짜가 히즈라력으로 바뀌어, 월요일부터 세는 주 격자와도 어긋난다.
//
//  그래서 앱이 아랍어로 뜰 때만, 이 프로세스의 지역 설정을 **0~9 숫자 · 양력**으로 바꾼다.
//  지역(나라)은 기기 것을 그대로 둔다. 다른 언어는 손대지 않는다(태국어 사용자는 불기력을 기대한다).
//
//  ⚠️ `Locale.current` 를 처음 읽기 **전에** 불러야 한다 — 그래서 앱 · 위젯의 `main` 첫 줄에서 부른다.
//     값은 휘발성 인자 영역에만 적으므로 기기에도, 앱 설정에도 남지 않는다.
//

import Foundation

enum ArabicLocale {
    /// 이 프로세스의 화면 말이 아랍어인가.
    static var isActive: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("ar") ?? false
    }

    static func applyIfNeeded() {
        guard isActive else { return }
        // 기기 지역은 AppleLocale 원문에서 읽는다. Locale.current 를 읽으면 그 값이 굳어 버린다.
        var components = Locale.Components(identifier: UserDefaults.standard.string(forKey: "AppleLocale") ?? "ar")
        components.languageComponents = Locale.Language.Components(identifier: "ar")
        components.numberingSystem = "latn"
        components.calendar = .gregorian

        let defaults = UserDefaults.standard
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["AppleLocale"] = Locale(components: components).identifier
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
}
