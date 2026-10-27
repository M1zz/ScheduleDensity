//
//  PurchaseManager.swift
//
//  무지개 Plus · Pro 를 파는 자리. **속은 전부 `LeeoStore`다.**
//
//  이 클래스가 하는 일은 두 가지뿐이다 —
//   ① LeeoKit의 값(`ObservableObject`)을 SwiftUI의 `@Observable` 세계로 옮겨 적는 것,
//   ② 그 값을 앱의 정책(`ProEntitlement`)에 통과시키는 것.
//
//  ⚠️ 맥앱 '무지개 공방'의 같은 이름 파일과 **같은 구조**다. 두 앱이 같은 사다리(무료 · Plus · Pro,
//     칸마다 연 구독과 평생)를
//     팔고 같은 함정(영수증이 늦게 오면 산 사람이 잠긴다)을 지나므로, 고칠 때 같이 고친다.
//
//  ⚠️ 상품 로드·구매·복원·거래 리스너(다른 기기에서 산 것, 가족 공유, '구입 요청' 승인분,
//     환불, 구독 만료)는 전부 LeeoStore 안에 있다. 여기 직접 쓰지 않는다 —
//     예전에 StoreKit을 직접 쥐고 있었고, 그때 구독 갱신·만료를 따라갈 자리가 없었다.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
import SwiftData
import WidgetKit
import LeeoKit

@MainActor
@Observable
final class PurchaseManager {

    static let shared = PurchaseManager()

    @ObservationIgnored let store: LeeoStore

    /// 언제나 평생 패스. 열려 있으면 가장 높은 칸(Pro)이다.
    /// 캐시는 위젯과 함께 쓰는 통에 둔다 (위젯이 같은 답을 보게).
    @ObservationIgnored let foreverPass = LeeoForeverPass(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
                                                          defaults: ProEntitlement.defaults)

    /// 지금 쓰는 칸. 화면은 전부 이 값(과 `allows`)만 본다.
    private(set) var tier: ProTier = ProEntitlement.tier

    /// **애플에게 물어봐서 답을 받았는가.** false면 화면은 '무료'라고 단정하면 안 된다.
    private(set) var isKnown: Bool = ProEntitlement.isKnown

    /// 페이월에 설 상품들.
    private(set) var products: [Product] = []

    /// 이 Apple 계정이 가진 권한 상품들 (산 것 · 구독 중인 것).
    private(set) var ownedProductIDs: Set<String> = []

    /// 지금 살아 있는 구독. 있으면 설정에 '평생으로 바꾸기' 가 선다.
    private(set) var subscription: LeeoGraduation.Subscription?

    private(set) var isWorking = false

    /// 사다가 막혔을 때 화면에 그대로 보여줄 말. 조용히 실패하면 사용자는 단추가 고장 난 줄 안다.
    private(set) var failureMessage: String?

    /// **이번 실행에서 영수증을 실제로 읽었는가.**
    ///
    /// ⚠️ 이 플래그가 서기 전에는 캐시에 아무것도 쓰지 않는다. LeeoStore는 상품을 불러오는
    ///    중에도 값이 바뀌었다고 알려 오는데, 그 알림에 대고 아직 빈 권한을 캐시에
    ///    적어 버리면 **처음 켠 구매자가 '무료'로 못박힌다.** 그 순간 위젯도 같이 잠긴다.
    @ObservationIgnored private var entitlementsChecked = false
    @ObservationIgnored private var observations: [AnyCancellable] = []

    private init() {
        guard let config = ScheduleDensityAppSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다. ScheduleDensityAppSpec.monetization을 확인할 것")
        }
        store = LeeoStore(config: config)

