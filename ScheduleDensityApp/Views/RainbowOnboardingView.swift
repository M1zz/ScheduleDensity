//
//  RainbowOnboardingView.swift
//  ScheduleDensityApp
//
//  무지개 화면에 처음 들어온 사람에게 "꾹 눌러 네모를 만든다"를 한 번만 보여준다.
//  설명을 읽히는 대신, 실제로 눌러야 할 칸을 하이라이트해서 직접 만들어 보게 한다.
//
//  아래쪽 SpotlightCoachOverlay는 일정 추가 화면의 항목 안내(→ AddEventView)와 함께 쓴다.
//

import SwiftUI

// MARK: - 코치마크 공통 부품

/// 하이라이트 대상이 자기 위치를 오버레이로 올려보내는 통로.
/// 대상은 스크롤을 따라 움직이므로 좌표는 매 프레임 다시 올라온다.
struct SpotlightAnchorKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] { [] }
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// 지금 이 뷰가 코치마크가 가리키는 자리라면 자기 위치를 올려보낸다.
    func spotlightAnchor(_ isTarget: Bool) -> some View {
        anchorPreference(key: SpotlightAnchorKey.self, value: .bounds) { isTarget ? [$0] : [] }
    }
}

extension GeometryProxy {
    /// 올라온 자리들을 하나로 합친다. 여러 칸에 걸친 대상(줄 전체, 두 줄짜리 항목)을 한 구멍으로 뚫으려고.
    func spotlightRect(_ anchors: [Anchor<CGRect>]) -> CGRect? {
        anchors.reduce(nil as CGRect?) { partial, anchor in
            let rect = self[anchor]
            return partial?.union(rect) ?? rect
        }
    }
}

/// 화면을 어둡게 덮고 한 자리만 도려내 설명하는 코치마크.
struct SpotlightCoachOverlay<Actions: View>: View {
    /// 도려낼 자리. nil이면 그냥 어둡게만 덮는다.
    let hole: CGRect?
    let containerSize: CGSize
    let icon: String
    let title: String
    let message: String
    /// 사용자가 직접 만져 봐야 하는 단계인지. 이때는 손가락이 막을 그대로 통과한다.
    var passesTouches: Bool = false
    @ViewBuilder var actions: () -> Actions

    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            dimLayer
            if let hole { ring(hole) }
            card
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    private var dimLayer: some View {
        Rectangle()
            .fill(Color.black.opacity(passesTouches ? 0.45 : 0.6))
            .frame(width: containerSize.width, height: containerSize.height)
            .punchOut(hole)
            .allowsHitTesting(!passesTouches)
            .animation(.easeInOut(duration: 0.25), value: hole)
    }

    private func ring(_ hole: CGRect) -> some View {
        ZStack {
            // 번져 나가는 맥박 — "여기예요"를 말없이 가리킨다.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(pulse ? 0 : 0.75), lineWidth: 3)
                .frame(width: hole.width + (pulse ? 30 : 0),
                       height: hole.height + (pulse ? 30 : 0))

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 3)
                .frame(width: hole.width, height: hole.height)
                .shadow(color: .white.opacity(0.7), radius: 6)
        }
        .position(x: hole.midX, y: hole.midY)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.25), value: hole)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) { actions() }
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: 330, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(width: containerSize.width, height: containerSize.height, alignment: cardAlignment)
        .animation(.easeInOut(duration: 0.25), value: cardAlignment)
    }

    /// 카드가 가리킨 자리를 덮지 않도록, 대상이 아래쪽이면 카드를 위로 올린다.
    private var cardAlignment: Alignment {
        guard let hole else { return .center }
        return hole.midY > containerSize.height * 0.5 ? .top : .bottom
    }
}

// MARK: - 무지개 첫 진입 온보딩

/// 온보딩 진행 단계.
enum RainbowOnboardingStep: Equatable {
    /// 진행 중이 아님(이미 봤거나 아직 시작 전).
    case idle
    /// 첫 안내 카드.
    case intro
    /// 시작하는 날 칸을 꾹 누르는 단계.
    case pressStart
    /// 끝나는 날 칸을 꾹 누르는 단계.
    case pressEnd
    /// 일정 추가 시트가 열려 있는 동안 — 안내는 그 시트가 이어받는다.
    case filling
    /// 마무리 카드.
    case done

    /// 무지개 화면 위에 오버레이를 띄워야 하는 단계인지.
    /// 마무리(`done`)는 여기 없다 — 뜻풀이는 격자 위 카드가 아니라 전체 화면으로 받는다
    /// (→ RainbowMeaningView). 뒤에 격자가 비치면 세 문단이 읽히지 않는다.
    var showsOverlay: Bool {
        switch self {
        case .idle, .filling, .done: return false
        case .intro, .pressStart, .pressEnd: return true
        }
    }

    /// 이 단계에서 칸을 도려내 보여주는지.
    var showsSpotlight: Bool {
        self == .pressStart || self == .pressEnd
    }

    /// 지금이 사용자가 직접 눌러야 하는 차례인지. 이때는 손가락이 막을 통과해야 한다.
    var awaitsLongPress: Bool {
        self == .pressStart || self == .pressEnd
    }
}

/// 하이라이트할 자리 — 한 레인에서 시작일부터 종료일까지.
/// 누를 차례에는 하루짜리(칸 하나), 마무리에는 방금 만든 줄 전체를 가리킨다.
struct RainbowSpot: Equatable {
    let date: Date
    let endDate: Date
    let lane: Int

    init(date: Date, endDate: Date? = nil, lane: Int) {
        self.date = date
        self.endDate = endDate ?? date
        self.lane = lane
    }

