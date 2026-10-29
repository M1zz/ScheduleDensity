//
//  ScheduleDensityAppRoadmap.swift
//  ScheduleDensityApp
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("1.3.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다). 다른 앱과 같은 피처는 같은 id 를 쓴다.
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 번역은 `Localizable.xcstrings` 에 모든 언어로 채운다.
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//

import SwiftUI
import LeeoKit

extension ScheduleDensityAppSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 다음에 만들어요
        .init(id: "timer.control", status: .shipped("1.1.16"),
              title: String(localized: "앱 밖에서 타이머 켜기", comment: "Roadmap item: start the timer from Control Center"),
              detail: String(localized: "제어센터나 잠금 화면의 단추 하나로 지금 일정의 타이머를 바로 켜요.", comment: "Roadmap item detail: start the timer from Control Center")),
        .init(id: "timer.upcoming", status: .shipped("1.1.16"),
              title: String(localized: "다음 일정 미리 보기", comment: "Roadmap item: show the next event 15 minutes ahead"),
              detail: String(localized: "일정 15분 전에 잠금 화면에 다음 일정과 남은 시간이 떠요.", comment: "Roadmap item detail: show the next event 15 minutes ahead")),
        .init(id: "a11y.voiceover", status: .building,
              title: String(localized: "VoiceOver로 더 편하게", comment: "Roadmap item: VoiceOver"),
              detail: String(localized: "화면 읽기 기능이 단추와 내용을 빠짐없이, 알맞은 순서로 읽어 줘요.", comment: "Roadmap item detail: VoiceOver")),
        .init(id: "a11y.largetext", status: .building,
              title: String(localized: "큰 글씨에 맞춘 화면", comment: "Roadmap item: larger text layouts"),
              detail: String(localized: "글자 크기를 키워도 잘리지 않고 보기 좋게 다시 배치돼요.", comment: "Roadmap item detail: larger text layouts")),
        .init(id: "display.dark", status: .shipped("1.1.14"),
              title: String(localized: "다크 모드", comment: "Roadmap item: dark mode"),
              detail: String(localized: "어두운 화면에서도 글자와 단추가 또렷하게 보여요.", comment: "Roadmap item detail: dark mode")),
        .init(id: "a11y.contrast", status: .shipped("1.1.14"),
              title: String(localized: "보기 편한 색과 대비", comment: "Roadmap item: colors and contrast"),
              detail: String(localized: "대비를 높이거나 색을 구별하기 어려워도 일정을 알아볼 수 있어요.", comment: "Roadmap item detail: colors and contrast")),
        .init(id: "whatsnew", status: .shipped("1.1.14"),
              title: String(localized: "업데이트 소식", comment: "Roadmap item: what's new after an update"),
              detail: String(localized: "업데이트 뒤 처음 열 때 무엇이 새로 생겼는지 알려 줘요.", comment: "Roadmap item detail: what's new after an update")),
        .init(id: "gift", status: .building,
              title: String(localized: "Pro 선물하기", comment: "Roadmap item: gift Pro"),
              detail: String(localized: "Pro를 다른 사람에게 선물할 수 있어요.", comment: "Roadmap item detail: gift Pro")),
        .init(id: "lock.faceid", status: .planned,
              title: String(localized: "Face ID 잠금", comment: "Roadmap item: Face ID lock"),
              detail: String(localized: "Face ID나 Touch ID로 앱을 잠가 내 일정과 할 일을 지켜요.", comment: "Roadmap item detail: Face ID lock")),
        .init(id: "fold", status: .planned,
              title: String(localized: "펼치는 아이폰 화면", comment: "Roadmap item: foldable iPhone layout"),
              detail: String(localized: "펼치는 아이폰에서 넓은 화면을 두 쪽으로 나눠 써요.", comment: "Roadmap item detail: foldable iPhone layout")),
        .init(id: "autosave", status: .planned,
              title: String(localized: "쓰던 일정 이어서 쓰기", comment: "Roadmap item: keep a half-written event"),
              detail: String(localized: "일정을 적다가 앱이 꺼져도 쓰던 내용이 남아 있어요.", comment: "Roadmap item detail: keep a half-written event")),
    ]}
}

// MARK: - 화면

/// 설정 ▸ 앞으로 만들 기능. "이런 기능이 있으면 좋겠어요" 는 기능 제안으로 시작하는 피드백 창을 연다.
struct RoadmapScreen: View {
    @State private var showFeedback = false

    var body: some View {
        LeeoRoadmapView<ScheduleDensityAppSpec>(onSuggest: { showFeedback = true })
            .sheet(isPresented: $showFeedback) {
                // LeeoFeedbackView 는 자기 NavigationStack 과 닫기 단추를 갖고 있다 — 감싸지 않는다.
                LeeoFeedbackView<ScheduleDensityAppSpec>(initialType: .feature)
            }
    }
}
