import SwiftUI

/// '이번 주 계획' 컬럼에 시각 순으로 섞어 표시하는 한 항목.
/// '요일별 하루' 타임라인의 보이는 조각을 그대로 따른다:
/// - 고정 루틴이 자정을 넘겨 두 조각이면 각 조각이 따로(occurrenceID로 구분) → 위·아래 두 번 표시.
/// - 유연 쿼터(끼니)는 다른 일정과 겹치지 않는 세션만 자기 시각 위치에 표시.
enum DayPlanItem: Identifiable {
    case fixedRoutine(Routine, occurrenceID: String, atHour: Double, hours: Double)
    case quotaSession(Routine, sessionIndex: Int, atHour: Double)
    case block(PlanBlock)

    var id: String {
        switch self {
        case .fixedRoutine(_, let oid, _, _): "fixed:\(oid)"
        case .quotaSession(let r, let idx, _): "quota:\(r.name):\(idx)"
        case .block(let b): "block:\(String(describing: b.persistentModelID))"
        }
    }
}

struct DayColumn: View {
    let day: DayOfWeek
    let date: Date
    var canPlan: Bool = true
    /// 시각 순으로 정렬된 통합 항목(고정 루틴·쿼터·블록).
    let items: [DayPlanItem]
    /// '이번 주 계획'엔 있으나 '요일별 하루 24시간' 타임라인엔 자리를 못 잡은 블록 id — 경고 심볼용.
    var unplacedBlockIDs: Set<String> = []
    let onAdd: () -> Void
    let onEdit: (PlanBlock) -> Void
    let onEditRoutine: (Routine) -> Void          // 클릭 → 루틴 편집·삭제 시트
    var onShowRoutineDetail: (Routine) -> Void = { _ in }  // 우클릭 → 상세(실행 전략·프리모템)
    let onDropBacklog: (String) -> Void

    @State private var isDropTargeted = false

    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 1) {
                Text(day.shortLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)
                Text(dayNumber)
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 30, height: 30)
                    .background {
                        if isToday {
                            Circle().fill(Color.accentColor)
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 2)

            // 고정 루틴·유연 쿼터·계획 블록을 시각 순으로 섞어, '요일별 하루' 타임라인과 같은 흐름으로 표시.
            ForEach(items) { item in
                switch item {
                case .fixedRoutine(let routine, _, let atHour, let hours):
                    // 자정을 넘겨 쪼개진 조각은 각자 자기 길이를 보여, 합이 루틴 전체 길이가 되도록.
                    RoutineChip(routine: routine,
                                subtitleOverride: "\(formatHour(atHour))  \(String(format: "%.1fh", hours))",
                                onShowDetail: { onShowRoutineDetail(routine) }) {
                        onEditRoutine(routine)
                    }
                case .quotaSession(let routine, _, let atHour):
                    RoutineChip(routine: routine, subtitleOverride: formatHour(atHour),
                                onShowDetail: { onShowRoutineDetail(routine) }) { onEditRoutine(routine) }
                case .block(let block):
                    BlockChip(block: block,
                              isUnplaced: unplacedBlockIDs.contains(String(describing: block.persistentModelID))) {
                        onEdit(block)
                    }
                }
            }

            Button(action: onAdd) {
                Image(systemName: canPlan ? "plus" : "lock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                Color.secondary.opacity(0.25),
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canPlan)
            .help(canPlan ? "\(day.longLabel)에 블록 추가" : "고정 루틴을 먼저 추가하세요")
        }
        .padding(8)
        .frame(minHeight: 180, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(isDropTargeted
                      ? Color.accentColor.opacity(0.08)
                      : Color(nsColor: .controlBackgroundColor))
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard canPlan, let token = items.first else { return false }
            onDropBacklog(token)
            return true
        } isTargeted: { isDropTargeted = canPlan && $0 }
    }
}

struct RoutineChip: View {
    let routine: Routine
    /// 컬럼에서 끼니 세션처럼 '이 occurrence의 시각'을 보여주고 싶을 때 부제를 대체.
    var subtitleOverride: String? = nil
    /// 우클릭 '상세 정보' — 실행 전략·프리모템 등(편집·삭제와 분리).
    var onShowDetail: () -> Void = {}
    let onTap: () -> Void

    @State private var hovering = false

