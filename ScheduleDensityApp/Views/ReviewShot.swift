//
//  ReviewShot.swift
//
//  인앱 상품 **심사용 이미지** — 선물 화면을 결제 없이 그린다(LeeoKit `LeeoGiftView(previewPrice:)`).
//  시뮬레이터에는 StoreKit 상품이 오지 않아 실제 화면은 단추가 비어 있다. **DEBUG 빌드에서만** 선다.
//
//      xcrun simctl launch <기기> com.example.ScheduleDensityApp \
//          -reviewShot com.example.ScheduleDensityApp.gift.plus -reviewShotPrice '$9.99'
//

import SwiftUI
import LeeoKit

extension View {
    /// DEBUG 에서 `-reviewShot` 이 있으면 앱 화면 대신 그 선물 화면을 그린다. 출시 빌드에서는 아무것도 하지 않는다.
    @ViewBuilder
    func reviewShotOverlay() -> some View {
        #if DEBUG
        // 덮지 않고 **바꿔 낀다.** 덮으면 온보딩(풀스크린 커버)이 그 위로 올라온다.
        if let productID = UserDefaults.standard.string(forKey: "reviewShot") {
            // `-reviewShot paywall` 은 페이월(기능 그림 확인 · 스크린샷용)
            if productID == "paywall" { PaywallView() } else { ReviewShotView(productID: productID) }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if DEBUG
private struct ReviewShotView: View {
    let productID: String
    private let gifts = PurchaseManager.shared.store.gifts

    var body: some View {
        NavigationStack {
            if let gift = gifts.first(where: { $0.config.productID == productID }) {
                LeeoGiftView<ScheduleDensityAppSpec>(
                    previewPrice: UserDefaults.standard.string(forKey: "reviewShotPrice") ?? "$9.99", gift: gift)
                    .navigationTitle(String(localized: "선물하기"))
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                Text(verbatim: "no gift \(productID)")
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
#endif
