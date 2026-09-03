//
//  UsageDiary.swift
//
//  **앱을 연 날만 적어 둔다.** 그 이상은 적지 않는다.
//
//  꾸준함을 말하려면 "며칠 열었나"가 있어야 하는데, 그걸 알려면 연 날을 적어야 한다.
//  적는 것은 **날짜뿐이다** — 몇 시에 열었는지도, 무엇을 했는지도 남기지 않는다.
//  날짜만 있으면 연속 며칠과 이번 달 며칠을 셀 수 있고, 그게 이 파일이 하는 일 전부다.
//
//  ⚠️ 값은 App Group 에 있다. 기기 안에만 있고 iCloud 로도, 밖으로도 나가지 않는다.
//     밖으로 나가는 것은 여기서 **센 숫자**뿐이고, 그마저 사용자가 켰을 때만 나간다
//     (→ UsageReporting.swift).
//

import Foundation

enum UsageDiary {

    private static let appGroupID = "group.com.devkoan.ScheduleDensity"
    private static let daysKey = "usage.activeDays"

    /// 적어 두는 날의 최대 개수. 1년 남짓이면 꾸준함을 말하기에 충분하고,
    /// 그보다 오래된 날짜는 세는 데 쓰이지도 않는다.
    private static let limit = 400

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// 오늘을 적는다. 앱을 켤 때마다 부른다 — 이미 적혀 있으면 아무 일도 안 한다.
    static func markToday(_ now: Date = Date()) {
        let today = formatter.string(from: now)
        var days = defaults.stringArray(forKey: daysKey) ?? []
        guard !days.contains(today) else { return }
        days.append(today)
        if days.count > limit { days = Array(days.suffix(limit)) }
        defaults.set(days, forKey: daysKey)
    }

    /// 적어 둔 날들. 오래된 것부터.
    static var activeDays: [Date] {
        (defaults.stringArray(forKey: daysKey) ?? [])
            .compactMap { formatter.date(from: $0) }
            .sorted()
    }

    /// **연속으로 며칠째인가.** 오늘부터 거꾸로 하루씩 끊기지 않고 이어진 날의 수.
    ///
    /// 오늘이 안 적혀 있으면 어제부터 센다 — 앱을 켜기 **전에** 이 값을 읽는 자리가
    /// 있을 수 있고, 그때 0이 뜨면 어제까지 쌓은 것이 사라진 것처럼 보인다.
    static func streak(_ now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let days = Set(activeDays.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// 최근 며칠 사이에 연 날이 몇 날인가. 오늘을 포함해서 센다.
    static func activeDayCount(inLast days: Int, from now: Date = Date()) -> Int {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -(days - 1),
                                        to: calendar.startOfDay(for: now)) else { return 0 }
        return activeDays.filter { $0 >= start }.count
    }

    /// 적어 둔 것을 전부 버린다. 설정에서 '보내지 않기'로 되돌릴 때 함께 부른다 —
    /// 안 보낼 거면 들고 있을 이유도 없다.
    static func forgetEverything() {
        defaults.removeObject(forKey: daysKey)
    }
}
