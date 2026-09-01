//
//  WeekBlocksStore.swift
//  ScheduleDensityApp
//
//  Mac '무지개 공방(WeekBlocks)'이 같은 iCloud(private DB)에 저장한 주간 계획을 읽어
//  iOS 밀도 시각화용 Event(메모리 전용)로 변환하는 서비스.
//
//  설계 원칙:
//   - 기존 Event 스토어(ScheduleDensityApp.swift)와 **완전히 분리된** 별도 ModelContainer.
//     서로 영향 없음. 출시된 로컬 Event 데이터는 건드리지 않는다.
//   - loadVisualEvents가 만든 Event는 **절대 SwiftData에 insert하지 않는다**
//     (시각화 입력용 임시 객체).
//   - 변환은 의존성 없는 순수 코어 WeekBlocksAdapter를 재사용.
//
//  ⚠️ **다시 읽기 전용이다.** 2026-08에 '할 일을 오늘로 배정'을 위해 PlanBlock 쓰기가
//     들어왔다가 걷어냈다. 두 가지 이유다:
//
//     1. **뜻이 틀렸다.** 그 쓰기는 마감이 오늘인 할 일을 맥의 오늘 칸에 자동으로
//        올렸다. 그런데 '마감이 오늘까지'와 '오늘 하기로 했다'는 다른 일이다.
//        앞의 것은 밖에서 온 제약이고 뒤의 것은 사람이 한 약속이다. 앱이 제약을
//        약속으로 바꿔 적으면, 사람은 약속한 적이 없는데 계획표에는 약속이 서 있다.
//        (마감이 3주 뒤인 일은 3주 내내 오늘 칸에 못 올라오는 문제도 같은 뿌리다.)
//
//     2. **맥의 데이터를 지웠다.** 되돌리는 길이 `unassign(title:)`이었는데, 같은 날
//        같은 제목이면 **맥에서 사람이 손으로 만든 블록까지** 지웠다. 이 앱의 PlanBlock
//        모델에는 맥에 있는 필드 13개(전파 계약)가 없어서, 지워진 것이 무엇이었는지
//        알 수도 없었다.
//
//     '언제 손댈지'는 맥이 정하고, 이 앱은 그걸 **읽어서 보여준다.** 폰에서 약속을
//     잡는 길은 나중에 PlanBlock에 안정적인 열쇠(할 일의 dragToken)가 실린 뒤에 연다 —
//     제목으로 맞추는 한 어떤 쓰기도 남의 블록을 건드릴 수 있다.
//

import Foundation
import SwiftData

extension Notification.Name {
    /// iOS에서 WeekBlocks 계획(PlanBlock)을 직접 바꿨을 때 보낸다.
    /// CloudKit 원격 변경 알림은 같은 프로세스의 로컬 저장에는 오지 않으므로,
    /// 밀도 화면이 즉시 다시 그리도록 직접 알린다.
    static let weekBlocksPlanDidChange = Notification.Name("weekBlocksPlanDidChange")
}

final class WeekBlocksStore {
    /// 앱 전체에서 공유하는 인스턴스.
    /// 같은 store 파일에 ModelContainer를 두 개 열면 조정자가 갈라져 쓰기가 서로 안 보인다.
    static let shared = WeekBlocksStore()
    /// Mac WeekBlocks가 쓰는 CloudKit private 컨테이너 ID (양쪽 정확히 일치해야 함).
    static let containerID = "iCloud.com.devkoan.ScheduleDensity"

    /// 로컬 미러의 store 파일 이름(확장자 제외).
    /// 이 앱이 iCloud로 오가는 **단 하나의** 스토어 파일.
    ///
    /// ⚠️ 예전에는 이 미러(루틴·계획)와 할 일이 **서로 다른 스토어**로 갈라져 있었다.
    ///    Core Data는 한 컨테이너에 여러 스토어를 미러링하는 것을 데이터베이스 범위가
    ///    서로 다를 때만(private/public/shared) 지원한다. private 하나에 둘을 붙이면
    ///    한쪽이 조용히 진다 — 실제로 미러만 오가고 **할 일은 양방향으로 한 톨도
    ///    안 건너왔다**(맥 1개 / 아이폰 4개로 갈라져 있었다).
    ///    그래서 둘을 한 스토어로 합쳤다. **다시 갈라놓지 말 것.**
    ///
    ///    파일은 할 일이 들어 있던 쪽(WeekBlocksTodos)을 쓴다 — 그 할 일이 이 기기에만
    ///    있는 유일본이라 옮기지 않고 그 자리에 두는 것이 가장 안전하다.
    ///    루틴·계획은 어차피 iCloud에서 다시 내려온다.
    static let storeName = "WeekBlocksTodos"

