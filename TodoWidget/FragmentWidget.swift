//
//  FragmentWidget.swift
//
//  **번개만 모아 보여주는 위젯** — 지금 5분에 집을 수 있는 단계들.
//
//  '할 일' 위젯과 목록의 단위가 다르다. 그쪽은 최상위 할 일 하나에 한 줄이고 그 안의
//  '지금 할 단계'를 접어 넣는데, 5분이 났을 때 필요한 건 '무슨 일이 남았나'가 아니라
//  **'지금 집을 게 뭐가 있나'** 다. 그래서 여기서는 단계 하나가 한 줄이고,
//  한 일 안에서 조각이 여럿이면 여럿 다 선다(순서 없는 묶음).
//
//  무엇이 지금 손댈 수 있는지는 앱이 정해서 스냅샷에 굽는다
//  (→ `TodoTree.availableSteps`, `TodoWidgetSync.makeFragments`).
//  위젯은 판정을 안 한다 — 사전(TodoSplitAdvisor)을 들고 있지 않다.
//
//  잠금 화면이 이 위젯의 본자리다. 5분이 나는 순간은 대개 화면을 켜는 순간이고,
//  거기서 앱을 열어 목록을 훑어야 하면 그 왕복에서 5분이 끝난다.
//

import WidgetKit
import SwiftUI

// MARK: - 타임라인

struct FragmentEntry: TimelineEntry {
    /// 값을 안 낸 상태인가. 갤러리 미리보기에서는 언제나 false다.
    var isLocked: Bool = false
    let date: Date
    let snapshot: TodoWidgetSnapshot
}

struct FragmentProvider: TimelineProvider {
    func placeholder(in context: Context) -> FragmentEntry {
        FragmentEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (FragmentEntry) -> Void) {
        // 위젯 갤러리에서는 빈 목록 대신 예시를 보여준다.
        let snapshot = context.isPreview ? .sample : TodoWidgetBridge.read()
        completion(FragmentEntry(isLocked: !context.isPreview && !ProEntitlement.isUnlocked,
                                 date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FragmentEntry>) -> Void) {
        let entry = FragmentEntry(isLocked: !ProEntitlement.isUnlocked,
                                  date: Date(), snapshot: TodoWidgetBridge.read())
        // 내용이 바뀌면 앱이 reloadTimelines를 부른다. 여기서는 날짜가 넘어가면
        // '이번 주'가 달라지므로 자정 직후 한 번만 다시 그리게 한다.
        let midnight = Calendar.current.nextDate(after: entry.date,
                                                 matching: DateComponents(hour: 0, minute: 1),
                                                 matchingPolicy: .nextTime)
            ?? entry.date.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - 위젯 정의

struct FragmentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodoWidgetBridge.fragmentWidgetKind, provider: FragmentProvider()) { entry in
            FragmentWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(TodoWidgetBridge.fragmentDeepLink)
        }
        .configurationDisplayName("번개")
        .description("지금 5분에 집을 수 있는 단계만 모아 봅니다.")
        // 원형도 넣는다. '할 일' 위젯에서는 원 안에 개수밖에 못 넣어서 뺐지만,
        // 여기서는 **개수가 곧 전언**이다 — 지금 집을 게 몇 개 있느냐.
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryInline, .accessoryCircular,
        ])
    }
}

// MARK: - 패밀리별 라우팅

struct FragmentWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FragmentEntry

    private var fragments: [TodoWidgetSnapshot.Fragment] { entry.snapshot.fragments }

    var body: some View {
        if entry.isLocked {
            // 잠금 화면의 한 줄·동그라미 자리에는 세로로 쌓은 안내가 안 들어간다.
            if family == .accessoryInline {
                Text("🔒 번개 — 모두 열기")
            } else if family == .accessoryCircular {
                Image(systemName: "lock.fill")
                    .accessibilityLabel("번개 위젯이 잠겨 있습니다")
            } else {
                WidgetLockedView(name: "번개")
            }
        } else {
            unlocked
        }
    }

    @ViewBuilder
    private var unlocked: some View {
        switch family {
        case .accessoryInline:      FragmentInlineView(snapshot: entry.snapshot)
        case .accessoryCircular:    FragmentCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular: FragmentRectangularView(snapshot: entry.snapshot)
        case .systemSmall:          FragmentListView(snapshot: entry.snapshot, limit: 3, compact: true)
        case .systemLarge:          FragmentListView(snapshot: entry.snapshot, limit: 8, compact: false)
        default:                    FragmentListView(snapshot: entry.snapshot, limit: 4, compact: false)
        }
    }
}

// MARK: - 잠금 화면

/// 한 줄짜리 자리. 개수와 맨 앞 하나.
private struct FragmentInlineView: View {
    let snapshot: TodoWidgetSnapshot

    var body: some View {
        if let first = snapshot.fragments.first {
            // 개수가 앞에 온다. "지금 집을 게 몇 개 있나"가 이 위젯이 하는 말이고,
            // 이름 하나만 있으면 그게 전부인지 더 있는지를 알 수 없다.
            Text("⚡︎ \(snapshot.fragmentCount) · \(first.title)")
        } else {
            Text("⚡︎ 집을 조각 없음")
        }
    }
}

