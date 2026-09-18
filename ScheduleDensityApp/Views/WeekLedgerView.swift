//
//  WeekLedgerView.swift
//  ScheduleDensityApp
//
//  이번 주 결산. 세 칸이 있고, 세 칸은 서로 더해지지 않는다.
//
//  - 남은 몫: 착수 조건별로 갈라 센 일. 합계를 내지 않는다.
//  - 회수: 아낀 시간이 조각으로 돌아왔는지 블록으로 돌아왔는지 따로.
//  - 회복: 숨 돌린 것. 성과 칸이 아니다.
//
//  근거와 저장 방식은 → WeekLedger.swift
//

import SwiftUI

struct WeekLedgerView: View {
    @Environment(\.dismiss) private var dismiss

    let weekStart: Date
    /// 이번 주에 남은 단계들 (지금 할 단계 기준).
    let work: [(title: String, hours: Double)]

    @State private var entry = WeekLedgerEntry()
    @State private var showingClearConfirm = false
    @State private var purchases = PurchaseManager.shared
    @State private var showingPaywall = false

    /// 지금 보고 있는 주. 뒤로 넘기면 지난 주들이 나온다.
    @State private var shownWeek: Date?

    private var week: Date { shownWeek ?? weekStart }

    /// **무료로도 최근 2주는 그냥 보인다** (→ ScheduleDensityAppSpec.Gate.ledgerWeeks).
    ///
    /// ⚠️ 문을 통째로 잠그면, 무엇을 사는지 모르는 채로 값을 내라는 말이 된다. 이 장부는
    ///    쌓여야 값이 나오는 것이라 더 그렇다 — 두 주를 직접 써 보고 나서야 "지난 달은
    ///    어땠지"가 궁금해진다. 그 물음이 생긴 자리에서 판다.
    private func isFree(_ candidate: Date) -> Bool {
        let weeksBack = Calendar(identifier: .iso8601)
            .dateComponents([.weekOfYear], from: candidate, to: weekStart).weekOfYear ?? 0
        return weeksBack < ProFeature.freeWeekCount
    }

    private var isLocked: Bool { !purchases.isUnlocked && !isFree(week) }

    /// 이번 주인가. 지난 주 장부는 읽기만 한다 — 지나간 주에 새 기록을 더할 일은 없다.
    private var isThisWeek: Bool {
        Calendar(identifier: .iso8601).isDate(week, inSameDayAs: weekStart)
    }

