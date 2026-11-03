//
//  FirstRunStart.swift
//  ScheduleDensityApp
//
//  처음 받은 사람이 **빈 화면에서 기능 하나로** 시작하게 하는 길.
//
//  이 앱은 할 일 · 무지개 · 하루 · 타이머 · 결산 · 공유까지 한꺼번에 서 있어서,
//  처음 연 사람에게는 무엇부터 눌러야 할지가 첫 숙제가 된다. 그래서 처음에는
//  **할 일 적기 하나만** 보여 준다:
//
//    1. 튜토리얼 (`WelcomeTutorialView`) — 글 대신 움직이는 그림 세 장. 적는다 · 끝낸다 · 나머지는 천천히.
//       마지막 단추가 곧 첫 할 일을 적는 빈 줄이다. 배우고 나서 할 일이 따로 없다.
//    2. 집중 시작 (`FirstRunStage.focus`) — 탭 막대 없이 할 일 화면 하나. 결산 · 번개 안내 · 팁도 숨긴다.
//       빈 화면 가운데에는 단추 하나뿐이다 (`FocusEmptyState`).
//    3. 모든 기능 (`FirstRunStage.full`) — 할 일을 셋 적었거나 하나 끝내면 목록 아래에
//       열자는 줄이 선다 (`FocusUnlockRow`). 기다리기 싫은 사람은 왼쪽 위 '모든 기능'으로 바로 연다.
//
//  ⚠️ **쓰던 사람은 이 길을 절대 타지 않는다.** 판정은 앱 init 에서 한 번만 한다 (→ FirstRunGate).
//     온보딩을 본 흔적, 실행 횟수, 스토어에 든 것 — 하나라도 있으면 바로 `full` 이다.
//  ⚠️ 위젯 · 딥링크로 다른 탭을 부르면 집중 모드를 끝낸다. 위젯을 단 사람은 처음 온 사람이 아니다.
//

import SwiftUI

// MARK: - 단계

/// 처음 온 사람이 지금 어디까지 왔는가. UserDefaults 에 rawValue 로 산다.
enum FirstRunStage: String {
    /// 움직이는 튜토리얼을 보는 중.
    case tutorial
    /// 탭 없이 할 일 화면 하나로 쓰는 중.
    case focus
    /// 모든 기능이 열렸다. 쓰던 사람은 처음부터 여기다.
    case full

    static let storageKey = "firstRunStage"

    /// 저장된 값. 없거나 모르는 값이면 `full` — 판정을 못 했을 때 쓰던 사람을 가두는 것보다 낫다.
    static var current: FirstRunStage {
        UserDefaults.standard.string(forKey: storageKey).flatMap(FirstRunStage.init) ?? .full
    }
}

/// 처음 온 사람인지를 가르는 한 곳 (순수 함수 — 시험이 같은 입력으로 확인한다).
enum FirstRunGate {
    /// - Parameters:
    ///   - storedStage: 이미 정해 둔 단계. 있으면 그대로 간다 — 판정은 한 번뿐이다.
    ///   - launchCount: 이번 실행까지 센 실행 횟수. 1이면 첫 실행.
    ///   - hasUsedBefore: 전에 쓴 흔적(온보딩을 본 적, 새 소식을 본 적).
    ///   - hasData: 할 일이나 일정이 한 줄이라도 있는가.
    static func decide(storedStage: String?, launchCount: Int,
                       hasUsedBefore: Bool, hasData: Bool) -> FirstRunStage {
        if let storedStage, let stage = FirstRunStage(rawValue: storedStage) { return stage }
        if launchCount <= 1 && !hasUsedBefore && !hasData { return .tutorial }
        return .full
    }

    /// 집중 모드에서 '모든 기능을 열자'는 줄을 세울 때인가.
    /// 적기만 해 본 사람에게 무지개를 보여 주면 빈 격자다. 세 줄은 있어야 그릴 것이 있다.
    static func suggestsUnlock(written: Int, completed: Int) -> Bool {
        written >= 3 || completed >= 1
    }
}

// MARK: - 환경

/// 할 일 화면이 집중 모드로 서 있는지, 그리고 모든 기능을 여는 문.
/// 앱 루트가 넣어 준다. 없으면(평소) 할 일 화면은 원래 모습 그대로다.
struct FocusStart {
    var unlock: () -> Void
}

private struct FocusStartKey: EnvironmentKey {
    static let defaultValue: FocusStart? = nil
}

