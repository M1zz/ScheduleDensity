//
//  CalendarMirror.swift
//  ScheduleDensityApp
//
//  **고른 캘린더의 일정을 무지개에 늘 비춘다.** 복사하지 않는다.
//
//  '캘린더에서 가져오기'(→ CalendarImportView)는 그 순간의 일정을 무지개 일정으로 한 번
//  베껴 온다. 그 뒤로 캘린더에서 회의가 옮겨지거나 취소돼도 무지개는 모른다. 사람은
//  두 군데를 따로 고쳐야 하고, 안 고치면 무지개가 거짓말을 한다.
//
//  여기서는 무지개를 그릴 때마다 캘린더를 **읽기만** 한다. 맥 계획을 비추는 것과 같은
//  방식이다 (→ WeekBlocksStore.loadVisualEvents). 만든 `Event`는 스토어에 넣지 않는다.
//
//  ⚠️ **한 방향이다.** 캘린더 → 무지개. `EKEventStore`에 저장 계열 호출을 두지 않는다.
//     맥 '무지개 공방'도 같은 약속을 한다 (→ WeekBlocks/CalendarImport.swift).
//
//  ⚠️ 고르는 단위는 **캘린더**다. 한 번 정해 두면 손이 안 가고, '업무만' 같은 실제 쓰임과
//     맞는다. 공휴일·생일 캘린더는 켜지 않는 것이 보통이다 — 그날 나를 붙잡는 일이 아니다.
//

import Foundation
import EventKit

extension Notification.Name {
    /// 비추는 캘린더를 바꿨거나, 캘린더 쪽 일정이 바뀌었다. 무지개를 다시 그린다.
    static let calendarMirrorDidChange = Notification.Name("calendarMirrorDidChange")
}

@Observable
final class CalendarMirror {
    static let shared = CalendarMirror()

    /// 레인 열쇠와 줄 색 이름의 머리. 미러 일정인지 가를 때도 쓴다 (→ `Event.isCalendarMirror`).
    static let keyPrefix = "cal:"

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private static let selectionKey = "calendarMirror.selectedIDs"
    @ObservationIgnored private var changeObserver: NSObjectProtocol?

    private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    /// 비추기로 고른 캘린더(`calendarIdentifier`).
    private(set) var selectedIDs: Set<String>

    var isAuthorized: Bool { status == .fullAccess }
    /// 무지개에 실제로 무언가를 비추는 중인가.
    var isActive: Bool { isAuthorized && !selectedIDs.isEmpty }

