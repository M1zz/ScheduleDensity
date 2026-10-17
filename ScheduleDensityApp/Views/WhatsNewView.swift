//
//  WhatsNewView.swift
//  ScheduleDensityApp
//
//  업데이트 뒤 처음 열 때 **한 번** 뜨는 "새로 생긴 것" 시트. 설정 ▸ 지원에서 다시 볼 수 있다.
//
//  ⚠️ **처음 받은 사람에게는 뜨지 않는다.** 새로 온 사람에게 "새로워졌어요"는 무슨 말인지
//     알 수 없는 말이다 — 그 사람은 온보딩이 맞이한다. 첫 실행이면 본 것으로 표시만 한다.
//  ⚠️ 내용을 바꿀 때 `WhatsNewContent.version` 도 같이 올린다. 안 올리면 업데이트한 사람은
//     이미 본 것으로 기록돼 있어 새 안내를 **한 번도 못 본다.**
//  ⚠️ 여기 적는 것은 **이번 버전에 실제로 들어간 것**만이다. 로드맵(앞으로 만들 것)과 섞지 않는다.
//

import SwiftUI

/// 이 안내가 소개하는 버전. 내용과 함께 올린다.
enum WhatsNewContent {
    static let version = "1.1.14"

    struct Item: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
    }

    static var items: [Item] {[
        Item(id: "dark", symbol: "moon.stars",
             title: String(localized: "어두운 화면에서도 무지개가 또렷해요",
                           comment: "What's new 1.1.14: dark mode title"),
             detail: String(localized: "칸 사이 선과 옅은 칸을 어두운 모드에 맞게 다시 칠했어요.",
                            comment: "What's new 1.1.14: dark mode detail")),
        Item(id: "a11y", symbol: "accessibility",
             title: String(localized: "손쉬운 사용을 더 챙겼어요",
                           comment: "What's new 1.1.14: accessibility title"),
             detail: String(localized: "음성 제어로 단추를 부를 수 있고, 지우거나 끝낸 일을 VoiceOver가 알려 줘요. 색 없이 구별을 켜면 일정 첫 글자가 칸에 보여요.",
                            comment: "What's new 1.1.14: accessibility detail. 'Differentiate Without Color' is the iOS setting name")),
        Item(id: "code", symbol: "ticket",
             title: String(localized: "받은 코드로 Pro를 열 수 있어요",
                           comment: "What's new 1.1.14: offer code title"),
             detail: String(localized: "설정의 내 버전에서 '코드 사용'을 누르세요.",
                            comment: "What's new 1.1.14: offer code detail. 'Redeem Code' is the button name")),
        Item(id: "roadmap", symbol: "map",
             title: String(localized: "앞으로 만들 기능을 볼 수 있어요",
                           comment: "What's new 1.1.14: roadmap title"),
             detail: String(localized: "설정의 지원에서 다음에 올 것을 보고, 바라는 기능을 보낼 수 있어요.",
                            comment: "What's new 1.1.14: roadmap detail")),
    ]}
}

/// 띄울지 말지를 가르는 한 곳 (순수 함수 — 시험이 같은 입력으로 확인한다).
enum WhatsNewGate {
    enum Decision: Equatable {
        /// 쓰던 사람이고 이번 안내를 아직 못 봤다.
        case show
        /// 처음 온 사람. 띄우지 않고 본 것으로만 적는다.
        case markSeenSilently
        /// 이미 봤다.
        case nothing
    }

    /// - Parameters:
    ///   - launchCount: 이번 실행까지 센 실행 횟수 (`LeeoEngagement.launchCount`). 1이면 첫 실행.
    ///   - hasUsedBefore: 이 기기에서 전에 쓴 흔적(온보딩을 본 적)이 있는가. 실행 횟수를 세기 전
    ///     버전부터 쓰던 사람을 처음 온 사람으로 잘못 보지 않게 한다.
    static func decide(launchCount: Int, hasUsedBefore: Bool,
                       lastSeenVersion: String?, currentVersion: String = WhatsNewContent.version) -> Decision {
        if lastSeenVersion == currentVersion { return .nothing }
        if launchCount <= 1 && !hasUsedBefore { return .markSeenSilently }
        return .show
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "rainbow")
                            .font(.system(size: 56, weight: .light))
                            .symbolRenderingMode(.multicolor)
                            .padding(.top, 28)
                            .accessibilityHidden(true)
                        Text("새로 생긴 것")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text("업데이트에서 달라진 점이에요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(WhatsNewContent.items.enumerated()), id: \.element.id) { index, item in
                            row(item)
                                .opacity(appeared || reduceMotion ? 1 : 0)
                                .offset(y: appeared || reduceMotion ? 0 : 12)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.35).delay(0.08 * Double(index)),
                                           value: appeared)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            Button {
                dismiss()
            } label: {
                Text("확인")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .accessibilityIdentifier("whatsNew.close")
        }
        .onAppear { appeared = true }
    }

    private func row(_ item: WhatsNewContent.Item) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WhatsNewView()
}
