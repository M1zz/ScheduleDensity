//
//  MacCompanionView.swift
//  ScheduleDensityApp
//
//  맥 '무지개 공방'을 소개하는 한 장 — 설정에서 밀어 넣고, 할 일 화면의 조언에서도 들어온다.
//
//  아이폰은 **잡는 곳**, 맥은 **나누는 곳**이다. 할 일이 쌓이면 작은 화면에서 한 주를
//  통째로 다시 짜기가 버겁다. 그때 "같은 목록이 맥에 이미 있다"는 걸 알려 주는 자리다.
//
//  ⚠️ 이 화면은 아이폰에만 있다. 맥 쪽에는 짝이 되는 화면이 없으므로 복제하지 않는다.
//

import SwiftUI
import SwiftData
import TipKit

struct MacCompanionView: View {
    /// 맥 App Store의 '무지개 공방'. 아이폰에서 열면 소개만 보이고, 설치는 맥에서 한다.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6777737322")!

    private static let accent = Color.indigo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                hero

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(points) { point in
                        pointRow(point)
                    }
                }

                getIt
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle("맥에서 정리하기")
        .navigationBarTitleDisplayMode(.inline)
        // 이 장을 한 번 읽었으면, 여기저기 선 같은 권유는 더 볼 필요가 없다.
        .onAppear { MacCompanion.markSeen() }
    }

    // MARK: - 머리

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Self.accent)
                .accessibilityHidden(true)

            Text("잡는 건 아이폰에서,\n나누는 건 맥에서")
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)

            Text("맥 앱 ‘무지개 공방’은 이 할 일 목록을 그대로 열어, 한 주 안에 자리를 잡아 주는 앱입니다.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 네 가지

    private struct Point: Identifiable {
        let icon: String
        let heading: String
        let body: String
        var id: String { icon }
    }

    private var points: [Point] {
        [
            Point(
                icon: "clock.badge.checkmark",
                heading: String(localized: "정말 남은 시간부터"),
                body: String(localized: "한 주는 168시간이지만 잠·식사·일이 먼저 가져갑니다. 이런 고정 루틴을 먼저 깔면, 할 일에 쓸 수 있는 시간이 숫자로 보입니다.")
            ),
            Point(
                icon: "hand.draw",
                heading: String(localized: "끌어다 놓으면 계획"),
                body: String(localized: "할 일을 요일 위로 끌어다 놓으면, 들어갈 수 있는 빈틈에 맞춰 앉습니다. 넓은 화면이라 한 주를 한눈에 보며 옮길 수 있습니다.")
            ),
            Point(
                icon: "bolt.fill",
                heading: String(localized: "같은 목록, 두 크기의 시간"),
                body: String(localized: "시간을 잡아야 하는 단계는 맥에서 한 주에 놓고, 5분이면 끝나는 단계는 아이폰의 번개로 바로 합니다. 한쪽에서 끝내면 양쪽에서 끝납니다.")
            ),
            Point(
                icon: "icloud",
                heading: String(localized: "옮겨 적을 것이 없습니다"),
                body: String(localized: "같은 iCloud 계정이면 지금 이 목록이 맥에 그대로 나타납니다. 한쪽에서 Pro를 사면 다른 쪽도 함께 열립니다.")
            )
        ]
    }

    private func pointRow(_ point: Point) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: point.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Self.accent)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(point.heading)
                    .font(.headline)
                Text(point.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 받는 법

    /// 맥 앱은 아이폰에서 설치할 수 없다. 그래서 문을 둘 둔다 —
    /// 소개를 여기서 읽어 보는 문, 그리고 링크를 맥으로 보내 거기서 받는 문.
    private var getIt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("맥에서 App Store를 열고 ‘무지개 공방’을 찾거나, 아래 링크를 맥으로 보내세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ShareLink(item: Self.appStoreURL) {
                Label("맥으로 링크 보내기", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Self.accent)

            Link(destination: Self.appStoreURL) {
                Label("App Store에서 보기", systemImage: "arrow.up.right.square")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(Self.accent)
        }
        .padding(.top, 4)
    }
}

// MARK: - 권유가 함께 보는 값

/// 맥 권유(넛지) 세 곳과 설정 배지가 함께 보는 두 가지 — 맥을 이미 쓰는가, 소개를 봤는가.
///
/// 설정은 무지개 탭(일정 스토어)에 붙어 있어 할 일 스토어를 못 본다. 그래서 할 일 화면이
/// 재 두고, 다른 곳은 여기 적힌 값을 읽는다.
enum MacCompanion {
    /// 이 iCloud 스토어에 맥 앱이 적은 루틴·계획이 있는가.
    static let usesMacKey = "macCompanion.usesMac"
    /// 소개 한 장을 열어 본 적이 있는가. 열었으면 설정의 배지를 내린다.
    static let seenKey = "macCompanion.seen"

