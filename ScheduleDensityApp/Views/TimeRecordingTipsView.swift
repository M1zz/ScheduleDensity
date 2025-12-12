//
//  TimeRecordingTipsView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

struct TimeRecordingTipsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 헤더
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("시간 기록 팁")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("스크린 타임으로 숨겨진 시간 찾기")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("일정에 없지만 실제로 사용한 시간을 찾아서 기록하면, 더 정확한 시간 분석이 가능합니다.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Divider()

                    // 스크린 타임 확인 방법
                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            Text("스크린 타임 확인 방법")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "hourglass")
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            StepView(number: 1, title: "설정 앱 열기", description: "iPhone의 '설정' 앱을 실행합니다.")
                            StepView(number: 2, title: "스크린 타임 메뉴", description: "'스크린 타임'을 찾아 탭합니다.")
                            StepView(number: 3, title: "모든 활동 보기", description: "상단의 그래프 아래 '모든 활동 보기'를 탭합니다.")
                            StepView(number: 4, title: "카테고리별 확인", description: "앱 카테고리별로 사용 시간을 확인합니다.")
                        }
                    }

                    Divider()

                    // 확인할 카테고리
                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            Text("확인할 주요 카테고리")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "apps.iphone")
                                .foregroundColor(.purple)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            CategoryTipView(
                                icon: "bubble.left.and.bubble.right.fill",
                                color: .blue,
                                title: "소셜 네트워킹",
                                examples: "인스타그램, 페이스북, 트위터",
                                tip: "친구들과 대화하거나 피드를 보는 시간"
                            )

                            CategoryTipView(
                                icon: "play.rectangle.fill",
                                color: .red,
                                title: "엔터테인먼트",
                                examples: "유튜브, 넷플릭스, 디즈니+",
                                tip: "영상을 보거나 음악을 듣는 시간"
                            )

                            CategoryTipView(
                                icon: "gamecontroller.fill",
                                color: .green,
                                title: "게임",
                                examples: "모바일 게임 앱",
                                tip: "게임을 플레이한 시간"
                            )

                            CategoryTipView(
                                icon: "book.fill",
                                color: .orange,
                                title: "읽기 및 참고자료",
                                examples: "뉴스, 웹툰, 전자책",
                                tip: "정보를 읽거나 학습한 시간"
                            )

                            CategoryTipView(
                                icon: "cart.fill",
                                color: .pink,
                                title: "쇼핑 및 음식",
                                examples: "쿠팡, 배달의민족, 쇼핑 앱",
                                tip: "쇼핑이나 음식 주문에 사용한 시간"
                            )

                            CategoryTipView(
                                icon: "safari.fill",
                                color: .cyan,
                                title: "웹 브라우징",
                                examples: "Safari, Chrome",
                                tip: "웹사이트를 탐색한 시간"
                            )
                        }
                    }

                    Divider()

                    // 시간 기록하는 방법
                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            Text("일정에 기록하는 방법")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            RecordingStepView(
                                icon: "1.circle.fill",
                                title: "카테고리별 총 시간 확인",
                                description: "스크린 타임에서 각 카테고리별로 하루에 사용한 총 시간을 확인합니다."
                            )

                            RecordingStepView(
                                icon: "2.circle.fill",
                                title: "앱에서 일정 추가",
                                description: "홈 화면에서 '+' 버튼을 눌러 새 일정을 추가합니다."
                            )

                            RecordingStepView(
                                icon: "3.circle.fill",
                                title: "제목과 시간 입력",
                                description: "예: '유튜브 시청' 제목으로 2시간 일정을 추가합니다."
                            )

                            RecordingStepView(
                                icon: "4.circle.fill",
                                title: "날짜 설정",
                                description: "오늘 날짜로 설정하거나, 실제 사용한 날짜를 선택합니다."
                            )
                        }
                    }

                    Divider()

                    // 팁과 권장사항
                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            Text("유용한 팁")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            TipCardView(
                                icon: "calendar",
                                title: "매일 확인하기",
                                description: "저녁에 하루 한 번 스크린 타임을 확인하고 주요 활동을 기록하세요.",
                                color: .blue
                            )

                            TipCardView(
                                icon: "tag.fill",
                                title: "카테고리 활용",
                                description: "비슷한 활동은 같은 이름으로 기록하면 나중에 패턴을 파악하기 쉽습니다.",
                                color: .purple
                            )

                            TipCardView(
                                icon: "clock.fill",
                                title: "대략적인 시간도 괜찮아요",
                                description: "정확하지 않아도 괜찮습니다. 30분 단위로 반올림해도 충분합니다.",
                                color: .green
                            )

                            TipCardView(
                                icon: "exclamationmark.triangle.fill",
                                title: "중요한 활동 우선",
                                description: "모든 앱을 기록할 필요는 없습니다. 시간이 많이 소요된 활동만 기록하세요.",
                                color: .orange
                            )
                        }
                    }

                    // 하단 정보
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("이렇게 기록하면 좋은 점")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("• 실제로 어떤 활동에 시간을 썼는지 명확히 알 수 있습니다.\n• 계획하지 않은 시간 사용 패턴을 발견할 수 있습니다.\n• 시간 관리를 개선할 수 있는 인사이트를 얻을 수 있습니다.\n• 더 정확한 밀도 분석이 가능해집니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("시간 기록 팁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StepView: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CategoryTipView: View {
    let icon: String
    let color: Color
    let title: String
    let examples: String
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(examples)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(tip)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecordingStepView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TipCardView: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    TimeRecordingTipsView()
}