    /// 갈라져 있던 시절의 미러 파일. 이제 열지 않는다 (리셋만 이 이름을 겨눈다).
    private static let legacyMirrorStoreName = "WeekBlocksMirror"

    /// 미러를 통째로 버리고 CloudKit에서 다시 받아야 할 때 올리는 토큰.
    ///
    /// CloudKit 환경(Development ↔ Production)이 바뀌면 기존 미러에 남아 있는 존 정보와
    /// 변경 토큰이 새 환경과 맞지 않아 동기화가 조용히 멈춘다. 이 값을 바꾸면 다음 실행에
    /// 미러 파일을 지우고 처음부터 다시 내려받는다.
    ///
    /// ⚠️ 이제 이 store에 iOS가 직접 쓴다(오늘로 배정). 미러를 지우면 **아직 CloudKit에
    ///    올라가지 않은 배정이 유실된다.** 예전처럼 "지워도 안전한 파생 데이터"가 아니다.
    ///    토큰을 올리기 전에 정말 필요한 상황인지 확인할 것.
    private static let mirrorResetToken = "production-2026-07"
    private static let mirrorResetKey = "weekBlocksMirror.resetToken"

    /// WeekBlocks 모델 전용 읽기 컨테이너. 실패 시 nil(미로그인·권한·entitlement 불일치 등).
    private let container: ModelContainer?

    /// 컨테이너 생성이 실패했을 때의 사유. 화면이 그냥 비어 보이는 것과
    /// 연동 자체가 끊긴 것을 구분하기 위해 보관한다.
    private(set) var lastErrorDescription: String?

    /// 루틴·계획·할 일이 **한 스토어**에 함께 산다. 맥 '무지개 공방'과 같은 여섯 타입이다.
    static let schema = Schema([Routine.self, PlanBlock.self, BacklogItem.self,
                                RoutineOccurrence.self, BacklogCategory.self, QuotaPlacement.self])

    /// 앱 전체가 함께 쓰는 단 하나의 컨테이너. 할 일 화면도 이것을 꽂아 쓴다.
    /// (→ ScheduleDensityApp.todoContainer)
    static let sharedContainer: ModelContainer? = {
        resetMirrorIfTokenChanged()
        do {
            let container = try makeContainer(schema)
            CloudDiagnostics.todoStoreMode = .cloud
            print("✅ [WeekBlocks] 컨테이너 준비됨 — 한 스토어(\(storeName)), container=\(containerID)")
            return container
        } catch {
            print("⚠️ [WeekBlocks] CloudKit 컨테이너 실패, 로컬 전용으로 전환: \(error)")
            CloudDiagnostics.todoStoreMode = .localOnly
            CloudDiagnostics.todoStoreError = String(describing: error)
            let local = ModelConfiguration(storeName, schema: schema,
                                           groupContainer: .none, cloudKitDatabase: .none)
            return try? ModelContainer(for: schema, configurations: [local])
        }
    }()

    init() {
        self.container = Self.sharedContainer
        if self.container == nil {
            self.lastErrorDescription = CloudDiagnostics.todoStoreError ?? "컨테이너 생성 실패"
            print("⚠️ [WeekBlocks] 컨테이너 없음 — 계획도 할 일도 읽지 못한다")
        }
    }

