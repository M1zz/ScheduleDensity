//
//  EntitlementLatch.swift
//
//  **산 사람이 잠기지 않게 하는 두 표식.** 영수증 조회는 늦거나 비어서 올 때가 있다.
//  그 한 번의 빈 답으로 평생을 산 사람이 '무료'가 되면 안 된다.
//
//   · 평생 래치: 평생 상품이 영수증에 보이면 그 칸을 Keychain 에 적는다(앱을 지웠다 깔아도 남는다).
//     **올리는 건 바로, 내리는 건 환불을 확인했을 때만** — `Transaction.all` 에서 그 상품의
//     `revocationDate` 를 본 때다. 조회가 비었다는 것만으로는 내리지 않는다.
//   · 구독 표식: 구독은 끝나면 권한도 끝나야 하므로 래치가 아니다. 칸과 **만료일**을 함께 적고,
//     만료일이 지나거나 환불을 확인하면 사라진다. 그 사이 조회가 비어도 만료일까지는 연다.
//
//  판단은 순수 함수(`EntitlementLatch`)로 두고 테스트가 지킨다(→ PricingTierTests).
//  저장(Keychain · App Group)과 StoreKit 조회는 `PurchaseManager` 가 한다.
//

import Foundation
import Security

/// 영수증 한 번 읽은 결과. StoreKit 없이 테스트할 수 있게 값만 담는다.
struct ReceiptSnapshot: Equatable {
    /// 지금 살아 있는 권한 상품(환불 안 된 것).
    var owned: Set<String> = []
    /// `Transaction.all` 에서 환불(`revocationDate`)을 확인한 상품.
    var refunded: Set<String> = []
    /// 살아 있는 구독의 칸과 만료일. 없으면 nil.
    var subscription: SubscriptionMark?
}

/// 구독이 여는 칸과 그 끝. 끝이 지나면 아무것도 열지 않는다.
struct SubscriptionMark: Codable, Equatable {
    var tier: ProTier
    var expires: Date

    func tier(at now: Date) -> ProTier { now < expires ? tier : .free }
}

extension ProTier: Codable {}

enum EntitlementLatch {

    /// 영수증에 보이는 **평생** 상품이 여는 가장 높은 칸.
    static func lifetimeTier(in owned: Set<String>) -> ProTier {
        ProEntitlement.tier(owning: owned.intersection(ProEntitlement.lifetimeIDs))
    }

    /// 평생 래치의 새 값.
    ///
    /// - 영수증의 평생 칸이 더 높으면 바로 올린다.
    /// - 더 낮으면 **래치된 칸을 여는 평생 상품의 환불을 확인했을 때만** 영수증 칸으로 내린다.
    ///   환불 확인이 없으면(조회가 비었거나 늦었으면) 그대로 둔다.
    static func latchedLifetime(current: ProTier, receipt: ReceiptSnapshot) -> ProTier {
        let seen = lifetimeTier(in: receipt.owned)
        if seen >= current { return seen }
        // 래치된 **그 칸**을 여는 평생 상품의 환불이어야 한다. 아래 칸(Plus 평생) 환불로 Pro 가 닫히면 안 된다.
        let latchedTierRefunded = receipt.refunded.contains { id in
            ProEntitlement.lifetimeIDs.contains(id) && ProEntitlement.tier(of: id) == current
        }
        return latchedTierRefunded ? seen : current
    }

    /// 구독 표식의 새 값.
    ///
    /// - 살아 있는 구독이 보이면 그것으로 바꾼다(갱신되면 만료일이 늘어난다).
    /// - 안 보이면 적어 둔 표식을 만료일까지 둔다. 단, 그 칸의 구독이 환불됐으면 지운다.
    static func latchedSubscription(current: SubscriptionMark?, receipt: ReceiptSnapshot,
                                    now: Date) -> SubscriptionMark? {
        if let seen = receipt.subscription { return seen }
        guard let current, current.tier(at: now) > .free else { return nil }
        let refunded = receipt.refunded.contains { id in
            ProEntitlement.subscriptionIDs.contains(id) && ProEntitlement.tier(of: id) == current.tier
        }
        return refunded ? nil : current
    }

    /// 두 표식과 지금 영수증이 함께 여는 칸.
    static func tier(lifetime: ProTier, subscription: SubscriptionMark?, receipt: ReceiptSnapshot,
                     now: Date) -> ProTier {
        max(lifetime, subscription?.tier(at: now) ?? .free, ProEntitlement.tier(owning: receipt.owned))
    }
}

// MARK: - 저장

/// 평생 래치를 두는 Keychain 한 칸. 앱을 지웠다 깔아도 남는다.
///
/// ⚠️ 값은 칸 번호(`ProTier.rawValue`) 하나다. 없으면 무료.
enum LifetimeLatchStore {
    private static let service = "com.example.ScheduleDensityApp.entitlement"
    private static let account = "lifetime.tier"

    static func load() -> ProTier {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let raw = Int(String(decoding: data, as: UTF8.self)),
              let tier = ProTier(rawValue: raw) else { return .free }
        return tier
    }

    static func save(_ tier: ProTier) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: account]
        let data = Data(String(tier.rawValue).utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(base as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// 구독 표식. 위젯과 같은 통(App Group)에 둔다.
enum SubscriptionMarkStore {
    private static let key = "pro.subscriptionMark"

    static func load(from defaults: UserDefaults = ProEntitlement.defaults) -> SubscriptionMark? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SubscriptionMark.self, from: data)
    }

    static func save(_ mark: SubscriptionMark?, to defaults: UserDefaults = ProEntitlement.defaults) {
        guard let mark, let data = try? JSONEncoder().encode(mark) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