    /// 이 날짜가 하이라이트 구간 안인지.
    func covers(_ other: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: other)
        return day >= calendar.startOfDay(for: date) && day <= calendar.startOfDay(for: endDate)
    }
}

/// 무지개 화면 위에 얹는 온보딩 오버레이.
struct RainbowOnboardingOverlay: View {
    let step: RainbowOnboardingStep
    /// 하이라이트할 자리(오버레이와 같은 좌표계). 아직 못 찾았으면 nil.
    let spotlight: CGRect?
    let containerSize: CGSize
    var onStart: () -> Void
    var onSkip: () -> Void

    /// 실제로 뚫을 구멍. 칸보다 살짝 넉넉하게 잡아야 테두리가 칸을 가리지 않는다.
    private var hole: CGRect? {
        guard step.showsSpotlight, let spotlight else { return nil }
        return spotlight.insetBy(dx: -5, dy: -5)
    }

    var body: some View {
        SpotlightCoachOverlay(
            hole: hole,
            containerSize: containerSize,
            icon: icon,
            title: headline,
            message: message,
            passesTouches: step.awaitsLongPress
        ) {
            switch step {
            case .intro:
                Button("나중에", action: onSkip)
                    .buttonStyle(.bordered)
                Button("해볼게요", action: onStart)
                    .buttonStyle(.borderedProminent)
            case .pressStart, .pressEnd:
                Spacer()
                Button("건너뛰기", action: onSkip)
                    .font(.footnote)
            case .idle, .filling, .done:
                EmptyView()
            }
        }
    }

    private var icon: String {
        switch step {
        case .intro: return "rainbow"
        case .pressStart: return "hand.tap"
        case .pressEnd: return "hand.tap.fill"
        case .idle, .filling, .done: return "rainbow"
        }
    }

    private var headline: String {
        switch step {
        case .intro: return "무지개는 꾹 눌러서 그려요"
        case .pressStart: return "시작하는 날을 꾹"
        case .pressEnd: return "끝나는 날을 한 번 더 꾹"
        case .idle, .filling, .done: return ""
        }
    }

    private var message: String {
        switch step {
        case .intro:
            return "위에서 아래로 날짜가 흐르고, 가로 칸은 그날 한꺼번에 굴리는 일의 개수예요.\n빈 칸을 꾹 눌러 시작하는 날과 끝나는 날을 집으면 세로로 이어진 네모 하나가 만들어집니다. 한 번 같이 해볼까요?"
        case .pressStart:
            return "하얗게 표시된 빈 칸을 꾹 눌러 보세요. 테두리가 한 바퀴 다 차면 그 날이 시작하는 날로 잡힙니다."
        case .pressEnd:
            return "같은 세로줄에서 끝나는 날을 다시 꾹 누르면 두 날 사이가 네모로 이어지고, 일정을 적는 창이 열려요."
        case .idle, .filling, .done:
            return ""
        }
    }
}

// MARK: - 구멍 뚫기

private extension View {
    /// 주어진 사각형만 도려낸 모양으로 자신을 자른다.
    @ViewBuilder
    func punchOut(_ hole: CGRect?) -> some View {
        if let hole {
            mask {
                Rectangle()
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .frame(width: hole.width, height: hole.height)
                            .position(x: hole.midX, y: hole.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
        } else {
            self
        }
    }
}

// MARK: - 일정 추가 화면 항목 안내

/// 처음 일정을 만들 때, 무엇을 어떤 순서로 적어야 하는지 하나씩 짚어준다.
/// 빈 폼을 통째로 던져 주면 어디부터 손대야 하는지 알 수 없기 때문.
enum AddEventGuideStep: Int, CaseIterable {
    case title, period, activeDays, hours, save

    var next: AddEventGuideStep? { AddEventGuideStep(rawValue: rawValue + 1) }

    /// 이 단계에서 카드에 붙는 순서 표시 (마지막 '추가' 단계는 적는 항목이 아니라서 뺀다).
    var order: (index: Int, total: Int)? {
        guard self != .save else { return nil }
        return (rawValue + 1, AddEventGuideStep.allCases.count - 1)
    }

    var icon: String {
        switch self {
        case .title: return "pencil.line"
        case .period: return "calendar"
        case .activeDays: return "clock.badge.checkmark"
        case .hours: return "clock.fill"
        case .save: return "checkmark.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .title: return "무슨 일인지 적어요"
        case .period: return "언제부터 언제까지인지"
        case .activeDays: return "그중 실제로 시간 쓰는 날"
        case .hours: return "그 날 하루에 몇 시간"
        case .save: return "다 됐어요"
        }
    }

    var message: String {
        switch self {
        case .title:
            return "나중에 무지개에서 이 칸을 눌렀을 때 알아볼 수 있게, 한 줄로 적어주세요."
        case .period:
            return "아까 꾹 눌러 집은 두 날이 들어와 있어요. 끝나는 날은 반드시 있어야 합니다 — 끝을 안 정하면 그 일은 영영 안 끝나요."
        case .activeDays:
            return "기간 전부가 아니라, 그 안에서 진짜로 손을 대는 요일만 고르세요.\n스터디가 화요일에만 모인다면 화요일만 고르면 됩니다. 나머지 날은 '아직 안 끝난 일'로 옅게 남아요."
        case .hours:
            return "고른 날 하루에 들어가는 시간이에요. 이 숫자가 그날이 얼마나 차는지를 정합니다."
        case .save:
            return "오른쪽 위 '추가'를 누르면 무지개에 한 줄이 그어집니다."
        }
    }
}