extension EnvironmentValues {
    var focusStart: FocusStart? {
        get { self[FocusStartKey.self] }
        set { self[FocusStartKey.self] = newValue }
    }
}

// MARK: - 튜토리얼

/// 처음 연 사람에게 한 번 서는 움직이는 그림 세 장.
/// 글은 한 장에 두 줄까지만 — 설명은 그림이 한다.
struct WelcomeTutorialView: View {
    /// '첫 할 일 적기' 또는 '건너뛰기'. 부르는 쪽이 집중 모드로 넘긴다.
    /// `startWriting` 이 true 면 닫히자마자 빈 줄을 연다.
    var onFinish: (_ startWriting: Bool) -> Void

    @State private var page = 0
    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pageCount - 1 {
                    Button("건너뛰기") { onFinish(false) }
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            .frame(height: 52)

            TabView(selection: $page) {
                TutorialPage(title: String(localized: "적기만 하세요"),
                             message: String(localized: "떠오르는 일을 한 줄씩 적어요. 정리는 나중에 해도 됩니다.")) {
                    WriteScene()
                }
                .tag(0)
                TutorialPage(title: String(localized: "끝내면 톡"),
                             message: String(localized: "다 한 일은 동그라미를 눌러 지워요. 남은 일만 보입니다.")) {
                    FinishScene()
                }
                .tag(1)
                TutorialPage(title: String(localized: "나머지는 천천히 열려요"),
                             message: String(localized: "할 일이 손에 익으면 무지개 · 하루 · 타이머가 하나씩 열립니다.")) {
                    UnlockScene()
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: pageCount, current: page)
                .padding(.bottom, 20)

            Button {
                if page < pageCount - 1 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 }
                } else {
                    onFinish(true)
                }
            } label: {
                Text(page < pageCount - 1 ? "다음" : "첫 할 일 적기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }
}

/// 한 장: 위에 움직이는 그림, 아래에 제목과 두 줄.
private struct TutorialPage<Scene: View>: View {
    let title: String
    let message: String
    @ViewBuilder var scene: Scene

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            scene
                .frame(maxWidth: 340)
                .frame(height: 260)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == current ? 22 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(current + 1) / \(count)"))
    }
}

/// 그림 속 할 일 한 줄의 모양. 실제 목록 줄과 닮게 — 동그라미 하나와 글 한 줄.
private struct MockRow: View {
    let text: String
    var done = false
    var circleScale: CGFloat = 1

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(done ? Color.green : Color.secondary.opacity(0.5), lineWidth: 2)
                    .background(Circle().fill(done ? Color.green : .clear))
                if done {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 26, height: 26)
            .scaleEffect(circleScale)

            Text(text)
                .font(.body)
                .strikethrough(done, color: .secondary)
                .foregroundStyle(done ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
    }
}

/// 1장 — 줄이 하나씩 내려와 앉고, 글자가 타자 치듯 찍힌다.
private struct WriteScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typed: [String] = []
    @State private var cursorOn = true

    private var lines: [String] {[
        String(localized: "장 보기"),
        String(localized: "보고서 초안 쓰기"),
        String(localized: "엄마에게 전화"),
    ]}

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(typed.enumerated()), id: \.offset) { index, text in
                let isTyping = index == typed.count - 1 && text.count < lines[index].count
                MockRow(text: text + (isTyping && cursorOn ? "|" : ""))
                    .transition(.push(from: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            typed = lines
            return
        }
        while !Task.isCancelled {
            typed = []
            for line in lines {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { typed.append("") }
                try? await Task.sleep(for: .milliseconds(250))
                for ch in line {
                    typed[typed.count - 1].append(ch)
                    cursorOn.toggle()
                    try? await Task.sleep(for: .milliseconds(90))
                    if Task.isCancelled { return }
                }
                cursorOn = true
                try? await Task.sleep(for: .milliseconds(450))
            }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.3)) { typed = [] }
            try? await Task.sleep(for: .milliseconds(400))
        }
    }
}

