//
//  SettingsView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-14.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ScheduleViewModel

    @State private var monthsToShow: Int
    @State private var sleepHours: Double
    @State private var showPastEvents: Bool
    @State private var isSyncEnabled: Bool
    @State private var showingSyncAlert = false
    @State private var syncAlertTitle = ""
    @State private var syncAlertMessage = ""
    @State private var isSyncing = false
    @State private var syncProgress: Double = 0.0
    @State private var syncProgressText = ""
    @State private var showingEventManagement = false
    @State private var showingStatistics = false
    @State private var showingDeleteiCloudAlert = false
    @State private var showingBalanceAlert = false
    @State private var balanceSuggestions: [Event: Date] = [:]
    @State private var isAnalyzingBalance = false

    private let cloudKitManager = CloudKitManager.shared
    private let syncSettings = SyncSettingsManager.shared

    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        _monthsToShow = State(initialValue: viewModel.monthsToShow)
        _sleepHours = State(initialValue: viewModel.sleepHoursPerDay)
        _showPastEvents = State(initialValue: viewModel.showPastEvents)
        _isSyncEnabled = State(initialValue: SyncSettingsManager.shared.isSyncEnabled)
    }

    var body: some View {
        NavigationView {
            Form {
                // 일정 관리 섹션
                Section {
                    Button(action: {
                        showingEventManagement = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("일정 관리")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("모든 일정을 리스트로 보기")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button(action: {
                        showingStatistics = true
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("일정 통계")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("전체 일정 분석 및 통계")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // 지나간 이벤트 보기 토글
                    Toggle(isOn: $showPastEvents) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(showPastEvents ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("지나간 이벤트 보기")
                                    .font(.headline)
                                Text("종료일이 지난 일정도 표시")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("일정")
                } footer: {
                    Text(showPastEvents
                        ? "모든 일정(지나간 일정 포함)을 표시합니다."
                        : "종료일이 오늘 이전인 일정은 자동으로 숨겨집니다.")
                }

                // 일정 분산 섹션
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: analyzeScheduleBalance) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("일정 분산 분석")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("과부하된 일정을 균형있게 재배치")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if isAnalyzingBalance {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        .disabled(isAnalyzingBalance)
                        .padding(.vertical, 4)

                        if !balanceSuggestions.isEmpty {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                    Text("\(balanceSuggestions.count)개 일정 이동 제안")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                ForEach(Array(balanceSuggestions.keys.prefix(3)), id: \.color) { event in
                                    if let newDate = balanceSuggestions[event] {
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "arrow.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(event.title)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                HStack(spacing: 4) {
                                                    Text(formatDateShort(event.startDate))
                                                        .font(.caption2)
                                                    Image(systemName: "arrow.right")
                                                        .font(.caption2)
                                                    Text(formatDateShort(newDate))
                                                        .font(.caption2)
                                                        .foregroundColor(.green)
                                                }
                                                .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }

                                if balanceSuggestions.count > 3 {
                                    Text("외 \(balanceSuggestions.count - 3)개...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                }

                                Button(action: {
                                    showingBalanceAlert = true
                                }) {
                                    Text("제안된 일정 적용하기")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.purple)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("🤖 AI 최적화")
                } footer: {
                    Text("일정이 몰려있는 날짜를 감지하고, 자유시간과 중요도를 고려하여 자동으로 일정을 재배치합니다. 중요도가 낮은 일정만 이동됩니다.")
                }

                // iCloud 동기화 섹션
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: cloudKitManager.isAvailable ? "icloud" : "icloud.slash")
                                .foregroundColor(cloudKitManager.isAvailable ? .blue : .gray)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("iCloud 상태")
                                    .font(.headline)
                                Text(cloudKitManager.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        if cloudKitManager.isAvailable {
                            Toggle(isOn: $isSyncEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("데이터 백업")
                                        .font(.headline)
                                    Text("iCloud에 일정 데이터 백업")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onChange(of: isSyncEnabled) { oldValue, newValue in
                                handleSyncToggle(newValue)
                            }
                            .disabled(isSyncing)

                            VStack(alignment: .leading, spacing: 8) {
                                if isSyncEnabled {
                                    HStack {
                                        Text("마지막 백업")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(syncSettings.lastSyncDateString)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if isSyncing {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ProgressView(value: syncProgress, total: 1.0)
                                        Text(syncProgressText)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Divider()
                                    .padding(.vertical, 8)

                                // 수동 백업 버튼
                                Button(action: manualBackupToiCloud) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 20))
                                            .frame(width: 28)
                                        Text("수동 백업")
                                            .font(.system(size: 16))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                                .disabled(isSyncing)

                                Divider()
                                    .padding(.vertical, 4)

                                // iCloud 복원 버튼
                                Button(action: restoreFromiCloud) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 20))
                                            .frame(width: 28)
                                        Text("iCloud에서 복원")
                                            .font(.system(size: 16))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.green)
                                .disabled(isSyncing)

                                Divider()
                                    .padding(.vertical, 4)

                                // iCloud 데이터 전체 삭제 버튼
                                Button(action: {
                                    showingDeleteiCloudAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 20))
                                            .frame(width: 28)
                                        Text("iCloud 데이터 삭제")
                                            .font(.system(size: 16))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                                .disabled(isSyncing)
                            }
                        } else {
                            Text("iCloud를 사용하려면 설정에서 Apple ID로 로그인해주세요.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("iCloud 백업")
                } footer: {
                    Text("동기화를 켜면 일정 추가/수정/삭제 시 자동으로 iCloud에 백업됩니다.\n• 수동 백업: 현재 로컬 데이터를 iCloud에 업로드\n• iCloud에서 복원: 앱 재설치 후 백업 데이터 복원")
                }

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
        .alert(syncAlertTitle, isPresented: $showingSyncAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(syncAlertMessage)
        }
        .sheet(isPresented: $showingEventManagement) {
            EventManagementView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView(viewModel: viewModel)
        }
        .alert("iCloud 데이터 삭제", isPresented: $showingDeleteiCloudAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteiCloudData()
            }
        } message: {
            Text("iCloud에 백업된 모든 일정 데이터를 삭제하시겠습니까?\n\n로컬 데이터는 유지되며, iCloud 백업만 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
        }
        .alert("일정 분산 적용", isPresented: $showingBalanceAlert) {
            Button("취소", role: .cancel) { }
            Button("적용", role: .destructive) {
                applyScheduleBalance()
            }
        } message: {
            Text("\(balanceSuggestions.count)개의 일정을 새로운 날짜로 이동하시겠습니까?\n\n이 작업은 일정의 시작/종료일을 변경합니다.")
        }
    }

    private func saveSettings() {
        viewModel.updateMonthsToShow(monthsToShow)
        viewModel.updateSleepHours(sleepHours)
        viewModel.updateShowPastEvents(showPastEvents)
        dismiss()
    }

    // MARK: - iCloud Sync Functions

    private func handleSyncToggle(_ isEnabled: Bool) {
        if isEnabled {
            // 동기화 켜기: 현재 데이터를 CloudKit에 백업
            startBackupToiCloud()
        } else {
            // 동기화 끄기: CloudKit 데이터 삭제
            turnOffSync()
        }
    }

    private func startBackupToiCloud() {
        guard cloudKitManager.isAvailable else {
            isSyncEnabled = false
            syncAlertTitle = "백업 실패"
            syncAlertMessage = "iCloud를 사용할 수 없습니다."
            showingSyncAlert = true
            return
        }

        isSyncing = true
        syncProgress = 0.0
        syncProgressText = "백업 시작 중..."

        // 현재 로컬 데이터 가져오기
        let events = viewModel.fetchEvents()

        // 1단계: iCloud 데이터 전체 삭제 (로컬과 동기화)
        print("🗑️ [SettingsView] Deleting all iCloud events before backup...")
        cloudKitManager.deleteAllEvents { deleteResult in
            DispatchQueue.main.async {
                switch deleteResult {
                case .success:
                    print("✅ [SettingsView] iCloud data cleared")

                    guard !events.isEmpty else {
                        // 데이터가 없어도 설정은 저장
                        syncSettings.isSyncEnabled = true
                        syncSettings.updateLastSyncDate()
                        isSyncing = false
                        syncAlertTitle = "백업 완료"
                        syncAlertMessage = "백업할 일정이 없습니다.\niCloud 데이터가 비워졌습니다."
                        showingSyncAlert = true
                        return
                    }

                    // 2단계: 로컬 데이터를 iCloud에 업로드
                    syncProgressText = "\(events.count)개 일정 백업 중..."
                    print("📤 [SettingsView] Uploading \(events.count) events to iCloud...")

                    // CloudKit에 저장
                    cloudKitManager.saveEvents(events, progress: { saved, total in
                        DispatchQueue.main.async {
                            syncProgress = Double(saved) / Double(total)
                            syncProgressText = "\(saved)/\(total)개 백업 중..."
                        }
                    }) { result in
                        DispatchQueue.main.async {
                            isSyncing = false

                            switch result {
                            case .success:
                                syncSettings.isSyncEnabled = true
                                syncSettings.updateLastSyncDate()
                                syncProgress = 1.0
                                syncProgressText = "백업 완료"

                                syncAlertTitle = "백업 성공"
                                syncAlertMessage = "\(events.count)개의 일정이 iCloud에 백업되었습니다.\niCloud 데이터가 로컬과 동기화되었습니다."
                                showingSyncAlert = true

                            case .failure(let error):
                                isSyncEnabled = false
                                syncAlertTitle = "백업 실패"
                                syncAlertMessage = "오류: \(error.localizedDescription)"
                                showingSyncAlert = true
                            }
                        }
                    }

                case .failure(let error):
                    isSyncing = false
                    isSyncEnabled = false
                    syncAlertTitle = "백업 실패"
                    syncAlertMessage = "iCloud 데이터 삭제 실패: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }

    private func turnOffSync() {
        guard cloudKitManager.isAvailable else {
            syncSettings.isSyncEnabled = false
            return
        }

        isSyncing = true
        syncProgressText = "백업 데이터 삭제 중..."

        // CloudKit의 모든 데이터 삭제
        cloudKitManager.deleteAllEvents { result in
            DispatchQueue.main.async {
                isSyncing = false
                syncSettings.isSyncEnabled = false

                switch result {
                case .success:
                    syncAlertTitle = "동기화 해제"
                    syncAlertMessage = "iCloud 백업이 해제되었습니다. 로컬 데이터는 유지됩니다."
                    showingSyncAlert = true

                case .failure(let error):
                    syncAlertTitle = "해제 실패"
                    syncAlertMessage = "오류: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }

    // MARK: - iCloud Sync Functions

    private func manualBackupToiCloud() {
        guard cloudKitManager.isAvailable else {
            syncAlertTitle = "백업 실패"
            syncAlertMessage = "iCloud를 사용할 수 없습니다."
            showingSyncAlert = true
            return
        }

        isSyncing = true
        syncProgress = 0.0
        syncProgressText = "백업 시작 중..."

        // 현재 로컬 데이터 가져오기
        let events = viewModel.fetchEvents()

        // 1단계: iCloud 데이터 전체 삭제 (로컬과 동기화)
        print("🗑️ [SettingsView] Manual backup: Deleting all iCloud events...")
        cloudKitManager.deleteAllEvents { deleteResult in
            DispatchQueue.main.async {
                switch deleteResult {
                case .success:
                    print("✅ [SettingsView] iCloud data cleared")

                    guard !events.isEmpty else {
                        // 로컬 데이터가 없으면 iCloud도 비워진 상태로 완료
                        isSyncing = false
                        syncAlertTitle = "백업 완료"
                        syncAlertMessage = "로컬에 일정이 없습니다.\niCloud 데이터가 비워졌습니다."
                        showingSyncAlert = true
                        syncSettings.updateLastSyncDate()
                        return
                    }

                    // 2단계: 로컬 데이터를 iCloud에 업로드
                    syncProgressText = "\(events.count)개 일정 백업 중..."
                    print("📤 [SettingsView] Manual backup: Uploading \(events.count) events to iCloud...")

                    // CloudKit에 저장
                    cloudKitManager.saveEvents(events, progress: { saved, total in
                        DispatchQueue.main.async {
                            syncProgress = Double(saved) / Double(total)
                            syncProgressText = "\(saved)/\(total)개 백업 중..."
                        }
                    }) { result in
                        DispatchQueue.main.async {
                            isSyncing = false

                            switch result {
                            case .success:
                                syncSettings.updateLastSyncDate()
                                syncProgress = 1.0
                                syncProgressText = "백업 완료"

                                syncAlertTitle = "백업 성공"
                                syncAlertMessage = "\(events.count)개의 일정이 iCloud에 백업되었습니다."
                                showingSyncAlert = true

                            case .failure(let error):
                                syncAlertTitle = "백업 실패"
                                syncAlertMessage = "오류: \(error.localizedDescription)"
                                showingSyncAlert = true
                            }
                        }
                    }

                case .failure(let error):
                    isSyncing = false
                    syncAlertTitle = "백업 실패"
                    syncAlertMessage = "iCloud 데이터 삭제 실패: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }

    // MARK: - Delete iCloud Data Function

    private func deleteiCloudData() {
        guard cloudKitManager.isAvailable else {
            syncAlertTitle = "삭제 실패"
            syncAlertMessage = "iCloud를 사용할 수 없습니다."
            showingSyncAlert = true
            return
        }

        isSyncing = true
        syncProgressText = "iCloud 데이터 삭제 중..."

        // CloudKit의 모든 데이터 삭제
        cloudKitManager.deleteAllEvents { result in
            DispatchQueue.main.async {
                isSyncing = false

                switch result {
                case .success:
                    // 동기화 토글도 자동으로 끄기
                    syncSettings.isSyncEnabled = false
                    isSyncEnabled = false

                    syncAlertTitle = "삭제 완료"
                    syncAlertMessage = "iCloud에 백업된 모든 일정 데이터가 삭제되었습니다.\n로컬 데이터는 유지됩니다.\n\n동기화가 자동으로 해제되었습니다."
                    showingSyncAlert = true

                case .failure(let error):
                    syncAlertTitle = "삭제 실패"
                    syncAlertMessage = "오류: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }

    // MARK: - iCloud Restore Function (iCloud → 로컬)

    private func restoreFromiCloud() {
        guard cloudKitManager.isAvailable else {
            syncAlertTitle = "복원 실패"
            syncAlertMessage = "iCloud를 사용할 수 없습니다."
            showingSyncAlert = true
            return
        }

        isSyncing = true
        syncProgress = 0.0
        syncProgressText = "복원 시작 중..."

        // CloudKit에서 데이터 가져오기
        cloudKitManager.restoreEvents(progress: { restored, total in
            DispatchQueue.main.async {
                syncProgress = Double(restored) / Double(total)
                syncProgressText = "\(restored)/\(total)개 복원 중..."
            }
        }) { result in
            DispatchQueue.main.async {
                isSyncing = false

                switch result {
                case .success(let events):
                    if events.isEmpty {
                        syncAlertTitle = "복원 완료"
                        syncAlertMessage = "iCloud에 백업된 일정이 없습니다."
                        showingSyncAlert = true
                        return
                    }

                    // 1단계: 로컬 데이터 전체 삭제 (iCloud와 동기화)
                    print("🗑️ [SettingsView] Deleting all local events before restore...")
                    let localEvents = viewModel.fetchEvents()
                    for event in localEvents {
                        // 로컬만 삭제 (CloudKit은 삭제하지 않음)
                        guard let context = viewModel.modelContext else { return }
                        context.delete(event)
                    }

                    do {
                        try viewModel.modelContext?.save()
                        print("✅ [SettingsView] Local data cleared: \(localEvents.count) events deleted")
                    } catch {
                        print("❌ [SettingsView] Failed to clear local data: \(error)")
                    }

                    // 2단계: iCloud 데이터로 완전히 교체
                    print("📥 [SettingsView] Restoring \(events.count) events from iCloud...")
                    for event in events {
                        // addEvent를 사용하되, CloudKit 동기화는 건너뛰도록 임시로 동기화 OFF
                        let wasSyncEnabled = syncSettings.isSyncEnabled
                        syncSettings.isSyncEnabled = false

                        viewModel.addEvent(event)

                        syncSettings.isSyncEnabled = wasSyncEnabled
                    }

                    syncProgress = 1.0
                    syncProgressText = "복원 완료"

                    // 복원 성공 시 동기화 토글 자동으로 켜기
                    syncSettings.isSyncEnabled = true
                    syncSettings.updateLastSyncDate()
                    isSyncEnabled = true

                    // 화면 즉시 새로고침 트리거
                    viewModel.dataRefreshTrigger = UUID()
                    print("🔄 [SettingsView] Triggering UI refresh after restore")

                    syncAlertTitle = "복원 성공"
                    syncAlertMessage = "\(events.count)개의 일정이 iCloud에서 복원되었습니다.\n로컬 데이터가 iCloud와 동기화되었습니다."
                    showingSyncAlert = true

                case .failure(let error):
                    syncAlertTitle = "복원 실패"
                    syncAlertMessage = "오류: \(error.localizedDescription)"
                    showingSyncAlert = true
                }
            }
        }
    }

    // MARK: - Schedule Balance Functions

    private func analyzeScheduleBalance() {
        isAnalyzingBalance = true
        balanceSuggestions = [:]

        // 백그라운드에서 분석 실행
        DispatchQueue.global(qos: .userInitiated).async {
            let suggestions = viewModel.suggestScheduleBalancing()

            DispatchQueue.main.async {
                isAnalyzingBalance = false
                balanceSuggestions = suggestions

                if suggestions.isEmpty {
                    syncAlertTitle = "분산 분석 완료"
                    syncAlertMessage = "일정이 이미 균형잡혀 있습니다.\n재배치가 필요한 일정이 없습니다."
                    showingSyncAlert = true
                }
            }
        }
    }

    private func applyScheduleBalance() {
        viewModel.applyScheduleBalancing(suggestions: balanceSuggestions)
        balanceSuggestions = [:]

        syncAlertTitle = "분산 완료"
        syncAlertMessage = "일정이 성공적으로 재배치되었습니다."
        showingSyncAlert = true
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

