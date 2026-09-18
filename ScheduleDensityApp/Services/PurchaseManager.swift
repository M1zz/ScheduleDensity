//
//  PurchaseManager.swift
//
//  '무지개 Pro'를 파는 자리. **속은 전부 `LeeoStore`다.**
//
//  이 클래스가 하는 일은 두 가지뿐이다 —
//   ① LeeoKit의 값(`ObservableObject`)을 SwiftUI의 `@Observable` 세계로 옮겨 적는 것,
//   ② 그 값을 앱의 정책(`ProEntitlement`)에 통과시키는 것.
//
//  ⚠️ 맥앱 '무지개 공방'의 같은 이름 파일과 **같은 구조**다. 두 앱이 같은 사다리(연간·평생·월간)를
//     팔고 같은 함정(영수증이 늦게 오면 산 사람이 잠긴다)을 지나므로, 고칠 때 같이 고친다.
//
//  ⚠️ 상품 로드·구매·복원·거래 리스너(다른 기기에서 산 것, 가족 공유, '구입 요청' 승인분,
//     환불, 구독 만료)는 전부 LeeoStore 안에 있다. 여기 직접 쓰지 않는다 —
//     예전에 StoreKit을 직접 쥐고 있었고, 그때 구독 갱신·만료를 따라갈 자리가 없었다.
//

import Foundation
import Combine
import StoreKit
import SwiftData
import WidgetKit
import LeeoKit

@MainActor
@Observable
final class PurchaseManager {

    static let shared = PurchaseManager()

    @ObservationIgnored let store: LeeoStore

    /// 지금 열려 있는가. 화면은 전부 이 값만 본다.
    private(set) var isUnlocked: Bool = ProEntitlement.isUnlocked

    /// **애플에게 물어봐서 답을 받았는가.** false면 화면은 '무료'라고 단정하면 안 된다.
    private(set) var isKnown: Bool = ProEntitlement.isKnown

    /// 페이월에 설 상품들. 계약의 차례(연간 → 평생 → 월간)를 따른다.
    private(set) var products: [Product] = []

    private(set) var isWorking = false

    /// 사다가 막혔을 때 화면에 그대로 보여줄 말. 조용히 실패하면 사용자는 단추가 고장 난 줄 안다.
    private(set) var failureMessage: String?

    /// **Pro를 화면에 세우는가.** 팔고 있거나, 이미 산 사람이면.
    /// 산 사람에게는 판매를 멈춘 뒤에도 계속 보인다 — 값을 치른 것이 사라지면 안 된다.
    var offersPro: Bool { ProEntitlement.sellsPro || isUnlocked }

    /// 설정 화면에 가격 한 줄을 적을 대표 상품 (연간).
    var featuredProduct: Product? {
        products.first { $0.id == ProEntitlement.yearlyID } ?? products.first
    }

    /// **이번 실행에서 영수증을 실제로 읽었는가.**
    ///
    /// ⚠️ 이 플래그가 서기 전에는 캐시에 아무것도 쓰지 않는다. LeeoStore는 상품을 불러오는
    ///    중에도 값이 바뀌었다고 알려 오는데, 그 알림에 대고 `hasPro`(아직 false)를 캐시에
    ///    적어 버리면 **처음 켠 구매자가 '무료'로 못박힌다.** 그 순간 위젯 셋도 같이 잠긴다.
    @ObservationIgnored private var entitlementsChecked = false
    @ObservationIgnored private var observation: AnyCancellable?

    private init() {
        guard let config = ScheduleDensityAppSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다 — ScheduleDensityAppSpec.monetization을 확인할 것")
        }
        store = LeeoStore(config: config)

