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

    /// 로컬 미러의 store 파일 이름(확장자 제외).
    private static let storeName = "WeekBlocksMirror"

    /// 미러를 통째로 버리고 CloudKit에서 다시 받아야 할 때 올리는 토큰.
    ///
    /// CloudKit 환경(Development ↔ Production)이 바뀌면 기존 미러에 남아 있는 존 정보와
    /// 변경 토큰이 새 환경과 맞지 않아 동기화가 조용히 멈춘다. 이 값을 바꾸면 다음 실행에
    /// 미러 파일을 지우고 처음부터 다시 내려받는다.
    /// 미러는 **읽기 전용 파생 데이터**라 지워도 원본(맥앱·CloudKit)에는 영향이 없다.
    private static let mirrorResetToken = "production-2026-07"
    private static let mirrorResetKey = "weekBlocksMirror.resetToken"

    /// WeekBlocks 모델 전용 읽기 컨테이너. 실패 시 nil(미로그인·권한·entitlement 불일치 등).
    private let container: ModelContainer?

    /// 컨테이너 생성이 실패했을 때의 사유. 화면이 그냥 비어 보이는 것과
    /// 연동 자체가 끊긴 것을 구분하기 위해 보관한다.
    private(set) var lastErrorDescription: String?

    init() {
        Self.resetMirrorIfTokenChanged()
        do {
            // 관계 없는 독립 모델이라 필요한 둘만 스키마로 선언해도 읽을 수 있다.
            let schema = Schema([Routine.self, PlanBlock.self])
            // ⚠️ 반드시 별도 store 파일을 지정한다. 이름을 비우면 Event 스토어와 같은
            //    default.store 로 떨어져 한 파일에서 충돌한다(ZEVENT 손상·CloudKit 미러링 오염).
            let config = ModelConfiguration(
                Self.storeName,
                schema: schema,
                cloudKitDatabase: .private(Self.containerID)
            )
            self.container = try ModelContainer(for: schema, configurations: [config])
            print("✅ [WeekBlocks] 읽기 컨테이너 준비됨 (container=\(Self.containerID))")
        } catch {
            print("⚠️ [WeekBlocks] 읽기 컨테이너 생성 실패: \(error)")
            self.container = nil
            self.lastErrorDescription = String(describing: error)
        }
    }

    /// 리셋 토큰이 바뀌었으면 로컬 미러 파일을 지운다. 컨테이너를 만들기 **전에** 호출해야 한다.
    ///
    /// 지우는 대상은 `WeekBlocksMirror` store와 그 부속 파일(-wal/-shm)뿐이다.
    /// 앱의 다른 저장소(Event 로컬 원본, 할 일)는 건드리지 않는다 — 그쪽은 로컬에만 있는
    /// 데이터가 섞여 있어 지우면 진짜로 유실된다.
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
        let targets = ["\(storeName).store", "\(storeName).store-wal", "\(storeName).store-shm"]
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

    /// WeekBlocks 계획 → 밀도 시각화용 Event 배열(메모리 전용).
    /// 고정 루틴은 가시 범위(rangeStart~rangeEnd) **전체**에 펼친다 — 오늘 이전 날짜도 포함.
    /// 컨테이너가 없거나 데이터가 비어 있으면 빈 배열.
    func loadVisualEvents(rangeStart: Date, rangeEnd: Date) -> [Event] {
        guard let container else {
            print("⛔️ [WeekBlocks] 컨테이너 없음 — 계획을 읽지 않음. 사유: \(lastErrorDescription ?? "알 수 없음")")
            return []
        }
        let context = ModelContext(container)

        // 루틴은 referenceDate(=rangeStart)부터 weeks 만큼 앞으로 펼쳐지므로,
        // 가시 범위를 모두 덮도록 시작을 rangeStart(과거)로 두고 주 수를 범위에 맞춘다.
        let cal = Calendar.current
        let spanDays = (cal.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 56)
        let weeks = max(1, Int(ceil(Double(spanDays) / 7.0)) + 1)
        let referenceDate = rangeStart

        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let blocks = (try? context.fetch(FetchDescriptor<PlanBlock>())) ?? []

        // 어디서 비는지 한 줄로 판별하기 위한 계측:
        //  - 0/0 이면 미러가 아직 안 내려왔거나(첫 동기화 대기) CloudKit 환경/계정이 다른 것.
        //  - 값이 있는데 화면이 비면 아래 withinRoutine 필터나 날짜 범위 문제.
        print("📥 [WeekBlocks] 미러 조회: routines=\(routines.count), blocks=\(blocks.count), "
              + "범위=\(rangeStart)~\(rangeEnd)")

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

        let skippedWithinRoutine = blocks.count - blockInputs.count
        print("🧮 [WeekBlocks] 변환 결과: 시각화 이벤트=\(visual.count) "
              + "(루틴 밖 일정=\(blockInputs.count), '루틴 안'이라 제외=\(skippedWithinRoutine), weeks=\(weeks))")

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
