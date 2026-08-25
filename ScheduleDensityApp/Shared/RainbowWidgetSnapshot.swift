import Foundation

// 앱 타깃과 위젯 익스텐션이 함께 컴파일하는 파일.
//
// 일정(Event)은 앱 샌드박스 안의 SwiftData store에 있어 위젯이 열 수 없다.
// (App Group으로 옮기면 이미 배포된 사용자의 일정을 마이그레이션해야 한다.)
// 그래서 앱이 App Group에 읽기 전용 스냅샷을 구워두고, 위젯은 그 파일만 읽는다.
// → 할 일 위젯도 같은 방식이다 (TodoWidgetSnapshot.swift).

/// 위젯이 무지개 한 조각을 그리는 데 필요한 최소 정보.
struct RainbowWidgetSnapshot: Codable {
    /// 칸 하나.
    struct Cell: Codable {
        /// 0...6 레인 번호. 색은 이 번호가 정한다.
        var lane: Int
        /// 그날 실제로 시간을 쓰는 칸인지. false면 매여만 있는 칸(옅게).
        var isWorking: Bool
    }

    struct Day: Codable, Identifiable {
        var date: Date
        /// 그날 차 있는 칸들. 빈 레인은 아예 없다 (파일을 작게 유지).
        var cells: [Cell]
        /// 그날 실제로 들어가는 시간 합.
        var hours: Double
        /// 잘 시간을 뺀 하루 대비 점유율. 1을 넘을 수 있다.
        var load: Double

        var id: Date { date }

        /// 그날 동시에 굴리는 일의 개수 (진한 칸만).
        var workingCount: Int { cells.filter(\.isWorking).count }
    }

    /// 오늘부터 며칠치.
    var days: [Day]
    var updatedAt: Date

    /// 위젯이 아무리 커도 이 이상은 안 그린다.
    static let maxDays = 14

    /// 레인 색. ⚠️ 앱의 `ScheduleViewModel.laneColors`와 같은 배열이어야 한다
    /// (둘 다 여기 `RainbowPalette`를 본다 → ColorHex.swift).
    static var laneColors: [String] { RainbowPalette.laneColors }

    static let empty = RainbowWidgetSnapshot(days: [], updatedAt: .distantPast)

    var today: Day? { days.first }

    /// 앞으로 아무 일도 없는 상태.
    var isEmpty: Bool { days.allSatisfy { $0.cells.isEmpty } }

    /// 위젯 갤러리 미리보기용 — 겹쳐 있는 며칠을 보여줘야 무엇을 보는 위젯인지 안다.
    static var sample: RainbowWidgetSnapshot {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let plan: [[Cell]] = [
            [Cell(lane: 0, isWorking: true), Cell(lane: 1, isWorking: true), Cell(lane: 3, isWorking: false)],
            [Cell(lane: 0, isWorking: false), Cell(lane: 1, isWorking: true), Cell(lane: 3, isWorking: true)],
            [Cell(lane: 0, isWorking: true), Cell(lane: 3, isWorking: false)],
            [Cell(lane: 0, isWorking: false), Cell(lane: 3, isWorking: false), Cell(lane: 5, isWorking: true)],
            [Cell(lane: 0, isWorking: true), Cell(lane: 5, isWorking: true)],
            [Cell(lane: 5, isWorking: false)],
            [Cell(lane: 5, isWorking: true), Cell(lane: 6, isWorking: true)]
        ]
        let days = plan.enumerated().map { offset, cells in
            Day(date: calendar.date(byAdding: .day, value: offset, to: start) ?? start,
                cells: cells,
                hours: Double(cells.filter(\.isWorking).count) * 1.5,
                load: Double(cells.filter(\.isWorking).count) * 1.5 / 16)
        }
        return RainbowWidgetSnapshot(days: days, updatedAt: Date())
    }
}

/// 앱 ↔ 무지개 위젯 사이의 App Group 통로.
enum RainbowWidgetBridge {
    /// 할 일 위젯과 같은 App Group을 쓴다.
    static let appGroupID = TodoWidgetBridge.appGroupID

    /// `WidgetCenter.reloadTimelines(ofKind:)`에 쓰는 위젯 종류 ID.
    static let widgetKind = "RainbowWidget"

    /// 위젯을 탭하면 앱의 '무지개' 탭으로 이동한다.
    static let deepLink = URL(string: "rainbow://rainbow")!

    private static let fileName = "rainbow-widget-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func write(_ snapshot: RainbowWidgetSnapshot) {
        guard let url = fileURL else {
            print("⚠️ [Widget] App Group 컨테이너를 찾을 수 없습니다: \(appGroupID)")
            return
        }
        do {
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            print("⚠️ [Widget] 무지개 스냅샷 저장 실패: \(error)")
        }
    }

    /// 스냅샷이 없거나 깨졌으면 빈 스냅샷을 돌려준다 (위젯은 '비어 있음'으로 그린다).
    static func read() -> RainbowWidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(RainbowWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
