import SwiftData
import SwiftUI

#if DEBUG
/// iPad 스토어 스크린샷용 예시 — 실행 인자 `-iPadDemo YES` 일 때만 (DEBUG 빌드 전용).
/// 무지개에는 오늘 앞뒤로 겹치는 일정 다섯을, 할 일에는 그 언어로 쓴 할 일 셋과 단계 둘을 넣는다.
/// `-iPadDemoTab rainbow` 면 무지개 탭으로 연다. 찍는 스크립트: scripts/capture_ipad.sh
enum IPadScreenshotDemo {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "iPadDemo") }
    static var startsOnRainbow: Bool { UserDefaults.standard.string(forKey: "iPadDemoTab") == "rainbow" }

    @MainActor
    static func seed(events: ModelContext, todos: ModelContext) {
        guard isOn else { return }
        // 일정: 오늘을 가운데 두고 겹치게 — 겹치는 날일수록 무지개가 진해진다. 제목은 설정의 샘플 데이터와 같다.
        if ((try? events.fetchCount(FetchDescriptor<Event>())) ?? 0) == 0 {
            let cal = Calendar.current, today = cal.startOfDay(for: .now)
            func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today)! }
            let samples: [(String.LocalizationValue, Int, Int, String, Double)] = [
                ("프로젝트 A", -9, 9, "#FF3B30", 6), ("프로젝트 B", -3, 14, "#FF9500", 4),
                ("출장", 2, 4, "#FFCC00", 9), ("교육 프로그램", -14, -5, "#34C759", 3),
                ("컨퍼런스", 7, 8, "#007AFF", 8),
            ]
            for (title, from, to, color, hours) in samples {
                events.insert(Event(title: String(localized: title), startDate: day(from), endDate: day(to),
                                    color: color, hoursPerDay: hours))
            }
            try? events.save()
        }
        guard ((try? todos.fetchCount(FetchDescriptor<BacklogItem>())) ?? 0) == 0 else { return }
        let slides = BacklogItem(title: String(localized: "발표 자료 만들기"), durationHours: 0, sortIndex: 0)
        let moving = BacklogItem(title: String(localized: "이사 준비하기"), durationHours: 3, sortIndex: 1)
        let taxes = BacklogItem(title: String(localized: "세금 서류 챙기기"), durationHours: 1, sortIndex: 2)
        [slides, moving, taxes].forEach(todos.insert)
        todos.insert(TodoTree.makeStep(under: slides, title: String(localized: "목차 정하기"), sortIndex: 0))
        todos.insert(TodoTree.makeStep(under: slides, title: String(localized: "그림 고르기"), sortIndex: 1, durationHours: 1))
        try? todos.save()
    }
}
#endif
