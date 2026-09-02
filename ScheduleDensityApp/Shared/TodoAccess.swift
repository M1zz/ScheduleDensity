//
//  TodoAccess.swift
//  ScheduleDensityApp
//
//  **이 기기에서 할 일을 적을 수 있는가.**
//
//  값을 받는 선을 '기능'이 아니라 **'적기'**에 그었다. 잠긴 기기는 상대 기기의 할 일을
//  받아 보기는 하지만 적지는 못한다. 안 적으니 보낼 것이 없고, 그래서 결과적으로
//  **산 쪽 → 안 산 쪽** 한 방향이 된다.
//
//  ⚠️ 동기화 엔진에는 방향이 없다. `NSPersistentCloudKitContainer`는 받기와 보내기를
//     따로 못 끈다 — 켜면 둘 다, 끄면 둘 다다. 그래서 방향은 **엔진이 아니라 사람이
//     적을 수 있는지로** 만든다. 이 파일이 그 한 줄이다.
//
//  ⚠️ 잠근다고 **이미 적어 둔 것을 숨기지 않는다.** 쓰던 사람의 목록이 비면 그건
//     값을 받는 게 아니라 뺏는 것이다. 보이고, 읽히고, 끝낸 것도 그대로 남는다.
//     새로 적는 것만 막는다.
//

import Foundation

enum TodoAccess {

    /// **적기를 팔기 시작했는가.** false인 동안에는 모두에게 열려 있다.
    ///
    /// ⚠️ 이 스위치가 없으면 업데이트를 내는 순간 **지금까지 무료로 적던 사람들이
    ///    갑자기 못 적게 된다.** 그건 값을 받는 게 아니라 뺏는 것이다.
    ///    상품이 실제로 팔리기 시작할 때 켠다. 맥의 `MacEntitlement.sellsAccess`와
    ///    짝이고, 두 앱을 따로 팔 것이므로 **각자 따로 켠다.**
    ///
    /// 🚢 1.1.0에서 켰다. 이 버전부터 판다.
    ///    쓰던 사람은 `ProEntitlement.grandfathersExistingUsers`가 받아낸다 —
    ///    **그 스위치를 끄면 1.0.9까지 무료로 적던 사람들이 이 업데이트로 못 적게 된다.**
    ///    둘은 반드시 함께 켜져 있어야 한다.
    static let sellsEditing = true

    /// 이 기기에서 할 일을 적고 고칠 수 있는가.
    /// 화면들은 **이 값 하나만** 본다.
    static var canEdit: Bool {
        guard sellsEditing else { return true }
        return ProEntitlement.isUnlocked
    }

    /// 잠긴 기기에서 안내에 쓰는 말. 화면마다 따로 쓰면 문구가 갈라진다.
    static let lockedTitle = "이 기기에서는 읽기만 됩니다"
    static let lockedNote = "적는 것은 열어야 합니다. 이미 적어 둔 것은 그대로 보이고, 다른 기기에서 적은 것도 계속 내려옵니다."
}

// MARK: - 지금 실제로 값을 받는 것들
//
// `ProFeature.allCases`는 **팔 수 있는 것의 목록**이지 지금 파는 것의 목록이 아니다.
// '적기'에는 스위치가 따로 달려 있어서(위 `sellsEditing`), 켜기 전까지는 무료다.
// 화면이 allCases를 그대로 세면 잠기지도 않은 것을 잠겼다고 말하게 된다.
//
// ⚠️ ProEntitlement.swift가 아니라 여기 둔다. 그 파일은 위젯 익스텐션도 함께
//    컴파일하는데 위젯에는 이 파일이 없다 (→ ScheduleDensityApp.project.yml).

extension ProFeature {

    /// 페이월과 설정이 함께 읽는, **오늘 잠겨 있는 것들**.
    static var sold: [ProFeature] {
        allCases.filter { $0 != .editing || TodoAccess.sellsEditing }
    }
}
