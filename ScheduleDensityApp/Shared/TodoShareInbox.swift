import Foundation

// 앱 타깃과 공유 익스텐션(TodoShareExtension)이 함께 컴파일하는 파일.
//
// 다른 앱에서 '욕망의 무지개'로 공유하면 익스텐션이 작은 창을 띄우고, 거기서 확정한
// 할 일을 여기 '받은 상자'에 쌓아둔다. 앱은 켜질 때마다 상자를 비워 SwiftData에 넣는다.
//
// 왜 바로 SwiftData에 안 넣는가:
// 할 일은 `WeekBlocksTodos` store(CloudKit 동기화)에 들어 있는데 그 store는 앱 샌드박스
// 안에 있어 익스텐션이 열 수 없다. store를 App Group으로 옮기면 이미 배포된 사용자의
// 데이터를 마이그레이션해야 한다 — 위젯이 스냅샷 파일만 읽는 것과 똑같은 이유다
// (→ TodoWidgetSnapshot.swift). 그래서 방향만 반대인 같은 구조를 쓴다:
// 위젯은 앱이 구워준 걸 읽고, 공유 익스텐션은 앱이 가져갈 걸 적어둔다.

/// 공유로 받아 아직 할 일이 되지 못한 한 줄.
struct SharedTodoDraft: Codable, Identifiable {
    var id: String
    var title: String
    /// `TodoLabel.rawValue`. 익스텐션에서 고른 값 = 예상 시간.
    /// ⚠️ 더 이상 안 쓴다. 예전 공유 익스텐션이 넣어 둔 값이 상자에 남아 있을 수 있어
    ///    디코딩만 되게 남겨 둔다 (없으면 옛 draft를 못 읽는다).
    var labelRaw: String?
    var receivedAt: Date

    // 링크는 따로 들고 오지 않는다. 할 일 한 줄에 URL을 통째로 붙이면 목록에서
    // 읽히지 않기 때문에, 익스텐션이 링크를 '읽을 수 있는 제목' 하나로 정리해 보낸다.
    // (원본 URL까지 보관하려면 BacklogItem에 메모 필드가 필요하고, 그건 맥앱과 공유하는
    //  CloudKit 스키마를 함께 바꿔야 하는 일이다.)

    init(id: String = UUID().uuidString,
         title: String,
         labelRaw: String? = nil,
         receivedAt: Date = Date())
    {
        self.id = id
        self.title = title
        self.labelRaw = labelRaw
        self.receivedAt = receivedAt
    }
}

/// 공유 익스텐션 → 앱 사이의 App Group 통로.
enum TodoShareInbox {
    /// ⚠️ 앱·위젯·공유 익스텐션 세 타깃의 entitlements에 똑같이 들어 있어야 한다.
    ///    (TodoWidgetBridge.appGroupID와 같은 값이다. 위젯 타깃은 이 파일을 컴파일하지
    ///     않으므로 상수를 공유하지 못하고 각자 들고 있다 — 한쪽을 고치면 같이 고칠 것.)
    static let appGroupID = "group.com.devkoan.ScheduleDensity"

    private static let fileName = "todo-share-inbox.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// 상자가 무한정 커지지 않게. 앱을 한 번도 안 켜고 이만큼 공유하는 건 사고에 가깝다.
    private static let maxPending = 200

    /// 익스텐션에서 확정한 할 일을 상자에 넣는다.
    /// - Returns: 성공 여부. App Group을 못 열면 false (익스텐션이 사용자에게 알린다).
    @discardableResult
    static func add(_ draft: SharedTodoDraft) -> Bool {
        guard let url = fileURL else {
            print("⚠️ [Share] App Group 컨테이너를 찾을 수 없습니다: \(appGroupID)")
            return false
        }
        var ok = false
        // 앱이 같은 순간 상자를 비우고 있을 수 있다. 읽기-고치기-쓰기를 통째로 감싼다.
        coordinate(writingTo: url) { url in
            var drafts = decode(at: url)
            drafts.append(draft)
            if drafts.count > maxPending { drafts.removeFirst(drafts.count - maxPending) }
            ok = encode(drafts, to: url)
        }
        return ok
    }

    /// 상자를 통째로 비우고 내용을 돌려준다. 앱이 켜질 때 한 번 부른다.
    /// 비우기까지 한 번의 조율 안에서 끝내야, 그 사이에 들어온 항목을 흘리지 않는다.
    static func drain() -> [SharedTodoDraft] {
        guard let url = fileURL else { return [] }
        var drafts: [SharedTodoDraft] = []
        coordinate(writingTo: url) { url in
            drafts = decode(at: url)
            guard !drafts.isEmpty else { return }
            try? FileManager.default.removeItem(at: url)
        }
        return drafts.sorted { $0.receivedAt < $1.receivedAt }
    }

    // MARK: - 파일

    /// 앱과 익스텐션은 서로 다른 프로세스라 같은 파일을 동시에 만질 수 있다.
    /// NSFileCoordinator로 감싸 한쪽이 끝날 때까지 다른 쪽이 기다리게 한다.
    private static func coordinate(writingTo url: URL, _ body: (URL) -> Void) {
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { url in
            body(url)
        }
        if let coordinationError {
            print("⚠️ [Share] 받은 상자 접근 실패: \(coordinationError)")
        }
    }

    private static func decode(at url: URL) -> [SharedTodoDraft] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        // 형식이 깨졌으면 버린다 — 공유 하나를 잃는 것이 상자가 영영 안 비는 것보다 낫다.
        return (try? JSONDecoder().decode([SharedTodoDraft].self, from: data)) ?? []
    }

    private static func encode(_ drafts: [SharedTodoDraft], to url: URL) -> Bool {
        do {
            try JSONEncoder().encode(drafts).write(to: url, options: .atomic)
            return true
        } catch {
            print("⚠️ [Share] 받은 상자 저장 실패: \(error)")
            return false
        }
    }
}