        // ⚠️ objectWillChange는 값이 바뀌기 **직전**에 온다. 그 자리에서 읽으면 옛 값이므로
        //    다음 차례로 미뤄서 읽는다.
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.pull() }
        }
    }

    // MARK: - 상태 맞추기

    /// 영수증을 다시 읽어 열림/잠김을 정한다. 앱이 켜질 때와 활성화될 때마다 부른다.
    func refresh() async {
        await store.refreshEntitlements()
        if ProEntitlement.sellsPro { await store.loadProducts() }
        entitlementsChecked = true
        await syncCrossPlatformMark()
        pull()
    }

    // MARK: - 한쪽에서 사면 양쪽이 (→ ProMark.swift)

    /// **내 영수증을 맥이 읽을 수 있는 표로 옮겨 적고, 맥이 적어 둔 표를 읽는다.**
    ///
    /// 두 앱은 App Store에서 서로 다른 앱이라 영수증이 건너가지 않는다. 그런데 두 앱을 다
    /// 쓰는 사람에게 두 번 받는 것은 팔기 전에 이미 잃는 장사다. 같은 iCloud를 쓰므로
    /// 산 쪽이 표를 하나 남기면 다른 쪽이 그것을 보고 연다.
    private func syncCrossPlatformMark() async {
        // 맥과 함께 쓰는 그 스토어. 표는 거기 산다 (→ ProMark.swift).
        guard let context = WeekBlocksStore.sharedContainer?.mainContext else { return }

        if store.hasPro {
            // 구독은 끝나는 날을 함께 적는다. 평생 이용권은 끝이 없으므로 비운다.
            var expiry: Date?
            var productID = ProEntitlement.yearlyID
            var lifetime = false
            for await entitlement in Transaction.currentEntitlements {
                guard case .verified(let transaction) = entitlement,
                      ProEntitlement.entitlementIDs.contains(transaction.productID),
                      transaction.revocationDate == nil else { continue }
                productID = transaction.productID
                if let end = transaction.expirationDate {
                    expiry = max(expiry ?? .distantPast, end)
                } else {
                    lifetime = true   // 평생 이용권·옛 1회 구매
                }
            }
            ProMarkStore.stamp(productID: productID, validUntil: lifetime ? nil : expiry, in: context)
        } else {
            // 내 쪽 권한이 사라졌으면 내 표도 지운다 — 해지가 다른 기기에도 닿아야 한다.
            ProMarkStore.clearMine(in: context)
        }

        crossPlatformPro = ProMarkStore.otherPlatformHasPro(in: context)
    }

    /// 맥에서 산 것이 살아 있는가.
    @ObservationIgnored private var crossPlatformPro = false

    /// 상품을 아직 못 불러왔을 때 페이월이 다시 청한다.
    /// 실패해도 조용히 넘어가지 않는다 — 페이월이 값을 못 보여주면 단추가 죽고,
    /// 그 죽은 단추는 "안 팔린 것"으로만 남아 왜 안 팔렸는지가 사라진다.
    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    // MARK: - 사기 / 되찾기

    /// 고른 상품을 산다. 성공·취소·승인 대기·실패의 갈래와 퍼널 이벤트는 LeeoStore 안에 있다.
    func purchase(_ product: Product) async {
        _ = await store.purchase(product)
        entitlementsChecked = true
        pull()
    }

    /// 기기를 바꿨거나 앱을 지웠다 받은 사람이 되찾는 길. 심사에서도 요구한다.
    func restore() async {
        await store.restore()
        entitlementsChecked = true
        pull()
        if !isUnlocked, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 구매한 기록을 찾지 못했습니다.")
        }
    }

    // MARK: -

    private func pull() {
        let before = isUnlocked
        // ⚠️ 물어보기 전에는 캐시에 쓰지 않는다 (위 `entitlementsChecked` 주석).
        // 맥에서 산 표가 살아 있으면 그것도 권한이다 (→ syncCrossPlatformMark).
        if entitlementsChecked { ProEntitlement.setPurchased(store.hasPro || crossPlatformPro) }

        isUnlocked = ProEntitlement.isUnlocked
        isKnown = entitlementsChecked || ProEntitlement.isKnown
        products = store.products
        isWorking = store.purchasingProductID != nil || store.isRestoring
        failureMessage = store.lastError

        // 위젯은 App Group의 그 한 줄만 읽는다. 열림/잠김이 바뀐 판에만 다시 그리게 한다.
        if before != isUnlocked { WidgetCenter.shared.reloadAllTimelines() }
    }
}
