//
//  TimerWidget.swift
//  TodoWidget
//
//  홈·잠금 화면의 타이머 — 앱의 탭 위 줄과 같은 것을 말한다.
//  직접 세는 타이머가 있으면 그것을, 없으면 일정에 적힌 지금 것을 보인다.
//
//  **여기서도 시간을 세지 않는다.** 숫자는 `Text(_:style: .timer)`가, 막대는
//  `ProgressView(timerInterval:)`이 저 혼자 흐른다. 타임라인은 **바뀌는 순간**(일정의 경계,
//  타이머가 0을 지나는 때)에만 한 장씩 둔다. 데이터는 앱이 구워 둔 스냅샷만 읽는다 (→ TimerWidgetSnapshot.swift).
//

import WidgetKit
import SwiftUI

// MARK: - 타임라인

struct TimerWidgetEntry: TimelineEntry {
    enum Face {
        /// 직접 세는 중.
        case timer(TaskTimerAttributes.ContentState)
        /// 세는 것은 없고 일정에 적힌 지금 것이 있다.
        case slot(TimerWidgetSnapshot.Slot)
        /// 아무것도 없다. 다음 것이 있으면 그것을 말한다.
        case idle(next: TimerWidgetSnapshot.Slot?)
    }

    var isLocked: Bool = false
    let date: Date
    let face: Face
}

struct TimerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerWidgetEntry {
        TimerWidgetEntry(date: Date(), face: .timer(TimerWidgetSnapshot.sample.timer!))
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let now = Date()
        completion(Self.entry(at: now, from: TimerWidgetBridge.read(),
                              locked: !ProEntitlement.isUnlocked))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerWidgetEntry>) -> Void) {
        let snap = TimerWidgetBridge.read()
        let locked = !ProEntitlement.isUnlocked
        let now = Date()

        // 얼굴이 바뀌는 순간들. 그 사이는 숫자와 막대가 알아서 흐른다.
        var moments: [Date] = [now]
        // 타이머의 데드라인에서 일정 기준으로 넘어가고, 그 뒤로는 일정의 경계마다 한 장.
        if let timer = snap.timer, timer.isRunning, timer.endDate > now { moments.append(timer.endDate) }
        let edges = snap.slots.flatMap { [$0.start, $0.end] }.filter { $0 > now }
        moments += Set(edges).sorted().prefix(60)
        moments = Array(Set(moments)).sorted()
        let entries = moments.map { Self.entry(at: $0, from: snap, locked: locked) }
        // 타이머가 바뀌거나 일정이 바뀌면 앱이 다시 부른다. 그 밖에는 마지막 장 뒤에 한 번 더 읽는다.
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func entry(at date: Date, from snap: TimerWidgetSnapshot, locked: Bool) -> TimerWidgetEntry {
        let face: TimerWidgetEntry.Face
        // 데드라인이 지난 타이머는 끝난 것이다 — 앱이 아직 걷지 않았어도 일정 기준으로 돌아간다.
        if let timer = snap.timer, !(timer.isRunning && timer.endDate <= date) {
            face = .timer(timer)
        } else if let slot = snap.currentSlot(at: date) {
            face = .slot(slot)
        } else {
            face = .idle(next: snap.slots.filter { $0.start > date }.min { $0.start < $1.start })
        }
        return TimerWidgetEntry(isLocked: locked, date: date, face: face)
    }
}

// MARK: - 위젯 정의

