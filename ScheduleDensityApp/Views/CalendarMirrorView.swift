//
//  CalendarMirrorView.swift
//  ScheduleDensityApp
//
//  무지개에 비출 캘린더를 고르는 화면 (→ CalendarMirror).
//

import SwiftUI
import EventKit

struct CalendarMirrorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var mirror = CalendarMirror.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("고른 캘린더의 일정이 무지개에 늘 함께 보입니다. 캘린더에서 옮기거나 지우면 무지개도 따라갑니다.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("읽기만 합니다. 캘린더에는 아무것도 쓰지 않습니다.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                switch mirror.status {
                case .fullAccess:
                    calendarList
                case .notDetermined:
                    Section {
                        Button("캘린더 접근 허용") {
                            Task { await mirror.requestAccess() }
                        }
                        .font(.body)
                    }
                default:
                    // 한 번 거절하면 앱이 다시 물어도 창이 안 뜬다. 켜는 자리로 곧장 보낸다.
                    Section {
                        Text("캘린더 접근이 꺼져 있습니다. 설정 앱에서 이 앱의 캘린더를 '전체 접근'으로 바꿔 주세요.")
                            .font(.body)
                        Button("설정 앱 열기") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .font(.body)
                    }
                }
            }
            .navigationTitle("캘린더 연동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .onAppear { mirror.refreshStatus() }
            // 설정 앱에서 권한을 켜고 돌아오면 바로 목록이 서야 한다.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { mirror.refreshStatus() }
            }
        }
    }

    @ViewBuilder
    private var calendarList: some View {
        let groups = Dictionary(grouping: mirror.calendars(), by: { $0.source.title })
        ForEach(groups.keys.sorted(), id: \.self) { source in
            Section(source) {
                ForEach(groups[source] ?? [], id: \.calendarIdentifier) { calendar in
                    Toggle(isOn: Binding(
                        get: { mirror.isSelected(calendar) },
                        set: { mirror.setSelected(calendar, $0) }
                    )) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 12, height: 12)
                            Text(calendar.title)
                                .font(.body)
                        }
                    }
                }
            }
        }
    }
}