    /// 할 일 스토어를 보고 '맥을 쓰는가'를 다시 잰다. 루틴과 계획은 맥 앱만 적으므로
    /// 하나라도 보이면 이미 쓰는 사람이다.
    static func refresh(in context: ModelContext) {
        let routines = (try? context.fetchCount(FetchDescriptor<Routine>())) ?? 0
        let blocks = (try? context.fetchCount(FetchDescriptor<PlanBlock>())) ?? 0
        let usesMac = routines + blocks > 0
        UserDefaults.standard.set(usesMac, forKey: usesMacKey)
        MacHandoffTip.usesMac = usesMac
    }

    /// 소개를 읽었다. 배지를 내리고, 아직 안 뜬 권유도 모두 거둔다.
    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
        MacHandoffTip().invalidate(reason: .actionPerformed)
        MacBlockStepTip().invalidate(reason: .actionPerformed)
        MacBusyWeekTip().invalidate(reason: .actionPerformed)
    }
}

// MARK: - 할 일 화면의 권유

/// 할 일이 쌓였는데 맥은 아직 안 쓰는 사람에게, 맥에서 나눠 보라고 한 번만 권한다.
///
/// 처음부터 띄우지 않는다 — 목록이 몇 줄뿐일 때는 아이폰만으로 충분하고, 그때 맥 이야기는
/// 광고로 읽힌다. 쌓여서 버거워질 즈음에야 "그럴 땐 이런 길이 있다"가 도움으로 읽힌다.
/// 맥 앱이 이미 적어 둔 루틴이나 계획이 보이면 이미 쓰는 사람이므로 띄우지 않는다.
///
/// ⚠️ TodoTips.swift가 아니라 여기에 둔다. 그 파일은 맥과 글자까지 같아야 하는데,
///    이 권유는 아이폰에만 있다.
struct MacHandoffTip: Tip {
    /// 아직 안 끝낸 최상위 할 일 수.
    @Parameter static var openTodoCount: Int = 0
    /// 이 iCloud 스토어에 맥 앱이 적은 루틴·계획이 있는가.
    @Parameter static var usesMac: Bool = false

    var title: Text { Text("할 일이 쌓였다면, 맥에서 한 주에 나눠 보세요") }
    var message: Text? {
        Text("맥 앱 ‘무지개 공방’이 이 목록을 그대로 열어, 남은 시간 안에 끌어다 놓게 해 줍니다.")
    }
    var image: Image? { Image(systemName: "macbook.and.iphone") }
    var actions: [Action] {
        Action(id: "learn", title: String(localized: "맥 앱 알아보기"))
    }
    var rules: [Rule] {
        // 여덟 줄쯤 쌓이면 작은 화면에서 한 주를 다시 짜기가 버거워진다.
        #Rule(Self.$openTodoCount) { $0 >= 8 }
        #Rule(Self.$usesMac) { $0 == false }
    }
}

// MARK: - 할 일 상세의 권유

/// 5분에 안 끝나는 단계(덩어리)가 생긴 순간 — 그건 지켜 둔 시간이 필요하고,
/// 그 시간을 한 주 안에 잡는 게 맥 앱이 하는 일이다. 말이 가장 잘 통하는 때라 여기서 권한다.
/// 덩어리가 있는지는 부르는 쪽이 보고, 이 팁은 '맥을 아직 안 쓰는가'만 본다.
struct MacBlockStepTip: Tip {
    var title: Text { Text("이 단계는 지켜 둔 시간이 필요해요") }
    var message: Text? {
        Text("5분에 끝나지 않는 단계는 맥 ‘무지개 공방’에서 한 주의 빈틈에 놓아 두면 미뤄지지 않습니다.")
    }
    var image: Image? { Image(systemName: "calendar.badge.clock") }
    var actions: [Action] {
        Action(id: "learn", title: String(localized: "맥 앱 알아보기"))
    }
    var rules: [Rule] {
        #Rule(MacHandoffTip.$usesMac) { $0 == false }
    }
}

// MARK: - 무지개의 권유

/// 앞으로 한 주가 진하게 겹쳐 있을 때. 무지개는 '붐빈다'까지만 말해 줄 수 있고,
/// 그 안에서 정말 남은 시간을 재어 다시 나누는 건 맥 앱의 몫이다.
/// 붐비는지는 부르는 쪽이 보고, 이 팁은 '맥을 아직 안 쓰는가'만 본다.
struct MacBusyWeekTip: Tip {
    var title: Text { Text("이번 주가 붐비네요") }
    var message: Text? {
        Text("맥 ‘무지개 공방’에서는 잠·식사·일을 뺀 정말 남은 시간을 보며 할 일을 다시 나눌 수 있습니다.")
    }
    var image: Image? { Image(systemName: "square.stack.3d.up.fill") }
    var actions: [Action] {
        Action(id: "learn", title: String(localized: "맥 앱 알아보기"))
    }
    var rules: [Rule] {
        #Rule(MacHandoffTip.$usesMac) { $0 == false }
    }
}

