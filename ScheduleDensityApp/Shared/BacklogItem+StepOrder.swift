//
//  BacklogItem+StepOrder.swift
//
//  쪼갠 단계들이 **서로를 기다리는가**. 묶음 하나에 스위치 하나.
//
//  지금까지 앱은 모든 쪼개기를 사슬로 봤다 — `currentStep`이 '첫 번째 미완료 잎'이었으니
//  '초고 → 퇴고 → 발행'이든 '업체 예약 / 주소 이전 / 짐 싸기'든 똑같이 줄을 세웠다.
//  앞의 것은 맞지만 뒤의 것은 틀리다. 셋 다 지금 할 수 있는데 하나만 보여주고
//  나머지는 차례를 기다리게 만들면, 5분이 났을 때 집을 수 있는 것이 화면에 없다.
//
//  **단계마다 걸지 않고 묶음마다 건다.** 사람이 손으로 쪼갠 네댓 줄에서 일부만 순서가
//  있는 경우는 드물다 — 대개 통째로 사슬이거나 통째로 자루다. 단계마다 의존성을 걸면
//  그건 그래프이고, 화살표와 관리 부담이 따라온다. 1비트로 끝나는 것을 그렇게 살 이유가 없다.
//
//  저장 자리는 `labelRaw`다. 두 질문의 답(`pick:`)이 쓰는 자리와 같지만 겹치지 않는다 —
//  **`pick:`은 잎에만, `order:`는 묶음에만** 쓰인다. 묶음의 조각 판정은 앱이 아예 안 읽으므로
//  (→ `TodoTree.markedStep`, `TodoDetailView.stepsSection`) 그 자리는 비어 있는 셈이다.
//  새 필드를 더하면 맥앱과 공유하는 CloudKit 스키마를 양쪽에서 같이 바꿔야 하는데,
//  이 값은 그만한 무게가 없다 — `pick:`을 그렇게 넣었던 이유와 같다.
//
//  ⚠️ 맥앱('무지개 공방')은 아직 이 값을 모른다. 옛 코드가 묶음의 `order:free`를 읽으면
//     `pick:` 접두어가 없으니 '답 없음'으로 읽고 지나간다 — 깨지지 않는다.
//     맥앱에 순서 개념을 옮길 때 이 파일을 그대로 복제하면 된다.
//

import Foundation

/// 한 묶음 아래 단계들이 서로 순서를 지키는가.
enum StepOrder: String, CaseIterable {
    /// 앞 단계가 끝나야 다음이 온다. 기본값 — 지금까지 앱이 가정해 온 것.
    case sequential
    /// 서로 기다리지 않는다. 남은 것 중 아무거나 집으면 된다.
    case free

    var title: String {
        switch self {
        case .sequential: return "순서대로"
        case .free:       return "아무거나"
        }
    }

    var systemImage: String {
        switch self {
        case .sequential: return "arrow.down.to.line"
        case .free:       return "square.grid.2x2"
        }
    }

    /// 이 스위치가 무엇을 바꾸는지 한 줄로. 고르는 자리에 붙는다.
    var note: String {
        switch self {
        case .sequential: return "앞 단계가 끝나야 다음이 옵니다."
        case .free:       return "서로 기다리지 않습니다. 남은 것 중 5분에 집을 수 있는 것부터 세웁니다."
        }
    }
}

extension BacklogItem {

    /// 저장 형식: `order:` + `sequential`|`free`. 없으면 `sequential`.
    private static let orderPrefix = "order:"

    /// 이 할 일 **아래 단계들**이 서로를 기다리는가.
    ///
    /// 단계가 없는 줄에서는 아무 뜻이 없다 — 읽으면 언제나 `.sequential`이다.
    var stepOrder: StepOrder {
        get {
            guard let raw = labelRaw, raw.hasPrefix(Self.orderPrefix) else { return .sequential }
            return StepOrder(rawValue: String(raw.dropFirst(Self.orderPrefix.count))) ?? .sequential
        }
        set {
            guard newValue != .sequential else {
                // 기본값으로 되돌릴 때만 자리를 비운다. 내가 쓴 값이 아니면 건드리지 않는다 —
                // 잎이었다가 단계를 얻어 묶음이 된 줄에는 옛 `pick:` 답이 남아 있을 수 있다.
                if let raw = labelRaw, raw.hasPrefix(Self.orderPrefix) { labelRaw = nil }
                return
            }
            labelRaw = Self.orderPrefix + newValue.rawValue
        }
    }
}
