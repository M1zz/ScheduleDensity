//
//  TodoSharing.swift
//  ScheduleDensityApp
//
//  **올라가는 것은 못 막는다. 그리면 안 되는 것은 안 그리면 된다.**
//
//  잠긴 기기의 할 일이 상대 기기에 보이면 안 된다. 그런데 동기화 엔진은 "이건 올리고
//  저건 올리지 마"를 못 한다 — 미러링을 켜면 로컬에 있는 것을 전부 올린다.
//  스토어를 둘로 나누면 막을 수야 있지만, 그건 데이터가 사는 집을 둘로 쪼개는 일이라
//  값이 안 맞는다.
//
//  그래서 **막는 자리를 옮겼다.** 데이터는 올라가게 두고, 각 줄에 '나눠 쓰는 줄인가'를
//  적어 둔 뒤 **받는 쪽에서 안 그린다.**
//
//  ⚠️ 이건 담장이 아니라 **커튼**이다. 값은 사용자 자신의 iCloud를 거쳐 사용자 자신의
//     다른 기기 디스크에 실제로 놓인다. 남의 데이터가 아니므로 보안 문제는 아니지만,
//     "물리적으로 못 가게 막았다"고 말하면 안 된다. 거르는 것을 한 군데(→ `isVisible`)
//     로 모아 둔 이유가 그것이다 — 화면마다 조건을 따로 쓰면 어딘가는 새어 보인다.
//
//  ## 왜 '누가 만들었나'가 필요한가
//
//  잠긴 기기의 스토어에는 **자기 것과 상대 것이 섞여** 있다. 상대(산 쪽)가 보낸 줄은
//  보여야 하고, 자기가 예전에 적어 둔 줄은 상대에게 안 보여야 한다. 그래서 줄마다
//  어느 기기에서 났는지를 적는다.
//
//  ## 깃발은 한쪽으로만 넘어간다
//
//  `isShared`는 false → true 로만 간다. 결제하면 켜지고, 다시 꺼지지 않는다.
//  양쪽에서 서로 반대로 뒤집으면 충돌을 풀 방법이 없는데, 한 방향이면 그럴 일이 없다.
//  (환불로 되돌리지 않는 것은 의도한 것이다 — 이미 상대 기기에 내려간 줄을 뒤늦게
//   감추면, 사용자에게는 데이터가 사라진 것으로 보인다.)
//

import Foundation
import SwiftData

/// **함께 쓰는지를 스스로 말할 수 있는 것.**
///
/// 할 일에만 걸려 있던 규칙을 계획 블록·루틴까지 넓히면서 세 모델이 같은 두 칸을 갖게
/// 됐다. 규칙을 세 번 쓰면 언젠가 한 벌만 고쳐져 어긋나므로 하나로 묶는다.
/// ⚠️ 맥('무지개 공방')의 같은 이름 파일과 규칙이 **글자까지 같아야** 한다.
protocol SharedRecord: AnyObject {
    var isShared: Bool { get set }
    var originInstallID: String { get set }
}

extension BacklogItem: SharedRecord {}
extension PlanBlock: SharedRecord {}
extension Routine: SharedRecord {}

enum TodoSharing {

    /// 이 설치본의 이름. 기기를 가리키는 것이 아니라 **이 앱이 깔린 자리**를 가리킨다.
    /// 지우고 다시 깔면 새 이름이 되는데, 그래도 되는 값이다 — 예전 줄들은 그때
    /// 이미 클라우드에 자기 이름을 달고 올라가 있다.
    static var installID: String {
        let key = "todo.installID"
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: key), !saved.isEmpty { return saved }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: key)
        return fresh
    }

    /// 이 줄을 이 기기에서 만들었는가.
    /// 이름이 비어 있으면(이 기능이 생기기 전에 적은 줄) 내 것으로 본다 —
    /// 쓰던 사람의 줄이 갑자기 남의 것이 되어 사라지면 안 된다.
    static func isMine(_ item: some SharedRecord) -> Bool {
        item.originInstallID.isEmpty || item.originInstallID == installID
    }

    /// **화면에 그릴 줄인가.** 거르는 규칙은 여기 하나뿐이다.
    ///
    /// 감추는 것은 **남이 잠긴 채로 적어 둔 줄** 하나뿐이다.
    /// 내 줄은 잠겨 있어도 내 화면에서는 그대로 보인다.
    static func isVisible(_ item: some SharedRecord) -> Bool {
        item.isShared || isMine(item)
    }

    /// 새로 적는 줄에 지금 상태를 새긴다.
    static func stamp(_ item: some SharedRecord) {
        item.originInstallID = installID
        item.isShared = TodoAccess.canSync
    }

    // MARK: - 열리고 잠길 때

    /// **결제했다.** 이 기기에서 난 줄들을 상대에게도 보이게 한다.
    ///
    /// 값을 치른 순간 예전에 적어 둔 것까지 함께 열리는 게 맞다. 그때부터 올라가는
    /// 것이 아니라 **이미 올라가 있던 것이 그제서야 보이는** 것이라, 기다림이 없다.
    static func openMyItems(in context: ModelContext) {
        let mine = ((try? context.fetch(FetchDescriptor<BacklogItem>())) ?? [])
            .filter { !$0.isShared && isMine($0) }
        guard !mine.isEmpty else { return }
        for item in mine { item.isShared = true }
        try? context.save()
        print("🔓 [Sharing] 이 기기의 할 일 \(mine.count)개를 함께 쓰기로 열었다")
    }

    /// 이 기기에서 난 줄 중 상대에게 **아직 안 보이는** 것의 수.
    /// 가끔 안내할 때 쓴다 — "여기 것은 저기서 안 보입니다"를 숫자로 말한다.
    static func hiddenFromOthersCount(in context: ModelContext) -> Int {
        ((try? context.fetch(FetchDescriptor<BacklogItem>())) ?? [])
            .filter { !$0.isShared && isMine($0) && !$0.isCompleted }
            .count
    }
}
