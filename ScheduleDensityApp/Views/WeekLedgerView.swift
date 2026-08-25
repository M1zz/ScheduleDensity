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
    /// 이번 주에 남은 단계들을 착수 조건별로 갈라 센 것 (→ TodoTree.tally).
    let work: [LabelTally]

    @State private var entry = WeekLedgerEntry()
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            List {
                workSection
                reclaimSection
                recoverySection
                if !entry.isEmpty { clearSection }
            }
            .navigationTitle("이번 주 결산")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear { entry = WeekLedger.entry(for: weekStart) }
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
                ForEach(work) { tally in
                    HStack(spacing: 12) {
                        TodoLabelChip(label: tally.label, hours: tally.hours, count: tally.count)
                        Spacer(minLength: 0)
                        Text(tally.label.whenToDo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("남은 몫")
        } footer: {
            // 이 화면에서 가장 중요한 문장이다. 여기에만 적어 두고 목록에서는 반복하지 않는다.
            Text("일부러 합계를 내지 않습니다. ‘바로 15분’ 넷은 1시간이 아니라 다른 단위입니다 — 조각 시간은 총량으로 환산되지 않고 전환 비용에 먹힙니다.\n하루로도 결산하지 않습니다. 하루 5분은 잡음이고, 신호는 주 단위에서만 보입니다.")
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
        minutes <= 0 ? "0분" : formatDuration(Double(minutes) / 60.0)
    }
}
