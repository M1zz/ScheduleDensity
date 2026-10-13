//
//  RainbowBridge.swift
//  ScheduleDensityApp
//
//  **무지개 일정(`Event`, 이 기기 전용) ↔ 함께 쓰는 사본(`RainbowEvent`, 맥과 공용) 다리.**
//
//  `Event` 스토어는 iCloud 사본이 없는 유일본이다. 그래서 옮기지 않고 그대로 두고, 공용 스토어에
//  사본을 하나씩 세워 두 쪽을 맞춘다. 맥은 사본만 읽고 쓴다 (→ RainbowEvent.swift).
//
//  짝은 장부(links.json)에 적는다: `Event`의 이름(persistentModelID) → 사본의 uuid, 마지막으로 맞춘 내용.
//  `Event` 스키마는 건드리지 않는다 — 칸 하나 더하는 것도 이 기기 유일본의 마이그레이션이다.
//
//  맞추는 규칙 (한 번 돌 때마다, 몇 번을 돌아도 결과가 같다):
//   1. 짝이 있고 둘 다 있다 → 마지막으로 맞춘 내용과 견주어 바뀐 쪽을 다른 쪽에 옮긴다.
//      ⚠️ 둘 다 바뀌었으면 **어느 기기 것이 이길지 여기서 정할 수 없다.** 아이폰이 둘이면 두 폰이 저마다
//         '이 기기 것'을 사본에 올리고, iCloud에 나중에 닿은 저장이 남는다. 진 폰은 다음에 돌 때 그 값을
//         '저쪽에서 고쳤다'로 받아들인다 — 그래서 **이 기기가 올린 값이 저쪽 값으로 덮일 때는
//         덮이기 전에 원본을 RainbowBridge/Conflicts/에 JSON으로 떠 둔다.** 덮는 쪽도 저쪽 값을 떠 둔다.
//   2. 사본에 '지움' 표가 있다 → 맥에서 지웠다. 이 기기 원본도 지운다 — **지우기 전에 JSON으로 떠 둔다.**
//   3. 사본이 표 없이 사라졌다 → 지운 게 아니다(미러 다시 받기 등). 원본에서 사본을 다시 세운다.
//   4. 원본이 사라졌다 → 이 기기에서 지웠다. 사본에 '지움' 표를 찍는다.
//      ⚠️ 한꺼번에 많이 사라졌으면(스토어가 비어 열린 것일 수 있다) 표를 찍지 않고 기다린다.
//         사람이 지운 것은 `willDelete`로 미리 알려 오므로 이 가드에 안 걸린다.
//   5. 짝 없는 원본 → 같은 내용의 짝 없는 사본이 있으면 잇고(장부를 잃었을 때), 없으면 사본을 만든다.
//   6. 장부에 한 번도 오른 적 없는 사본 → 맥에서 만든 것. 원본을 만든다.
//      ⚠️ 단, 다른 아이폰이 **같은 일정을 이미 갖고 있다가** 저마다 사본을 세운 것이면(옛 iCloud 복원으로
//         두 폰을 맞춰 둔 경우) 원본을 또 만들면 네 기기 모두 두 벌이 된다. 내 사본과 이어진 원본이
//         같은 내용(또는 같은 할 일의 기한)이면 **uuid가 작은 사본 하나로 잇고** 진 사본 행은 표 없이 지운다.
//         두 폰이 같은 규칙으로 같은 쪽을 고르므로, 상대 폰도 자기 원본을 이긴 사본에 다시 잇는다.
//   7. 같은 할 일(todoToken)에 이어진 짝이 둘 넘으면 uuid가 작은 것만 남기고 나머지 사본에 '지움' 표를
//      찍는다 → 2번으로 각 기기의 남는 원본이 지워진다(백업 뒤). 두 폰이 같은 할 일에 따로 기한을 정한 경우.
//
//  날짜: 사본에는 **적은 기기의 그날 0시**가 실린다 (맥 RainbowLane도 같다). 시간대가 다른 기기가 적은 값을
//  그냥 startOfDay로 자르면 하루 당겨지므로, 사본에서 읽을 때는 **가장 가까운 0시**로 맞춘다 (→ sharedDay).
//

import Foundation
import SwiftData
import CoreData

extension Notification.Name {
    /// 다리가 이 기기의 무지개 일정을 바꿨다 (맥에서 온 것). 무지개를 다시 그린다.
    static let rainbowBridgeDidApply = Notification.Name("rainbowBridgeDidApply")
}

