//
//  PaywallView.swift
//  ScheduleDensityApp
//
//  '무지개 Pro'를 파는 한 장.
//
//  ⚠️ 맥앱 '무지개 공방'의 같은 이름 파일과 **같은 순서**로 말한다 —
//     무엇이 그대로 무료인지 → 사면 열리는 것 → 요금제 셋 → 자동 갱신 고지와 약관.
//     두 앱이 같은 사다리를 파는데 화면이 다른 말을 하면, 두 앱을 다 쓰는 사람이
//     어느 쪽을 믿어야 할지 모른다.
//
//  **무료인 것을 먼저 말한다.** 페이월은 "이걸 안 사면 못 쓴다"가 아니라 "이 앱은 이만큼
//  무료이고, 쌓여야 보이는 것만 값을 받는다"는 말이라야 한다. 사는 사람도 안 사는 사람도
//  이 화면을 닫고 나서 앱을 계속 쓴다.
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallView: View {
    /// 어디서 들어왔는가. 그 자리를 목록 맨 위에 세워 "지금 누른 그것"이 보이게 한다.
    var highlight: ProFeature?

    @State private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// 고른 상품. 처음엔 연간.
    @State private var selectedID: String = ProEntitlement.yearlyID
    /// 체험을 받을 수 있는 구독 상품들. 이미 한 번 받은 사람에게 '무료 체험'이라고 말하면 거짓말이다.
    @State private var trialEligible: Set<String> = []

    private var selectedProduct: Product? {
        purchases.products.first { $0.id == selectedID }
    }

    /// 열리는 것 — 지금 누른 자리가 맨 위.
    private var features: [ProFeature] {
        let sold = ProFeature.sold
        guard let highlight, sold.contains(highlight) else { return sold }
        return [highlight] + sold.filter { $0 != highlight }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    freeSection
                    paidSection
                    plans
                    if let message = purchases.failureMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                    legal
                }
                .padding(20)
                .padding(.bottom, 120)   // 아래 고정 단추에 글이 가리지 않게
            }
            .navigationTitle("무지개 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("나중에") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("복원") {
                        Task {
                            await purchases.restore()
                            if purchases.isUnlocked { dismiss() }
                        }
                    }
                    .disabled(purchases.isWorking)
                }
            }
            .safeAreaInset(edge: .bottom) { buyBar }
            // ⚠️ `.onAppear`가 아니라 `.task`다. NavigationStack 안의 onAppear는 재진입·레이아웃
            //    변화로 여러 번 불려서, 페이월 조회수(=전환율의 분모)를 부풀린다.
            .task {
                // 본 횟수는 기기 안에 따로 센다 — 허브로 가는 분석은 동의한 사람만이라
                // 그 숫자만으로는 전환율의 분모가 되지 못한다 (→ UsageDiary).
                UsageDiary.markPaywallSeen()
                LeeoAnalyticsCenter.track(.paywallShown(reason: highlight?.rawValue ?? "settings"))
                await purchases.loadProducts()
                await loadTrialEligibility()
            }
        }
    }

    // MARK: 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("쌓여야 보이는 것을 엽니다")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("오늘을 사는 데 필요한 것은 그대로 무료입니다. 맥 '무지개 공방'과 오가는 것도 무료입니다.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 그대로 무료인 것 (먼저 말한다)

    private var freeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("그대로 무료인 것")
            row("rainbow", "무지개", "일정이 겹칠수록 진해지는 격자. 개수 제한 없습니다.")
            row("checklist", "할 일과 단계 쪼개기", "두 질문으로 조각과 덩어리를 가르는 것까지 전부.")
            row("timer", "타이머", "계획에 적힌 시간을 거꾸로 셉니다.")
            row("iphone.and.arrow.forward", "맥과 오가기", "같은 Apple 계정이면 양쪽에서 보입니다.")
        }
    }

    // MARK: 사면 열리는 것

    private var paidSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Pro가 여는 것")
            ForEach(features) { feature in
                row(feature.systemImage, LocalizedStringKey(feature.title), LocalizedStringKey(feature.note),
                    highlighted: feature == highlight)
            }
        }
    }

    // MARK: 요금제

    private var plans: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("요금제")
            if purchases.products.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("값을 불러오는 중…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    // 한 번 실패하면 영영 죽은 단추로 남지 않게, 그 자리에서 다시 청한다.
                    Button("다시 시도") { Task { await purchases.loadProducts() } }
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 8)
            } else {
                ForEach(purchases.products, id: \.id) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let selected = product.id == selectedID
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            guard !selected else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { selectedID = product.id }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planName(product))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        if product.id == ProEntitlement.yearlyID {
                            Text("추천")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    Text(planNote(product))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(product.displayPrice)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    if let unit = periodUnit(product) {
                        Text(unit)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                shape.fill(selected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
                shape.strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    // MARK: 사는 자리

    private var buyBar: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = selectedProduct else { return }
                Task {
                    await purchases.purchase(product)
                    if purchases.isUnlocked {
                        UsageDiary.markPaywallBought()
                        dismiss()
                    }
                }
            } label: {
                Group {
                    if purchases.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(buyTitle)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(purchases.isWorking || selectedProduct == nil)

            if let product = selectedProduct, trialEligible.contains(product.id) {
                Text("체험 중에 해지하면 요금이 나가지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var buyTitle: String {
        guard let product = selectedProduct else { return String(localized: "계속") }
        if trialEligible.contains(product.id) { return String(localized: "무료 체험 시작") }
        return String(localized: "\(product.displayPrice) 결제")
    }

    // MARK: 약관 (구독을 파는 앱의 심사 필수 항목)

    private var legal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 요금으로 자동 갱신되며, Apple 계정으로 결제됩니다. 무료 체험 중에 해지하면 요금이 나가지 않습니다. 해지와 관리는 App Store의 계정 설정에서 합니다. 평생 이용권은 구독이 아니라 한 번 결제입니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                if let terms = ScheduleDensityAppSpec.monetization.subscriptionTermsURL {
                    Button("이용약관") { openURL(terms) }
                }
                Button("개인정보 처리방침") { openURL(ScheduleDensityAppSpec.legal.privacyURL) }
            }
            .font(.caption)
        }
    }

    // MARK: 부속

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ note: LocalizedStringKey,
                     highlighted: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(highlighted ? Color.accentColor : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium))
                Text(note).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, highlighted ? 8 : 0)
        .padding(.horizontal, highlighted ? 10 : 0)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
    }

    private func planName(_ product: Product) -> String {
        switch product.id {
        case ProEntitlement.yearlyID: String(localized: "연간")
        case ProEntitlement.lifetimeID: String(localized: "평생")
        case ProEntitlement.monthlyID: String(localized: "월간")
        default: product.displayName
        }
    }

    private func planNote(_ product: Product) -> String {
        if trialEligible.contains(product.id), let days = trialDays(product) {
            return String(localized: "\(days)일 무료로 써 보고, 그 뒤에 결제됩니다.")
        }
        switch product.id {
        case ProEntitlement.lifetimeID: return String(localized: "한 번 결제로 계속 씁니다. 구독이 아닙니다.")
        case ProEntitlement.monthlyID: return String(localized: "달마다 결제되고 언제든 해지합니다.")
        default: return String(localized: "해마다 결제되고 언제든 해지합니다.")
        }
    }

    /// "/ 년" · "/ 월". 평생 이용권에는 없다.
    private func periodUnit(_ product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }
        switch period.unit {
        case .year: return String(localized: "/ 년")
        case .month: return String(localized: "/ 월")
        case .week: return String(localized: "/ 주")
        case .day: return String(localized: "/ 일")
        @unknown default: return nil
        }
    }

    /// 체험 기간을 날수로. 체험이 아닌 할인 제안이면 nil.
    private func trialDays(_ product: Product) -> Int? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let unitDays: Int
        switch offer.period.unit {
        case .day: unitDays = 1
        case .week: unitDays = 7
        case .month: unitDays = 30
        case .year: unitDays = 365
        @unknown default: return nil
        }
        return offer.period.value * unitDays * max(1, offer.periodCount)
    }

    /// **이미 체험을 쓴 사람에게 '무료 체험'이라고 말하지 않는다.** 그 말은 한 번 쓰면 거짓말이 되고,
    /// 결제 창에서 값이 바로 청구되는 것을 보는 순간 신뢰가 깨진다.
    private func loadTrialEligibility() async {
        var eligible: Set<String> = []
        for product in purchases.products {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer?.paymentMode == .freeTrial else { continue }
            if await subscription.isEligibleForIntroOffer { eligible.insert(product.id) }
        }
        trialEligible = eligible
    }
}

// MARK: - 잠긴 자리에서 부르는 길
//
// 막힌 곳마다 시트 상태·조건문을 따로 두면 다섯 군데가 조금씩 달라진다.
// 눌렀을 때 열려 있으면 하던 일을, 잠겨 있으면 페이월을 내는 것 하나로 묶는다.

extension View {
    /// `isPresented`가 켜지면 그 기능의 페이월을 낸다.
    func paywall(for feature: ProFeature, isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            PaywallView(highlight: feature)
        }
    }
}

/// 잠긴 줄 오른쪽에 붙는 작은 자물쇠. 눌러보기 전에 잠긴 걸 알 수 있어야 한다.
struct ProLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
            .accessibilityLabel("잠김, 무지개 Pro 필요")
    }
}