struct TimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TimerWidgetBridge.widgetKind, provider: TimerWidgetProvider()) { entry in
            TimerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.isLocked ? ProEntitlement.paywallDeepLink : TimerWidgetBridge.deepLink)
        }
        .configurationDisplayName("타이머")
        .description("지금 하는 일정에 얼마 남았는지 봅니다.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - 한 얼굴로 모으기

/// 세는 타이머든 일정이든, 그리는 쪽은 이 모양 하나만 안다.
/// 둘 다 **끝 시각(데드라인)까지** 센다. 멈춤도, 넘긴 시간도 없다 — 끝은 일정이 정한다.
private struct TimerFace {
    var title: String
    var iconName: String
    var tint: Color
    /// 숫자가 가리키는 끝 시각.
    var end: Date
    /// 막대가 흐르는 구간.
    var interval: ClosedRange<Date>
    var caption: String

    init?(_ entry: TimerWidgetEntry) {
        switch entry.face {
        case .timer(let s):
            // 데드라인이 지난 것은 여기까지 오지 않는다 (→ TimerWidgetProvider.entry).
            title = s.title
            iconName = s.iconName
            tint = s.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
            end = s.endDate
            interval = s.startDate...max(s.endDate, s.startDate.addingTimeInterval(1))
            caption = String(localized: "\(formatWidgetClock(s.endDate))에 끝남")
        case .slot(let slot):
            title = slot.title
            iconName = slot.iconName
            tint = slot.colorHex.flatMap { Color(hex: $0) } ?? .accentColor
            end = slot.end
            interval = slot.start...slot.end
            caption = String(localized: "일정 기준")
        case .idle:
            return nil
        }
    }

    /// 남은 시간 숫자. `Text`로 돌려준다 — 한 줄 위젯에서 제목과 한 글자로 붙여야 하기 때문이다.
    func number(at date: Date) -> Text {
        Text(end, style: .timer)
    }

    /// 남은 만큼 줄어드는 막대 (→ 앱의 고리와 같은 방향).
    func bar() -> some View {
        ProgressView(timerInterval: interval, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
    }
}

/// "14:35". 앱의 `formatClockTime`과 같은 모양 (위젯은 앱 타깃의 그 함수를 못 본다).
private func formatWidgetClock(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = .autoupdatingCurrent
    f.dateFormat = DateFormatter.dateFormat(fromTemplate: "jm", options: 0, locale: .autoupdatingCurrent)
    return f.string(from: date)
}

// MARK: - 패밀리별 라우팅

struct TimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimerWidgetEntry

    var body: some View {
        if entry.isLocked {
            switch family {
            case .accessoryInline:   Text("🔒 무지개 Pro")
            case .accessoryCircular: Image(systemName: "lock.fill")
                                         .accessibilityLabel("타이머 위젯이 잠겨 있습니다")
            default:                 WidgetLockedView(name: String(localized: "타이머"))
            }
        } else if let face = TimerFace(entry) {
            switch family {
            case .accessoryInline:      inline(face)
            case .accessoryCircular:    circular(face)
            case .accessoryRectangular: rectangular(face)
            case .systemMedium:         medium(face)
            default:                    small(face)
            }
        } else {
            idle
        }
    }

    // MARK: 잠금 화면

    private func inline(_ face: TimerFace) -> some View {
        // 한 줄 자리는 글자 하나로 붙여야 시스템이 안 자른다.
        Label {
            Text(verbatim: face.title + " ") + face.number(at: entry.date)
        } icon: {
            Image(systemName: face.iconName)
        }
    }

    private func circular(_ face: TimerFace) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            face.bar()
                .progressViewStyle(.circular)
            .widgetAccentable()
            Image(systemName: face.iconName)
                .font(.title3.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(face.title)
    }

    private func rectangular(_ face: TimerFace) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(face.title, systemImage: face.iconName)
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            face.number(at: entry.date)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
            face.bar()
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 홈 화면

    private func small(_ face: TimerFace) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(face.title, systemImage: face.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(face.tint)
                .lineLimit(2)
            Spacer(minLength: 0)
            face.number(at: entry.date)
                .font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(face.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            face.bar()
                .tint(face.tint)
            Text(face.caption)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ face: TimerFace) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(face.tint.opacity(0.16))
                Image(systemName: face.iconName)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(face.tint)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(face.title)
                    .font(.headline)
                    .lineLimit(1)
                face.number(at: entry.date)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(face.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                face.bar()
                    .tint(face.tint)
                Text(face.caption)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: 비어 있을 때

    private var nextSlot: TimerWidgetSnapshot.Slot? {
        if case .idle(let next) = entry.face { return next }
        return nil
    }

    @ViewBuilder
    private var idle: some View {
        switch family {
        case .accessoryInline:
            if let next = nextSlot {
                Text("다음 \(next.title) \(formatWidgetClock(next.start))")
            } else {
                Text("지금 일정 없음")
            }
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "timer")
                    .font(.title3)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Label("지금 일정 없음", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if let next = nextSlot {
                    Text("다음 \(next.title)")
                        .font(.body)
                        .lineLimit(1)
                    Text(formatWidgetClock(next.start))
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
