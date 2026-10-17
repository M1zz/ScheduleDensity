//
//  AppLog.swift
//  ScheduleDensityApp
//
//  **무슨 일이 있었는지 나중에 따라갈 수 있게** 남기는 자리.
//
//  예전에는 전부 `print` 였다. 그건 Xcode 에 붙어 있을 때만 보이고, 사용자가
//  "할 일이 사라졌어요" 라고 할 때 기기에서 꺼내 볼 길이 없었다. `Logger` 로 남기면
//  콘솔 앱·sysdiagnose 에서 분류별로 걸러 볼 수 있다.
//
//  ⚠️ 사람이 적은 글자(일정·할 일 제목)는 **그대로 두면 가려진다**(Logger 기본값 private).
//     오류 설명만 `.public` 으로 연다 — 원인을 찾는 데 필요하고 사용자 글이 섞이지 않는다.
//
//  성능 구간(`signposter`)은 Instruments ▸ Points of Interest 에 같은 이름으로 선다.
//  느려졌다는 말이 오면 어느 구간이 늘었는지부터 본다.
//

import Foundation
import OSLog

enum AppLog {
    /// 번들 ID가 없을 수는 없지만, 강제로 풀어 크래시를 낼 이유도 없다.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.ScheduleDensityApp"

    /// 앱이 뜨는 길 — 스토어 열기, 세이프 모드, 원격 스위치.
    static let launch = Logger(subsystem: subsystem, category: "Launch")
    /// 일정·할 일 스토어와 금고(되살리기).
    static let store = Logger(subsystem: subsystem, category: "Store")
    /// 무지개(일정) 계산과 편집.
    static let schedule = Logger(subsystem: subsystem, category: "Schedule")
    /// iCloud·맥과 오가는 것.
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    /// 화면에서 일어나는 일.
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// 핵심 작업의 걸린 시간. 구간 이름은 `StaticString` 이라 한 번 정하면 그대로 쓴다.
    static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)

    /// 구간 하나를 재며 `work` 를 돌린다. 재는 비용은 Instruments 가 붙지 않으면 거의 없다.
    @discardableResult
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        defer { signposter.endInterval(name, state) }
        return try work()
    }

    /// `async` 작업용.
    @discardableResult
    static func measure<T>(_ name: StaticString, _ work: () async throws -> T) async rethrows -> T {
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        defer { signposter.endInterval(name, state) }
        return try await work()
    }
}
