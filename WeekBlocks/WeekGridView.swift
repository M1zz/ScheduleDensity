import SwiftUI

struct DayColumn: View {
    let day: DayOfWeek
    let date: Date
    var canPlan: Bool = true
    let routines: [Routine]
    let blocks: [PlanBlock]
    let onAdd: () -> Void
    let onEdit: (PlanBlock) -> Void
    let onEditRoutine: (Routine) -> Void
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

            ForEach(routines) { routine in
                RoutineChip(routine: routine) { onEditRoutine(routine) }
            }

            if !routines.isEmpty && !blocks.isEmpty {
                Divider().opacity(0.4)
            }

            ForEach(blocks) { block in
                BlockChip(block: block) { onEdit(block) }
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
    let onTap: () -> Void

    @State private var hovering = false

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
                    Text("\(formatHour(routine.startHour))  \(String(format: "%.1fh", routine.durationHours))")
                        .font(.system(size: 10))
                        .opacity(0.7)
                }

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .opacity(0.35)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color.opacity(hovering ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(color.opacity(hovering ? 0.5 : 0.3), lineWidth: 1)
            )
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(routine.scheduleDescription)")
    }
}

struct BlockChip: View {
    let block: PlanBlock
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
                    .stroke(palette.stroke, lineWidth: hovering ? 1.5 : 1)
            )
            .foregroundStyle(palette.fg)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(block.successCriteria.isEmpty ? "구체성 미검증 — 클릭해서 다듬기" : block.successCriteria)
    }

    private func reviewTint(_ status: ReviewStatus) -> Color {
        switch status {
        case .done: .green
        case .partial: .yellow
        case .skipped: .red
        }
    }
}