    /// 지난 주 장부 — 그 주에 무엇이 돌아왔는지만.
    @ViewBuilder
    private var pastWeekSummary: some View {
        Section {
            if entry.isEmpty {
                Text("이 주에는 적어 둔 것이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("조각으로 회수", value: formatDuration(Double(entry.fragmentMinutes) / 60))
                LabeledContent("블록으로 회수", value: formatDuration(Double(entry.blockMinutes) / 60))
                LabeledContent("회복", value: formatDuration(Double(entry.breakMinutes) / 60))
            }
        } header: {
            Text("이 주에 돌아온 것")
        }
    }

    private var previousWeek: Date {
        Calendar(identifier: .iso8601).date(byAdding: .day, value: -7, to: week) ?? week
    }

    /// "9월 8일 주". 지난 주를 볼 때 제목에 선다.
    private var weekLabel: String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: .autoupdatingCurrent)
        return String(localized: "\(f.string(from: week)) 주")
    }

    var body: some View {
        NavigationStack {
            List {
                // 지난 주 장부는 **읽기만 한다.** 지나간 주에 새로 회수를 적는 일은 없고,
                // '남은 몫'은 지금 남은 단계라 이번 주에만 뜻이 있다.
                if isThisWeek {
                    workSection
                    reclaimSection
                    recoverySection
                    if !entry.isEmpty { clearSection }
                } else {
                    pastWeekSummary
                }
            }
            .navigationTitle(isThisWeek ? String(localized: "이번 주 결산") : weekLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        let previous = Calendar(identifier: .iso8601)
                            .date(byAdding: .day, value: -7, to: week) ?? week
                        // 잠긴 주로 넘어가려 하면, 넘기는 대신 그 자리에서 판다.
                        if !purchases.isUnlocked, !isFree(previous) {
                            showingPaywall = true
                        } else {
                            shownWeek = previous
                        }
                    } label: {
                        Image(systemName: purchases.isUnlocked || isFree(previousWeek) ? "chevron.left" : "lock")
                    }
                    .accessibilityLabel("지난 주")

                    Button {
                        shownWeek = Calendar(identifier: .iso8601)
                            .date(byAdding: .day, value: 7, to: week) ?? week
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(isThisWeek)
                    .accessibilityLabel("다음 주")
                }
            }
            .onAppear { entry = WeekLedger.entry(for: week) }
            .onChange(of: week) { _, newWeek in entry = WeekLedger.entry(for: newWeek) }
            .paywall(for: .ledger, isPresented: $showingPaywall)
            .confirmationDialog("이번 주 장부를 지울까요?",
                                isPresented: $showingClearConfirm,
                                titleVisibility: .visible) {
                Button("지우기", role: .destructive) {
                    WeekLedger.clear(weekStart: weekStart)
                    entry = WeekLedger.entry(for: weekStart)
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("회수와 회복 기록만 지웁니다. 할 일은 그대로입니다.")
            }
        }
    }

    // MARK: - 남은 몫

    @ViewBuilder
    private var workSection: some View {
        Section {
            if work.isEmpty {
                Text("이번 주에 남은 단계가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(work.enumerated()), id: \.offset) { _, step in
                    HStack(spacing: 12) {
                        Text(step.title)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(formatDuration(step.hours))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("남은 몫")
        } footer: {
            // 이 화면에서 가장 중요한 문장이다. 여기에만 적어 두고 목록에서는 반복하지 않는다.
            Text("일부러 합계를 내지 않습니다. 15분짜리 넷은 1시간이 아니라 다른 단위입니다 — 조각 시간은 총량으로 환산되지 않고 전환 비용에 먹힙니다.\n하루로도 결산하지 않습니다. 하루 5분은 잡음이고, 신호는 주 단위에서만 보입니다.")
        }
    }

    // MARK: - 회수

    private var reclaimSection: some View {
        Section {
            ForEach(ReclaimKind.allCases) { kind in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(kind == .block ? Color.indigo : Color.green)
                            .frame(width: 22)
                        Text(kind.name)
                            .font(.body.weight(.medium))
                        Spacer()
                        Text(formatMinutes(entry.minutes(of: kind)))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(entry.minutes(of: kind) > 0 ? Color.primary : Color.secondary)
                        addMenu(for: kind)
                    }
                    Text(kind.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("회수한 시간")
        } footer: {
            Text("두 칸은 끝까지 따로 셉니다. 합치면 “50분 벌었는데 왜 아무것도 못 했지”가 됩니다.\n하루의 끝이 시계로 고정돼 있으면 절약은 시간으로 회수되지 않고 여유(부하 감소)로만 회수됩니다. 그때 이 칸이 0인 것은 실패가 아니라 사실입니다.")
        }
    }

    private func addMenu(for kind: ReclaimKind) -> some View {
        Menu {
            ForEach(kind.steps, id: \.self) { minutes in
                Button("\(minutes)분 적기") {
                    WeekLedger.reclaim(minutes, as: kind, weekStart: weekStart)
                    entry = WeekLedger.entry(for: weekStart)
                }
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel("\(kind.name) 회수한 시간 적기")
    }

    // MARK: - 회복

    private var recoverySection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "wind")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 22)
                Text("숨 돌리기")
                    .font(.body.weight(.medium))
                Spacer()
                Text(entry.breakCount > 0
                     ? "\(entry.breakCount)번 · \(formatMinutes(entry.breakMinutes))"
                     : "아직 없음")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(entry.breakCount > 0 ? Color.primary : Color.secondary)
                Menu {
                    ForEach([5, 10, 15], id: \.self) { minutes in
                        Button("\(minutes)분 쉬었음") {
                            WeekLedger.tookBreak(minutes: minutes, weekStart: weekStart)
                            entry = WeekLedger.entry(for: weekStart)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("숨 돌린 것 적기")
            }
            .padding(.vertical, 2)
        } header: {
            Text("회복")
        } footer: {
            Text("여기 쌓이는 숫자는 진행률에 섞이지 않습니다. 성과 칸이 아니라 회복 칸입니다.\n짧은 휴식은 활력(d=.36)과 피로(d=.35)에는 효과가 확인됐지만 성과에는 유의한 효과가 없습니다(d=.16, p=.116). 성과를 기대하니까 “5분 쉬어야지”가 헛되게 느껴지는 것입니다.\n— Albulescu et al. 2022, PLOS ONE (22개 표본, N=2,335)")
        }
    }

    // MARK: - 지우기

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showingClearConfirm = true
            } label: {
                Label("이번 주 장부 지우기", systemImage: "trash")
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        minutes <= 0 ? String(localized: "0분") : formatDuration(Double(minutes) / 60.0)
    }
}
