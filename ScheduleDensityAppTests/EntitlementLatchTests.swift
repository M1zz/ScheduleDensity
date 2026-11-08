//
//  EntitlementLatchTests.swift
//  ScheduleDensityAppTests
//
//  산 사람이 잠기지 않는가 (→ EntitlementLatch.swift), 선물 · 팁이 권한을 열지 않는가,
//  예전에 산 사람의 권한이 그대로인가.
//

import XCTest
import LeeoKit
@testable import ScheduleDensityApp

final class EntitlementLatchTests: XCTestCase {

    private typealias E = ProEntitlement
    private typealias L = EntitlementLatch
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    // MARK: - 평생 래치

    func testLifetimeRaisesAtOnce() {
        XCTAssertEqual(L.latchedLifetime(current: .free, receipt: .init(owned: [E.plusLifetimeID])), .plus)
        XCTAssertEqual(L.latchedLifetime(current: .plus, receipt: .init(owned: [E.proLifetimeID])), .pro)
        XCTAssertEqual(L.latchedLifetime(current: .plus, receipt: .init(owned: [E.upgradeID])), .pro)
        XCTAssertEqual(L.latchedLifetime(current: .free, receipt: .init(owned: [E.graduateID])), .pro)
    }

    /// 조회가 비어 왔다고 평생을 산 사람을 무료로 내리지 않는다.
    func testEmptyReceiptKeepsLifetime() {
        XCTAssertEqual(L.latchedLifetime(current: .pro, receipt: .init()), .pro)
        XCTAssertEqual(L.latchedLifetime(current: .plus, receipt: .init()), .plus)
    }

    /// 구독만 보이는 영수증도 평생 래치를 내리지 않는다(구독은 평생이 아니다).
    func testSubscriptionDoesNotMoveLifetime() {
        XCTAssertEqual(L.latchedLifetime(current: .free, receipt: .init(owned: [E.proYearlyID])), .free)
        XCTAssertEqual(L.latchedLifetime(current: .pro, receipt: .init(owned: [E.plusYearlyID])), .pro)
    }

    /// 환불을 확인했을 때만 내린다.
    func testRefundLowersLifetime() {
        XCTAssertEqual(L.latchedLifetime(current: .pro, receipt: .init(refunded: [E.proLifetimeID])), .free)
        XCTAssertEqual(L.latchedLifetime(current: .pro,
                                         receipt: .init(owned: [E.plusLifetimeID], refunded: [E.upgradeID])), .plus)
    }

    /// 다른 칸의 환불은 이 칸을 내리지 않는다. Plus 평생 환불로 Pro 평생이 닫히면 안 된다.
    func testRefundOfLowerTierKeepsHigher() {
        XCTAssertEqual(L.latchedLifetime(current: .pro, receipt: .init(refunded: [E.plusLifetimeID])), .pro)
    }

    /// 구독 환불은 평생 래치와 무관하다.
    func testSubscriptionRefundKeepsLifetime() {
        XCTAssertEqual(L.latchedLifetime(current: .pro, receipt: .init(refunded: [E.proYearlyID])), .pro)
    }

    // MARK: - 구독 표식

    func testSubscriptionMarkFollowsReceipt() {
        let mark = SubscriptionMark(tier: .pro, expires: now.addingTimeInterval(86_400))
        XCTAssertEqual(L.latchedSubscription(current: nil, receipt: .init(subscription: mark), now: now), mark)
    }

    /// 조회가 비어도 만료일까지는 연다.
    func testSubscriptionMarkSurvivesEmptyReceiptUntilExpiry() {
        let mark = SubscriptionMark(tier: .plus, expires: now.addingTimeInterval(3_600))
        XCTAssertEqual(L.latchedSubscription(current: mark, receipt: .init(), now: now), mark)
        XCTAssertEqual(L.tier(lifetime: .free, subscription: mark, receipt: .init(), now: now), .plus)
    }

    /// 만료일이 지나면 닫힌다. 구독은 래치가 아니다.
    func testSubscriptionMarkExpires() {
        let mark = SubscriptionMark(tier: .pro, expires: now.addingTimeInterval(-1))
        XCTAssertNil(L.latchedSubscription(current: mark, receipt: .init(), now: now))
        XCTAssertEqual(L.tier(lifetime: .free, subscription: mark, receipt: .init(), now: now), .free)
    }

    func testSubscriptionRefundClearsMark() {
        let mark = SubscriptionMark(tier: .pro, expires: now.addingTimeInterval(86_400))
        XCTAssertNil(L.latchedSubscription(current: mark, receipt: .init(refunded: [E.proYearlyID]), now: now))
        // 다른 칸 구독의 환불은 이 표식을 지우지 않는다.
        XCTAssertEqual(L.latchedSubscription(current: mark, receipt: .init(refunded: [E.plusYearlyID]), now: now), mark)
    }