    private init() {
        selectedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.selectionKey) ?? [])
        // 캘린더 앱에서 일정을 옮기거나 지우면 온다. 다른 앱(구글 캘린더 동기화 등)이 바꿔도 온다.
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            guard let self, self.isActive else { return }
            NotificationCenter.default.post(name: .calendarMirrorDidChange, object: nil)
        }
    }

    deinit {
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
    }

    // MARK: - 권한

    /// 권한은 **앱 밖(설정 앱)에서** 바뀐다. 화면이 뜰 때마다 다시 읽는다.
    func refreshStatus() {
        status = EKEventStore.authorizationStatus(for: .event)
    }

    @MainActor
    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        refreshStatus()
        if isActive {
            NotificationCenter.default.post(name: .calendarMirrorDidChange, object: nil)
        }
    }

    // MARK: - 고르기

    /// 기기의 모든 일정 캘린더. **읽기 전용 캘린더도 넣는다** — 구독한 회사 캘린더처럼
    /// 고칠 수 없는 캘린더가 오히려 가장 비춰 보고 싶은 것이다.
    func calendars() -> [EKCalendar] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
    }

    func isSelected(_ calendar: EKCalendar) -> Bool {
        selectedIDs.contains(calendar.calendarIdentifier)
    }

    func setSelected(_ calendar: EKCalendar, _ on: Bool) {
        if on { selectedIDs.insert(calendar.calendarIdentifier) }
        else { selectedIDs.remove(calendar.calendarIdentifier) }
        UserDefaults.standard.set(Array(selectedIDs), forKey: Self.selectionKey)
        NotificationCenter.default.post(name: .calendarMirrorDidChange, object: nil)
    }

    // MARK: - 비추기

    /// 그 기간에 고른 캘린더에 있는 일정 → 무지개용 `Event`(메모리 전용).
    ///
    /// - 반복 일정은 **한 줄**로 묶는다. 매주 회의가 여덟 줄로 서면 무지개가 회의로 덮인다.
    ///   요일은 실제로 열린 날에서 읽고, 그 요일인데 안 열린 날(격주·건너뛴 주)은 제외일로 둔다.
    /// - 종일 일정은 시간을 안 잡아먹는다(0시간). 맥과 같다 — 기념일이 한 시간짜리로 들어와
    ///   빈 시간을 깎던 것을 맥에서 먼저 고쳤다.
    /// - 내가 거절한 초대와 취소된 일정은 뺀다. 캘린더에는 남아 있어도 나를 붙잡지 않는다.
    ///
    /// - Parameter planned: 맥 계획표에 이미 옮겨 적힌 회차. 두 번 세지 않는다 (→ `PlannedCopies`).
    func visualEvents(from rangeStart: Date, to rangeEnd: Date, planned: PlannedCopies = .init()) -> [Event] {
        guard isActive else { return [] }
        let cal = Calendar.current
        let calendars = store.calendars(for: .event).filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty,
              let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: rangeEnd))
        else { return [] }

        let predicate = store.predicateForEvents(withStart: cal.startOfDay(for: rangeStart),
                                                 end: end, calendars: calendars)
        let occurrences = store.events(matching: predicate)
            .filter { Self.holdsMe($0) && !planned.contains($0) }

        var result: [Event] = []
        var recurring: [String: [EKEvent]] = [:]
        for event in occurrences {
            if event.hasRecurrenceRules {
                recurring[event.calendarItemIdentifier, default: []].append(event)
            } else {
                result.append(Self.single(event))
            }
        }
        for (id, group) in recurring {
            result.append(contentsOf: Self.series(id: id, group.sorted { $0.startDate < $1.startDate }))
        }
        print("📅 [CalendarMirror] 캘린더 \(calendars.count)개 → 일정 \(occurrences.count)건을 \(result.count)줄로")
        return result
    }

    /// 그 날 시각이 있는 캘린더 일정 — 하루 화면이 **적힌 시각 그대로** 세운다.
    ///
    /// 그 날 안으로 잘라서 준다(0...24시). 밤을 넘기는 일정은 그 날 몫만 온다.
    /// 종일 일정은 시계 위에 자리가 없어서 뺀다 (시간을 안 잡아먹는다 → `visualEvents`).
    /// `key`는 무지개 줄의 `mirrorKey`와 같다 — 하루 화면이 같은 줄 색을 찾는 열쇠다.
    func timedEvents(on date: Date, planned: PlannedCopies = .init()) -> [(key: String, title: String, start: Double, end: Double, color: CGColor)] {
        guard isActive else { return [] }
        let cal = Calendar.current
        let day0 = cal.startOfDay(for: date)
        guard let day1 = cal.date(byAdding: .day, value: 1, to: day0) else { return [] }
        let calendars = store.calendars(for: .event).filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: day0, end: day1, calendars: calendars)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && Self.holdsMe($0) && !planned.contains($0) }
            .compactMap { event in
                let s = max(event.startDate, day0).timeIntervalSince(day0) / 3600
                let e = min(event.endDate, day1).timeIntervalSince(day0) / 3600
                guard e > s else { return nil }
                return (Self.key(for: event), event.title ?? String(localized: "제목 없음"), s, e,
                        event.calendar.cgColor)
            }
    }

    /// 무지개 줄의 이름표. 반복 일정은 한 벌에 하나, 한 번뿐인 일정은 회차마다 하나.
    private static func key(for event: EKEvent) -> String {
        event.hasRecurrenceRules
            ? "\(keyPrefix)\(event.calendarItemIdentifier)"
            : "\(keyPrefix)\(event.calendarItemIdentifier)@\(Int(event.startDate.timeIntervalSince1970))"
    }

    /// **맥이 이미 계획표에 옮겨 적은 캘린더 일정.**
    ///
    /// 맥 '무지개 공방'의 캘린더 가져오기는 회의를 계획 블록으로 **베껴** 둔다. 그 블록은 무지개와
    /// 하루 화면에 맥 계획으로 이미 선다. 여기서 캘린더를 또 비추면 같은 시각에 같은 회의가 두 개다 —
    /// 무지개는 한 칸 더 진해지고, 하루 화면은 한 회의를 반쪽 둘로 가른다.
    ///
    /// 알아보는 길은 둘이다.
    ///  1. 블록에 적힌 `calendarEventID` — 맥이 `"<eventIdentifier>|<시작 시각 초>"`로 적는다
    ///     (→ WeekBlocks/CalendarImport.key). 같은 기기 캘린더라면 이것으로 정확히 맞는다.
    ///  2. **같은 날 · 같은 시작 분 · 같은 제목.** `eventIdentifier`는 기기마다 다를 수 있어서
    ///     1만으로는 모자란다. 시각까지 같아야 하므로, 이름만 같은 다른 날·다른 시각 일정은 안 걸린다.
    struct PlannedCopies {
        var ids: Set<String> = []
        var slots: Set<String> = []

        static func slot(day: Date, minute: Int, title: String) -> String {
            "\(Int(Calendar.current.startOfDay(for: day).timeIntervalSince1970))|\(minute)|\(title)"
        }

        func contains(_ event: EKEvent) -> Bool {
            if let id = event.eventIdentifier,
               ids.contains("\(id)|\(Int(event.startDate.timeIntervalSince1970))") { return true }
            guard !slots.isEmpty else { return false }
            let c = Calendar.current.dateComponents([.hour, .minute], from: event.startDate)
            let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            return slots.contains(Self.slot(day: event.startDate, minute: minute, title: event.title ?? ""))
        }
    }

    private static func holdsMe(_ event: EKEvent) -> Bool {
        if event.status == .canceled { return false }
        if let me = event.attendees?.first(where: \.isCurrentUser), me.participantStatus == .declined {
            return false
        }
        return true
    }

    /// 한 번뿐인 일정. 여러 날에 걸치면 그 날들에 걸쳐 한 줄이다.
    private static func single(_ event: EKEvent) -> Event {
        let (start, end) = days(of: event)
        let dayCount = max(1, (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        return make(event, start: start, end: end,
                    hours: hours(of: event) / Double(dayCount),
                    key: "\(keyPrefix)\(event.calendarItemIdentifier)@\(Int(event.startDate.timeIntervalSince1970))")
    }

    /// 반복 일정 한 벌. 하루짜리 회차들이면 한 줄로, 아니면(여러 날짜리 반복) 회차마다 한 줄.
    private static func series(id: String, _ group: [EKEvent]) -> [Event] {
        guard let first = group.first, let last = group.last else { return [] }
        guard group.allSatisfy({ days(of: $0).start == days(of: $0).end }) else {
            return group.map(single)
        }
        let cal = Calendar.current
        let dates = Set(group.map { cal.startOfDay(for: $0.startDate) })
        let weekdays = Set(dates.map { cal.component(.weekday, from: $0) })

        // 그 요일인데 안 열린 날 = 제외일. 격주 회의가 매주로 보이지 않게.
        let start = cal.startOfDay(for: first.startDate)
        let end = cal.startOfDay(for: last.startDate)
        var skipped: Set<Date> = []
        var day = start
        while day <= end {
            if weekdays.contains(cal.component(.weekday, from: day)), !dates.contains(day) {
                skipped.insert(day)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let averageHours = group.map(hours(of:)).reduce(0, +) / Double(group.count)
        return [make(first, start: start, end: end, hours: averageHours,
                     weekdays: weekdays.count == 7 ? nil : weekdays.sorted(),
                     skipped: skipped, key: "\(keyPrefix)\(id)")]
    }

    private static func make(_ event: EKEvent, start: Date, end: Date, hours: Double,
                             weekdays: [Int]? = nil, skipped: Set<Date> = [], key: String) -> Event {
        let mirrored = Event(
            title: event.title?.isEmpty == false ? event.title! : String(localized: "제목 없음"),
            startDate: start,
            endDate: end,
            color: key,   // 실제 색은 배정된 레인이 정한다.
            hoursPerDay: hours,
            selectedWeekdays: weekdays,
            importance: .medium,
            excludedDates: skipped
        )
        mirrored.mirrorKey = key
        return mirrored
    }

    /// 걸친 날들(시작일·마지막 날). 자정에 끝나는 일정은 그 전날에 끝난 것이다.
    private static func days(of event: EKEvent) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: event.startDate)
        let end = cal.startOfDay(for: event.endDate.addingTimeInterval(-1))
        return (start, max(start, end))
    }

    private static func hours(of event: EKEvent) -> Double {
        guard !event.isAllDay else { return 0 }
        return max(0, event.endDate.timeIntervalSince(event.startDate) / 3600)
    }
}

extension Event {
    /// 캘린더를 비춘 줄인가 (→ CalendarMirror). 이 앱에서 고치거나 지울 수 없다.
    var isCalendarMirror: Bool { mirrorKey?.hasPrefix(CalendarMirror.keyPrefix) == true }
}
