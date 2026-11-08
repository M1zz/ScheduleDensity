//
//  PaywallShowcase.swift
//  ScheduleDensityApp
//
//  페이월에서 옆으로 넘겨 보는 기능 그림 (LeeoKit `LeeoShowcase`). 클립키보드 페이월과 같은 방식이다.
//  스크린샷이 아니라 SwiftUI 로 줄여 그린 그림이라 언어 · 다크 모드를 따라가고 앱 용량이 늘지 않는다.
//
//  ⚠️ 그림 속에는 글자를 넣지 않는다(숫자 · 기호만). 문장은 그림 아래 기능 이름과 한 줄 설명이 맡는다.
//     이름과 설명은 `ProFeature.title` · `note` 그대로라 설정 · 잠금 배지와 같은 말을 한다.
//

import SwiftUI
import LeeoKit

extension ProTier {
    /// 이 칸을 고르면 넘겨 보는 그림. 들어온 기능(`highlight`)이 첫 장.
    func showcases(highlight: ProFeature?) -> [LeeoShowcase] {
        var features = ProFeature.opened(by: self)
        if let highlight, let index = features.firstIndex(of: highlight) {
            features.insert(features.remove(at: index), at: 0)
        }
        var pages = features.map { feature in
            LeeoShowcase(id: feature.rawValue, title: feature.title, detail: feature.note) { feature.art }
        }
        if self == .pro {
            pages.append(LeeoShowcase(id: "plusAndMac", title: String(localized: "Plus 전부"),
                                      detail: String(localized: "맥 앱도 Pro로 함께 열립니다.")) { PlusAndMacArt() })
        }
        return pages
    }
}

extension ProFeature {
    @ViewBuilder fileprivate var art: some View {
        switch self {
        case .widget:         WidgetArt()
        case .calendarImport: CalendarImportArt()
        case .scheduleShare:  ShareArt()
        case .statistics:     StatisticsArt()
        case .ledger:         LedgerArt()
        }
    }
}

// MARK: - 그림 조각

/// 무지개 일곱 색. 앱의 일정 색과 같다.
private let spectrum: [Color] = Rainbow.spectrum.map { Color(hex: $0.hex) ?? .accentColor }

/// 하루치 무지개 띠 — 겹친 일정이 줄마다 색 막대로.
private struct ArtLanes: View {
    var rows: [(start: CGFloat, length: CGFloat, color: Int)]
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 5) {
                ForEach(rows.indices, id: \.self) { i in
                    let row = rows[i]
                    Capsule()
                        .fill(spectrum[row.color % spectrum.count])
                        .frame(width: proxy.size.width * row.length, height: height)
                        .offset(x: proxy.size.width * row.start)
                }
            }
        }
        .frame(height: CGFloat(rows.count) * (height + 5))
    }
}

private struct ArtCard<Content: View>: View {
    var width: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(width: width)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

private let sampleLanes: [(start: CGFloat, length: CGFloat, color: Int)] = [
    (0.0, 0.55, 0), (0.2, 0.5, 2), (0.45, 0.4, 4), (0.1, 0.35, 5),
]

// MARK: - Plus

/// 회수 장부 전체 기간: 주마다 되찾은 시간이 쌓이고, 위로 끝없이 거슬러 올라간다.
private struct LedgerArt: View {
    private let weeks: [CGFloat] = [0.45, 0.7, 0.35, 0.85, 0.6]

    var body: some View {
        ArtCard(width: 240) {
            VStack(spacing: 8) {
                Image(systemName: "chevron.compact.up")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(weeks.indices, id: \.self) { i in
                    HStack(spacing: 10) {
                        Image(systemName: "book.closed.fill")
                            .font(.caption)
                            .foregroundStyle(spectrum[(i * 2) % spectrum.count])
                        GeometryReader { proxy in
                            Capsule()
                                .fill(spectrum[(i * 2) % spectrum.count].opacity(0.85))
                                .frame(width: proxy.size.width * weeks[i])
                        }
                        .frame(height: 9)
                    }
                    .opacity(0.45 + Double(i) * 0.13)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "infinity")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: Circle())
                .offset(x: 14, y: -14)
        }
    }
}

/// 일정 통계: 요일별 막대가 무지개 색으로.
private struct StatisticsArt: View {
    private let bars: [CGFloat] = [0.4, 0.75, 0.55, 0.95, 0.65, 0.3, 0.5]

    var body: some View {
        ArtCard(width: 250) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(bars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(spectrum[i % spectrum.count].gradient)
                        .frame(width: 20, height: 130 * bars[i])
                }
            }
            .frame(height: 140, alignment: .bottom)
        }
    }
}

// MARK: - Pro

/// 위젯: 홈 화면 아이콘 사이에 오늘의 무지개 위젯.
private struct WidgetArt: View {
    var body: some View {
        VStack(spacing: 14) {
            ArtCard(width: 230) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Circle().fill(spectrum[0]).frame(width: 8, height: 8)
                        Capsule().fill(Color.primary.opacity(0.7)).frame(width: 80, height: 7)
                        Spacer(minLength: 0)
                        Image(systemName: "rainbow").symbolRenderingMode(.multicolor)
                    }
                    ArtLanes(rows: sampleLanes, height: 9)
                }
            }
            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(spectrum[(i * 2 + 1) % spectrum.count].opacity(0.35))
                        .frame(width: 42, height: 42)
                }
            }
        }
    }
}

/// 캘린더에서 가져오기: 캘린더의 일정이 무지개 줄로 들어온다.
private struct CalendarImportArt: View {
    var body: some View {
        HStack(spacing: 16) {
            ArtCard {
                Image(systemName: "calendar")
                    .font(.system(size: 52))
                    .foregroundStyle(.red)
            }
            Image(systemName: "arrow.right")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Color.accentColor)
            ArtCard(width: 130) {
                ArtLanes(rows: sampleLanes, height: 10)
            }
        }
    }
}

/// 일정 공유: 내 무지개를 다른 사람이 읽기만 한다.
private struct ShareArt: View {
    var body: some View {
        HStack(spacing: 18) {
            ArtCard(width: 140) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    ArtLanes(rows: sampleLanes, height: 9)
                }
            }
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { i in
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Image(systemName: "eye.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(spectrum[i == 0 ? 3 : 4], in: Circle())
                    }
                }
            }
        }
    }
}

/// Pro 의 나머지: Plus 에서 열리는 것과 맥 앱까지.
private struct PlusAndMacArt: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ForEach([ProFeature.ledger, .statistics], id: \.self) { feature in
                    Image(systemName: feature.systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 60, height: 60)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                }
            }
            HStack(alignment: .bottom, spacing: 16) {
                Image(systemName: "iphone").font(.system(size: 46))
                Image(systemName: "laptopcomputer").font(.system(size: 64))
            }
            .foregroundStyle(Color.accentColor)
        }
    }
}