        // ⚠️ objectWillChange는 값이 바뀌기 **직전**에 온다. 그 자리에서 읽으면 옛 값이므로
        //    다음 차례로 미뤄서 읽는다.
        observations = [store.objectWillChange.eraseToAnyPublisher(),
                        foreverPass.objectWillChange.eraseToAnyPublisher()].map {
            $0.sink { [weak self] _ in Task { @MainActor in self?.pull() } }
        }
    }

    /// 이 기능을 써도 되는가.
    func allows(_ feature: ProFeature) -> Bool { tier >= feature.tier }

    /// 이 칸의 평생을 이미 가졌는가.
    func ownsLifetime(_ tier: ProTier) -> Bool { ProEntitlement.ownsLifetime(tier, in: ownedProductIDs) }

    /// 상품 하나. 아직 못 불러왔으면 nil.
    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    // MARK: - 상태 맞추기

    /// 영수증을 다시 읽어 칸을 정한다. 앱이 켜질 때와 활성화될 때마다 부른다.
    func refresh() async {
        await store.refreshEntitlements()
        await foreverPass.refresh()
        if ProEntitlement.sellsPro { await store.loadProducts() }
        entitlementsChecked = true
        await syncCrossPlatformMark()
        subscription = await LeeoGraduation.currentSubscription(among: ProEntitlement.subscriptionIDs)
        pull()
    }

    /// **구독 졸업을 제안할 때인가.** 6개월째와 갱신 7일 전에 한 번씩 (→ LeeoGraduation).
    /// 띄운 쪽이 `markGraduationOffered()` 를 부른다.
    var graduationIsDue: Bool {
        guard let subscription, product(ProEntitlement.graduateID) != nil else { return false }
        return LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered())
    }

    func markGraduationOffered() { LeeoGraduation.markOffered() }

    // MARK: - 한쪽에서 사면 양쪽이 (→ ProMark.swift)

    /// **내 영수증의 칸을 맥이 읽을 수 있는 표로 옮겨 적고, 맥이 적어 둔 표를 읽는다.**
    ///
    /// 두 앱은 App Store에서 서로 다른 앱이라 영수증이 건너가지 않는다. 같은 iCloud를 쓰므로
    /// 산 쪽이 표를 하나 남기면 다른 쪽이 그것을 보고 같은 칸을 연다.
    /// ⚠️ 표에는 **이 앱의 영수증**만 적는다. 패스는 두 앱이 각자 판정한다.
    private func syncCrossPlatformMark() async {
        // 맥과 함께 쓰는 그 스토어. 표는 거기 산다 (→ ProMark.swift).
        guard let context = WeekBlocksStore.sharedContainer?.mainContext else { return }
        let mine = receiptTier
        markedTier = mine
        crossPlatformTier = ProTier(await ProMarkStore.sync(tier: mine.mark,
                                                            entitlementIDs: ProEntitlement.productIDs(opening: mine),
                                                            defaultProductID: mine == .plus ? ProEntitlement.plusYearlyID
                                                                                            : ProEntitlement.proYearlyID,
                                                            in: context))
    }

    /// 이 앱의 영수증이 여는 칸.
    private var receiptTier: ProTier { ProEntitlement.tier(owning: store.purchasedProductIDs) }

    /// 맥에서 산 칸.
    @ObservationIgnored private var crossPlatformTier: ProTier = .free

    /// 내 표에 마지막으로 옮겨 적은 칸. 영수증이 이것과 달라지면 표를 다시 적는다.
    ///
    /// ⚠️ 전에는 켤 때(`refresh`)만 표를 적어서, 여기서 막 산 사람이 바로 맥을 켜면
    ///    맥은 아직 표를 못 봤다. 이 앱을 한 번 더 켜야 열렸다. 해지·환불·가족 공유도 같았다.
    @ObservationIgnored private var markedTier: ProTier?

    /// 상품을 아직 못 불러왔을 때 페이월이 다시 청한다.
    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    // MARK: - 사기 / 되찾기

    /// 고른 상품을 산다. 성공·취소·승인 대기·실패의 갈래와 퍼널 이벤트는 LeeoStore 안에 있다.
    ///
    /// ⚠️ `action`은 페이월의 `@Environment(\.purchase)`다. `product.purchase()`로 사면
    ///    결제 시트를 띄울 창을 StoreKit이 짐작하는데, 아이패드에서 그 짐작이 빗나가
    ///    구매가 오류로 끝났다. 1.1.8 심사가 iPad Air에서 그걸로 2.1(b) 거절을 냈다.
    func purchase(_ product: Product, using action: PurchaseAction) async {
        _ = await store.purchase(product) { try await action($0) }
        entitlementsChecked = true
        subscription = await LeeoGraduation.currentSubscription(among: ProEntitlement.subscriptionIDs)
        pull()
    }

    /// 기기를 바꿨거나 앱을 지웠다 받은 사람이 되찾는 길. 심사에서도 요구한다.
    func restore() async {
        await store.restore()
        await foreverPass.refresh()
        entitlementsChecked = true
        pull()
        if tier == .free, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 구매한 기록을 찾지 못했습니다.")
        }
    }

    // MARK: -

    private func pull() {
        // 사기·복원·리스너(다른 기기, 가족 공유, 환불, 만료)로 영수증이 바뀌었으면 표도 바로 고친다.
        if entitlementsChecked, let marked = markedTier, marked != receiptTier {
            markedTier = receiptTier
            Task { await syncCrossPlatformMark(); pull() }
        }
        let before = tier
        // ⚠️ 물어보기 전에는 캐시에 쓰지 않는다 (위 `entitlementsChecked` 주석).
        // 영수증 · 패스 · 맥에서 산 표 가운데 가장 높은 칸이다.
        if entitlementsChecked {
            let owned = ProEntitlement.tier(owning: store.purchasedProductIDs, foreverPass: foreverPass.isActive)
            ProEntitlement.setTier(max(owned, crossPlatformTier))
        }

        tier = ProEntitlement.tier
        isKnown = entitlementsChecked || ProEntitlement.isKnown
        products = store.products
        ownedProductIDs = store.purchasedProductIDs
        isWorking = store.purchasingProductID != nil || store.isRestoring
        failureMessage = store.lastError

        // 위젯은 App Group의 그 한 줄만 읽는다. 칸이 바뀐 판에만 다시 그리게 한다.
        if before != tier { WidgetCenter.shared.reloadAllTimelines() }
    }
}

// MARK: - 맥과 나누는 표의 등급 (→ ProMark.swift)

extension ProTier {
    /// 표에 적는 등급. 무료는 표가 없다.
    var mark: ProMarkTier? {
        switch self {
        case .free: nil
        case .plus: .plus
        case .pro:  .pro
        }
    }

    init(_ mark: ProMarkTier?) {
        switch mark {
        case .plus: self = .plus
        case .pro:  self = .pro
        case nil:   self = .free
        }
    }
}
