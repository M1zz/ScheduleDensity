//
//  ScreenTimeImportView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-14.
//

import SwiftUI

struct ScreenTimeImportView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: ScheduleViewModel
    @State private var screenTimeManager = ScreenTimeManager()
    @State private var selectedCategories: Set<UUID> = []
    @State private var isLoading = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("스크린 타임 데이터 불러오는 중...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if !screenTimeManager.isAuthorized {
                    authorizationView
                } else if screenTimeManager.categories.isEmpty {
                    emptyView
                } else {
                    categoryListView
                }
            }
            .navigationTitle("스크린 타임 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                if !screenTimeManager.categories.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("일정 추가") {
                            addSelectedEvents()
                        }
                        .disabled(selectedCategories.isEmpty)
                    }
                }
            }
            .alert("오류", isPresented: $showError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(screenTimeManager.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }

    private var authorizationView: some View {
        VStack(spacing: 24) {
            Image(systemName: "hourglass")
                .font(.system(size: 70))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("스크린 타임 접근 권한 필요")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("평균 앱 사용 시간을 분석하여 자동으로 일정을 추천합니다.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("지난 7일간 평균 사용 시간 분석", systemImage: "chart.bar")
                Label("카테고리별 시간 자동 계산", systemImage: "square.grid.2x2")
                Label("선택한 항목만 일정으로 추가", systemImage: "checkmark.circle")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Button(action: {
                requestPermission()
            }) {
                Text("권한 요청")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 20)

            Text("개인정보는 기기에만 저장되며 외부로 전송되지 않습니다.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("스크린 타임 데이터 없음")
                .font(.title3)
                .fontWeight(.semibold)

            Text("데이터를 불러오는 중입니다.\n잠시 후 다시 시도해주세요.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                loadScreenTimeData()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var categoryListView: some View {
        List {
            Section {
                Text("지난 7일간의 평균 사용 시간을 기반으로 일정을 추천합니다.\n추가할 카테고리를 선택하세요.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("추천 일정") {
                ForEach(screenTimeManager.categories) { category in
                    categoryRow(category)
                }
            }

            if !selectedCategories.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("선택된 항목: \(selectedCategories.count)개")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        let totalHours = screenTimeManager.categories
                            .filter { selectedCategories.contains($0.id) }
                            .reduce(0.0) { $0 + $1.hours }

                        Text("총 시간: \(String(format: "%.1f시간/일", totalHours))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: ScreenTimeCategory) -> some View {
        let isSelected = selectedCategories.contains(category.id)

        return HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(String(format: "평균 %.1f시간/일", category.hours))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.3))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedCategories.remove(category.id)
            } else {
                selectedCategories.insert(category.id)
            }
        }
    }

    private func requestPermission() {
        isLoading = true

        Task {
            do {
                try await screenTimeManager.requestAuthorization()

                if screenTimeManager.isAuthorized {
                    await loadScreenTimeData()
                }
            } catch {
                await MainActor.run {
                    showError = true
                    isLoading = false
                }
            }
        }
    }

    private func loadScreenTimeData() {
        isLoading = true

        Task {
            await screenTimeManager.fetchScreenTimeData()

            await MainActor.run {
                isLoading = false

                // 자동으로 30분 이상 사용한 카테고리 선택
                for category in screenTimeManager.categories {
                    if category.totalMinutes >= 30 {
                        selectedCategories.insert(category.id)
                    }
                }
            }
        }
    }

    private func addSelectedEvents() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let futureDate = calendar.date(byAdding: .month, value: 1, to: today) else {
            return
        }

        for category in screenTimeManager.categories {
            if selectedCategories.contains(category.id) {
                let event = Event(
                    title: category.name,
                    startDate: today,
                    endDate: futureDate,
                    hoursPerDay: category.hours
                )
                viewModel.addEvent(event)
                print("✅ 일정 추가됨: \(category.name) - \(String(format: "%.1f", category.hours))시간/일")
            }
        }

        dismiss()
    }
}
