//
//  DensityIntents.swift
//  ScheduleDensityApp
//
//  "욕망의 무지개, 이번 주 제일 빽빽한 날 언제야?" — 앞으로 7일 중 일정이 가장 겹치는 날을 알려 준다.
//  주간 밀도 화면과 같은 계산(DensityCalculator)을 쓴다.
//

import AppIntents
import Foundation
import SwiftData

struct BusiestDayIntent: AppIntent {
    static let title = LocalizedStringResource("가장 빽빽한 날", comment: "Siri: the busiest day of the coming week")
    static let description = IntentDescription(
        LocalizedStringResource("앞으로 7일 중 일정이 가장 겹치는 날을 알려 줍니다.", comment: "Siri: busiest day description")
    )

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: today) else { return .result(dialog: "") }
        let events = (try? ModelContext(container).fetch(FetchDescriptor<Event>())) ?? []
        let week = DensityCalculator.calculateRangeDensity(from: today, to: weekEnd, events: events)
        guard let busiest = week.max(by: { $0.density < $1.density }), busiest.density > 0 else {
            return .result(dialog: IntentDialog(LocalizedStringResource("앞으로 7일은 비어 있어요.", comment: "Siri: nothing scheduled this week")))
        }
        let day = busiest.date.formatted(.dateTime.month().day().weekday(.wide))
        return .result(dialog: IntentDialog(LocalizedStringResource("가장 빽빽한 날은 \(day)이에요. 일정 \(busiest.density)개가 겹쳐요.", comment: "Siri: busiest day. Arguments: date, number of overlapping events")))
    }
}

struct ScheduleDensityShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BusiestDayIntent(),
            phrases: ["What’s my busiest day in \(.applicationName)", "\(.applicationName) busiest day"],
            shortTitle: "Busiest Day",
            systemImageName: "chart.bar.fill"
        )
    }
}
