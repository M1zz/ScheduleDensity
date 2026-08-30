//
//  TodoWidget.swift
//  TodoWidget
//
//  '욕망의 무지개' 할 일 위젯 — 홈 화면과 잠금 화면에서 이번 주 남은 할 일을 보여준다.
//  데이터는 앱이 App Group에 구워둔 스냅샷(TodoWidgetSnapshot)만 읽는다. 읽기 전용.
//

import WidgetKit
import SwiftUI

// MARK: - 타임라인

struct TodoEntry: TimelineEntry {
    let date: Date
    let snapshot: TodoWidgetSnapshot
}

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        // 위젯 갤러리에서는 빈 화면 대신 예시를 보여준다.
        let snapshot = context.isPreview ? .sample : TodoWidgetBridge.read()
        completion(TodoEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let entry = TodoEntry(date: Date(), snapshot: TodoWidgetBridge.read())
        // 내용이 바뀌면 앱이 reloadTimelines를 부른다. 여기서는 날짜가 넘어가면
        // '지난 주 잔여' 구분이 달라지므로 자정 직후 한 번만 다시 그리게 한다.
        let midnight = Calendar.current.nextDate(after: entry.date,
                                                 matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime)
            ?? entry.date.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - 위젯 정의

struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodoWidgetBridge.widgetKind, provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(TodoWidgetBridge.deepLink)
        }
        .configurationDisplayName("할 일")
        .description("아직 안 한 일을 홈 화면과 잠금 화면에서 바로 봅니다.")
        // .accessoryCircular은 원 안에 개수밖에 못 넣어서 뺐다 — 이 위젯은 목록이 본체다.
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryInline,
        ])
    }
}

@main
struct RainbowWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
        RainbowWidget()
    }
}

// MARK: - 패밀리별 라우팅

struct TodoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodoEntry

    private var snapshot: TodoWidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryInline:      InlineView(snapshot: snapshot)
        case .accessoryRectangular: RectangularView(snapshot: snapshot)
        case .systemSmall:          ListView(snapshot: snapshot, limit: 4, font: .system(size: 12))
        case .systemLarge:          ListView(snapshot: snapshot, limit: 10, font: .system(size: 14))
        default:                    ListView(snapshot: snapshot, limit: 5, font: .system(size: 14))
        }
    }
}

// MARK: - 잠금 화면

/// 잠금 화면 한 줄. 가장 급한 할 일 하나.
private struct InlineView: View {
    let snapshot: TodoWidgetSnapshot

    var body: some View {
        if let first = snapshot.items.first {
            // 단계로 쪼갠 할 일은 '지금 할 단계'가 곧 지금 해야 하는 일이다.
            // 조각이면 앞에 번개를 하나 — 한 줄짜리 자리라 이 이상은 못 넣는다.
            Text((first.isFragment ? "⚡︎ " : "")
                 + [first.title, first.stepLabel].compactMap { $0 }.joined(separator: " · "))
        } else {
            Text("할 일 없음")
        }
    }
}

/// 잠금 화면 가로형. 제목 3줄까지.
private struct RectangularView: View {
    let snapshot: TodoWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if snapshot.isEmpty {
                Text("남은 할 일이 없어요")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.items.prefix(3)) { item in
                    HStack(spacing: 3) {
                        // 5분이 났을 때 잠금 화면에서 바로 고르라고 다는 표식.
                        // 여기서 앱을 열어 판정을 보러 가야 하면 그 왕복에서 5분이 끝난다.
                        if item.isFragment {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                        }
                        Text(item.stepLabel ?? item.title)
                            .font(.system(size: 13, weight: item.isToday ? .semibold : .regular))
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetAccessibilityLabel(listAccessibilityLabel(snapshot, limit: 3))
    }
}

// MARK: - 홈 화면

/// 홈 위젯 — 헤더 없이 할 일만 위에서부터 나열한다.
private struct ListView: View {
    let snapshot: TodoWidgetSnapshot
    let limit: Int
    let font: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if snapshot.isEmpty {
                Text("남은 할 일이 없어요")
                    .font(font)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(snapshot.items.prefix(limit)) { item in
                    TodoLine(item: item, font: font)
                }
                Spacer(minLength: 0)
                // 잘렸다는 사실은 알려줘야 한다 — 없으면 이게 전부인 줄 안다.
                if snapshot.openCount > limit {
                    Text("+\(snapshot.openCount - limit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .widgetAccessibilityLabel(listAccessibilityLabel(snapshot, limit: limit))
    }
}

private struct TodoLine: View {
    let item: TodoWidgetSnapshot.Item
    let font: Font

    var body: some View {
        HStack(spacing: 6) {
            // 오늘 하기로 한 일은 점을 채워서, 나머지는 테두리만.
            // 조각인 줄만 점 대신 번개 — 5분이 났을 때 눈이 먼저 가야 하는 것이 그 줄이다.
            Group {
                if item.isFragment {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(dotColor)
                } else if item.isToday {
                    Circle().fill(dotColor)
                } else {
                    Circle().strokeBorder(dotColor, lineWidth: 1.5)
                }
            }
            .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(font)
                    .fontWeight(item.isToday ? .semibold : .regular)
                    .lineLimit(1)

                if let step = item.stepTitle {
                    HStack(spacing: 3) {
                        // 진행률(%)보다 '몇 번째'가 먼저다 — 지금 뭘 하면 되는지를
                        // 말해주는 건 퍼센트가 아니라 순서다.
                        if let index = item.stepIndex, let count = item.stepCount {
                            Text("\(index)/\(count)")
                                .monospacedDigit()
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.system(size: 6))
                        }
                        Text(step)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
            }

            if item.isCarryover {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
        }
    }

    private var dotColor: Color {
        item.colorHex.flatMap { Color(hex: $0) } ?? .secondary
    }
}

// MARK: - 공통

private extension TodoWidgetSnapshot.Item {
    /// "3/4 글 다듬기" — 지금 어디쯤인지까지 한 덩어리로.
    var stepLabel: String? {
        guard let stepTitle else { return nil }
        guard let index = stepIndex, let count = stepCount else { return stepTitle }
        return "\(index)/\(count) \(stepTitle)"
    }
}

// MARK: - 접근성

private func listAccessibilityLabel(_ snapshot: TodoWidgetSnapshot, limit: Int) -> String {
    guard !snapshot.isEmpty else { return "남은 할 일 없음" }
    let titles = snapshot.items.prefix(limit).map { item in
        var text = item.title
        if let step = item.stepTitle {
            if let index = item.stepIndex, let count = item.stepCount {
                text += ", \(count)단계 중 \(index)번째, 지금 \(step)"
            } else {
                text += ", 지금 \(step)"
            }
        }
        if item.isFragment { text += ", 5분에 집을 수 있음" }
        return item.isToday ? "\(text), 오늘" : text
    }
    return "할 일. " + titles.joined(separator: ", ")
}

private extension View {
    /// VoiceOver가 위젯 내용을 한 문장으로 읽게 묶는다.
    func widgetAccessibilityLabel(_ label: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
    }
}
