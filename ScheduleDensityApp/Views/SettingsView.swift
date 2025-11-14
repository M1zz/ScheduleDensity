//
//  SettingsView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-14.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel

    @State private var monthsToShow: Int
    @State private var sleepHours: Double

    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        _monthsToShow = State(initialValue: viewModel.monthsToShow)
        _sleepHours = State(initialValue: viewModel.sleepHoursPerDay)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper(value: $monthsToShow, in: 1...12) {
                        HStack {
                            Text("표시 기간")
                            Spacer()
                            Text("오늘 ± \(monthsToShow)개월")
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("오늘을 기준으로 과거 \(monthsToShow)개월, 미래 \(monthsToShow)개월의 일정을 표시합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("달력 범위")
                }

                Section {
                    HStack {
                        Text("총 표시 일수")
                        Spacer()
                        Text("약 \(monthsToShow * 60)일")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("정보")
                }

                Section {
                    Stepper(value: $sleepHours, in: 0...24, step: 0.5) {
                        HStack {
                            Text("평균 수면시간")
                            Spacer()
                            Text(String(format: "%.1f시간", sleepHours))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("시간 분석에서 자유시간 중 수면시간을 별도로 표시합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("수면 시간")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundColor(.blue)
                            Text("스크린 타임 확인")
                                .font(.headline)
                        }

                        Text("iOS 설정 앱의 '스크린 타임' 메뉴에서 앱 사용 시간을 확인하고, 숨겨진 시간 사용을 파악해보세요.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("소셜 미디어 사용 시간", systemImage: "bubble.left.and.bubble.right")
                                .font(.caption)
                            Label("엔터테인먼트 (유튜브/넷플릭스)", systemImage: "play.rectangle")
                                .font(.caption)
                            Label("게임", systemImage: "gamecontroller")
                                .font(.caption)
                            Label("생산성 앱", systemImage: "briefcase")
                                .font(.caption)
                            Label("웹 브라우징", systemImage: "safari")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("시간 사용 확인")
                } footer: {
                    Text("💡 스크린 타임에서 확인한 시간을 수동으로 일정에 추가할 수 있습니다.")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveSettings()
                    }
                }
            }
        }
    }

    private func saveSettings() {
        viewModel.updateMonthsToShow(monthsToShow)
        viewModel.updateSleepHours(sleepHours)
        dismiss()
    }
}