/// 동그라미 자리. 개수만 — 여기서는 그게 전언이다.
private struct FragmentCircularView: View {
    let snapshot: TodoWidgetSnapshot

    var body: some View {
        VStack(spacing: -1) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(snapshot.fragmentCount)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .widgetAccessibility(snapshot.fragmentCount > 0
            ? "지금 5분에 집을 수 있는 단계 \(snapshot.fragmentCount)개"
            : "지금 집을 조각 없음")
    }
}

/// 가로형 자리. 개수 한 줄 + 이름 둘.
private struct FragmentRectangularView: View {
    let snapshot: TodoWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if snapshot.hasNoFragments {
                Text("지금 집을 조각이 없어요")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("5분이면 \(snapshot.fragmentCount)개")
                        .font(.system(size: 12, weight: .semibold))
                }
                ForEach(snapshot.fragments.prefix(2)) { fragment in
                    Text(fragment.title)
                        .font(.system(size: 13, weight: fragment.isMarked ? .semibold : .regular))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetAccessibility(fragmentAccessibilityLabel(snapshot, limit: 2))
    }
}

// MARK: - 홈 화면

private struct FragmentListView: View {
    let snapshot: TodoWidgetSnapshot
    let limit: Int
    /// 작은 자리에서는 딸린 정보(무슨 일의 일부인지)를 접는다.
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Self.boltGreen)
                Text(snapshot.hasNoFragments ? "번개" : "5분이면 \(snapshot.fragmentCount)개")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            if snapshot.hasNoFragments {
                // 빈 화면으로 두지 않는다. 왜 비었는지와 어떻게 채우는지를 한 줄로 적는다 —
                // "없음"만 있으면 고장인지 진짜 없는 건지 구분이 안 된다.
                Text("지금 집을 조각이 없어요")
                    .font(.system(size: compact ? 12 : 13))
                    .foregroundStyle(.secondary)
                if !compact {
                    Text("단계를 5분에 닫히는 크기로 잘라 두면 여기 섭니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(snapshot.fragments.prefix(limit)) { fragment in
                    FragmentLine(fragment: fragment, compact: compact)
                }
                Spacer(minLength: 0)
                // 잘렸다는 사실은 알려줘야 한다 — 없으면 이게 전부인 줄 안다.
                if snapshot.fragmentCount > limit {
                    Text("+\(snapshot.fragmentCount - limit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .widgetAccessibility(fragmentAccessibilityLabel(snapshot, limit: limit))
    }

    /// 앱 목록의 '바로 하면 되는 일' 칸과 같은 초록 (→ TodoView.nowGreen).
    /// 두 화면에서 같은 것을 가리키므로 색도 같아야 한다.
    static let boltGreen = Color(hue: 0.26, saturation: 0.72, brightness: 0.66)
}

private struct FragmentLine: View {
    let fragment: TodoWidgetSnapshot.Fragment
    let compact: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // 사람이 표시한 것은 채운 번개, 앱이 짐작한 것은 빈 번개.
            // 이 자리의 값어치는 "여기 있는 건 진짜 바로 된다"는 믿음에서 나오므로,
            // 짐작으로 올라온 줄과 눈으로 구분돼야 한다.
            Image(systemName: fragment.isMarked ? "bolt.fill" : "bolt")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(fragment.isMarked ? FragmentListView.boltGreen : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(fragment.title)
                    .font(.system(size: compact ? 12 : 13,
                                  weight: fragment.isMarked ? .semibold : .regular))
                    .lineLimit(1)
                // 단계 이름만 서 있으면 무슨 일의 일부인지 알 수 없다 (앱 목록과 같은 이유).
                if !compact, let parent = fragment.parentTitle {
                    Text(parent)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // 0분은 '시간을 안 잡은 줄'이라 적을 게 없다.
            if fragment.minutes > 0 {
                Text("\(fragment.minutes)분")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Circle()
                .fill(fragment.colorHex.flatMap { Color(hex: $0) } ?? .secondary)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - 접근성

private func fragmentAccessibilityLabel(_ snapshot: TodoWidgetSnapshot, limit: Int) -> String {
    guard !snapshot.hasNoFragments else { return "지금 집을 조각 없음" }
    let titles = snapshot.fragments.prefix(limit).map { fragment -> String in
        var text = fragment.title
        if let parent = fragment.parentTitle { text += ", \(parent)의 단계" }
        if fragment.minutes > 0 { text += ", \(fragment.minutes)분" }
        if fragment.isMarked { text += ", 직접 표시함" }
        return text
    }
    return "5분에 집을 수 있는 단계 \(snapshot.fragmentCount)개. " + titles.joined(separator: ", ")
}

private extension View {
    /// VoiceOver가 위젯 내용을 한 문장으로 읽게 묶는다.
    func widgetAccessibility(_ label: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
    }
}