    private static func makeContainer(_ schema: Schema) throws -> ModelContainer {
        // ⚠️ 반드시 별도 store 파일을 지정한다. 이름을 비우면 Event 스토어와 같은
        //    default.store 로 떨어져 한 파일에서 충돌한다(ZEVENT 손상·CloudKit 미러링 오염).
        // ⚠️ groupContainer: .none — App Group entitlement(위젯용)가 붙으면 SwiftData
        //    기본 저장 위치가 App Group 컨테이너로 바뀐다. resetMirrorIfTokenChanged가
        //    지우는 경로(FileManager 기준 앱 샌드박스)와 어긋나 미러 리셋이 무력화된다.
        let config = ModelConfiguration(
            storeName,
            schema: schema,
            groupContainer: .none,
            cloudKitDatabase: .private(containerID)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// 갈라져 있던 시절의 미러 파일을 치운다. 컨테이너를 만들기 **전에** 호출해야 한다.
    ///
    /// ⚠️ 지우는 대상은 이제 쓰지 않는 `WeekBlocksMirror`뿐이다.
    ///    합쳐진 스토어(WeekBlocksTodos)는 **절대 지우지 않는다** — 그 안의 할 일이
    ///    iCloud에 아직 없는 유일본일 수 있다.
    private static func resetMirrorIfTokenChanged() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: mirrorResetKey) != mirrorResetToken else { return }

        let fm = FileManager.default
        guard let supportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // 경로를 못 구하면 토큰을 세우지 않고 다음 실행에 재시도한다.
            print("⚠️ [WeekBlocks] Application Support 경로를 찾지 못해 미러 리셋을 건너뜀")
            return
        }

        // SwiftData가 store 옆에 만드는 부속 파일까지 함께 지워야 잔여 상태가 남지 않는다.
        let targets = ["\(legacyMirrorStoreName).store",
                       "\(legacyMirrorStoreName).store-wal",
                       "\(legacyMirrorStoreName).store-shm"]
        var removed: [String] = []
        for name in targets {
            let url = supportURL.appendingPathComponent(name)
            guard fm.fileExists(atPath: url.path) else { continue }
            do {
                try fm.removeItem(at: url)
                removed.append(name)
            } catch {
                print("⚠️ [WeekBlocks] 미러 파일 삭제 실패(\(name)): \(error)")
            }
        }

