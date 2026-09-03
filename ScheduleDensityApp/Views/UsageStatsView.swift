//
//  UsageStatsView.swift
//
//  **내가 이 앱을 어떻게 쓰고 있나.**
//
//  일정 통계(→ StatisticsView.swift)가 '적어 둔 일정이 어떻게 생겼나'를 말한다면
//  여기는 '내가 어떻게 쓰고 있나'를 말한다. 네 가지다 —
//  꾸준함, 쪼개기 습관, 완주율, 어디에 시간이 갔나.
//
//  ⚠️ 맨 아래에 **보낼지 말지를 묻는 줄**이 선다. 설정 깊은 곳에만 두면 켜 놓고도
//     모르게 되고, 그건 동의가 아니다. 숫자를 보는 그 자리에서 같은 숫자를
//     보낼지 정하게 한다.
//

import SwiftUI
import SwiftData
import LeeoKit

struct UsageStatsView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var stats = UsageStats()
    @State private var sendsToDeveloper = UsageReporting.isEnabled

    // ⚠️ @Query 를 쓰지 않는다. 이 화면은 설정에서 뜨는데, 설정이 사는 자리의
    //    컨테이너는 **일정(Event) 쪽**이라 할 일이 거기 없다. 할 일 스토어를 직접 연다
    //    (→ CloudDiagnostics.todoContainer, ScheduleDensityApp.swift).

    var body: some View {
        NavigationStack {
            List {
                steadinessSection
                splittingSection
                finishingSection
                timeSection
                sharingSection
            }
            .listStyle(.insetGrouped)
            .task { stats = Self.load() }
            .navigationTitle("사용 통계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: - 꾸준함

    private var steadinessSection: some View {
        Section {
            bigRow(title: "연속으로 여신 날",
                   value: "\(stats.streakDays)일",
                   note: stats.streakDays >= 2 ? "끊기지 않고 이어지는 중입니다." : "오늘부터 셉니다.")
            row("최근 30일 중", "\(stats.activeDaysLast30)일")
            row("쓰신 지", "\(stats.daysSinceInstall)일째")
        } header: {
            Text("꾸준함")
        } footer: {
            Text("연 날짜만 셉니다. 몇 시에 열었는지, 무엇을 하셨는지는 남기지 않습니다.")
        }
    }

    // MARK: - 쪼개기 습관

    private var splittingSection: some View {
        Section {
            if stats.todoCount == 0 {
                Text("아직 셀 것이 없습니다. 할 일을 몇 개 적으시면 여기가 채워집니다.")
                    .foregroundStyle(.secondary)
            } else {
                bigRow(title: "쪼개신 할 일",
                       value: "\(stats.splitCount)개",
                       note: "적으신 \(stats.todoCount)개 중 \(percent(stats.splitRate))입니다.")
                if stats.splitCount > 0 {
                    row("쪼개실 때 평균", String(format: "%.1f단계", stats.averageSteps))
                }
            }
        } header: {
            Text("쪼개기 습관")
        }
    }

    // MARK: - 완주율

    private var finishingSection: some View {
        Section {
            if stats.todoCount == 0 {
                Text("아직 셀 것이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                bigRow(title: "끝내신 비율",
                       value: percent(stats.completedRate),
                       note: nil)
                if let split = stats.splitCompletedRate { row("쪼갠 것", percent(split)) }
                if let plain = stats.plainCompletedRate { row("안 쪼갠 것", percent(plain)) }
            }
        } header: {
            Text("완주율")
        } footer: {
            // 이 두 줄을 나란히 두는 이유가 이 앱의 주장 전체다. 다만 **주장을 대신
            // 말해 주지는 않는다** — 숫자가 반대로 나올 수도 있고, 그때 앱이 우기면
            // 통계가 아니라 광고가 된다.
            if stats.splitCompletedRate != nil && stats.plainCompletedRate != nil {
                Text("쪼갠 것과 안 쪼갠 것을 갈라 두었습니다. 어느 쪽이 더 끝나는지는 숫자가 답합니다.")
            }
        }
    }

    // MARK: - 어디에 시간이 갔나

    private var timeSection: some View {
        Section {
            if stats.hoursByCategory.isEmpty {
                Text("아직 시간이 적힌 할 일이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.hoursByCategory) { slice in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(slice.name)
                            Spacer()
                            Text(hours(slice.hours))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        ProgressView(value: stats.totalHours > 0 ? slice.hours / stats.totalHours : 0)
                            .tint(color(named: slice.colorName))
                    }
                    .padding(.vertical, 2)
                }
                row("모두 합쳐", hours(stats.totalHours))
            }
        } header: {
            Text("어디에 시간이 갔나")
        } footer: {
            Text("할 일에 적어 두신 소요시간을 분류별로 모은 것입니다.")
        }
    }

    // MARK: - 보낼지 말지

    private var sharingSection: some View {
        Section {
            Toggle(isOn: $sendsToDeveloper) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("개발자에게도 익명으로 보내기")
                    Text(UsageReporting.hasAnswered
                         ? "언제든 여기서 끄실 수 있습니다."
                         : "아직 안 보내고 있습니다. 켜셔야 나갑니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: sendsToDeveloper) { _, on in
                UsageReporting.isEnabled = on
                if on { UsageReporting.reportIfAllowed(stats) }
            }
        } header: {
            Text("보내기")
        } footer: {
            Text("""
                 보내는 것은 이 화면의 **숫자뿐**입니다. 할 일 제목도, 일정 이름도, 분류 이름도, 날짜도 나가지 않습니다.
                 누가 보냈는지는 앱을 깔 때 만들어진 무작위 번호로만 구분하고, 그 번호는 Apple 계정이나 기기와 이어져 있지 않습니다. 앱을 지우면 사라집니다.
                 끄시면 이 기기에 적어 둔 날짜 기록도 함께 지웁니다.
                 """)
        }
    }

    /// 할 일 스토어를 열어 지금 값을 센다. 못 열면 빈 값이다 —
    /// 통계를 못 보여주는 것보다 오류 화면이 뜨는 게 나쁘다.
    private static func load() -> UsageStats {
        guard let context = CloudDiagnostics.todoContainer?.mainContext else { return UsageStats() }
        let todos = (try? context.fetch(FetchDescriptor<BacklogItem>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<BacklogCategory>())) ?? []
        return UsageStats.make(todos: todos,
                               categories: categories,
                               engagement: (LeeoEngagement.shared.launchCount,
                                            LeeoEngagement.shared.daysSinceInstall))
    }

    // MARK: - 조각

    private func bigRow(title: String, value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func hours(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f시간", value) : "\(Int(value.rounded()))시간"
    }

    private func color(named name: String) -> Color {
        switch name {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return .green
        case "mint":   return .mint
        case "teal":   return .teal
        case "blue":   return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink":   return .pink
        case "brown":  return .brown
        default:       return .gray
        }
    }
}