/// 2장 — 손가락이 동그라미를 누르면 체크가 차고, 줄이 옆으로 빠져나간다.
private struct FinishScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Line: Identifiable, Equatable {
        let id: Int
        let text: String
        var done = false
    }

    @State private var rows: [Line] = []
    @State private var pressing: Int?
    @State private var fingerAt: Int?

    private func freshRows() -> [Line] {[
        Line(id: 0, text: String(localized: "장 보기")),
        Line(id: 1, text: String(localized: "보고서 초안 쓰기")),
        Line(id: 2, text: String(localized: "엄마에게 전화")),
    ]}

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows) { row in
                MockRow(text: row.text, done: row.done, circleScale: pressing == row.id ? 0.8 : 1)
                    .overlay(alignment: .leading) {
                        if fingerAt == row.id {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                                .shadow(radius: 2, y: 1)
                                .offset(x: 26, y: 18)
                                .transition(.scale(scale: 1.4).combined(with: .opacity))
                        }
                    }
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .task { await play() }
    }

    private func play() async {
        rows = freshRows()
        if reduceMotion {
            rows[0].done = true
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(700))
            for _ in 0..<2 {
                guard let target = rows.first?.id else { break }
                withAnimation(.spring(response: 0.35)) { fingerAt = target }
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.easeIn(duration: 0.12)) { pressing = target }
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    pressing = nil
                    rows[0].done = true
                }
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeOut(duration: 0.2)) { fingerAt = nil }
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { _ = rows.removeFirst() }
                try? await Task.sleep(for: .milliseconds(600))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeInOut(duration: 0.4)) { rows = freshRows() }
        }
    }
}

/// 3장 — 할 일 하나가 먼저 서 있고, 잠긴 기능들이 차례로 풀리며 색이 든다.
private struct UnlockScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = 0

    private struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let label: String
        let tint: Color
    }

    private var features: [Feature] {[
        Feature(id: 0, symbol: "rainbow", label: String(localized: "무지개"), tint: .orange),
        Feature(id: 1, symbol: "calendar.day.timeline.left", label: String(localized: "하루"), tint: .blue),
        Feature(id: 2, symbol: "timer", label: String(localized: "타이머"), tint: .purple),
    ]}

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("할 일")
                    .font(.headline)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.accentColor.opacity(0.12)))

            HStack(spacing: 14) {
                ForEach(features) { feature in
                    let isOpen = feature.id < opened
                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: feature.symbol)
                                .font(.system(size: 28, weight: .medium))
                                .symbolRenderingMode(isOpen && feature.id == 0 ? .multicolor : .monochrome)
                                .foregroundStyle(isOpen ? feature.tint : Color.secondary.opacity(0.5))
                                .frame(width: 64, height: 64)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isOpen ? feature.tint.opacity(0.14) : Color(.tertiarySystemFill)))
                                .scaleEffect(isOpen ? 1 : 0.9)
                            Image(systemName: isOpen ? "lock.open.fill" : "lock.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isOpen ? feature.tint : .secondary)
                                .padding(5)
                                .background(Circle().fill(Color(.systemBackground)))
                                .offset(x: 8, y: -8)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        Text(feature.label)
                            .font(.body)
                            .foregroundStyle(isOpen ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(.top, 10)
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            opened = features.count
            return
        }
        while !Task.isCancelled {
            opened = 0
            try? await Task.sleep(for: .milliseconds(900))
            for _ in features {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { opened += 1 }
                try? await Task.sleep(for: .milliseconds(750))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.4)) { opened = 0 }
        }
    }
}

// MARK: - 집중 모드의 빈 화면

/// 할 일이 한 줄도 없을 때 화면 가운데 서는 것. 단추 하나뿐이다.
struct FocusEmptyState: View {
    var onWrite: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(breathe ? 1.06 : 1)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("무엇부터 할까요?")
                    .font(.title2.bold())
                Text("한 줄이면 충분합니다.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Button(action: onWrite) {
                Label("할 일 적기", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityInputLabels([Text("할 일 적기"), Text("할 일 추가"), Text("추가")])
        }
        .padding(32)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

// MARK: - 모든 기능을 열자는 줄

/// 집중 모드에서 할 일이 손에 익었을 때(→ FirstRunGate.suggestsUnlock) 목록 아래에 서는 줄.
struct FocusUnlockRow: View {
    var onUnlock: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "rainbow")
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                    .rotationEffect(.degrees(glow ? -6 : 6))
                    .accessibilityHidden(true)
                Text("할 일이 손에 익었어요")
                    .font(.headline)
            }
            Text("적은 일이 언제 걸려 있는지 무지개로 보고, 하루 시간표와 타이머도 써 볼 수 있습니다.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onUnlock) {
                Text("모든 기능 열기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

#Preview("튜토리얼") {
    WelcomeTutorialView { _ in }
}
