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
//      둘 다 바뀌었으면 이 기기 것이 이긴다(저쪽 것은 금고 백업에 남아 있다).
//   2. 사본에 '지움' 표가 있다 → 맥에서 지웠다. 이 기기 원본도 지운다 — **지우기 전에 JSON으로 떠 둔다.**
//   3. 사본이 표 없이 사라졌다 → 지운 게 아니다(미러 다시 받기 등). 원본에서 사본을 다시 세운다.
//   4. 원본이 사라졌다 → 이 기기에서 지웠다. 사본에 '지움' 표를 찍는다.
//      ⚠️ 한꺼번에 많이 사라졌으면(스토어가 비어 열린 것일 수 있다) 표를 찍지 않고 기다린다.
//         사람이 지운 것은 `willDelete`로 미리 알려 오므로 이 가드에 안 걸린다.
//   5. 짝 없는 원본 → 같은 내용의 짝 없는 사본이 있으면 잇고(장부를 잃었을 때), 없으면 사본을 만든다.
//   6. 장부에 한 번도 오른 적 없는 사본 → 맥에서 만든 것. 원본을 만든다.
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

    struct Link: Codable {
        var uuid: String
        /// 마지막으로 두 쪽이 같았던 내용 (→ `fingerprint`).
        var fingerprint: String
    }

    struct Ledger: Codable {
        /// Event 이름 → 짝.
        var links: [String: Link] = [:]
        /// 한 번이라도 짝이 있었던 사본 uuid. 원본이 사라진 뒤에도 남겨, 맥에서 만든 것으로 착각하지 않게.
        var knownUUIDs: Set<String> = []
    }

    /// 시험에서만 바꾼다.
    nonisolated(unsafe) static var directoryOverride: URL?
    static var directory: URL { directoryOverride ?? URL.applicationSupportDirectory.appending(path: "RainbowBridge") }
    private static var ledgerURL: URL { directory.appending(path: "links.json") }

    private func loadLedger() -> Ledger {
        guard let data = try? Data(contentsOf: Self.ledgerURL),
              let ledger = try? JSONDecoder().decode(Ledger.self, from: data) else { return Ledger() }
        return ledger
    }

    private func saveLedger(_ ledger: Ledger) {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(ledger).write(to: Self.ledgerURL, options: .atomic)
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

    // MARK: 맞추기

    static func key(of event: Event) -> String { String(describing: event.persistentModelID) }

    /// 두 쪽이 같은지 견줄 글자. 칸이 하나라도 다르면 다르다.
    static func fingerprint(title: String, start: Date, end: Date, color: String, hours: Double,
                            weekdays: [Int]?, pattern: [Bool]?, importance: String,
                            infinite: Bool, excluded: Set<Date>, todo: String?) -> String {
        let cal = Calendar.current
        func day(_ d: Date) -> String { String(Int(cal.startOfDay(for: d).timeIntervalSince1970)) }
        return [
            title,
            day(start), infinite ? "inf" : day(end),
            color.uppercased(),
            String(format: "%.4f", hours),
            weekdays.map { $0.sorted().map(String.init).joined(separator: ",") } ?? "-",
            pattern.map { $0.map { $0 ? "1" : "0" }.joined() } ?? "-",
            importance,
            excluded.map(day).sorted().joined(separator: ","),
            todo ?? "-",
        ].joined(separator: "|")
    }

    static func fingerprint(_ e: Event) -> String {
        fingerprint(title: e.title, start: e.startDate, end: e.endDate, color: e.color, hours: e.hoursPerDay,
                    weekdays: e.selectedWeekdays, pattern: e.weeklyPattern, importance: e.importanceRaw,
                    infinite: e.isInfinite, excluded: e.excludedDates, todo: e.todoToken)
    }

    static func fingerprint(_ r: RainbowEvent) -> String {
        fingerprint(title: r.title, start: r.startDate, end: r.endDate, color: r.colorHex, hours: r.hoursPerDay,
                    weekdays: r.selectedWeekdays, pattern: r.weeklyPattern, importance: r.importanceRaw,
                    infinite: r.isInfinite, excluded: r.excludedDates, todo: r.todoToken)
    }

    static func copy(_ e: Event, into r: RainbowEvent) {
        r.title = e.title
        r.startDate = Calendar.current.startOfDay(for: e.startDate)
        r.endDate = Calendar.current.startOfDay(for: e.endDate)
        r.colorHex = e.color
        r.hoursPerDay = e.hoursPerDay
        r.selectedWeekdays = e.selectedWeekdays
        r.weeklyPattern = e.weeklyPattern
        r.importanceRaw = e.importanceRaw
        r.isInfinite = e.isInfinite
        r.excludedDates = e.excludedDates
        r.todoToken = e.todoToken
        r.updatedAt = Date()
    }

    static func copy(_ r: RainbowEvent, into e: Event) {
        e.title = r.title
        e.startDate = Calendar.current.startOfDay(for: r.startDate)
        e.endDate = Calendar.current.startOfDay(for: r.endDate)
        e.color = r.colorHex
        e.hoursPerDay = r.hoursPerDay
        e.selectedWeekdays = r.selectedWeekdays
        e.weeklyPattern = r.weeklyPattern
        e.importanceRaw = r.importanceRaw
        e.isInfinite = r.isInfinite
        e.excludedDates = r.excludedDates
        e.todoToken = r.todoToken
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
        // 같은 uuid가 둘이면(두 기기가 같은 때 만든 경우는 없지만 동기화 이중 도착) 먼저 것만 쓴다.
        var copyByUUID: [String: RainbowEvent] = [:]
        for r in copies where copyByUUID[r.uuid] == nil { copyByUUID[r.uuid] = r }

        var eventsChanged = false
        var sharedChanged = false
        var linkedUUIDs = Set(ledger.links.values.map(\.uuid))

        // 5-1. 짝 없는 원본 중, 같은 내용의 짝 없는 사본이 있으면 잇는다 (장부를 잃었거나 스토어가 새로 열렸을 때).
        //      원본이 사라진 짝(4번 후보)의 사본도 여기서 새 원본과 이어질 수 있다 — 그러면 지운 게 아니다.
        let orphanLinkUUIDs = Set(ledger.links.filter { eventByKey[$0.key] == nil }.map(\.value.uuid))
        var freeCopiesByPrint: [String: [RainbowEvent]] = [:]
        for r in copies where !r.isRemoved && (!linkedUUIDs.contains(r.uuid) || orphanLinkUUIDs.contains(r.uuid)) {
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
                // 저쪽(맥)에서 고쳤다.
                Self.copy(r, into: e)
                eventsChanged = true
                ledger.links[key]?.fingerprint = Self.fingerprint(e)
            } else {
                // 이쪽에서 고쳤다 — 또는 둘 다 고쳤다(이쪽이 이긴다).
                if pr != link.fingerprint {
                    print("⚠️ [RainbowBridge] \"\(e.title)\" 두 기기에서 함께 고침 — 이 기기 것을 남긴다")
                }
                Self.copy(e, into: r)
                sharedChanged = true
                ledger.links[key]?.fingerprint = Self.fingerprint(e)
            }
        }

        // 2. 맥에서 지운 것 — 지우기 전에 떠 둔다.
        // 떠 두지 못했으면 지우지 않는다 — 다음에 다시 해 본다.
        if !removedOriginals.isEmpty, !backup(removedOriginals, reason: "removed-on-mac") {
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
        for r in copies where !r.isRemoved && !ledger.knownUUIDs.contains(r.uuid) && !linkedUUIDs.contains(r.uuid) {
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

        if ledger.links.mapValues(\.uuid) != before.links.mapValues(\.uuid)
            || ledger.links.mapValues(\.fingerprint) != before.links.mapValues(\.fingerprint)
            || ledger.knownUUIDs != before.knownUUIDs {
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

    // MARK: 지우기 전 백업

    /// 지우기 전에 원본을 JSON으로 떠 둔다. 지운 쪽은 맥이고 되돌릴 곳은 여기뿐이다.
    @discardableResult
    private func backup(_ events: [Event], reason: String) -> Bool {
        struct Row: Codable {
            var title: String, startDate: Date, endDate: Date, color: String, hoursPerDay: Double
            var selectedWeekdays: [Int]?, weeklyPattern: [Bool]?, importanceRaw: String
            var isInfinite: Bool, excludedDates: [Date], todoToken: String?, cloudKitRecordName: String?
        }
        let rows = events.map {
            Row(title: $0.title, startDate: $0.startDate, endDate: $0.endDate, color: $0.color,
                hoursPerDay: $0.hoursPerDay, selectedWeekdays: $0.selectedWeekdays, weeklyPattern: $0.weeklyPattern,
                importanceRaw: $0.importanceRaw, isInfinite: $0.isInfinite, excludedDates: Array($0.excludedDates).sorted(),
                todoToken: $0.todoToken, cloudKitRecordName: $0.cloudKitRecordName)
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let dir = Self.directory.appending(path: "Removed")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rows).write(to: dir.appending(path: "\(f.string(from: Date()))_\(reason)_\(rows.count).json"),
                                           options: .atomic)
            return true
        } catch {
            print("❌ [RainbowBridge] 지우기 전 백업 실패: \(error)")
            return false
        }
    }
}
