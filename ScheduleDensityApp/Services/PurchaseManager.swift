//
//  PurchaseManager.swift
//
//  '모두 열기' 한 개(비소모성)를 파는 StoreKit 2 껍데기.
//
//  구독이 아니라 **평생 1회 구매**다. 갱신·유예·환불 상태를 따라다닐 필요가 없고,
//  산 사람은 다시 묻지 않아도 되며, 기기를 바꿔도 '구매 복원'으로 되찾는다.
//
//  권한의 근거는 언제나 `Transaction.currentEntitlements`다. App Group에 적어 둔
//  `ProEntitlement`의 한 줄은 위젯이 읽으라고 둔 거울일 뿐이라, 켤 때마다 여기서 덮어쓴다.
//

import Foundation
import StoreKit
import WidgetKit

@MainActor
@Observable
final class PurchaseManager {

    static let shared = PurchaseManager()

    /// 지금 열려 있는가. 화면은 전부 이 값만 본다.
    ///
    /// ⚠️ 값을 여기 따로 들고 있지 않는다. 근거는 App Group에 적힌 한 줄뿐이고,
    ///    이것은 그것을 그대로 비추기만 한다.
    ///
    ///    전에는 켤 때 한 번 읽어 캐시했다. 그 캐시는 `apply`에서만 고쳐지는데,
    ///    `apply`는 `refresh()`의 StoreKit 조회가 끝나야 불린다. 조회가 늦으면
    ///    캐시만 낡은 채 남는다 — 실시간 값을 읽는 적기·위젯은 열려 있는데,
    ///    캐시를 읽는 설정 화면은 '무료 버전'이라고 말했다.
    ///    진실이 두 벌이면 언젠가 반드시 갈라진다. 그래서 한 벌만 둔다.
    var isUnlocked: Bool {
        access(keyPath: \.isUnlocked)
        return ProEntitlement.isUnlocked
    }

    /// App Store에서 받아온 상품. 못 받아오면 값을 못 보여주므로 구매 버튼을 막는다.
    private(set) var product: Product?

    private(set) var isPurchasing = false
    private(set) var isRestoring = false

    /// 사용자에게 보여줄 마지막 실패 사유. 성공하면 비운다.
    var failureMessage: String?

    /// 앱 밖에서 일어난 거래(가족 공유, 다른 기기의 구매, 환불)를 받는 자리.
    private var updates: Task<Void, Never>?

    private init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refresh()
            }
        }
    }

    // deinit에서 updates를 끊지 않는다. 이 객체는 앱과 수명이 같은 하나뿐인 것이라
    // 죽을 일이 없고, @MainActor 격리된 속성은 nonisolated인 deinit에서 못 읽는다.

    // MARK: - 상태 맞추기

    /// 영수증을 다시 읽어 열림/잠김을 정한다. 앱이 켜질 때와 활성화될 때마다 부른다.
    func refresh() async {
        var owned = false
        var seen: [String] = []
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            seen.append(transaction.productID)
            if transaction.productID == ProEntitlement.productID, transaction.revocationDate == nil {
                owned = true
            }
        }
#if DEBUG
        // 안 열릴 때 물어볼 것은 둘뿐이다 — 영수증이 오기는 했는가, 그리고 그 안의
        // 상품 ID가 우리가 찾는 것과 같은가. 둘 다 여기서 눈으로 확인한다.
        //
        // ⚠️ 스킴에 로컬 StoreKit 설정이 붙어 있으면 이 목록은 **가짜 스토어의 것**이다.
        //    진짜 영수증을 보려면 Edit Scheme → Run → Options → StoreKit Configuration
        //    을 None 으로 두고 실기기에서 돌려야 한다 (→ project.yml 의 schemes).
        print("🔑 [Purchase] 찾는 ID: \(ProEntitlement.productID)")
        print("🔑 [Purchase] 영수증에 있는 ID: \(seen.isEmpty ? "(없음)" : seen.joined(separator: ", "))")
        print("🔑 [Purchase] 샀는가: \(owned) / 지금 열려 있는가: \(ProEntitlement.isUnlocked)")
#endif
        apply(owned: owned)
    }

    /// 값을 보여주려면 상품이 필요하다. 실패해도 조용히 넘어간다 —
    /// 네트워크가 없다고 화면이 오류로 덮이면, 이미 산 사람에게도 그렇게 보인다.
    func loadProduct() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [ProEntitlement.productID]).first
    }

    // MARK: - 사기 / 되찾기

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        failureMessage = nil
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    apply(owned: true)
                } else {
                    // 서명이 안 맞는 영수증. 열어주지 않는다.
                    failureMessage = "구매를 확인하지 못했습니다. 잠시 뒤 다시 시도해 주세요."
                }
            case .pending:
                // 승인 대기(가족 공유의 '구매 요청' 등). 실패가 아니므로 그렇게 말한다.
                failureMessage = "승인을 기다리는 중입니다. 승인되면 자동으로 열립니다."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            failureMessage = "구매하지 못했습니다: \(error.localizedDescription)"
        }
    }

    /// 기기를 바꿨거나 앱을 지웠다 받은 사람이 되찾는 길. 심사에서도 요구한다.
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        failureMessage = nil
        defer { isRestoring = false }

        try? await AppStore.sync()
        await refresh()
        if !isUnlocked {
            failureMessage = "이 Apple 계정에서 구매한 기록을 찾지 못했습니다."
        }
    }

    // MARK: -

    private func apply(owned: Bool) {
        mutatingEntitlement { ProEntitlement.setPurchased(owned) }
    }

    /// App Group의 한 줄을 바꾸는 일은 **전부 여기를 지난다.**
    ///
    /// `isUnlocked`가 계산 프로퍼티라 저장 프로퍼티처럼 저절로 알려지지 않는다.
    /// 밖에서 그 한 줄을 직접 고치면 화면은 낡은 말을 계속 하게 되므로,
    /// 고치는 자리를 하나로 모아 여기서 알린다.
    private func mutatingEntitlement(_ change: () -> Void) {
        let before = ProEntitlement.isUnlocked
        change()
        guard ProEntitlement.isUnlocked != before else { return }
        // 값은 이미 바뀐 뒤다. 괄호 안에서 더 할 일은 없고, 바뀌었다고 알리기만 한다.
        withMutation(keyPath: \.isUnlocked) { }
        // 위젯은 App Group의 한 줄만 읽는다. 바뀌었으면 다시 그리라고 알린다.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
