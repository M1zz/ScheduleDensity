import Foundation

// 앱 타깃과 위젯 익스텐션이 함께 컴파일하는 파일.
//
// 할 일은 SwiftData(`WeekBlocksTodos` store, CloudKit 동기화)에 들어 있는데 그 store는
// 앱 샌드박스 안에 있어 위젯이 열 수 없다. store를 App Group으로 옮기면 이미 배포된
// 사용자의 데이터를 마이그레이션해야 하므로, 앱이 App Group에 읽기 전용 스냅샷을 구워두고
// 위젯은 그 파일만 읽는다. (위젯에서 체크/수정은 하지 않는다.)

/// 위젯이 그리는 데 필요한 최소한의 할 일 정보.
struct TodoWidgetSnapshot: Codable {
    struct Item: Codable, Identifiable {
        var id: String
        var title: String
        /// 카테고리 색 hex. 미분류면 nil.
        var colorHex: String?
        var categoryName: String?
        /// 지난 주에 못 하고 넘어온 항목.
        var isCarryover: Bool
        /// 오늘 계획으로 배정된 항목 (맥 타임라인·무지개에도 올라가 있음).
        var isToday: Bool
        /// 단계로 쪼갠 할 일의 '지금 할 일'. 단계가 없으면 nil.
        var stepTitle: String?
        /// 0...1 진행률. 단계가 없으면 0.
        var progress: Double
        /// 지금 할 단계가 두 질문에 모두 '예'인가 — 5분이 났을 때 집어도 되는 줄.
        /// 판정은 앱에서만 한다(위젯은 사전을 안 들고 있다).
        var isFragment: Bool
        /// 지금 몇 번째 단계인가 (1부터). 단계가 없으면 nil.
        /// 잠금 화면에서도 "여기까지 왔고 지금은 이것"이 보여야 한다.
        var stepIndex: Int?
        /// 단계 수. 단계가 없으면 nil.
        var stepCount: Int?

        // isToday·stepTitle·progress·isFragment는 나중에 추가된 필드라, 이 키가 없는 옛
        // 스냅샷도 읽을 수 있어야 한다. (앱 업데이트 직후 위젯이 먼저 깨어나면 옛 파일을 만난다.)
        enum CodingKeys: String, CodingKey {
            case id, title, colorHex, categoryName, isCarryover, isToday, stepTitle, progress, isFragment
            case stepIndex, stepCount
        }

