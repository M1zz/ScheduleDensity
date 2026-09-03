//
//  WidgetLockedView.swift
//
//  위젯이 잠겨 있을 때 그 자리에 서는 것.
//
//  위젯은 값을 받고 여는 것 중 하나다 (→ ProEntitlement.swift). 익스텐션은 결제를
//  조회할 수 없으므로, 앱이 App Group에 구워둔 한 줄만 읽는다 — 스냅샷을 넘기는 방식과 같다.
//
//  **빈 화면으로 두지 않는다.** 홈 화면에 아무것도 없는 네모가 남으면 고장으로 읽힌다.
//  갤러리(미리보기)에서는 잠금을 걸지 않는다 — 뭘 얻는지 보여줘야 살지 말지를 정한다.
//

import SwiftUI

struct WidgetLockedView: View {
    /// 잠겨 있어도 이 위젯이 무엇인지는 말해준다.
    let name: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("앱의 설정에서 ‘무지개 Pro’")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) 위젯이 잠겨 있습니다. 앱의 설정에서 무지개 Pro를 사면 열립니다.")
    }
}
