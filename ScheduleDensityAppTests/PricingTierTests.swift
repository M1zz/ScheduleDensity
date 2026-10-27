//
//  PricingTierTests.swift
//  ScheduleDensityAppTests
//
//  무료 · Plus · Pro 세 칸의 권한 판정 (→ ProEntitlement.swift, ProMark.swift).
//  상품마다 여는 칸, 기능마다 필요한 칸, 예전에 산 것의 유지, 맥과 나누는 표의 등급.
//

import XCTest
@testable import ScheduleDensityApp

final class PricingTierTests: XCTestCase {

    private typealias E = ProEntitlement

    // MARK: - 상품 → 칸

    func testNewProductsOpenTheirTier() {
        XCTAssertEqual(E.tier(of: E.plusYearlyID), .plus)
        XCTAssertEqual(E.tier(of: E.plusLifetimeID), .plus)
        XCTAssertEqual(E.tier(of: E.proYearlyID), .pro)
        XCTAssertEqual(E.tier(of: E.proLifetimeID), .pro)
    }

    func testUpgradeAndGraduateArePro() {
        XCTAssertEqual(E.tier(of: E.upgradeID), .pro)
        XCTAssertEqual(E.tier(of: E.graduateID), .pro)
    }

    /// 판매를 멈춘 월 구독과 1.1.x 의 4,900원 상품을 산 사람은 그대로 Pro 다.
    func testLegacyProductsKeepPro() {
        XCTAssertEqual(E.tier(of: E.monthlyID), .pro)
        XCTAssertEqual(E.proLifetimeID, "com.example.ScheduleDensityApp.pro")
        XCTAssertTrue(E.entitlementIDs.contains(E.monthlyID))
        XCTAssertFalse(E.productIDs.contains(E.monthlyID), "월 구독은 더 팔지 않는다")
    }

    func testProductIDsMatchStoreConsole() {
        let base = "com.example.ScheduleDensityApp"
        XCTAssertEqual(E.plusYearlyID, base + ".plus.annual")
        XCTAssertEqual(E.plusLifetimeID, base + ".plus")
        XCTAssertEqual(E.proYearlyID, base + ".pro.annual")
        XCTAssertEqual(E.upgradeID, base + ".pro.upgrade")
        XCTAssertEqual(E.graduateID, base + ".pro.graduate")
        XCTAssertEqual(E.monthlyID, base + ".pro.monthly")
    }

    /// 유료 칸마다 연 구독과 평생을 나란히 판다. 패스 상품은 앱의 권한 목록에 넣지 않는다.
    func testSoldProductsAreTheLadder() {
        XCTAssertEqual(Set(E.productIDs),
                       [E.plusYearlyID, E.plusLifetimeID, E.proYearlyID, E.proLifetimeID, E.upgradeID, E.graduateID])
        XCTAssertTrue(E.entitlementIDs.isSuperset(of: E.productIDs))
        XCTAssertFalse(E.entitlementIDs.contains { $0.contains(".forever") })
        XCTAssertNil(E.tier(of: "com.example.ScheduleDensityApp.forever"))
    }

    func testUnknownProductOpensNothing() {
        XCTAssertNil(E.tier(of: "com.example.ScheduleDensityApp.tip.small"))
        XCTAssertEqual(E.tier(owning: ["com.example.ScheduleDensityApp.tip.small"]), .free)
    }

    // MARK: - 가진 것 → 칸

    func testNothingOwnedIsFree() {
        XCTAssertEqual(E.tier(owning: []), .free)
    }

    func testHighestOwnedTierWins() {
        XCTAssertEqual(E.tier(owning: [E.plusLifetimeID]), .plus)
        XCTAssertEqual(E.tier(owning: [E.plusLifetimeID, E.proYearlyID]), .pro)
        XCTAssertEqual(E.tier(owning: [E.plusLifetimeID, E.upgradeID]), .pro)
        XCTAssertEqual(E.tier(owning: [E.plusYearlyID, E.graduateID]), .pro)
    }

    func testForeverPassIsTheTopTier() {
        XCTAssertEqual(E.tier(owning: [], foreverPass: true), .pro)
        XCTAssertEqual(E.tier(owning: [E.plusYearlyID], foreverPass: true), .pro)
    }

    func testLifetimeOwnership() {
        XCTAssertTrue(E.ownsLifetime(.plus, in: [E.plusLifetimeID]))
        XCTAssertFalse(E.ownsLifetime(.plus, in: [E.plusYearlyID]), "구독은 평생이 아니다")
        XCTAssertTrue(E.ownsLifetime(.pro, in: [E.upgradeID]))
        XCTAssertTrue(E.ownsLifetime(.pro, in: [E.graduateID]))
        XCTAssertFalse(E.ownsLifetime(.pro, in: [E.proYearlyID, E.monthlyID]))
    }

