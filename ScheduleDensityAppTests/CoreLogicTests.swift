//
//  CoreLogicTests.swift
//  ScheduleDensityAppTests
//
//  이 앱의 핵심 계산 — 무지개 밀도와 할 일 단계 — 이 그대로 맞는지 지킨다.
//

import XCTest
@testable import ScheduleDensityApp

final class DensityCalculatorTests: XCTestCase {

    private let cal = Calendar.current

    private func day(_ offset: Int, from base: Date = Calendar.current.startOfDay(for: Date())) -> Date {
        cal.date(byAdding: .day, value: offset, to: base)!
    }

    func testRangeHasOneEntryPerDayInclusive() {
        let result = DensityCalculator.calculateRangeDensity(from: day(0), to: day(6), events: [])
        XCTAssertEqual(result.count, 7)
        XCTAssertTrue(result.allSatisfy { $0.density == 0 })
    }

    func testEventCountsOnlyInsideItsPeriod() {
        let event = Event(title: "출장", startDate: day(1), endDate: day(3))
        let result = DensityCalculator.calculateRangeDensity(from: day(0), to: day(4), events: [event])
        XCTAssertEqual(result.map(\.density), [0, 1, 1, 1, 0])
    }

    func testOverlappingEventsStackUp() {
        let a = Event(title: "A", startDate: day(0), endDate: day(2), color: "#FF3B30")
        let b = Event(title: "B", startDate: day(2), endDate: day(4), color: "#007AFF")
        let result = DensityCalculator.calculateRangeDensity(from: day(0), to: day(4), events: [a, b])
        XCTAssertEqual(result.map(\.density), [1, 1, 2, 1, 1])
    }

    func testExcludedDateDoesNotCount() {
        let event = Event(title: "운동", startDate: day(0), endDate: day(2), excludedDates: [day(1)])
        let middle = DensityCalculator.calculateDensity(for: day(1), events: [event])
        XCTAssertEqual(middle.density, 0)
    }
}

final class TodoTreeTests: XCTestCase {

    func testAdvanceCompletesStepsInOrderThenTheTodo() {
        let todo = BacklogItem(title: "이사 준비")
        let first = TodoTree.makeStep(under: todo, title: "박스 사기", sortIndex: 0)
        let second = TodoTree.makeStep(under: todo, title: "짐 싸기", sortIndex: 1)
        let tree = TodoTree([todo, first, second])

        XCTAssertEqual(tree.currentStep(of: todo)?.title, "박스 사기")
        tree.advance(todo)
        XCTAssertTrue(first.isCompleted)
        XCTAssertFalse(todo.isCompleted, "단계가 남아 있으면 할 일은 끝나지 않는다")
        XCTAssertEqual(tree.currentStep(of: todo)?.title, "짐 싸기")

        tree.advance(todo)
        XCTAssertTrue(todo.isCompleted, "마지막 단계를 끝내면 할 일도 끝난다")
        XCTAssertEqual(tree.doneLeafCount(of: todo), tree.leafCount(of: todo))
    }

    func testRewindUndoesOnlyTheLastStep() {
        let todo = BacklogItem(title: "보고서")
        let first = TodoTree.makeStep(under: todo, title: "자료", sortIndex: 0)
        let second = TodoTree.makeStep(under: todo, title: "쓰기", sortIndex: 1)
        let tree = TodoTree([todo, first, second])
        tree.advance(todo)
        tree.advance(todo)

        tree.rewind(todo)
        XCTAssertTrue(first.isCompleted)
        XCTAssertFalse(second.isCompleted)
        XCTAssertFalse(todo.isCompleted)
    }
}
