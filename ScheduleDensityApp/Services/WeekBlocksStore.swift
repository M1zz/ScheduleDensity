//
//  WeekBlocksStore.swift
//  ScheduleDensityApp
//
//  Mac '무지개 공방(WeekBlocks)'이 같은 iCloud(private DB)에 저장한 주간 계획을
//  **읽기 전용**으로 가져와, iOS 밀도 시각화용 Event(메모리 전용)로 변환하는 서비스.
//
//  설계 원칙:
//   - 기존 Event 스토어(ScheduleDensityApp.swift)와 **완전히 분리된** 별도 ModelContainer.
//     서로 영향 없음. 출시된 로컬 Event 데이터는 건드리지 않는다.
//   - 여기서 만든 Event는 **절대 SwiftData에 insert하지 않는다**(시각화 입력용 임시 객체).
//   - 변환은 의존성 없는 순수 코어 WeekBlocksAdapter를 재사용.
//

import Foundation
import SwiftData

final class WeekBlocksStore {
    /// Mac WeekBlocks가 쓰는 CloudKit private 컨테이너 ID (양쪽 정확히 일치해야 함).
    static let containerID = "iCloud.com.devkoan.ScheduleDensity"

    /// WeekBlocks 모델 전용 읽기 컨테이너. 실패 시 nil(미로그인·권한·entitlement 불일치 등).
    private let container: ModelContainer?

    init() {
        do {
            // 관계 없는 독립 모델이라 필요한 둘만 스키마로 선언해도 읽을 수 있다.
            let schema = Schema([Routine.self, PlanBlock.self])
            // ⚠️ 반드시 별도 store 파일을 지정한다. 이름을 비우면 Event 스토어와 같은
            //    default.store 로 떨어져 한 파일에서 충돌한다(ZEVENT 손상·CloudKit 미러링 오염).
            let config = ModelConfiguration(
                "WeekBlocksMirror",
                schema: schema,
                cloudKitDatabase: .private(Self.containerID)
            )
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ [WeekBlocks] 읽기 컨테이너 생성 실패: \(error)")
            self.container = nil
        }
    }

    /// 컨테이너가 준비되었는지(=연동 가능 상태인지).
    var isAvailable: Bool { container != nil }

    /// WeekBlocks 계획 → 밀도 시각화용 Event 배열(메모리 전용).
    /// 고정 루틴은 가시 범위(rangeStart~rangeEnd) **전체**에 펼친다 — 오늘 이전 날짜도 포함.
    /// 컨테이너가 없거나 데이터가 비어 있으면 빈 배열.
    func loadVisualEvents(rangeStart: Date, rangeEnd: Date) -> [Event] {
        guard let container else { return [] }
        let context = ModelContext(container)

        // 루틴은 referenceDate(=rangeStart)부터 weeks 만큼 앞으로 펼쳐지므로,
        // 가시 범위를 모두 덮도록 시작을 rangeStart(과거)로 두고 주 수를 범위에 맞춘다.
        let cal = Calendar.current
        let spanDays = (cal.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 56)
        let weeks = max(1, Int(ceil(Double(spanDays) / 7.0)) + 1)
        let referenceDate = rangeStart

        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let blocks = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []

        let routineInputs: [WBRoutineInput] = routines.map { r in
            WBRoutineInput(
                name: r.name,
                kind: r.kind == .fixed ? .fixed : .quota,
                colorName: r.colorName,
                weekdaysMonZero: r.selectedDays.map(\.rawValue).sorted(),
                durationHours: r.durationHours,
                weeklyHours: r.weeklyHours
            )
        }

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
            referenceDate: referenceDate,
            weeks: weeks
        )

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