    func testHighestOfLatchMarkAndReceiptWins() {
        let mark = SubscriptionMark(tier: .plus, expires: now.addingTimeInterval(86_400))
        XCTAssertEqual(L.tier(lifetime: .pro, subscription: mark, receipt: .init(), now: now), .pro)
        XCTAssertEqual(L.tier(lifetime: .free, subscription: mark, receipt: .init(owned: [E.proYearlyID]), now: now), .pro)
    }

    func testSubscriptionMarkRoundTrips() {
        let defaults = UserDefaults(suiteName: "EntitlementLatchTests")!
        defer { defaults.removePersistentDomain(forName: "EntitlementLatchTests") }
        let mark = SubscriptionMark(tier: .plus, expires: now)
        SubscriptionMarkStore.save(mark, to: defaults)
        XCTAssertEqual(SubscriptionMarkStore.load(from: defaults), mark)
        SubscriptionMarkStore.save(nil, to: defaults)
        XCTAssertNil(SubscriptionMarkStore.load(from: defaults))
    }

    // MARK: - 선물 · 팁은 권한을 열지 않는다

    func testGiftAndTipProductsAreNotSoldOrEntitled() {
        let extras = E.giftProductIDs.union(E.tipProductIDs)
        XCTAssertTrue(extras.isDisjoint(with: E.productIDs), "선물 · 팁을 사면 그 사람이 유료 칸이 된다")
        XCTAssertTrue(extras.isDisjoint(with: E.entitlementIDs))
        for id in extras { XCTAssertNil(E.tier(of: id), id) }
    }

    /// 선물은 App Store 오퍼 코드로 그 칸의 **평생** 상품을 연다. 받는 상품은 권한 목록에 있어야 한다.
    func testGiftsGrantLifetimeOfTheirTierThroughOfferCodes() {
        let pro = ScheduleDensityAppSpec.giftConfig
        XCTAssertEqual(pro.productID, E.giftProductID)
        XCTAssertEqual(pro.grantsProductID, E.proLifetimeID)
        XCTAssertTrue(pro.sellsGifts)
        XCTAssertNil(pro.poolKey, "Pro 묶음은 예전 그대로 번들 ID 열쇠다")

        let plus = try! XCTUnwrap(ScheduleDensityAppSpec.moreGiftConfigs.first)
        XCTAssertEqual(ScheduleDensityAppSpec.moreGiftConfigs.count, 1)
        XCTAssertEqual(plus.productID, E.plusGiftProductID)
        XCTAssertEqual(plus.grantsProductID, E.plusLifetimeID)
        XCTAssertTrue(plus.sellsGifts)
        XCTAssertEqual(plus.tierName, "Plus")
        XCTAssertEqual(plus.poolKey, "com.example.ScheduleDensityApp#" + E.plusLifetimeID)

        for gift in [pro, plus] {
            XCTAssertTrue(E.entitlementIDs.contains(gift.grantsProductID))
            XCTAssertTrue(E.lifetimeIDs.contains(gift.grantsProductID))
        }
    }

    func testGiftProductIDsMatchStoreConsole() {
        XCTAssertEqual(E.giftProductID, "com.example.ScheduleDensityApp.gift.pro")
        XCTAssertEqual(E.plusGiftProductID, "com.example.ScheduleDensityApp.gift.plus")
    }

    // MARK: - 예전에 산 사람

    /// 1.1.x 의 4,900원 상품, 판매를 멈춘 월 구독, 올리기 · 졸업가 — 모두 권한 목록에 남는다.
    func testExistingBuyersKeepTheirTier() {
        for (id, tier) in [(E.proLifetimeID, ProTier.pro), (E.monthlyID, .pro), (E.upgradeID, .pro),
                           (E.graduateID, .pro), (E.plusLifetimeID, .plus),
                           (E.plusYearlyID, .plus), (E.proYearlyID, .pro)] {
            XCTAssertTrue(E.entitlementIDs.contains(id), id)
            XCTAssertEqual(E.tier(of: id), tier, id)
        }
    }

    /// 평생 상품을 산 사람은 래치에 적힌다. 1.1.x 구매자도 같다.
    func testLegacyLifetimeBuyerIsLatched() {
        XCTAssertEqual(L.latchedLifetime(current: .free, receipt: .init(owned: [E.proLifetimeID])), .pro)
        XCTAssertEqual(L.latchedLifetime(current: .pro, receipt: .init()), .pro)
    }
}