    func testSubscriptionsAreTheGraduationCandidates() {
        XCTAssertEqual(E.subscriptionIDs, [E.plusYearlyID, E.proYearlyID, E.monthlyID])
        XCTAssertTrue(E.subscriptionIDs.isDisjoint(with: E.lifetimeIDs))
    }

    // MARK: - 기능 → 칸

    func testPlusOpensLookingBack() {
        XCTAssertEqual(ProFeature.ledger.tier, .plus)
        XCTAssertEqual(ProFeature.statistics.tier, .plus)
        XCTAssertEqual(Set(ProFeature.opened(by: .plus)), [.ledger, .statistics])
    }

    func testProOpensGoingOut() {
        XCTAssertEqual(Set(ProFeature.opened(by: .pro)), [.widget, .calendarImport, .scheduleShare])
    }

    func testEveryFeatureNeedsAPaidTier() {
        XCTAssertTrue(ProFeature.opened(by: .free).isEmpty)
        XCTAssertEqual(ProFeature.opened(by: .plus).count + ProFeature.opened(by: .pro).count,
                       ProFeature.sold.count)
    }

    /// Pro 는 Plus 를 전부 포함한다.
    func testProIncludesPlus() {
        for feature in ProFeature.sold {
            XCTAssertGreaterThanOrEqual(ProTier.pro, feature.tier)
        }
        XCTAssertLessThan(ProTier.free, .plus)
        XCTAssertLessThan(ProTier.plus, .pro)
    }

    // MARK: - 맥과 나누는 표 (두 무지개 앱의 약속)

    func testMarkTierStringsAreTheContract() {
        XCTAssertEqual(ProMarkTier.plus.rawValue, "plus")
        XCTAssertEqual(ProMarkTier.pro.rawValue, "pro")
        XCTAssertLessThan(ProMarkTier.plus, .pro)
    }

    /// 등급이 없는 예전 기록은 Pro 로 읽는다.
    func testMarkWithoutTierReadsAsPro() {
        let mark = ProMark(platform: .mac, productID: "x", validUntil: nil)
        mark.tier = nil
        XCTAssertEqual(mark.markTier, .pro)
        mark.tier = "unknown"
        XCTAssertEqual(mark.markTier, .pro)
        mark.tier = "plus"
        XCTAssertEqual(mark.markTier, .plus)
        XCTAssertEqual(ProMark(platform: .mac, productID: "x", validUntil: nil, tier: .plus).tier, "plus")
    }

    func testTierMapsToMark() {
        XCTAssertNil(ProTier.free.mark)
        XCTAssertEqual(ProTier.plus.mark, .plus)
        XCTAssertEqual(ProTier.pro.mark, .pro)
        XCTAssertEqual(ProTier(nil), .free)
        XCTAssertEqual(ProTier(.plus), .plus)
        XCTAssertEqual(ProTier(.pro), .pro)
    }

    func testMarkEntitlementsAreTheTiersProducts() {
        XCTAssertEqual(E.productIDs(opening: .plus), [E.plusYearlyID, E.plusLifetimeID])
        XCTAssertEqual(E.productIDs(opening: .pro),
                       [E.proYearlyID, E.proLifetimeID, E.upgradeID, E.graduateID, E.monthlyID])
        XCTAssertTrue(E.productIDs(opening: .free).isEmpty)
    }

    func testOtherPlatformHighestMarkWins() {
        let other: ProMarkPlatform = ProMarkPlatform.current == .ios ? .mac : .ios
        let plus = ProMark(platform: other, productID: "a", validUntil: nil, tier: .plus)
        let expiredPro = ProMark(platform: other, productID: "b", validUntil: Date().addingTimeInterval(-60), tier: .pro)
        let livePro = ProMark(platform: other, productID: "c", validUntil: Date().addingTimeInterval(3600), tier: .pro)
        let legacy = ProMark(platform: other, productID: "d", validUntil: nil)
        legacy.tier = nil
        let mine = ProMark(platform: ProMarkPlatform.current, productID: "e", validUntil: nil, tier: .pro)

        XCTAssertNil(ProMarkStore.bestOtherTier([]))
        XCTAssertEqual(ProMarkStore.bestOtherTier([plus]), .plus)
        // 끝난 구독의 표는 안 쳐준다.
        XCTAssertEqual(ProMarkStore.bestOtherTier([plus, expiredPro]), .plus)
        XCTAssertEqual(ProMarkStore.bestOtherTier([plus, livePro]), .pro)
        // 등급 없는 예전 표는 Pro.
        XCTAssertEqual(ProMarkStore.bestOtherTier([plus, legacy]), .pro)
        // 내 표는 상대 표로 세지 않는다.
        XCTAssertNil(ProMarkStore.bestOtherTier([mine]))
    }
}
