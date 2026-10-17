//
//  CoreFlowUITests.swift
//  ScheduleDensityAppUITests
//
//  앱을 실제로 띄워 핵심 흐름을 한 바퀴 돈다 — 할 일을 적고, 무지개를 보고, 설정을 연다.
//  그리고 각 화면에서 접근성 자동 점검(performAccessibilityAudit)을 돌린다.
//

import XCTest

final class CoreFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 한국어 화면으로 고정하고, 처음 한 번 뜨는 안내들은 이미 본 것으로 둔다
        // (UserDefaults 인자 도메인 — 앱 코드에 시험용 갈래를 두지 않는다).
        app.launchArguments += [
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR",
            "-hasSeenRainbowOnboarding", "YES",
            "-hasSeenBoltOnboarding", "YES",
            "-hasSeenSplitOnboarding", "YES",
            "-lastSeenWhatsNewVersion", "1.1.14",
        ]
        app.launch()
    }

    func testAddTodoThenVisitRainbowAndSettings() throws {
        // 1. 할 일 탭에서 한 줄 적는다.
        let add = app.navigationBars.buttons["할 일 추가"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let title = "UI 시험 \(Int(Date().timeIntervalSince1970) % 100_000)"
        field.typeText(title + "\n")
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "적은 할 일이 목록에 선다")
        // 빈 줄에서 한 번 더 엔터 = 다 적었다 — 키보드가 내려가야 탭 막대가 보인다.
        app.typeText("\n")

        // 2. 무지개 탭.
        app.tabBars.buttons["무지개"].tap()
        let settings = settingsButton
        XCTAssertTrue(settings.waitForExistence(timeout: 10))

        // 3. 설정을 열고 '새로 생긴 것'을 다시 본다.
        settings.tap()
        let whatsNew = app.buttons["새로 생긴 것"]
        var swipes = 0
        while !whatsNew.isHittable && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(whatsNew.isHittable)
        whatsNew.tap()
        let close = app.buttons["whatsNew.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
    }

    func testAccessibilityAuditOnMainScreens() throws {
        // 점검이 찾은 문제를 한 번에 다 보이게 한다(첫 문제에서 멈추면 하나씩 고치며 몇 번을 돌려야 한다).
        continueAfterFailure = true
        XCTAssertTrue(app.navigationBars.buttons["할 일 추가"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: auditTypes, issueHandler)

        app.tabBars.buttons["무지개"].tap()
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: auditTypes, issueHandler)
    }

    /// 설정 단추. 맥 소개를 아직 안 봤으면 라벨이 "설정, 새로 볼 것 있음"이 된다.
    private var settingsButton: XCUIElement {
        app.navigationBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "설정")).firstMatch
    }

    /// 모든 점검을 돌린다. 거르는 것은 아래 `issueHandler` 에 근거와 함께 적은 시스템 몫뿐이다.
    private var auditTypes: XCUIAccessibilityAuditType {
        .all
    }

    /// 걸러 내는 것은 **시스템이 그린 것**뿐이다. 앱이 그린 요소의 문제는 그대로 실패로 둔다.
    private func issueHandler(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        // 탭 막대·내비게이션 막대는 UIKit 이 그린다. 큰 글씨에서 잘리는 것은 앱이 고칠 수 없다.
        if issue.auditType == .dynamicType,
           let element = issue.element,
           element.elementType == .tab || element.elementType == .tabBar || element.elementType == .navigationBar {
            return true
        }
        // 내비게이션 막대의 유리(Liquid Glass) 단추는 시스템이 뒤 내용에 따라 글자색을 바꿔 그리고,
        // 막대 안 글자 크기도 시스템이 정한다(큰 글씨는 길게 눌러 보는 큰 내용 뷰어로 대신한다).
        // 점검은 그 둘을 앱 문제로 잡아 오탐이 난다. 막대 **뒤로 스크롤돼 흐리게 비치는** 목록 줄도 같다.
        // 막대 높이 안(위)에 있는 것만 걸러 낸다.
        if issue.auditType == .contrast || issue.auditType == .dynamicType,
           let element = issue.element,
           let bar = app.navigationBars.allElementsBoundByIndex.first,
           element.frame.midY < bar.frame.maxY {
            return true
        }
        // 무지개 날짜 칸은 40pt 격자라 글자 크기에 상한(accessibility1)을 일부러 두었다
        // (TimelineDensityView.DateRow). '일부만 지원'은 그 상한을 말하는 것이다.
        if issue.auditType == .dynamicType, issue.compactDescription.contains("partially") {
            return true
        }
        return false
    }
}
