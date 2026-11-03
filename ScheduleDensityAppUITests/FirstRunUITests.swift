//
//  FirstRunUITests.swift
//  ScheduleDensityAppUITests
//
//  처음 온 사람의 길을 한 바퀴 — 튜토리얼 → 빈 화면에서 할 일 적기 → 모든 기능 열기 (→ FirstRunStart.swift).
//
//  ⚠️ **새로 설치한 상태에서만 뜻이 있다.** 판정은 첫 실행에 한 번이라, 앱이 이미 깔려 있으면
//     건너뛴다. 돌리기 전에 `xcrun simctl uninstall <기기> com.example.ScheduleDensityApp`.
//     단계를 인자 도메인(-firstRunStage)으로 주면 앱이 쓴 값보다 인자가 이겨서 다음 단계로 못 넘어간다.
//

import XCTest

final class FirstRunUITests: XCTestCase {

    func testTutorialThenFocusThenUnlock() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()

        let next = app.buttons["다음"]
        guard next.waitForExistence(timeout: 15) else {
            attach(app, "0-튜토리얼이 안 뜸")
            print(app.debugDescription)
            throw XCTSkip("이미 설치돼 있던 앱 — 첫 실행 판정이 끝나 튜토리얼이 안 뜬다")
        }
        attach(app, "1-튜토리얼 1장")
        next.tap()
        sleep(2)
        attach(app, "2-튜토리얼 2장")
        next.tap()
        sleep(3)
        attach(app, "3-튜토리얼 3장")
        app.buttons["첫 할 일 적기"].tap()

        // 튜토리얼이 닫히면 탭 막대 없이 빈 줄이 열려 있다.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "첫 할 일을 적을 빈 줄이 열린다")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "집중 모드에는 탭 막대가 없다")
        XCTAssertFalse(app.buttons["이번 주 결산"].exists, "집중 모드에는 결산이 없다")
        XCTAssertTrue(app.buttons["모든 기능"].exists, "언제든 모든 기능을 여는 문이 있다")

        for title in ["첫째 일", "둘째 일", "셋째 일"] {
            app.typeText(title + "\n")
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        }
        app.typeText("\n")

        // 세 줄을 적으면 모든 기능을 열자는 줄이 선다.
        let unlock = app.buttons["모든 기능 열기"]
        var swipes = 0
        while !unlock.exists && swipes < 4 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(unlock.waitForExistence(timeout: 5), "세 줄을 적으면 열기 줄이 선다")
        attach(app, "4-열기 줄")
        unlock.tap()

        XCTAssertTrue(app.tabBars.buttons["무지개"].waitForExistence(timeout: 5), "탭 막대가 나타난다")
        attach(app, "5-모든 기능")

        // 다시 켜도 모든 기능 그대로다.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["무지개"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["다음"].exists)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
