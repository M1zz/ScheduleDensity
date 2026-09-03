//
//  TodoAccess.swift
//  ScheduleDensityApp
//
//  **여기서 적은 것이 다른 기기로 건너가는가.**
//
//  값을 받는 선은 '적기'가 아니라 **'건너가기'**에 그어져 있다. 적는 것은 이 앱의
//  본체라 잠그지 않는다 — 잠그면 새로 깐 사람이 첫 화면에서 한 줄도 못 적고,
//  앱이 무엇인지 알기도 전에 값부터 치르라는 말이 된다.
//
//  ⚠️ 동기화 엔진에는 방향이 없다. `NSPersistentCloudKitContainer`는 받기와 보내기를
//     따로 못 끈다 — 켜면 둘 다, 끄면 둘 다다. 그래서 방향은 엔진이 아니라 **줄에
//     도장을 찍는지로** 만든다 (→ TodoSharing.stamp).
//
//  ⚠️ 잠근다고 **이미 적어 둔 것을 숨기지 않는다.** 보이고, 읽히고, 끝낸 것도 그대로
//     남는다. 맥에서 온 것도 계속 내려온다. 값을 치르면 그때까지 적어 둔 것까지
//     함께 열린다.
//

import Foundation

enum TodoAccess {

    /// 이 기기에서 적은 것이 다른 기기로 건너가는가.
    ///
    /// 잠겨 있어도 **적는 데는 아무 지장이 없다.** 적은 것은 이 기기에서 그대로 보이고,
    /// 다른 기기에서 온 것도 계속 내려온다. 다만 여기서 적은 것이 저쪽에 안 보일 뿐이다
    /// (→ TodoSharing.swift). 값을 치르면 그때까지 적어 둔 것도 함께 열린다.
    static var canSync: Bool {
        guard ProEntitlement.sellsSync else { return true }
        return ProEntitlement.isUnlocked
    }

    /// 안내에 쓰는 말. 화면마다 따로 쓰면 문구가 갈라진다.
    static let lockedTitle = "여기서 적은 것은 아직 맥에 안 갑니다"
    static let lockedNote = "적는 데는 아무 지장이 없습니다. 맥에서 적은 것도 계속 내려옵니다. 열면 지금까지 적어 둔 것까지 함께 보입니다."
}
