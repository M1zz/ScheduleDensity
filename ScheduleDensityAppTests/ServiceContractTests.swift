//
//  ServiceContractTests.swift
//  ScheduleDensityAppTests
//
//  출시 전에 어긋나면 안 되는 약속들 — LeeoKit 계약, 새 기능 안내, 퍼널, 원격 스위치.
//

import XCTest
import LeeoKit
@testable import ScheduleDensityApp

final class PreflightTests: XCTestCase {

    /// 계약(Spec)에 출시를 막는 오류가 없다. 앱이 `LeeoKit.bootstrap` 을 쓰지 않아
    /// 부트스트랩의 DEBUG 감사가 돌지 않으므로, 이 시험이 그 자리를 지킨다.
    func testSpecIsReleasable() {
        let issues = LeeoPreflight.audit(ScheduleDensityAppSpec.self)
        XCTAssertTrue(issues.isReleasable,
                      issues.errors.map { "[\($0.code)] \($0.message)" }.joined(separator: "\n"))
    }

    func testRoadmapIDsAreUnique() {
        let ids = ScheduleDensityAppSpec.roadmap.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}

final class WhatsNewGateTests: XCTestCase {

    func testNewcomerIsMarkedSilently() {
        XCTAssertEqual(WhatsNewGate.decide(launchCount: 1, hasUsedBefore: false, lastSeenVersion: nil),
                       .markSeenSilently)
    }

    func testReturningUserSeesItOnce() {
        XCTAssertEqual(WhatsNewGate.decide(launchCount: 12, hasUsedBefore: true, lastSeenVersion: "1.1.13"),
                       .show)
        XCTAssertEqual(WhatsNewGate.decide(launchCount: 13, hasUsedBefore: true,
                                           lastSeenVersion: WhatsNewContent.version),
                       .nothing)
    }

    /// 실행 횟수를 세기 전 버전부터 쓰던 사람 — 횟수는 1이어도 쓴 흔적이 있으면 보여 준다.
    func testUserFromBeforeLaunchCountingStillSeesIt() {
        XCTAssertEqual(WhatsNewGate.decide(launchCount: 1, hasUsedBefore: true, lastSeenVersion: nil), .show)
    }

    func testContentIsNotEmpty() {
        XCTAssertFalse(WhatsNewContent.items.isEmpty)
        XCTAssertTrue(WhatsNewContent.items.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }
}

final class RainbowFunnelTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "RainbowFunnelTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testEachStageIsRecordedOnlyOnce() {
        var sent: [String] = []
        RainbowFunnel.noteLaunch(isFirstLaunch: true, defaults: defaults) { sent.append($0.name) }
        RainbowFunnel.reach(.firstTodo, defaults: defaults) { sent.append($0.name) }
        RainbowFunnel.reach(.firstTodo, defaults: defaults) { sent.append($0.name) }
        XCTAssertEqual(sent, ["funnel_install", "funnel_first_todo"])
    }

    /// 이 버전 전에 설치한 사람은 설치 단계가 없으므로 다음 단계도 남기지 않는다.
    func testUsersFromBeforeTheFunnelAreNotCounted() {
        var sent: [String] = []
        RainbowFunnel.noteLaunch(isFirstLaunch: false, defaults: defaults) { sent.append($0.name) }
        RainbowFunnel.reach(.firstTodo, defaults: defaults) { sent.append($0.name) }
        XCTAssertTrue(sent.isEmpty)
    }

    func testShouldRecordIsPure() {
        XCTAssertTrue(RainbowFunnel.shouldRecord(.install, reached: []))
        XCTAssertFalse(RainbowFunnel.shouldRecord(.firstStep, reached: []))
        XCTAssertTrue(RainbowFunnel.shouldRecord(.firstStep, reached: [.install]))
        XCTAssertFalse(RainbowFunnel.shouldRecord(.firstStep, reached: [.install, .firstStep]))
    }
}

final class RemoteFlagTests: XCTestCase {

    /// rawValue 가 곧 CloudKit 필드 이름이다. 바뀌면 대시보드에서 꺼도 앱은 켠 채로 돈다.
    func testFlagNamesMatchDashboardFields() {
        XCTAssertEqual(RainbowFlag.allCases.map(\.rawValue), ["macBridge", "calendarMirror", "usageReporting"])
    }

    /// 한 번도 받아 본 적 없는 값은 켬이다 — 네트워크가 없다고 기능이 꺼지면 안 된다.
    func testUnknownFlagDefaultsToOn() {
        struct Never: LeeoRemoteFlag { let rawValue = "rainbow.test.neverFetched" }
        XCTAssertTrue(LeeoRemoteFlags.isEnabled(Never()))
    }
}
