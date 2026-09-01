//
//  TodoTips.swift
//
//  할 일 화면의 조언을 담는 곳 — 전부 TipKit으로 낸다.
//
//  왜 TipKit인가:
//  화면에 조언을 상시로 깔아두면 정보가 너무 많아 정작 일을 시작하기 어렵다.
//  TipKit은 (1) 필요한 때에만 뜨고 (2) 닫으면 다시 안 뜨고 (3) 시스템이 빈도를 조절한다.
//  그래서 "알려줘야 하는 것"은 전부 여기로 모으고, 화면에는 지금 할 일만 남긴다.
//
//  ⚠️ 이 파일은 iOS('욕망의 무지개')와 macOS('무지개 공방') 두 레포에 **같은 내용으로**
//     복제돼 있다. 한쪽을 고치면 다른 쪽도 반드시 같이 고칠 것.
//

import SwiftUI
import TipKit

// MARK: - 앱 시작할 때 한 번

enum TodoTips {
    /// 앱 진입점에서 한 번 부른다. 실패해도 앱은 그대로 돌아간다(팁만 안 뜬다).
    static func configure() {
        try? Tips.configure([
            // 규칙을 만족하면 바로 보여준다. 어차피 각 팁은 한 번 닫으면 끝이다.
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    /// 조언을 처음부터 다시 보고 싶을 때 (설정에서 부른다).
    static func resetAll() {
        try? Tips.resetDatastore()
    }
}

// MARK: - 단계 나누기

/// 한 할 일 안에 단계가 둘 이상 생긴 순간, 단계에 무엇을 정해 주면 되는지 한 번만 설명한다.
struct ShareSplitTip: Tip {
    /// 단계를 둘 이상 만들어 본 적이 있는가.
    @Parameter static var hasSplit: Bool = false

    var title: Text { Text("한 자리에서 닫히는 크기로") }
    var message: Text? {
        Text("단계는 한 번 앉아서 끝낼 수 있는 크기여야 합니다. 하다 만 단계는 다음 시간까지 주의를 끌고 갑니다.\n이 일 전체 시간은 단계들의 합이 됩니다.")
    }
    var image: Image? { Image(systemName: "bolt.fill") }
    var rules: [Rule] {
        #Rule(Self.$hasSplit) { $0 == true }
    }
}

// MARK: - 목록의 색·손짓

/// 목록의 색과 스와이프가 무엇을 뜻하는지 **한 번만**.
///
/// 예전에는 목록 아래에 상시로 깔려 있었다. 늘 거기 있는 글은 처음 한 번을 빼면
/// 안 읽히면서 자리만 차지하고, 정작 세어야 할 숫자를 세 줄 아래로 밀어낸다 —
/// 이 파일이 조언을 전부 TipKit으로 보낸 이유가 그것이다.
struct ListLegendTip: Tip {
    /// 목록에 줄이 하나라도 생겼는가. 빈 화면에서는 설명할 색이 없다.
    @Parameter static var hasItems: Bool = false

    var title: Text { Text("색이 말하는 것") }
    var message: Text? {
        // 스와이프에 남은 것은 번개 하나다. '시간 잡기'는 상세의 스테퍼가,
        // '오늘'은 상세의 날짜가 답한다 (→ TodoView, TodoWhen).
        Text("연두는 5분이 나면 그냥 집어도 되는 줄, 회색은 시간을 안 잡은 줄입니다.\n오른쪽으로 밀면 번개를 붙이고 거둡니다.")
    }
    var image: Image? { Image(systemName: "paintpalette") }
    var rules: [Rule] {
        #Rule(Self.$hasItems) { $0 == true }
    }
}

// MARK: - 쪼개기 조언 (내용이 그때그때 다른 팁)

/// `TodoSplitAdvisor`가 만든 구성 조언 하나를 팁으로 낸다.
///
/// 조언 종류마다 다른 `id`를 쓴다 — 한 종류를 닫으면 그 종류만 다시 안 뜨고,
/// 다른 종류의 조언은 계속 뜬다.
struct SplitHintTip: Tip {
    let hint: SplitHint

    var id: String { "split-hint-\(hint.code)" }
    var title: Text { Text(hint.title) }
    var message: Text? {
        if let source = hint.source {
            return Text("\(hint.detail)\n\n— \(source)")
        }
        return Text(hint.detail)
    }
    var image: Image? {
        switch hint.tone {
        case .good:    return Image(systemName: "checkmark.seal.fill")
        case .caution: return Image(systemName: "exclamationmark.triangle.fill")
        case .info:    return Image(systemName: "lightbulb")
        }
    }
}

/// 단계 하나에 붙는 경고(시동 비용·너무 큰 단계 등)를 팁으로 낸다.
/// 지금 할 단계에만 띄운다 — 모든 줄에 경고를 깔면 다시 정보가 너무 많아진다.
struct StepWarningTip: Tip {
    let warning: StepAdvice.Warning

    var id: String { "step-warning-\(warning.source)" }
    var title: Text { Text("이 단계, 이대로 괜찮을까요") }
    var message: Text? { Text("\(warning.message)\n\n— \(warning.source)") }
    var image: Image? { Image(systemName: "exclamationmark.triangle.fill") }
}
