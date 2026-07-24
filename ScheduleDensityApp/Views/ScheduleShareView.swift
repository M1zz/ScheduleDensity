//
//  ScheduleShareView.swift
//  ScheduleDensityApp
//
//  일정 공유 화면 — 내 일정을 특정 사람에게 (읽기 전용) 공유하고,
//  나에게 공유된 다른 사람의 일정을 읽기 전용으로 본다.
//  ※ 애플의 iCloud '가족 공유' 그룹 기능과는 무관하다. CloudKit 링크 공유 방식.
//

import SwiftUI
import SwiftData

struct ScheduleShareView: View {
    @Query(sort: \Event.startDate) private var events: [Event]
    @State private var store = ScheduleShareStore.shared
    @State private var showingStartNotice = false

    var body: some View {
        NavigationStack {
            List {
                if !store.iCloudAvailable {
                    Section {
                        Label("iCloud에 로그인하면 일정을 공유할 수 있습니다.",
                              systemImage: "icloud.slash")
                            .foregroundStyle(.secondary)
                    }
                }

                mySharingSection
                sharedWithMeSection

                if let message = store.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("일정 공유")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isBusy)
                }
            }
            .task { await store.refresh() }
            .refreshable { await store.refresh() }
            .overlay {
                if store.isBusy && store.sharedWithMe.isEmpty {
                    ProgressView().controlSize(.large)
                }
            }
            .alert("일정 공유 시작", isPresented: $showingStartNotice) {
                Button("취소", role: .cancel) {}
                Button("공유하기") {
                    Task {
                        await store.startSharing()
                        await store.publish(events: events)
                    }
                }
            } message: {
                Text("초대 링크를 받은 사람은 내 일정을 읽기 전용으로 볼 수 있어요.\n링크는 보여주고 싶은 사람에게만 보내세요.")
            }
        }
    }

    // MARK: - 내 일정 공유하기

    @ViewBuilder
    private var mySharingSection: some View {
        Section {
            if store.isSharing {
                HStack {
                    Label("공유 중", systemImage: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("일정 \(store.publishedCount)개")
                        .foregroundStyle(.secondary)
                }

                if let url = store.shareURL {
                    ShareLink(item: url) {
                        Label("초대 링크 보내기", systemImage: "square.and.arrow.up")
                    }
                }

                Button {
                    Task { await store.publish(events: events) }
                } label: {
                    Label("지금 최신 일정으로 업데이트", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isBusy)

                Button(role: .destructive) {
                    Task { await store.stopSharing() }
                } label: {
                    Label("공유 중지", systemImage: "person.crop.circle.badge.xmark")
                }
            } else {
                Button {
                    showingStartNotice = true
                } label: {
                    Label("내 일정 공유 시작", systemImage: "person.crop.circle.badge.plus")
                }
                .disabled(!store.iCloudAvailable || store.isBusy)
            }
        } header: {
            Text("내 일정 공유하기")
        } footer: {
            Text("받는 사람은 읽기만 할 수 있고, 내 일정을 고칠 수 없어요. 일정을 바꾼 뒤엔 ‘업데이트’를 눌러 반영하세요.")
        }
    }

    // MARK: - 공유받은 일정

    @ViewBuilder
    private var sharedWithMeSection: some View {
        Section("공유받은 일정") {
            if store.sharedWithMe.isEmpty {
                Text(store.iCloudAvailable
                     ? "아직 공유받은 일정이 없어요.\n상대가 보낸 초대 링크를 누르면 여기에 나타납니다."
                     : "iCloud 로그인이 필요합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.sharedWithMe) { group in
                    DisclosureGroup {
                        if group.events.isEmpty {
                            Text("표시할 일정이 없어요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(group.events) { event in
                                SharedEventRow(event: event)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                            Text(group.personName)
                            Spacer()
                            Text("\(group.events.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await store.leave(group) }
                        } label: {
                            Label("나가기", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 공유받은 일정 한 줄(읽기 전용)

private struct SharedEventRow: View {
    let event: SharedEvent

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: event.color) ?? .blue)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title.isEmpty ? "(제목 없음)" : event.title)
                    .font(.body)
                Text(dateRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f시간/일", event.hoursPerDay))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var dateRangeText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        let start = f.string(from: event.startDate)
        if event.isInfinite {
            return "\(start)부터 계속"
        }
        let end = f.string(from: event.endDate)
        return start == end ? start : "\(start) ~ \(end)"
    }
}