        init(id: String, title: String, colorHex: String?, categoryName: String?,
             isCarryover: Bool, isToday: Bool = false,
             stepTitle: String? = nil, progress: Double = 0,
             isFragment: Bool = false,
             stepIndex: Int? = nil, stepCount: Int? = nil) {
            self.id = id
            self.title = title
            self.colorHex = colorHex
            self.categoryName = categoryName
            self.isCarryover = isCarryover
            self.isToday = isToday
            self.stepTitle = stepTitle
            self.progress = progress
            self.isFragment = isFragment
            self.stepIndex = stepIndex
            self.stepCount = stepCount
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
            categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName)
            isCarryover = try c.decodeIfPresent(Bool.self, forKey: .isCarryover) ?? false
            isToday = try c.decodeIfPresent(Bool.self, forKey: .isToday) ?? false
            stepTitle = try c.decodeIfPresent(String.self, forKey: .stepTitle)
            progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0
            isFragment = try c.decodeIfPresent(Bool.self, forKey: .isFragment) ?? false
            stepIndex = try c.decodeIfPresent(Int.self, forKey: .stepIndex)
            stepCount = try c.decodeIfPresent(Int.self, forKey: .stepCount)
        }
    }

    /// 지금 5분에 집을 수 있는 단계 하나. (→ 번개 위젯)
    ///
    /// `Item`과 달리 **최상위 할 일이 아니라 단계 하나**가 한 줄이다. 한 일 안에서도
    /// 조각은 여럿일 수 있고(순서 없는 묶음), 5분이 났을 때 필요한 건 '무슨 일이 남았나'가
    /// 아니라 '지금 집을 게 뭐가 있나'라서 목록의 단위가 다르다.
    struct Fragment: Codable, Identifiable {
        var id: String
        /// 단계 이름. 줄에 서는 것은 이것이다.
        var title: String
        /// 무슨 일의 일부인지. 안 쪼갠 줄이면 nil.
        var parentTitle: String?
        /// 카테고리 색 hex. 미분류면 nil.
        var colorHex: String?
        /// 걸리는 시간(분). 0이면 시간을 안 잡은 줄.
        var minutes: Int
        /// **사용자가 직접 표시한 것인가.** 앱의 짐작(낱말·시간)과 구분해서 그린다 —
        /// 이 자리의 값어치는 "여기 있는 건 진짜 바로 된다"는 믿음에서 나온다.
        var isMarked: Bool
    }

    /// 아직 안 한 일. 오늘 배정 → 지난 주 잔여 → 이번 주 순서(급한 것부터).
    var items: [Item]
    /// 지금 집을 수 있는 조각들. 표시해 둔 것 먼저, 그 다음 급한 순서.
    var fragments: [Fragment]
    /// 안 한 일 전체 개수. 화면에는 안 쓰지만 `items`가 잘렸는지 판단하는 데 쓴다.
    var openCount: Int
    /// 조각 전체 개수. `fragments`가 잘렸는지 판단하는 데 쓴다.
    var fragmentCount: Int
    var updatedAt: Date

    /// 위젯이 아무리 커도 이 이상은 못 보여준다. 파일도 작게 유지.
    static let maxItems = 12
    static let maxFragments = 12

    init(items: [Item], fragments: [Fragment] = [],
         openCount: Int, fragmentCount: Int = 0, updatedAt: Date) {
        self.items = items
        self.fragments = fragments
        self.openCount = openCount
        self.fragmentCount = fragmentCount
        self.updatedAt = updatedAt
    }

    // fragments·fragmentCount는 나중에 추가된 필드다. 이 키가 없는 옛 스냅샷도 읽어야 한다 —
    // 여기서 디코딩이 실패하면 앱을 한 번 열기 전까지 **할 일 위젯까지 같이 빈다.**
    enum CodingKeys: String, CodingKey {
        case items, fragments, openCount, fragmentCount, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decode([Item].self, forKey: .items)
        fragments = try c.decodeIfPresent([Fragment].self, forKey: .fragments) ?? []
        openCount = try c.decode(Int.self, forKey: .openCount)
        fragmentCount = try c.decodeIfPresent(Int.self, forKey: .fragmentCount) ?? 0
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    static let empty = TodoWidgetSnapshot(items: [], openCount: 0, updatedAt: .distantPast)

    /// 위젯 갤러리 미리보기용.
    static let sample = TodoWidgetSnapshot(
        items: [
            Item(id: "1", title: "기획서 초안 작성", colorHex: "#007AFF", categoryName: "개발",
                 isCarryover: false, isToday: true,
                 stepTitle: "목차 잡기", progress: 0.3,
                 stepIndex: 1, stepCount: 4),
            Item(id: "2", title: "위젯 스냅샷 정리", colorHex: "#5856D6", categoryName: "개발",
                 isCarryover: true, isToday: false),
            Item(id: "3", title: "장보기 — 우유, 계란", colorHex: "#34C759", categoryName: "집안일",
                 isCarryover: false, isToday: false, isFragment: true),
            Item(id: "4", title: "러닝 30분", colorHex: "#FF9500", categoryName: "운동",
                 isCarryover: false, isToday: false),
            Item(id: "5", title: "책 한 챕터 읽기", colorHex: nil, categoryName: nil,
                 isCarryover: false, isToday: false),
        ],
        fragments: [
            Fragment(id: "f1", title: "자료 링크 하나 챙기기", parentTitle: "기획서 초안 작성",
                     colorHex: "#007AFF", minutes: 5, isMarked: true),
            Fragment(id: "f2", title: "장보기 — 우유, 계란", parentTitle: nil,
                     colorHex: "#34C759", minutes: 15, isMarked: false),
            Fragment(id: "f3", title: "업체 예약 전화", parentTitle: "이사 준비",
                     colorHex: "#FF9500", minutes: 10, isMarked: false),
        ],
        openCount: 5, fragmentCount: 3, updatedAt: Date()
    )

    var isEmpty: Bool { items.isEmpty }
    var hasNoFragments: Bool { fragments.isEmpty }
}

/// 앱 ↔ 위젯 사이의 App Group 통로.
enum TodoWidgetBridge {
    /// ⚠️ 앱 타깃과 위젯 타깃의 entitlements에 똑같이 들어 있어야 한다.
    static let appGroupID = "group.com.devkoan.ScheduleDensity"

    /// `WidgetCenter.reloadTimelines(ofKind:)`에 쓰는 위젯 종류 ID.
    static let widgetKind = "TodoWidget"
    /// 조각만 모아 보여주는 위젯. 같은 스냅샷 파일을 읽으므로 통로는 하나뿐이다.
    static let fragmentWidgetKind = "FragmentWidget"

    /// 위젯을 탭하면 앱의 '할 일' 탭으로 이동한다.
    static let deepLink = URL(string: "rainbow://todo")!

    /// 번개 위젯의 착지점. 지금은 '할 일' 탭과 같은 자리에 내리지만 호스트를 따로 둔다 —
    /// 조각만 보는 자리가 생기면 위젯을 안 고치고 앱에서만 갈아끼울 수 있다.
    static let fragmentDeepLink = URL(string: "rainbow://fragment")!

    private static let fileName = "todo-widget-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func write(_ snapshot: TodoWidgetSnapshot) {
        guard let url = fileURL else {
            print("⚠️ [Widget] App Group 컨테이너를 찾을 수 없습니다: \(appGroupID)")
            return
        }
        do {
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            print("⚠️ [Widget] 스냅샷 저장 실패: \(error)")
        }
    }

    /// 스냅샷이 없거나 깨졌으면 빈 스냅샷을 돌려준다 (위젯은 '할 일 없음'으로 그린다).
    static func read() -> TodoWidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(TodoWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