@MainActor
final class RainbowBridge {
    static let shared = RainbowBridge()

    private var eventContainer: ModelContainer?
    private var sharedContainer: ModelContainer?
    private var observers: [NSObjectProtocol] = []
    private var pending: Task<Void, Never>?
    /// 맞추는 중이다. 이때 일어나는 저장은 다시 맞출 까닭이 아니다.
    private var applying = false
    /// 사람이 이 기기에서 지운 원본들 (→ `willDelete`). 많이 사라졌다는 가드를 건너뛴다.
    private var intentionalDeletes: Set<String> = []

    private init() {}

    // MARK: 장부

    struct Link: Codable, Equatable {
        var uuid: String
        /// 마지막으로 두 쪽이 같았던 내용 (→ `fingerprint`).
        var fingerprint: String
        /// 마지막으로 맞춘 값이 **이 기기가 사본에 올린 것**이다. 그 값이 저쪽 값으로 덮이면
        /// 동시 수정에서 진 것일 수 있어, 덮기 전에 떠 둔다 (→ 1번). 옛 장부에는 없다(nil = 아님).
        var pushed: Bool? = nil
    }

    struct Ledger: Codable, Equatable {
        /// Event 이름 → 짝.
        var links: [String: Link] = [:]
        /// 한 번이라도 짝이 있었던 사본 uuid. 원본이 사라진 뒤에도 남겨, 맥에서 만든 것으로 착각하지 않게.
        var knownUUIDs: Set<String> = []
    }

    /// 시험에서만 바꾼다.
    nonisolated(unsafe) static var directoryOverride: URL?
    static var directory: URL { directoryOverride ?? URL.applicationSupportDirectory.appending(path: "RainbowBridge") }
    private static var ledgerURL: URL { directory.appending(path: "links.json") }

    /// 읽어 둔 장부. 화면(TodoEventBridge)이 자주 묻기 때문에 파일을 매번 읽지 않는다.
    private var cachedLedger: Ledger?

    private func loadLedger() -> Ledger {
        if let cachedLedger { return cachedLedger }
        guard let data = try? Data(contentsOf: Self.ledgerURL),
              let ledger = try? JSONDecoder().decode(Ledger.self, from: data) else { return Ledger() }
        cachedLedger = ledger
        return ledger
    }

