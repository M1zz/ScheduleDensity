//
//  PaywallView.swift
//  ScheduleDensityApp
//
//  무지개의 세 칸(무료 · Plus · Pro)을 파는 한 장.
//
//  ⚠️ 맥앱 '무지개 공방'의 같은 이름 파일과 **같은 순서**로 말한다.
//     무엇이 그대로 무료인지 → Plus → Pro (칸마다 연 구독과 평생) → 언제나 평생 패스 → 약관.
//     두 앱이 같은 사다리를 파는데 화면이 다른 말을 하면, 두 앱을 다 쓰는 사람이
//     어느 쪽을 믿어야 할지 모른다.
//
//  **무료인 것을 먼저 말한다.** 페이월은 "이걸 안 사면 못 쓴다"가 아니라 "이 앱은 이만큼
//  무료이고, 쌓여야 보이는 것만 값을 받는다"는 말이라야 한다. 사는 사람도 안 사는 사람도
//  이 화면을 닫고 나서 앱을 계속 쓴다.
//
//  첫 해 할인(App Store 첫 구독 할인)과 "연 구독 N년치" 한 줄은 `LeeoTermPicker` 가 알아서 보인다.
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallView: View {
    /// 어디서 들어왔는가. 그 기능이 든 칸을 강조하고, 그 칸 맨 위에 세운다.
    var highlight: ProFeature?

    @State private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// 결제 시트를 **이 페이월이 떠 있는 창**에 띄운다 (→ PurchaseManager.purchase).
    @Environment(\.purchase) private var purchaseAction

    /// 칸마다 고른 길. 처음엔 연 구독.
    @State private var plusTerm: LeeoPlanTerm = .yearly
    @State private var proTerm: LeeoPlanTerm = .yearly
    /// 요금제를 불러오는 중인가. 못 불러온 채 끝났으면 도는 표시 대신 '다시 불러오기'를 세운다.
    @State private var loadingProducts = true
    /// App Store 의 '코드 사용' 시트. 받은 할인 코드(오퍼 코드)를 여기서 넣는다.
    @State private var redeemingCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    freeCard
                    plansStatus
                    tierCard(.plus)
                    tierCard(.pro)
                    // 세 칸 아래 한 줄. 이 앱의 Pro 평생을 가진 사람에게는 패스를 올리기 값으로 판다.
                    LeeoForeverPassLine(pass: purchases.foreverPass,
                                        ownsLifetimePro: purchases.ownsLifetime(.pro))
                    // 두 앱은 서로 다른 앱이지만, 한쪽에서 산 칸이 다른 쪽도 연다 (→ ProMark.swift).
                    // 두 번 사는 줄 알고 망설이는 사람이 가장 오래 쓸 사람이다. 값 앞에서 말해 둔다.
                    Label("산 칸은 맥 '무지개 공방'에서도 그대로 열립니다.", systemImage: "laptopcomputer")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    // 요금제를 못 불러온 것은 `plansStatus` 가 직접 말한다(다시 불러오기 단추와 함께).
                    // 같은 말을 여기 주황 경고로 또 띄우면 '결제가 고장 났다'로 읽힌다. 1.1.8 심사 2.1(b).
                    if let message = purchases.failureMessage, !purchases.products.isEmpty {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                    legal
                }
                .padding(20)
            }
            .navigationTitle("요금제")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("나중에") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("복원") {
                        Task {
                            await purchases.restore()
                            if purchases.tier > .free { dismiss() }
                        }
                    }
                    .disabled(purchases.isWorking)
                }
            }
            // 코드를 넣고 돌아오면 영수증을 다시 읽는다. 열렸으면 이 화면은 할 일이 끝났다.
            .offerCodeRedemption(isPresented: $redeemingCode) { _ in
                Task {
                    await purchases.refresh()
                    if purchases.tier > .free {
                        RainbowFunnel.reach(.purchased)
                        dismiss()
                    }
                }
            }
            // ⚠️ `.onAppear`가 아니라 `.task`다. NavigationStack 안의 onAppear는 재진입·레이아웃
            //    변화로 여러 번 불려서, 페이월 조회수(=전환율의 분모)를 부풀린다.
            .task {
                // 본 횟수는 기기 안에 따로 센다. 허브로 가는 분석은 동의한 사람만이라
                // 그 숫자만으로는 전환율의 분모가 되지 못한다 (→ UsageDiary).
                UsageDiary.markPaywallSeen()
                LeeoAnalyticsCenter.track(.paywallShown(reason: highlight?.rawValue ?? "settings"))
                RainbowFunnel.reach(.paywallShown)
                await loadPlans()
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

    // MARK: 무료 칸 (먼저 말한다. 버튼은 없다)

    private var freeCard: some View {
        card(highlighted: false) {
            cardTitle(ProTier.free.title, current: purchases.isKnown && purchases.tier == .free)
            row("rainbow", "무지개", "일정이 겹칠수록 진해지는 격자. 개수 제한 없습니다.")
            row("checklist", "할 일과 단계 쪼개기", "두 질문으로 조각과 덩어리를 가르는 것까지 전부.")
            row("timer", "타이머", "계획에 적힌 시간을 거꾸로 셉니다.")
            row("iphone.and.arrow.forward", "맥과 오가기", "같은 Apple 계정이면 양쪽에서 보입니다.")
            row("book.closed", "최근 2주 회수 장부", "이번 주와 지난주에 무엇을 되찾았는지 셉니다.")
        }
    }

    // MARK: 유료 칸

    /// 칸 하나. 열리는 것 → 연 구독 / 평생 고르기 → 고른 길의 구매 단추.
    private func tierCard(_ tier: ProTier) -> some View {
        card(highlighted: highlight?.tier == tier && purchases.tier < tier) {
            cardTitle(tier.title, current: purchases.tier == tier)
            if tier == .pro {
                row("square.stack.3d.up", "Plus 전부", "회수 장부 전체 기간과 일정 통계까지 함께 열립니다.")
            }
            ForEach(features(in: tier)) { feature in
                row(feature.systemImage, LocalizedStringKey(feature.title), LocalizedStringKey(feature.note),
                    highlighted: feature == highlight)
            }
            if tier == .pro {
                row("laptopcomputer", "맥 '무지개 공방' Pro", "맥 앱도 Pro로 함께 열립니다.")
            }
            // 이미 이 칸 이상이면 살 것이 없다. 구독을 평생으로 바꾸는 길은 설정에 있다.
            if purchases.tier < tier {
                LeeoTermPicker(term: term(for: tier), yearly: yearly(tier), lifetime: lifetime(tier))
                    .padding(.top, 4)
                buyButton(tier)
            }
        }
    }

    /// 그 칸에서 새로 열리는 것. 지금 누른 자리가 맨 위.
    private func features(in tier: ProTier) -> [ProFeature] {
        let opened = ProFeature.opened(by: tier)
        guard let highlight, opened.contains(highlight) else { return opened }
        return [highlight] + opened.filter { $0 != highlight }
    }

    private func term(for tier: ProTier) -> Binding<LeeoPlanTerm> {
        tier == .plus ? $plusTerm : $proTerm
    }

    private func yearly(_ tier: ProTier) -> Product? {
        purchases.product(tier == .plus ? ProEntitlement.plusYearlyID : ProEntitlement.proYearlyID)
    }

    /// 칸의 평생. **Plus 평생을 이미 산 사람에게는 Pro 평생 자리에 올리기 상품을 세운다.**
    /// 같은 Pro 평생을 두 번째 값을 다 내고 사게 두지 않는다.
    private func lifetime(_ tier: ProTier) -> Product? {
        if tier == .plus { return purchases.product(ProEntitlement.plusLifetimeID) }
        return purchases.product(upgradesToPro ? ProEntitlement.upgradeID : ProEntitlement.proLifetimeID)
    }

    private var upgradesToPro: Bool { purchases.ownsLifetime(.plus) }

    private func buyButton(_ tier: ProTier) -> some View {
        let chosen = term(for: tier).wrappedValue
        let product = chosen == .yearly ? yearly(tier) : lifetime(tier)
        let title: String = switch chosen {
        case .yearly: String(localized: "연 구독 시작")
        case .lifetime where tier == .pro && upgradesToPro: String(localized: "Pro 평생으로 올리기")
        case .lifetime: String(localized: "평생으로 사기")
        }
        return Button {
            guard let product else { return }
            Task {
                await purchases.purchase(product, using: purchaseAction)
                if purchases.tier >= tier {
                    UsageDiary.markPaywallBought()
                    RainbowFunnel.reach(.purchased)
                    dismiss()
                }
            }
        } label: {
            Group {
                if purchases.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(purchases.isWorking || product == nil)
    }

    // MARK: 요금제를 못 불러왔을 때

    @ViewBuilder
    private var plansStatus: some View {
        if purchases.products.isEmpty && loadingProducts {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("값을 불러오는 중…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 4)
        } else if purchases.products.isEmpty {
            // 한 번 실패하면 영영 죽은 단추로 남지 않게, 그 자리에서 다시 청한다.
            VStack(alignment: .leading, spacing: 10) {
                Text("요금제를 불러오지 못했습니다. 인터넷 연결을 확인하고 다시 불러와 주세요.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await loadPlans() }
                } label: {
                    Label("다시 불러오기", systemImage: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)
        }
    }

    /// 요금제를 불러온다. 첫 조회가 비어 오면 한 번 더 청한다. 샌드박스(심사 환경)는
    /// 첫 조회가 빈손으로 돌아오는 일이 잦다.
    private func loadPlans() async {
        loadingProducts = true
        await purchases.loadProducts()
        if purchases.products.isEmpty {
            try? await Task.sleep(for: .seconds(1.5))
            await purchases.loadProducts()
        }
        loadingProducts = false
    }

    // MARK: 약관 (구독을 파는 앱의 심사 필수 항목)

    private var sellsSubscription: Bool {
        purchases.products.contains { $0.subscription != nil }
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 구독 안내는 구독을 팔 때만. 한 번 결제만 세운 판에 자동 갱신을 말하면 거짓말이다.
            if sellsSubscription {
                Text("연 구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 요금으로 자동 갱신되며, Apple 계정으로 결제됩니다. 처음 구독하면 첫 해는 할인된 값으로 결제되고, 그 뒤에는 정가로 갱신됩니다. 해지와 관리는 App Store의 계정 설정에서 합니다. 평생은 구독이 아니라 한 번 결제입니다.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 16) {
                if let terms = ScheduleDensityAppSpec.monetization.subscriptionTermsURL {
                    Button("이용약관") { openURL(terms) }
                }
                Button("개인정보 처리방침") { openURL(ScheduleDensityAppSpec.legal.privacyURL) }
            }
            .font(.caption)
            // 할인 코드를 받은 사람이 넣을 자리. 없으면 코드를 받고도 쓸 데를 못 찾는다.
            Button {
                redeemingCode = true
            } label: {
                Label("코드 사용", systemImage: "ticket")
            }
            .font(.caption)
            .disabled(purchases.isWorking)
        }
    }

    // MARK: 부속

    private func card<Content: View>(highlighted: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Color(.secondarySystemBackground))
                shape.strokeBorder(highlighted ? Color.accentColor : Color.clear, lineWidth: 1.5)
            }
    }

    private func cardTitle(_ title: String, current: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            if current {
                Text("지금 쓰는 칸")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
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
    /// 잠긴 기능. 어느 칸에서 열리는지 읽어 준다.
    let feature: ProFeature

    init(for feature: ProFeature) { self.feature = feature }

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
            .accessibilityLabel(String(localized: "잠김, \(feature.tier.title) 필요"))
    }
}