        defaults.set(mirrorResetToken, forKey: mirrorResetKey)
        print("🧹 [WeekBlocks] 미러 리셋(token=\(mirrorResetToken)) — 삭제: "
              + (removed.isEmpty ? "없음(새 설치)" : removed.joined(separator: ", ")))
    }

    /// 컨테이너가 준비되었는지(=연동 가능 상태인지).
    var isAvailable: Bool { container != nil }

    // MARK: - 계획 읽기

    /// 그 날 계획에 올라 있는 블록들의 제목.
    ///
    /// 이제 여기 들어오는 것은 **사람이 맥에서 잡은 약속뿐이다.** 이 앱이 마감을 보고
    /// 자동으로 올리던 그림자는 없앴다(위 헤더 참조). 위젯 배지가 이 값을 쓴다.
    ///
    /// ⚠️ 제목으로 맞추므로 같은 제목의 할 일이 둘이면 배지가 함께 켜진다(알려진 한계).
    ///    할 일과 블록을 잇는 열쇠가 스키마에 생기면 그때 정확해진다.
    func titlesAssigned(to date: Date = Date()) -> Set<String> {
        guard let container else { return [] }
        let key = Self.dayKey(for: date)
        let context = ModelContext(container)
        let blocks = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []
        return Set(blocks.filter { Self.matches($0, key: key) }.map(\.title))
    }

    /// **오늘 계획을 기간에 맞춘다.** 사람이 누르는 자리는 상세의 시작일·끝나는 날 하나뿐이고,
    /// 계획 블록은 그 날짜를 따라오는 그림자다 (→ `TodoWhen`).
    ///
    /// ⚠️ 자동으로 **지우는** 것이 위험한 자리다. 맥에서 손으로 만든 블록까지 제목이 같다는
    ///    이유로 지우면, 사람이 아무것도 안 눌렀는데 계획이 사라진다. 그래서 **이 앱이
    ///    올려 둔 것만** 기억해 두고(아래 `autoAssignedKey`), 그중 기간에서 빠진 것만 내린다.
    ///    맥에서 만든 블록은 이 목록에 없으므로 끝까지 건드리지 않는다.
    ///
    /// - Parameter wanted: 오늘 계획에 있어야 할 (제목, 시간)들.
    func syncToday(_ wanted: [(title: String, hours: Double)]) {
        guard container != nil else { return }
        let wantedTitles = Set(wanted.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty })
        let mine = Self.autoAssignedTitles()

        // 기간에서 빠진 것 내리기 — 이 앱이 올린 것만.
        for title in mine.subtracting(wantedTitles) { unassign(title: title) }

        // 기간에 새로 들어온 것 올리기. 이미 같은 제목의 블록이 있으면 assign이 알아서 넘어간다.
        let already = titlesAssigned()
        for entry in wanted {
            let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !already.contains(title) else { continue }
            assign(title: title, durationHours: entry.hours)
        }
        Self.setAutoAssignedTitles(wantedTitles)
    }

    /// 이 앱이 오늘 계획에 올려 둔 제목들. 날이 바뀌면 빈 집합에서 다시 시작한다 —
    /// 어제 올린 것은 어제 계획이지, 오늘 내릴 대상이 아니다.
    private static func autoAssignedTitles() -> Set<String> {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: autoAssignedDayKey) == todayKey() else { return [] }
        return Set(defaults.stringArray(forKey: autoAssignedKey) ?? [])
    }

    private static func setAutoAssignedTitles(_ titles: Set<String>) {
        let defaults = UserDefaults.standard
        defaults.set(todayKey(), forKey: autoAssignedDayKey)
        defaults.set(Array(titles), forKey: autoAssignedKey)
    }

    private static let autoAssignedKey = "weekBlocks.autoAssignedToday"
    private static let autoAssignedDayKey = "weekBlocks.autoAssignedDay"

    private static func todayKey() -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// 할 일을 그 날짜의 계획 블록으로 배정한다. 이미 있으면 아무것도 하지 않고 true.
    @discardableResult
    func assign(title: String, durationHours: Double, to date: Date = Date()) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        guard let container else {
            print("⛔️ [WeekBlocks] 컨테이너 없음 — 배정 실패. 사유: \(lastErrorDescription ?? "알 수 없음")")
            return false
        }

        let key = Self.dayKey(for: date)
        let context = ModelContext(container)
        let blocks = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []
        if blocks.contains(where: { Self.matches($0, key: key) && $0.title == title }) {
            print("ℹ️ [WeekBlocks] 이미 배정됨: \(title)")
            return true
        }

        context.insert(PlanBlock(
            day: DayOfWeek(rawValue: key.day) ?? .mon,
            timeBand: Self.timeBand(for: date),
            durationHours: max(0, durationHours),
            title: title,
            successCriteria: "",
            deliverable: "",
            weekStartDate: key.weekStart,
            concreteVerified: false
        ))

        do {
            try context.save()
        } catch {
            print("⚠️ [WeekBlocks] 배정 저장 실패: \(error)")
            return false
        }
        print("✅ [WeekBlocks] 배정: \(title) → \(key.day)요일(월=0)")
        NotificationCenter.default.post(name: .weekBlocksPlanDidChange, object: nil)
        return true
    }

    /// 그 날짜의 같은 제목 블록을 지운다(배정 취소).
    @discardableResult
    func unassign(title: String, from date: Date = Date()) -> Bool {
        guard let container else { return false }
        let key = Self.dayKey(for: date)
        let context = ModelContext(container)
        let blocks = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []
        let victims = blocks.filter { Self.matches($0, key: key) && $0.title == title }
        guard !victims.isEmpty else { return false }

        for block in victims { context.delete(block) }
        do {
            try context.save()
        } catch {
            print("⚠️ [WeekBlocks] 배정 취소 저장 실패: \(error)")
            return false
        }
        print("🗑️ [WeekBlocks] 배정 취소: \(title) (\(victims.count)개)")
        NotificationCenter.default.post(name: .weekBlocksPlanDidChange, object: nil)
        return true
    }

    // MARK: - 날짜 열쇠

    /// (그 주 월요일 00:00, 월=0 기준 요일).
    private static func dayKey(for date: Date) -> (weekStart: Date, day: Int) {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)   // 1=일 … 7=토
        return (date.weekStart(), (weekday + 5) % 7)        // 월=0 … 일=6
    }

    /// 배정 시각이 속한 시간대. 맥앱 `timeBand(for:)`와 같은 경계를 쓴다.
    private static func timeBand(for date: Date) -> TimeBand {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12:  return .morning
        case 12..<18: return .afternoon
        case 18..<23: return .evening
        default:      return .night
        }
    }

    private static func matches(_ block: PlanBlock, key: (weekStart: Date, day: Int)) -> Bool {
        block.dayRaw == key.day
            && Calendar.current.isDate(block.weekStartDate, inSameDayAs: key.weekStart)
    }


    // MARK: - 하루 읽기 (타임라인용)

    /// 그 날 하루를 그리는 데 필요한 모든 것. 맥 타임라인과 같은 입력이다.
    struct DayInput {
        var fixedRoutines: [Routine] = []
        var quotaRoutines: [Routine] = []
        var blocks: [PlanBlock] = []
        var routineStartOverride: [String: Double] = [:]
        var quotaPlacement: [String: [Int: Double]] = [:]
        var quotaHidden: [String: Set<Int>] = [:]
        /// 맥 데이터를 아예 못 읽는 상태(iCloud 미로그인 등).
        var isAvailable = false
    }

    /// 그 날짜의 루틴·계획·요일별 배치를 한 번에 읽는다.
    /// 맥에서 숨긴 루틴/끼니는 처음부터 빼고 준다 — iOS에는 '되살리기'가 없어서
    /// 유령 블록을 보여줄 이유가 없다.
    func dayInput(for date: Date) -> DayInput {
        guard let container else { return DayInput() }
        let key = Self.dayKey(for: date)
        let context = ModelContext(container)

        let allRoutines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let allBlocks = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []
        let occurrences = (try? context.fetch(FetchDescriptor<RoutineOccurrence>())) ?? []
        let placements = (try? context.fetch(FetchDescriptor<QuotaPlacement>())) ?? []

        let dayOccurrences = occurrences.filter {
            $0.dayRaw == key.day && Calendar.current.isDate($0.weekStartDate, inSameDayAs: key.weekStart)
        }
        let dayPlacements = placements.filter {
            $0.dayRaw == key.day && Calendar.current.isDate($0.weekStartDate, inSameDayAs: key.weekStart)
        }

        var input = DayInput()
        input.isAvailable = true

        // 고정 루틴은 그 주·요일에 배치(occurrence)가 있는 것만 선다.
        // 배치 기록이 아예 없는 주라면 루틴의 요일 마스크로 판단한다(맥이 아직 만들지 않은 주).
        let hasOccurrences = !dayOccurrences.isEmpty
        let hiddenNames = Set(dayOccurrences.filter(\.hidden).map(\.routineName))
        let placedNames = Set(dayOccurrences.filter { !$0.hidden }.map(\.routineName))
        let weekday = DayOfWeek(rawValue: key.day) ?? .mon

        for routine in allRoutines {
            switch routine.kind {
            case .fixed:
                guard !hiddenNames.contains(routine.name) else { continue }
                let onThisDay = hasOccurrences
                    ? placedNames.contains(routine.name)
                    : routine.selectedDays.contains(weekday)
                if onThisDay { input.fixedRoutines.append(routine) }
            case .quota:
                input.quotaRoutines.append(routine)
            }
        }

        for occurrence in dayOccurrences where occurrence.startHourOverride >= 0 {
            input.routineStartOverride[occurrence.routineName] = occurrence.startHourOverride
        }
        for placement in dayPlacements {
            if placement.hidden {
                input.quotaHidden[placement.routineName, default: []].insert(placement.sessionIndex)
            } else {
                input.quotaPlacement[placement.routineName, default: [:]][placement.sessionIndex] = placement.startHour
            }
        }

        input.blocks = allBlocks.filter { Self.matches($0, key: key) }
        return input
    }

    /// WeekBlocks 계획 → 밀도 시각화용 Event 배열(메모리 전용).
    /// **루틴은 종류를 가리지 않고 전부 제외**하고, 계획 블록만 넘긴다.
    /// 컨테이너가 없거나 데이터가 비어 있으면 빈 배열.
    /// 미러가 지금 들고 있는 것. 설정 > 동기화 진단이 그대로 보여준다.
    /// 0/0이면 맥에서 아무것도 안 내려온 것 — 계정이 다르거나 iCloud가 안 붙은 것이다.
    func mirrorCounts() -> (routines: Int, blocks: Int) {
        guard let container else { return (0, 0) }
        let context = ModelContext(container)
        return ((try? context.fetchCount(FetchDescriptor<Routine>())) ?? 0,
                (try? context.fetchCount(FetchDescriptor<PlanBlock>())) ?? 0)
    }

    func loadVisualEvents(rangeStart: Date, rangeEnd: Date) -> [Event] {
        guard let container else {
            print("⛔️ [WeekBlocks] 컨테이너 없음 — 계획을 읽지 않음. 사유: \(lastErrorDescription ?? "알 수 없음")")
            return []
        }
        let context = ModelContext(container)

        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let blocks = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []

        // 어디서 비는지 한 줄로 판별하기 위한 계측:
        //  - 0/0 이면 미러가 아직 안 내려왔거나(첫 동기화 대기) CloudKit 환경/계정이 다른 것.
        //  - 값이 있는데 화면이 비면 아래 withinRoutine 필터나 날짜 범위 문제.
        print("📥 [WeekBlocks] 미러 조회: routines=\(routines.count)(전부 무지개에서 제외), "
              + "blocks=\(blocks.count), 범위=\(rangeStart)~\(rangeEnd)")

        // 루틴은 종류를 가리지 않고 전부 무지개에서 뺀다.
        //  - 고정(수면·운동 등): 매주 같은 자리에 똑같이 깔린다.
        //  - 쿼터(식사 등): 시각이 유연해서 7일 평균 부하 밴드로 온 요일에 깔린다.
        // 어느 쪽이든 매일 똑같이 바닥에 깔려, 정작 봐야 할 '이번 주에 정한 일'의 밀도를 덮는다.
        // 맥 '무지개 공방' 타임라인에는 그대로 남는다 — iOS 무지개에서만 걸러낸다.
        // (어댑터의 루틴 변환은 그대로 두고 여기서 안 넘기기만 한다 — 되살리기 쉽게.)
        let routineInputs: [WBRoutineInput] = []

        let blockInputs: [WBBlockInput] = blocks.compactMap { b in
            // '루틴 안' 일정은 자유시간을 추가 소비하지 않으므로 밀도에서 제외.
            guard !b.withinRoutine else { return nil }
            return WBBlockInput(
                title: b.title,
                weekStartDate: b.weekStartDate,
                dayOffset: b.day.rawValue,
                durationHours: b.durationHours
            )
        }

        let visual = WeekBlocksAdapter.makeVisualEvents(
            routines: routineInputs,
            blocks: blockInputs,
            // 루틴을 안 넘기므로 반복을 펼칠 기준일·주 수는 결과에 영향이 없다.
            referenceDate: rangeStart,
            weeks: 1
        )

        let skippedWithinRoutine = blocks.count - blockInputs.count
        print("🧮 [WeekBlocks] 변환 결과: 시각화 이벤트=\(visual.count) "
              + "(루틴 밖 일정=\(blockInputs.count), '루틴 안'이라 제외=\(skippedWithinRoutine))")

        // WBVisualEvent → Event (insert 금지, 시각화 입력용 임시 객체)
        return visual.map { v in
            Event(
                title: v.title,
                startDate: v.startDate,
                endDate: v.endDate,
                color: v.colorHex,
                hoursPerDay: v.hoursPerDay,
                selectedWeekdays: v.selectedWeekdays,
                importance: EventImportance(rawValue: v.importance) ?? .medium
            )
        }
    }
}
