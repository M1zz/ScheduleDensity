//
//  SettingsView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-14.
//

import SwiftUI
import SwiftData
import LeeoKit
import CloudKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ScheduleViewModel

    @State private var monthsToShow: Int
    @State private var sleepHours: Double
    @State private var showPastEvents: Bool
    @State private var showWeekBlocksPlans: Bool
    @State private var fillSpanToEndDate: Bool
    @State private var isSyncEnabled: Bool
    @State private var showingSyncAlert = false
    @State private var syncAlertTitle = ""
    @State private var syncAlertMessage = ""
    @State private var isSyncing = false
    @State private var syncProgress: Double = 0.0
    @State private var syncProgressText = ""
    /// 할 일 조언(TipKit) 다시 보기를 눌렀는지 — 한 화면 안에서 두 번 누를 일은 없다.
    @State private var tipsResetDone = false
    @State private var showingEventManagement = false
    @State private var showingStatistics = false
    @State private var showingDeleteiCloudAlert = false

    // MARK: 동기화 진단
    // "맥이랑 할 일이 다른데?"를 화면에서 바로 판별하려고 둔 값들.
    @State private var accountStatusText = "확인 중…"
    @State private var userRecordName = "확인 중…"
    @State private var mirrorRoutines = 0
    @State private var mirrorBlocks = 0
    @State private var todoCount = 0
    /// CloudKit에 레코드 타입이 실제로 있는지 (→ CloudSchemaProbe.swift).
    /// 여섯 번의 왕복이라 화면을 열 때마다 돌리지 않고, 눌렀을 때만 확인한다.
    @State private var zoneCensus: CloudSchemaProbe.Outcome?
    @State private var isProbingSchema = false
    /// 모델에는 있는데 서버에는 없는 필드. 하나라도 있으면 동기화 전체가 죽는다.
    @State private var missingFields: [String: [String]] = [:]
    @State private var isPrimingSchema = false
    @State private var primeNote: String?
    @State private var showingBalanceAlert = false
    @State private var balanceSuggestions: [Event: Date] = [:]
    @State private var isAnalyzingBalance = false
    @State private var showingCalendarImport = false
    @State private var showingAddSampleAlert = false
    /// 지우기 직전에 세우는 물음. 문구도 순서도 다른 화면과 같은 자리에서 낸다
    /// (→ EventDeletion.swift).
    @State private var deletionRequest: EventDeletionRequest?
    /// 유료로 가른 곁다리들 (→ ProEntitlement.swift). 잠겨 있으면 페이월을 낸다.
    @State private var purchases = PurchaseManager.shared
    @State private var paywallFeature: ProFeature?
    /// 할 일 분류를 만들고 고치는 시트 (→ CategoryManagerView.swift).
    @State private var showingCategoryManager = false
    @AppStorage("showInsightCards") private var showInsightCards = false
    @AppStorage(AppSettingsKey.showShareTab) private var showShareTab = false
    @AppStorage(AppSettingsKey.hasSeenRainbowOnboarding) private var hasSeenRainbowOnboarding = false
    @AppStorage(AppSettingsKey.hasSeenBoltOnboarding) private var hasSeenBoltOnboarding = false

    private let cloudKitManager = CloudKitManager.shared
    private let syncSettings = SyncSettingsManager.shared

    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        _monthsToShow = State(initialValue: viewModel.monthsToShow)
        _sleepHours = State(initialValue: viewModel.sleepHoursPerDay)
        _showPastEvents = State(initialValue: viewModel.showPastEvents)
        _showWeekBlocksPlans = State(initialValue: viewModel.showWeekBlocksPlans)
        _fillSpanToEndDate = State(initialValue: viewModel.fillSpanToEndDate)
        _isSyncEnabled = State(initialValue: SyncSettingsManager.shared.isSyncEnabled)
    }

    // MARK: - 내 버전 (설정 맨 위)

    /// 무료인가 열려 있는가. 한 단어로 먼저 답한다.
    private var entitlementTitle: String {
        purchases.isUnlocked ? "모두 열림" : "무료 버전"
    }

    /// 그래서 지금 무엇을 쓰고 있는가. 잠긴 쪽에서도 **본체는 다 쓴다**는 말을 먼저 한다 —
    /// 이 앱은 무료로도 온전히 돌아가고, 그 사실을 감추면 안 사는 사람이 지운다.
    private var entitlementNote: String {
        if purchases.isUnlocked {
            return "한 번 사서 곁다리까지 전부 열려 있습니다."
        }
        return "무지개, 할 일 쪼개기, 두 질문, 단계 순서는 그대로 쓰십니다. 곁다리 \(ProFeature.sold.count)가지가 잠겨 있습니다."
    }

    /// 값을 받고 여는 것들의 이름.
    /// ⚠️ 손으로 적지 않는다. 전에 여기 다섯 개만 적혀 있어서 나중에 들어온
    ///    '이 기기에서 적기'가 빠져 있었다 — 목록은 `ProFeature` 한 곳에서만 읽는다.
    private var lockedFeatureList: String {
        ProFeature.sold.map(\.title).joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                // ⚠️ 이 섹션은 **맨 위**에 둔다. 설정을 열고 제일 먼저 궁금한 것은
                //    "나는 지금 무료인가, 열려 있는가"인데, 전에는 이 답이 설정 바닥에
                //    있어서 끝까지 내려가야 알 수 있었다.
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: purchases.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                            .font(.title3)
                            .foregroundStyle(purchases.isUnlocked ? Color.green : Color.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entitlementTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(entitlementNote)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)

                    if !purchases.isUnlocked {
                        Button {
                            paywallFeature = .widget
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("모두 열기")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(lockedFeatureList)
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

                        Button("구매 복원") {
                            Task { await purchases.restore() }
                        }
                        .disabled(purchases.isRestoring)
                    }
                } header: {
                    Text("내 버전")
                } footer: {
                    Text("무지개, 할 일 쪼개기, 두 질문, 단계 순서는 값을 받지 않습니다. 한 번 사면 끝이고 구독이 아닙니다.")
                }

                Group {
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
                        // 잠긴 자리는 아무 일도 안 일어나게 두지 않는다 —
                        // 왜 안 되는지 그 자리에서 말해준다.
                        if purchases.isUnlocked { showingStatistics = true }
                        else { paywallFeature = .statistics }
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
                            if !purchases.isUnlocked { ProLockBadge() }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button(action: {
                        if purchases.isUnlocked { showingCalendarImport = true }
                        else { paywallFeature = .calendarImport }
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("캘린더에서 가져오기")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("시스템 캘린더 일정 불러오기")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !purchases.isUnlocked { ProLockBadge() }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider()

                    Button(action: {
                        viewModel.showingAddEvent = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("일정 추가")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("새로운 일정 만들기")
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
                        showingAddSampleAlert = true
                    }) {
                        HStack {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("샘플 데이터 추가")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("테스트용 샘플 일정 추가")
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
                        let events = viewModel.fetchEvents()
                        deletionRequest = EventDeletionRequest(
                            title: "일정 \(events.count)개 삭제",
                            plan: viewModel.deletionPlan(for: events)
                        ) { await viewModel.deleteAllEvents() }
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("모든 일정 삭제")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("모든 일정을 삭제합니다")
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

                    Divider()

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

                    // WeekBlocks(무지개 공방) 계획 표시 토글
                    Toggle(isOn: $showWeekBlocksPlans) {
                        HStack(spacing: 8) {
                            Image(systemName: "macwindow")
                                .foregroundColor(showWeekBlocksPlans ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("무지개 공방 계획 표시")
                                    .font(.headline)
                                Text("Mac에서 짠 주간 계획 블록을 밀도에 함께 표시 (읽기 전용).\n루틴(고정·쿼터)은 매일 그대로 깔리므로 그리지 않습니다.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // 종료일까지 이어 칠하기 토글
                    Toggle(isOn: $fillSpanToEndDate) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.to.line")
                                .foregroundColor(fillSpanToEndDate ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("종료일까지 이어서 표시")
                                    .font(.headline)
                                Text("주 1회 연습이라도 두 달 뒤 공연이면 그 두 달이 매여 있는 시간입니다.\n기간 전체를 옅게 깔고, 실제로 하는 날만 진하게 표시합니다.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // 인사이트 보이기 토글
                    Toggle(isOn: $showInsightCards) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(showInsightCards ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("인사이트 보이기")
                                    .font(.headline)
                                Text("일정 분석 및 추천 카드 표시")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // 공유 탭 표시 토글.
                    // 잠겨 있으면 토글을 끄는 대신 켜려는 순간 페이월을 낸다 —
                    // 회색으로 죽은 스위치는 고장인지 잠긴 건지 구분이 안 된다.
                    Toggle(isOn: Binding(
                        get: { showShareTab && purchases.isUnlocked },
                        set: { wants in
                            guard purchases.isUnlocked else {
                                if wants { paywallFeature = .scheduleShare }
                                return
                            }
                            showShareTab = wants
                        }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.circle")
                                .foregroundColor(showShareTab && purchases.isUnlocked ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("공유 탭 표시")
                                        .font(.headline)
                                    if !purchases.isUnlocked { ProLockBadge() }
                                }
                                Text("일정을 다른 사람과 공유하는 탭을 추가")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // 무지개 사용법 다시 보기 — 첫 진입 온보딩을 처음부터 다시 띄운다.
                    Button {
                        hasSeenRainbowOnboarding = false
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("무지개 사용법 다시 보기")
                                    .font(.headline)
                                Text("꾹 눌러 일정 만드는 법을 처음부터 안내")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
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
                }

                Group {
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
                }

                // 할 일이 iCloud로 오가고 있는지, 맥 것이 내려와 있는지를 한 화면에서 본다.
                // 조용히 로컬 전용으로 떨어져도 여기서는 드러난다.
                Section {
                    HStack {
                        Text("할 일 저장 위치")
                        Spacer()
                        Text(CloudDiagnostics.todoStoreMode.rawValue)
                            .foregroundColor(CloudDiagnostics.todoStoreMode == .cloud ? .secondary : .red)
                    }
                    if let error = CloudDiagnostics.todoStoreError {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    HStack {
                        Text("iCloud 계정")
                        Spacer()
                        Text(accountStatusText).foregroundColor(.secondary)
                    }
                    #if DEBUG
                    HStack {
                        Text("계정 식별자")
                        Spacer()
                        Text(userRecordName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    #endif
                    HStack {
                        Text("맥에서 내려온 계획")
                        Spacer()
                        Text("루틴 \(mirrorRoutines) · 블록 \(mirrorBlocks)")
                            .foregroundColor(mirrorBlocks == 0 ? .red : .secondary)
                    }
                    HStack {
                        Text("이 기기의 할 일")
                        Spacer()
                        Text("\(todoCount)개").foregroundColor(.secondary)
                    }

                    // 스키마가 배포 안 된 것은 위 값들로는 안 드러난다 —
                    // 계정도 맞고 저장 위치도 '클라우드'인데 아무것도 안 오간다.
                    // ── 여기부터는 개발용이다. 사용자에게는 위 네 줄이면 충분하고,
                    //    아래는 원문 에러와 필드 이름이라 읽을 사람이 다르다.
                    #if DEBUG
                    // 엔진이 직접 남긴 결과. 결과 숫자만으로는 '왜'를 알 수 없다.
                    syncEventRow("준비", CloudSyncLog.shared.setup)
                    syncEventRow("받기", CloudSyncLog.shared.importing)
                    syncEventRow("보내기", CloudSyncLog.shared.exporting)

                    Button {
                        Task { await probeSchema() }
                    } label: {
                        HStack {
                            Text(isProbingSchema ? "세는 중…" : "iCloud에 뭐가 있나 세어 보기")
                            Spacer()
                            if isProbingSchema { ProgressView() }
                        }
                    }
                    .disabled(isProbingSchema)

                    switch zoneCensus {
                    case .counted(let counts):
                        // 0인 줄이 곧 '아직 안 올라온 것'이다. 거기부터 보면 된다.
                        ForEach(counts.keys.sorted(), id: \.self) { type in
                            HStack {
                                Text(type.replacingOccurrences(of: "CD_", with: ""))
                                    .font(.callout)
                                Spacer()
                                Text("\(counts[type] ?? 0)개")
                                    .font(.callout)
                                    .monospacedDigit()
                                    .foregroundColor((counts[type] ?? 0) == 0 ? .red : .secondary)
                            }
                        }
                    case .noZone:
                        Text("iCloud에 존이 아직 없습니다 — 이 계정에서 아무것도 안 올라갔습니다.")
                            .font(.caption)
                            .foregroundColor(.red)
                    case .failed(let why):
                        Text("세지 못했습니다: \(why)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .none:
                        EmptyView()
                    }

                    if !missingFields.isEmpty {
                        ForEach(missingFields.keys.sorted(), id: \.self) { entity in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(entity) — 서버에 없는 필드")
                                    .font(.callout)
                                    .foregroundColor(.red)
                                Text((missingFields[entity] ?? []).joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    // 옵셔널 필드는 값을 한 번 넣어야 서버에 칸이 생긴다.
                    // 손으로 다 써 보는 대신 표본 한 벌로 만들어 둔다
                    // (→ CloudSchemaPrimer.swift). Development에서만 뜻이 있다.
                    Button {
                        Task { await primeSchema() }
                    } label: {
                        HStack {
                            Text(isPrimingSchema ? "만드는 중… (25초)" : "스키마 만들기")
                            Spacer()
                            if isPrimingSchema { ProgressView() }
                        }
                    }
                    .disabled(isPrimingSchema)

                    if let note = primeNote {
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    #endif
                } header: {
                    Text("동기화 진단")
                } footer: {
                    Text("맥과 같은 계정이면 '계정 식별자'가 서로 같습니다.\n'맥에서 내려온 계획'이 0이면 iCloud에서 아무것도 안 내려온 것이고, '할 일 저장 위치'가 빨간 글씨면 이 기기에만 쌓이고 있는 것입니다.\n\n'세어 보기'는 iCloud에 실제로 올라가 있는 것을 셉니다. 어떤 타입이 0개면 그건 **아직 안 올라간** 것이고, 대개 CloudKit 콘솔에서 Development → Production 스키마를 배포하지 않아서입니다. 반대로 개수가 있는데 앱 목록이 비었다면 올라온 걸 **못 읽는** 것이라 다른 문제입니다.")
                }

                Group {
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
                }

                Section {
                    Button {
                        showingCategoryManager = true
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("분류 만들기·고치기")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("할 일에 붙이는 분류의 이름·색·기호")
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
                } header: {
                    Text("할 일")
                } footer: {
                    Text("할 일 상세 화면의 ‘분류’를 눌러서도 바로 만들 수 있습니다.")
                }

                // 번개(‘바로 하면 되는 일’) — 스와이프에서 글자를 뺐으므로, 그 아이콘이
                // 무슨 뜻이었는지 잊었을 때 펴 볼 자리가 앱 안에 하나는 있어야 한다.
                Section {
                    // 덮어 씌우는 대신 밀어 넣는다. 설정 안의 다른 문들과 같은 손짓이다.
                    NavigationLink {
                        BoltMeaningView(eyebrow: "할 일 목록의 번개",
                                        showsDoneButton: false) { }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(TodoView.nowGreen)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("번개가 뭔가요")
                                    .font(.headline)
                                Text("‘지금 바로 되는 일’ 표시 — 뜻과 쓰는 법")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        hasSeenBoltOnboarding = false
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.draw")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("번개 안내 다시 보기")
                                    .font(.headline)
                                Text("할 일 목록 맨 위에 안내 줄을 다시 세웁니다")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                } header: {
                    Text("번개")
                }

                Section {
                    Button {
                        TodoTips.resetAll()
                        tipsResetDone = true
                    } label: {
                        Label(tipsResetDone ? "다시 보기로 바꿨습니다" : "할 일 조언 다시 보기",
                              systemImage: tipsResetDone ? "checkmark.circle.fill" : "lightbulb")
                    }
                    .disabled(tipsResetDone)

                    Text("할 일 화면에서 닫았던 조언(쪼개기·단계 크기 팁)을 처음부터 다시 봅니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("조언")
                }

                Section {
                    LeeoSupportSection<ScheduleDensityAppSpec>()
                } header: {
                    Text("지원")
                }

                DeveloperContactSection()
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
        .sheet(isPresented: $showingCalendarImport) {
            CalendarImportView(viewModel: viewModel)
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(highlight: feature)
        }
        .sheet(isPresented: $showingCategoryManager) {
            // ⚠️ 이 설정 화면은 **일정 스토어**에서 돈다. 분류는 할 일 스토어에 있으므로
            //    컨테이너를 붙여줘야 한다 — 안 붙이면 목록이 통째로 비어 보인다.
            if let container = TodoEventBridge.shared.todoContainer {
                CategoryManagerView()
                    .modelContainer(container)
            } else {
                // 앱 진입 직후 다리가 아직 안 붙은 아주 짧은 순간. 빈 화면 대신 이유를 적는다.
                ContentUnavailableView("잠시 뒤 다시 열어 주세요",
                                       systemImage: "hourglass",
                                       description: Text("할 일 저장소를 아직 준비하는 중입니다."))
            }
        }
        .task { await purchases.refresh() }
        .task { await loadSyncDiagnostics() }
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
        .alert("샘플 데이터 추가", isPresented: $showingAddSampleAlert) {
            Button("추가") {
                viewModel.addSampleEvents()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("5개의 샘플 일정을 추가하시겠습니까?\n(프로젝트 A, B, 출장, 교육 프로그램, 컨퍼런스)")
        }
        .confirmsEventDeletion($deletionRequest)
    }

    private func saveSettings() {
        viewModel.updateMonthsToShow(monthsToShow)
        viewModel.updateSleepHours(sleepHours)
        viewModel.updateShowPastEvents(showPastEvents)
        viewModel.updateShowWeekBlocksPlans(showWeekBlocksPlans)
        viewModel.updateFillSpanToEndDate(fillSpanToEndDate)
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

// MARK: - 개발자 문의
extension SettingsView {
    /// 동기화 엔진이 남긴 마지막 결과 한 줄 (→ CloudSyncLog.swift).
    @ViewBuilder
    func syncEventRow(_ name: String, _ entry: CloudSyncLog.Entry?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
            Spacer()
            if let entry {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.succeeded ? "성공" : "실패")
                        .foregroundColor(entry.succeeded ? .secondary : .red)
                    if let error = entry.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }
            } else {
                // 한 번도 안 돈 것과 실패한 것은 다르다. 섞어 적지 않는다.
                Text("아직 안 돌았음").foregroundColor(.orange)
            }
        }
    }

    #if DEBUG
    /// 모든 필드에 값을 넣은 표본을 한 벌 올렸다 지운다 (→ CloudSchemaPrimer.swift).
    /// 레코드는 지워도 스키마는 남는다 — 그게 목적이다.
    @MainActor
    func primeSchema() async {
        guard let container = CloudDiagnostics.todoContainer else {
            primeNote = "스토어가 없습니다."
            return
        }
        isPrimingSchema = true
        primeNote = nil
        let report = await CloudSchemaPrimer.prime(container.mainContext)
        primeNote = report.note
        isPrimingSchema = false
    }
    #endif

    /// iCloud 존에 실제로 무엇이 들어 있는지 센다 (→ CloudSchemaProbe.swift).
    @MainActor
    func probeSchema() async {
        isProbingSchema = true
        zoneCensus = await CloudSchemaProbe.census()
        // 개수만으로는 왜 안 오는지 모른다. 어긋난 필드까지 함께 찾는다 —
        // 하나라도 서버에 없으면 그것 때문에 동기화 전체가 죽는다.
        missingFields = await CloudSchemaProbe.missingFields()
        isProbingSchema = false
    }

    /// 동기화 진단 값을 채운다. iCloud 계정·미러 상태를 한 번에 물어본다.
    @MainActor
    func loadSyncDiagnostics() async {
        let counts = WeekBlocksStore.shared.mirrorCounts()
        mirrorRoutines = counts.routines
        mirrorBlocks = counts.blocks
        if let todos = CloudDiagnostics.todoContainer {
            todoCount = (try? ModelContext(todos).fetchCount(FetchDescriptor<BacklogItem>())) ?? 0
        }

        let container = CKContainer(identifier: WeekBlocksStore.containerID)
        do {
            switch try await container.accountStatus() {
            case .available: accountStatusText = "로그인됨"
            case .noAccount: accountStatusText = "로그인 안 됨"
            case .restricted: accountStatusText = "제한됨"
            case .couldNotDetermine: accountStatusText = "확인 불가"
            case .temporarilyUnavailable: accountStatusText = "일시적으로 사용 불가"
            @unknown default: accountStatusText = "알 수 없음"
            }
        } catch {
            accountStatusText = "확인 실패"
        }
        do {
            let id = try await container.userRecordID()
            userRecordName = id.recordName
        } catch {
            userRecordName = "가져오지 못함"
        }
    }
}

struct DeveloperContactSection: View {
    var body: some View {
        Section {
            Link(destination: URL(string: "mailto:leeo@kakao.com")!) {
                Label("이메일로 문의하기", systemImage: "envelope")
            }
            Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                Label("인스타그램 DM (@lee25_ios)", systemImage: "paperplane")
            }
        } header: {
            Text("개발자에게 문의")
        } footer: {
            Text("버그 제보와 기능 제안을 환영합니다.")
        }
    }
}

