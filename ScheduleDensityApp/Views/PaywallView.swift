//
//  PaywallView.swift
//
//  '모두 열기'를 사는 자리.
//
//  화면이 먼저 하는 말은 **무엇이 무료인가**다. 잠긴 것부터 늘어놓으면 앱이 인질처럼 보이고,
//  실제로도 이 앱의 본체는 잠겨 있지 않다 — 무지개도, 쪼개기도, 두 질문도, 단계 순서도
//  값을 안 받는다. 값을 받는 건 곁다리 다섯이다. 그 사실을 감추면 안 사는 사람이
//  앱을 못 쓴다고 오해하고 지운다.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    /// 어디서 막혀 들어왔는지. 그 줄을 목록에서 먼저 짚어준다.
    var highlight: ProFeature? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var purchases = PurchaseManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("무지개와 쪼개기는 그대로 무료입니다")
                            .font(.headline)
                        Text("일정 밀도(무지개), 할 일 쪼개기, 조각인지 덩어리인지 가르는 두 질문, 단계 순서 — 이 앱이 하는 일의 본체는 값을 받지 않습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(ProFeature.sold) { feature in
                        row(feature)
                    }
                } header: {
                    Text("한 번 사면 열리는 것")
                } footer: {
                    Text("한 번 사면 끝입니다. 구독이 아니고, 같은 Apple 계정의 다른 기기에서도 열립니다.")
                }

                if let message = purchases.failureMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Button(action: { Task { await purchases.restore() } }) {
                        HStack {
                            Text("구매 복원")
                            Spacer()
                            if purchases.isRestoring { ProgressView() }
                        }
                    }
                    .disabled(purchases.isRestoring)
                } footer: {
                    Text("전에 산 적이 있다면 여기서 되찾습니다.")
                }
            }
            .navigationTitle("모두 열기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { buyBar }
            .task {
                await purchases.loadProduct()
                await purchases.refresh()
            }
            .onChange(of: purchases.isUnlocked) { _, unlocked in
                // 사고 나면 이 화면이 할 일이 없다. 막혔던 자리로 바로 돌려보낸다.
                if unlocked { dismiss() }
            }
        }
    }

    private func row(_ feature: ProFeature) -> some View {
        let isHighlighted = feature == highlight
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 17))
                .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.body.weight(isHighlighted ? .semibold : .regular))
                Text(feature.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isHighlighted ? Color.accentColor.opacity(0.08) : nil)
    }

    /// 값과 버튼은 언제나 화면 아래에 붙여 둔다. 목록을 끝까지 내려야 살 수 있으면
    /// 사려던 사람도 사다 만다.
    @ViewBuilder
    private var buyBar: some View {
        VStack(spacing: 6) {
            Button(action: { Task { await purchases.purchase() } }) {
                HStack {
                    Spacer()
                    if purchases.isPurchasing {
                        ProgressView().tint(.white)
                    } else if let product = purchases.product {
                        Text("\(product.displayPrice)에 열기").fontWeight(.semibold)
                    } else {
                        // 값을 못 받아왔으면 값을 지어내지 않는다.
                        Text("값을 불러오는 중…")
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchases.product == nil || purchases.isPurchasing)

            Text("한 번 결제, 추가 요금 없음")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.bar)
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
            .accessibilityLabel("잠김, 모두 열기 필요")
    }
}