    private var isQuota: Bool { routine.kind == .quota }

    // 쿼터(유연)는 점선 테두리 + 더 옅은 배경으로 '시간 유연'임을 드러낸다(타임라인 점선과 일관).
    private var subtitle: String {
        if let subtitleOverride { return subtitleOverride }
        if isQuota {
            var s = String(format: "주 %.1fh", routine.weeklyHours)
            if routine.sessionsPerDay > 0 { s += " · \(routine.sessionsPerDay)회" }
            return s
        }
        return "\(formatHour(routine.startHour))  \(String(format: "%.1fh", routine.durationHours))"
    }

    var body: some View {
        let color = routine.displayColor
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: routine.iconName)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .opacity(0.7)
                }

                Spacer()

                Image(systemName: isQuota ? "arrow.left.and.right" : "lock.fill")
                    .font(.system(size: 9))
                    .opacity(isQuota ? 0.5 : 0.35)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color.opacity(isQuota ? (hovering ? 0.12 : 0.07) : (hovering ? 0.18 : 0.12)),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(color.opacity(hovering ? 0.55 : 0.4),
                            style: isQuota ? StrokeStyle(lineWidth: 1, dash: [3, 2]) : StrokeStyle(lineWidth: 1))
            )
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button { onTap() } label: {
                Label(isQuota ? "수정·삭제" : "이 요일만 수정", systemImage: "pencil")
            }
            Button { onShowDetail() } label: { Label("상세 정보 · 실행 전략", systemImage: "info.circle") }
        }
        .help("\(routine.scheduleDescription)\n"
              + (isQuota ? "클릭: 수정·삭제 · 우클릭: 상세" : "클릭: 이 요일만 수정 · 우클릭: 상세"))
    }
}

struct BlockChip: View {
    let block: PlanBlock
    /// 하루가 꽉 차 '요일별 하루 24시간' 타임라인에 배치되지 못했을 때 경고 심볼을 붙인다.
    var isUnplaced: Bool = false
    let onTap: () -> Void

    @State private var hovering = false

    private var palette: (bg: Color, fg: Color, stroke: Color) {
        if block.concreteVerified {
            return (Color.accentColor.opacity(0.22), Color.accentColor, Color.accentColor.opacity(0.55))
        } else {
            return (Color.orange.opacity(0.22), Color.orange, Color.orange.opacity(0.6))
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let status = block.reviewStatus {
                        Image(systemName: status.systemImage)
                            .font(.system(size: 11))
                            .foregroundStyle(reviewTint(status))
                    }
                    Text(block.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if isUnplaced {
                        Spacer(minLength: 2)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .accessibilityLabel("타임라인 미배치 경고")
                    }
                }
                HStack(spacing: 4) {
                    Text(block.timeBand.shortLabel)
                    Text("·")
                    Text(String(format: "%.1fh", block.durationHours))
                }
                .font(.system(size: 11))
                .opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(palette.bg, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isUnplaced ? Color.orange : palette.stroke,
                            style: isUnplaced ? StrokeStyle(lineWidth: hovering ? 1.8 : 1.4, dash: [4, 2])
                                              : StrokeStyle(lineWidth: hovering ? 1.5 : 1))
            )
            .foregroundStyle(palette.fg)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        // 다른 요일로 끌어 옮기기 — 드롭 대상(DayColumn)에서 요일을 바꾼다.
        .draggable("block:" + String(describing: block.persistentModelID))
        .help(helpText)
    }

    /// 툴팁 — 타임라인 미배치면 경고 문구를 앞에 덧붙인다.
    private var helpText: String {
        var lines: [String] = []
        if isUnplaced {
            lines.append("⚠️ 하루 24시간이 꽉 차 '요일별 하루' 타임라인에 배치되지 못했어요.\n시간을 줄이거나 다른 요일로 옮겨 보세요.")
        }
        lines.append(block.successCriteria.isEmpty
                     ? "구체성 미검증 — 클릭해서 다듬기 · 드래그해서 다른 요일로 옮기기"
                     : block.successCriteria + "\n드래그해서 다른 요일로 옮길 수 있습니다.")
        return lines.joined(separator: "\n\n")
    }

    private func reviewTint(_ status: ReviewStatus) -> Color {
        switch status {
        case .done: .green
        case .partial: .yellow
        case .skipped: .red
        }
    }
}