    private func saveLedger(_ ledger: Ledger) {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(ledger).write(to: Self.ledgerURL, options: .atomic)
            cachedLedger = ledger
        } catch {
            print("❌ [RainbowBridge] 장부 저장 실패: \(error)")
        }
    }

    // MARK: 붙이기

    func attach(eventContainer: ModelContainer, sharedContainer: ModelContainer) {
        guard self.eventContainer == nil else { return }
        self.eventContainer = eventContainer
        self.sharedContainer = sharedContainer

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, !self.applying, let ctx = note.object as? ModelContext,
                      ctx.container === self.eventContainer || ctx.container === self.sharedContainer else { return }
                self.schedule(after: 1)
            }
        })
        observers.append(center.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.schedule(after: 3) }
        })
        schedule(after: 0.5)
    }

    private func schedule(after seconds: Double) {
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    /// 사람이 이 일정들을 지우려 한다. 지운 뒤 맞출 때 맥 쪽에도 '지움' 표를 찍는다.
    func willDelete(_ events: [Event]) {
        for e in events where e.modelContext != nil { intentionalDeletes.insert(Self.key(of: e)) }
    }

    /// 같은 할 일에 일정이 여럿일 때 **남길 하나** (→ 7번, TodoEventBridge.event(for:)).
    /// 다리가 남기는 쪽과 같게 고른다 — 사본 uuid가 작은 것, 아직 사본이 없는 것은 그 뒤.
    /// 그래야 합쳐지기 전 몇 초 동안 화면이 본 기한과 합쳐진 뒤의 기한이 같다.
    func preferred(among events: [Event]) -> Event? {
        guard events.count > 1 else { return events.first }
        let links = loadLedger().links
        return events.min { a, b in
            let ua = links[Self.key(of: a)]?.uuid, ub = links[Self.key(of: b)]?.uuid
            switch (ua, ub) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return Self.key(of: a) < Self.key(of: b)
            }
        }
    }

    // MARK: 맞추기

    static func key(of event: Event) -> String { String(describing: event.persistentModelID) }

    /// 두 쪽이 같은지 견줄 글자. 칸이 하나라도 다르면 다르다.
    /// 날짜는 이미 이 기기의 그날 0시로 맞춰 넘긴다 (원본은 `startOfDay`, 사본은 `sharedDay`).
    static func fingerprint(title: String, start: Date, end: Date, color: String, hours: Double,
                            weekdays: [Int]?, pattern: [Bool]?, importance: String,
                            infinite: Bool, excluded: Set<Date>, todo: String?, repeatWeeks: Int = 1,
                            sessions: Data? = nil) -> String {
        func day(_ d: Date) -> String { String(Int(d.timeIntervalSince1970)) }
        // ⚠️ 매주(1)는 글자에 넣지 않는다 — 장부에 남은 옛 지문과 그대로 같아야 '고쳤다'로 읽지 않는다.
        let weekdaysText = (weekdays.map { $0.sorted().map(String.init).joined(separator: ",") } ?? "-")
            + (pattern == nil && repeatWeeks > 1 ? "/\(repeatWeeks)w" : "")
            + (sessions.map { "/s:" + $0.base64EncodedString() } ?? "")
        return [
            title,
            day(start), infinite ? "inf" : day(end),
            color.uppercased(),
            String(format: "%.4f", hours),
            weekdaysText,
            pattern.map { $0.map { $0 ? "1" : "0" }.joined() } ?? "-",
            importance,
            excluded.map(day).sorted().joined(separator: ","),
            todo ?? "-",
        ].joined(separator: "|")
    }

    static func fingerprint(_ e: Event) -> String {
        let cal = Calendar.current
        return fingerprint(title: e.title, start: cal.startOfDay(for: e.startDate), end: cal.startOfDay(for: e.endDate),
                           color: e.color, hours: e.hoursPerDay,
                           weekdays: e.selectedWeekdays, pattern: e.weeklyPattern, importance: e.importanceRaw,
                           infinite: e.isInfinite, excluded: e.excludedDates, todo: e.todoToken,
                           repeatWeeks: e.repeatWeeks, sessions: e.sessionsData)
    }

    static func fingerprint(_ r: RainbowEvent) -> String {
        fingerprint(title: r.title, start: sharedDay(r.startDate), end: sharedDay(r.endDate),
                    color: r.colorHex, hours: r.hoursPerDay,
                    weekdays: r.selectedWeekdays, pattern: r.weeklyPattern, importance: r.importanceRaw,
                    infinite: r.isInfinite, excluded: sharedExcluded(r), todo: r.todoToken,
                    repeatWeeks: r.repeatWeeks, sessions: r.sessionsData)
    }

    // MARK: 날짜 — 시간대

    /// 사본에 실린 날짜를 이 기기의 그날 0시로.
    ///
    /// 사본의 날짜는 **적은 기기의 그날 0시**다 (아이폰 `copy(_:into:)`도, 맥 RainbowLane.save도
    /// `startOfDay`로 적는다). 같은 시간대면 그대로 0시지만, 서울 0시는 런던에서 전날 15시다.
    /// 그걸 `startOfDay`로 자르면 하루 당겨진다. **가장 가까운 0시**로 맞추면 반나절(12시간) 안쪽의
    /// 시간대 차이는 양쪽 어느 방향이든 같은 날로 읽힌다. 같은 시간대 값은 지금과 똑같이 읽힌다.
    /// ⚠️ 0시로 적힌 값에만 쓴다. 이 기기 원본(`Event`)은 시각이 붙어 올 수 있어 `startOfDay`로 자른다.
    /// ⚠️ 저장 꼴(그날 0시)은 바꾸지 않는다 — 맥과 RainbowEvent.spans/occurs가 0시와 날것으로 견준다.
    nonisolated static func sharedDay(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d.addingTimeInterval(12 * 3600))
    }

    /// 사본의 빼 둔 날. `RainbowEvent.excludedDates`는 읽을 때 `startOfDay`로 잘라 버리므로 날것을 읽는다.
    nonisolated static func sharedExcluded(_ r: RainbowEvent) -> Set<Date> {
        guard let data = r.excludedDatesData,
              let dates = try? JSONDecoder().decode([Date].self, from: data) else { return [] }
        return Set(dates.map(sharedDay))
    }

    static func copy(_ e: Event, into r: RainbowEvent) {
        r.title = e.title
        r.startDate = Calendar.current.startOfDay(for: e.startDate)
        r.endDate = Calendar.current.startOfDay(for: e.endDate)
        r.colorHex = e.color
        r.hoursPerDay = e.hoursPerDay
        r.selectedWeekdays = e.selectedWeekdays
        r.weeklyPattern = e.weeklyPattern
        r.repeatWeeks = e.repeatWeeks
        r.sessionsData = e.sessionsData
        r.importanceRaw = e.importanceRaw
        r.isInfinite = e.isInfinite
        r.excludedDates = e.excludedDates
        r.todoToken = e.todoToken
        r.updatedAt = Date()
    }

    static func copy(_ r: RainbowEvent, into e: Event) {
        e.title = r.title
        e.startDate = sharedDay(r.startDate)
        e.endDate = sharedDay(r.endDate)
        e.color = r.colorHex
        e.hoursPerDay = r.hoursPerDay
        e.selectedWeekdays = r.selectedWeekdays
        e.weeklyPattern = r.weeklyPattern
        e.repeatWeeks = max(1, r.repeatWeeks)
        e.sessionsData = r.sessionsData
        e.importanceRaw = r.importanceRaw
        e.isInfinite = r.isInfinite
        e.excludedDates = sharedExcluded(r)
        e.todoToken = r.todoToken
    }

    /// 같은 uuid 행이 여럿일 때 `a`를 `b`보다 먼저 고르는가. **어느 기기에서나 같은 행을 고르게**
    /// 행 자체의 값으로만 정한다 — '지움' 표가 있는 행 → 나중에 고친 행 → 내용(날것) 순.
    /// (가져온 순서로 고르면 기기마다 다른 행을 보고, 한 폰은 지웠다 · 한 폰은 고쳤다로 갈린다.)
    static func prefers(_ a: RainbowEvent, over b: RainbowEvent) -> Bool {
        if a.isRemoved != b.isRemoved { return a.isRemoved }
        if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
        return rawContent(a) < rawContent(b)
    }

    /// 시간대와 상관없는 날것의 내용. 행을 고르는 마지막 기준으로만 쓴다.
    private static func rawContent(_ r: RainbowEvent) -> String {
        [r.title, String(r.startDate.timeIntervalSince1970), String(r.endDate.timeIntervalSince1970),
         r.colorHex, String(r.hoursPerDay), r.importanceRaw, String(r.isInfinite), r.todoToken ?? "-",
         r.selectedWeekdaysData?.base64EncodedString() ?? "-", r.weeklyPatternData?.base64EncodedString() ?? "-",
         String(r.repeatWeeks), r.sessionsData?.base64EncodedString() ?? "-", r.excludedDatesData?.base64EncodedString() ?? "-", r.originInstallID,
         String(r.createdAt.timeIntervalSince1970)].joined(separator: "|")
    }

    /// 한꺼번에 이만큼 넘게, 그리고 절반 넘게 사라졌으면 사람이 지운 게 아니라고 본다.
    private static let massLossThreshold = 3

    func reconcile() {
        guard let eventContext = eventContainer?.mainContext,
              let sharedContext = sharedContainer?.mainContext else { return }
        applying = true
        defer { applying = false }

        // 원본: 스토어에 실제로 있는 것만 (뷰모델 fetchEvents는 맥 계획 미러까지 섞는다).
        let events = (try? eventContext.fetch(FetchDescriptor<Event>())) ?? []
        let copies = (try? sharedContext.fetch(FetchDescriptor<RainbowEvent>())) ?? []
        var ledger = loadLedger()
        let before = ledger

        var eventByKey: [String: Event] = [:]
        for e in events { eventByKey[Self.key(of: e)] = e }
        // 같은 uuid가 둘이면(동기화 이중 도착, 3번으로 두 폰이 함께 다시 세움) 하나를 고른다.
        // ⚠️ 가져온 순서로 고르지 않는다 — 기기마다 순서가 달라 서로 다른 행을 본다 (→ prefers).
        //    남은 행은 그대로 둔다. 맥이 같은 uuid 행을 정리한다.
        var copyByUUID: [String: RainbowEvent] = [:]
        var rowsByUUID: [String: [RainbowEvent]] = [:]
        for r in copies {
            rowsByUUID[r.uuid, default: []].append(r)
            if let cur = copyByUUID[r.uuid], !Self.prefers(r, over: cur) { continue }
            copyByUUID[r.uuid] = r
        }
        /// uuid 순으로 — 무엇부터 보느냐가 결과를 바꾸는 단계(5-1, 6)가 기기마다 같게.
        let uniqueCopies = copyByUUID.values.sorted { $0.uuid < $1.uuid }

        var eventsChanged = false
        var sharedChanged = false
        var linkedUUIDs = Set(ledger.links.values.map(\.uuid))

        // 5-1. 짝 없는 원본 중, 같은 내용의 짝 없는 사본이 있으면 잇는다 (장부를 잃었거나 스토어가 새로 열렸을 때).
        //      원본이 사라진 짝(4번 후보)의 사본도 여기서 새 원본과 이어질 수 있다 — 그러면 지운 게 아니다.
        let orphanLinkUUIDs = Set(ledger.links.filter { eventByKey[$0.key] == nil }.map(\.value.uuid))
        var freeCopiesByPrint: [String: [RainbowEvent]] = [:]
        for r in uniqueCopies where !r.isRemoved && (!linkedUUIDs.contains(r.uuid) || orphanLinkUUIDs.contains(r.uuid)) {
            freeCopiesByPrint[Self.fingerprint(r), default: []].append(r)
        }
        for e in events where ledger.links[Self.key(of: e)] == nil {
            let fp = Self.fingerprint(e)
            guard var bucket = freeCopiesByPrint[fp], !bucket.isEmpty else { continue }
            let r = bucket.removeFirst()
            freeCopiesByPrint[fp] = bucket
            // 옛 짝(원본이 사라진 쪽)을 걷고 새 원본과 잇는다.
            for (k, link) in ledger.links where link.uuid == r.uuid { ledger.links[k] = nil }
            ledger.links[Self.key(of: e)] = Link(uuid: r.uuid, fingerprint: fp)
            ledger.knownUUIDs.insert(r.uuid)
            linkedUUIDs.insert(r.uuid)
        }

        // 4. 원본이 사라진 짝 → 이 기기에서 지웠다.
        let gone = ledger.links.filter { eventByKey[$0.key] == nil }
        let unexplained = gone.keys.filter { !intentionalDeletes.contains($0) }
        let massLoss = unexplained.count > Self.massLossThreshold && unexplained.count * 2 > ledger.links.count
        if massLoss {
            print("🛑 [RainbowBridge] 원본 \(unexplained.count)개가 한꺼번에 사라졌다 — 지운 것으로 보지 않고 사본에서 되살린다")
        }
        var restoredFromCopies: [(Event, String)] = []
        for (key, link) in gone {
            if massLoss && !intentionalDeletes.contains(key) {
                // 스토어가 비어 열렸거나 원본이 통째로 사라졌다. 사본이 남아 있으면 그걸로 원본을 다시 세운다.
                if let r = copyByUUID[link.uuid], !r.isRemoved {
                    let e = Event(title: r.title, startDate: r.startDate, endDate: r.endDate)
                    Self.copy(r, into: e)
                    eventContext.insert(e)
                    restoredFromCopies.append((e, r.uuid))
                }
                ledger.links[key] = nil
                continue
            }
            if let r = copyByUUID[link.uuid], !r.isRemoved {
                r.deletedAt = Date()
                r.updatedAt = Date()
                sharedChanged = true
            }
            ledger.links[key] = nil
        }
        intentionalDeletes.removeAll()

        if !restoredFromCopies.isEmpty {
            backupLedgerNote(count: restoredFromCopies.count)
            pendingNew += restoredFromCopies
            eventsChanged = true
        }

        // 6-0. 다른 아이폰이 같은 일정에 따로 세운 사본 → 새 원본을 만들지 않고 하나로 잇는다 (→ 머리 주석 6번).
        //      ⚠️ 3번보다 먼저 한다. 상대 폰이 진 사본을 먼저 지워 '표 없이 사라짐'이 되어도, 이긴 사본이
        //         보이면 여기서 다시 이어 3번이 진 사본을 되살리지 않는다.
        let me = TodoSharing.installID
        for r in uniqueCopies where !r.isRemoved && !ledger.knownUUIDs.contains(r.uuid) && !linkedUUIDs.contains(r.uuid)
            && r.originInstallID != me {
            guard let twin = twin(of: r, links: ledger.links, eventByKey: eventByKey, copyByUUID: copyByUUID, me: me)
            else { continue }
            if r.uuid < twin.uuid {
                // 저쪽 사본이 이긴다 — 내 원본을 그 사본에 다시 잇고, 내 사본 행은 표 없이 걷는다.
                // (표를 찍으면 상대 폰의 원본까지 지워진다.)
                let e = twin.event
                if Self.fingerprint(e) != Self.fingerprint(r) {
                    // 같은 할 일에 따로 정한 기한 — 저쪽 값으로 맞추기 전에 이쪽 값을 떠 둔다.
                    guard backup([BackupRow(e)], folder: "Conflicts", reason: "todo-twin") else { continue }
                    Self.copy(r, into: e)
                    eventsChanged = true
                }
                ledger.knownUUIDs.insert(r.uuid)
                ledger.links[twin.key] = Link(uuid: r.uuid, fingerprint: Self.fingerprint(e))
                for row in rowsByUUID[twin.uuid] ?? [] { sharedContext.delete(row) }
                copyByUUID[twin.uuid] = nil
                linkedUUIDs.remove(twin.uuid)
                linkedUUIDs.insert(r.uuid)
                print("🔗 [RainbowBridge] \"\(e.title)\" 다른 아이폰 사본에 다시 이음 — 내 사본은 걷음")
            } else {
                // 내 사본이 이긴다 — 저쪽 사본 행만 걷는다. 저쪽 폰도 같은 규칙으로 내 사본에 다시 잇는다.
                // 장부에 올려 두어 6번이 이 uuid로 원본을 만들지 않게 한다 (저쪽 폰이 3번으로 잠깐 되살려도).
                ledger.knownUUIDs.insert(r.uuid)
                for row in rowsByUUID[r.uuid] ?? [] { sharedContext.delete(row) }
                copyByUUID[r.uuid] = nil
                print("🔗 [RainbowBridge] \"\(r.title)\" 다른 아이폰이 따로 세운 같은 사본을 걷음")
            }
            sharedChanged = true
        }

        // 7. 같은 할 일에 이어진 짝이 여럿 → uuid가 작은 하나만 남긴다. 나머지 사본에 '지움' 표를 찍으면
        //    아래 2번이 이 기기의 남는 원본을 (떠 둔 뒤) 지운다. 상대 폰도 같은 쪽을 남긴다.
        var pairsByTodo: [String: [(key: String, uuid: String)]] = [:]
        for (key, link) in ledger.links {
            guard let e = eventByKey[key], let token = e.todoToken,
                  let r = copyByUUID[link.uuid], !r.isRemoved else { continue }
            pairsByTodo[token, default: []].append((key, link.uuid))
        }
        for (_, pairs) in pairsByTodo where pairs.count > 1 {
            let keep = pairs.min { $0.uuid < $1.uuid }!.uuid
            for p in pairs where p.uuid != keep {
                guard let r = copyByUUID[p.uuid] else { continue }
                r.deletedAt = Date()
                r.updatedAt = Date()
                sharedChanged = true
                print("🔗 [RainbowBridge] \"\(r.title)\" 같은 할 일에 기한이 둘 — 하나로 합침")
            }
        }

        // 1·2·3. 짝이 있고 원본이 있다.
        var removedOriginals: [Event] = []
        for (key, link) in ledger.links {
            guard let e = eventByKey[key] else { continue }
            guard let r = copyByUUID[link.uuid] else {
                // 3. 사본이 표 없이 사라졌다 → 다시 세운다. 같은 uuid로 — 맥이 기억하는 이름이 그대로다.
                let r = RainbowEvent(uuid: link.uuid)
                r.originInstallID = TodoSharing.installID
                Self.copy(e, into: r)
                sharedContext.insert(r)
                copyByUUID[r.uuid] = r
                ledger.links[key]?.fingerprint = Self.fingerprint(e)
                sharedChanged = true
                continue
            }
            if r.isRemoved {
                removedOriginals.append(e)
                continue
            }
            let pe = Self.fingerprint(e), pr = Self.fingerprint(r)
            if pe == pr {
                if link.fingerprint != pe { ledger.links[key]?.fingerprint = pe }
                continue
            }
            if pr != link.fingerprint && pe == link.fingerprint {
                // 저쪽(맥·다른 아이폰)에서 고쳤다.
                // 지금 값이 이 기기가 올린 것이면, 다른 폰과 함께 고쳐 이쪽이 진 것일 수 있다 — 덮기 전에 떠 둔다.
                // 떠 두지 못했으면 덮지 않는다 — 다음에 다시 해 본다.
                if link.pushed == true, !backup([BackupRow(e)], folder: "Conflicts", reason: "overwritten-local") {
                    continue
                }
                Self.copy(r, into: e)
                eventsChanged = true
                ledger.links[key]?.fingerprint = Self.fingerprint(e)
                ledger.links[key]?.pushed = nil
            } else {
                // 이쪽에서 고쳤다 — 또는 둘 다 고쳤다. 둘 다면 저쪽 값을 떠 두고 이쪽 값을 올린다.
                // 이 값이 남는다는 보장은 없다 — 저쪽 폰도 같은 판단으로 자기 값을 올린다 (→ 머리 주석 1번).
                if pr != link.fingerprint {
                    print("⚠️ [RainbowBridge] \"\(e.title)\" 두 기기에서 함께 고침 — 저쪽 값을 떠 두고 이 기기 것을 올린다")
                    backup([BackupRow(r)], folder: "Conflicts", reason: "overwritten-remote")
                }
                Self.copy(e, into: r)
                sharedChanged = true
                ledger.links[key]?.fingerprint = Self.fingerprint(e)
                ledger.links[key]?.pushed = true
            }
        }

        // 2. 맥에서 지운 것 — 지우기 전에 떠 둔다.
        // 떠 두지 못했으면 지우지 않는다 — 다음에 다시 해 본다.
        if !removedOriginals.isEmpty, !backup(removedOriginals.map(BackupRow.init), folder: "Removed", reason: "removed-on-mac") {
            removedOriginals.removeAll()
        }
        if !removedOriginals.isEmpty {
            for e in removedOriginals {
                ledger.links[Self.key(of: e)] = nil
                eventContext.delete(e)
            }
            eventsChanged = true
        }

        // 6. 처음 보는 사본 → 맥에서 만든 것. 원본을 만든다.
        for r in uniqueCopies where copyByUUID[r.uuid] != nil && !r.isRemoved
            && !ledger.knownUUIDs.contains(r.uuid) && !linkedUUIDs.contains(r.uuid) {
            let e = Event(title: r.title, startDate: r.startDate, endDate: r.endDate)
            Self.copy(r, into: e)
            eventContext.insert(e)
            // 이름(persistentModelID)은 저장해야 굳는다. 장부는 저장 뒤에 적는다.
            pendingNew.append((e, r.uuid))
            ledger.knownUUIDs.insert(r.uuid)
            linkedUUIDs.insert(r.uuid)
            eventsChanged = true
        }

        // 5-2. 그래도 짝 없는 원본 → 사본을 만든다.
        var newCopies: [(Event, RainbowEvent)] = []
        for e in events where ledger.links[Self.key(of: e)] == nil && !removedOriginals.contains(where: { $0 === e }) {
            let r = RainbowEvent()
            r.originInstallID = TodoSharing.installID
            r.createdAt = Date()
            Self.copy(e, into: r)
            sharedContext.insert(r)
            newCopies.append((e, r))
            sharedChanged = true
        }

        if eventsChanged {
            do {
                try eventContext.save()
            } catch {
                print("❌ [RainbowBridge] 일정 저장 실패: \(error)")
                pendingNew.removeAll()
                return   // 장부를 안 고친다 — 다음에 같은 일을 다시 한다.
            }
        }
        if sharedChanged {
            do {
                try sharedContext.save()
            } catch {
                print("❌ [RainbowBridge] 사본 저장 실패: \(error)")
                pendingNew.removeAll()
                return
            }
        }

        for (e, r) in newCopies {
            ledger.links[Self.key(of: e)] = Link(uuid: r.uuid, fingerprint: Self.fingerprint(e))
            ledger.knownUUIDs.insert(r.uuid)
        }
        for (e, uuid) in pendingNew {
            ledger.links[Self.key(of: e)] = Link(uuid: uuid, fingerprint: Self.fingerprint(e))
        }
        pendingNew.removeAll()

        if ledger != before {
            saveLedger(ledger)
        }
        if eventsChanged {
            print("🌈 [RainbowBridge] 맥에서 온 변경을 이 기기 일정에 옮겼다")
            NotificationCenter.default.post(name: .rainbowBridgeDidApply, object: nil)
            // 무지개 화면은 이 알림에 이미 다시 그린다 (→ ScheduleViewModel.planChangeObserver).
            NotificationCenter.default.post(name: .weekBlocksPlanDidChange, object: nil)
        }
        if sharedChanged { print("🌈 [RainbowBridge] 이 기기 일정을 맥과 함께 쓰는 사본에 옮겼다") }
    }

    private var pendingNew: [(Event, String)] = []

    /// 사본에서 원본을 되살렸다는 기록. 무슨 일이 있었는지 나중에 알 수 있게 남긴다.
    private func backupLedgerNote(count: Int) {
        let dir = Self.directory.appending(path: "Restored")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let line = "\(Date().ISO8601Format()) restored \(count) events from shared copies\n"
        try? Data(line.utf8).write(to: dir.appending(path: "\(Int(Date().timeIntervalSince1970)).log"), options: .atomic)
    }

    // MARK: 덮거나 지우기 전 백업

    /// 떠 두는 한 줄. 원본(`Event`)도 사본(`RainbowEvent`)도 같은 꼴로 — 옛 Removed/ 파일과 칸이 같다.
    struct BackupRow: Codable {
        var title: String, startDate: Date, endDate: Date, color: String, hoursPerDay: Double
        var selectedWeekdays: [Int]?, weeklyPattern: [Bool]?, importanceRaw: String
        var isInfinite: Bool, excludedDates: [Date], todoToken: String?, cloudKitRecordName: String?
        /// 옛 백업에는 없다 (없으면 매주).
        var repeatWeeks: Int? = nil
        var sessionsData: Data? = nil
        /// 사본에서 뜬 것이면 그 uuid.
        var uuid: String? = nil

        init(_ e: Event) {
            title = e.title; startDate = e.startDate; endDate = e.endDate; color = e.color
            hoursPerDay = e.hoursPerDay; selectedWeekdays = e.selectedWeekdays; weeklyPattern = e.weeklyPattern
            importanceRaw = e.importanceRaw; isInfinite = e.isInfinite
            excludedDates = Array(e.excludedDates).sorted(); todoToken = e.todoToken
            cloudKitRecordName = e.cloudKitRecordName; repeatWeeks = e.repeatWeeks; sessionsData = e.sessionsData
        }

        init(_ r: RainbowEvent) {
            title = r.title; startDate = r.startDate; endDate = r.endDate; color = r.colorHex
            hoursPerDay = r.hoursPerDay; selectedWeekdays = r.selectedWeekdays; weeklyPattern = r.weeklyPattern
            importanceRaw = r.importanceRaw; isInfinite = r.isInfinite
            excludedDates = Array(sharedExcluded(r)).sorted(); todoToken = r.todoToken
            cloudKitRecordName = nil; uuid = r.uuid; repeatWeeks = r.repeatWeeks; sessionsData = r.sessionsData
        }
    }

    /// 덮거나 지우기 전에 JSON으로 떠 둔다. 되돌릴 곳은 여기뿐이다.
    /// `Removed/` = 다른 기기에서 지워 이 기기 원본을 지울 때 · `Conflicts/` = 동시 수정으로 값이 덮일 때.
    @discardableResult
    private func backup(_ rows: [BackupRow], folder: String, reason: String) -> Bool {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let dir = Self.directory.appending(path: folder)
        // 한 번 돌 때 여러 벌을 뜰 수 있어 이름 끝에 짧은 꼬리를 붙인다 — 같은 초에 덮어쓰지 않게.
        let tail = UUID().uuidString.prefix(6)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rows).write(to: dir.appending(path: "\(f.string(from: Date()))_\(reason)_\(rows.count)_\(tail).json"),
                                           options: .atomic)
            return true
        } catch {
            print("❌ [RainbowBridge] \(folder) 백업 실패: \(error)")
            return false
        }
    }

    // MARK: 쌍둥이 — 다른 아이폰이 같은 일정에 따로 세운 사본

    /// 처음 보는 사본 `r`과 같은 일정인, **이 기기가 세운 사본**과 이어진 짝.
    /// 같은 내용이거나, 같은 할 일의 기한이면 쌍둥이로 본다.
    ///
    /// ⚠️ 내 사본(originInstallID == 나)과 이어진 짝만 본다. 남이 세운 사본과 이어진 짝까지 보면,
    ///    한 기기에서 일부러 똑같이 둘 적은 것을 다른 기기가 걷고 → 그 기기가 3번으로 되살리고 →
    ///    다시 걷는 핑퐁이 난다. 두 폰이 저마다 자기 원본에 세운 사본끼리만 쌍둥이다.
    private func twin(of r: RainbowEvent, links: [String: Link], eventByKey: [String: Event],
                      copyByUUID: [String: RainbowEvent], me: String) -> (key: String, event: Event, uuid: String)? {
        let fr = Self.fingerprint(r)
        var found: (key: String, event: Event, uuid: String)?
        for (key, link) in links where link.uuid != r.uuid {
            guard let e = eventByKey[key], let mine = copyByUUID[link.uuid], !mine.isRemoved,
                  mine.originInstallID == me else { continue }
            let sameTodo = r.todoToken != nil && r.todoToken == e.todoToken
            guard sameTodo || Self.fingerprint(e) == fr else { continue }
            // 여럿이면 uuid가 작은 짝 — 사전 순서에 기대지 않게.
            if found == nil || link.uuid < found!.uuid { found = (key, e, link.uuid) }
        }
        return found
    }
}
