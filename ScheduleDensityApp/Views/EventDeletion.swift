//
//  EventDeletion.swift
//
//  **일정을 지우기 전에, 무슨 일이 벌어지는지 먼저 말한다.**
//
//  지우는 자리가 다섯 군데다 — 일정 관리의 스와이프, 하루 화면의 스와이프,
//  네모를 길게 눌러 뜨는 알림, 편집 화면의 삭제 버튼, 그리고 전체 삭제.
//  문구를 화면마다 따로 쓰면 같은 삭제가 다른 삭제처럼 읽히고, 그중 한 군데만
//  iCloud 이야기를 빠뜨리면 **그 화면에서 지운 것만 나중에 되살아난다.**
//  그래서 묻는 말도, 지우는 순서도 여기 한 곳에서 낸다.
//
//  ⚠️ 순서는 **iCloud 먼저, 이 기기는 그 다음이다.** 뒤집으면 저쪽 삭제가 실패했을 때
//     무엇을 지우려 했는지조차 남지 않는다 (→ ScheduleViewModel.deleteEvent).
//

import SwiftUI

/// 지금 이 일정을 지우면 무슨 일이 벌어지는가.
enum EventDeletion {

    /// 이 기기와 iCloud 양쪽에서 지운다. 보통은 이것이다.
    case bothSides

    /// iCloud 에 올라간 적이 없다. 지울 것은 이 기기 것뿐이다.
    case localOnly

    /// 동기화를 꺼 두셨다. iCloud 에 올라가 있는 것은 그대로 남는다.
    case syncOff

    /// 지금 iCloud 에 닿지 못한다. **여기서 지우면 저쪽 것이 남았다가 되살아난다.**
    case unreachable

    /// 지금 지워도 되는가. 되살아날 것이 뻔한 경우에만 막는다 —
    /// 지워도 다시 나타나는 것은 삭제가 아니라 고장으로 읽힌다.
    var isAllowed: Bool {
        if case .unreachable = self { return false }
        return true
    }

    var message: String {
        switch self {
        case .bothSides:
            return "이 기기와 iCloud 양쪽에서 지웁니다. 되돌릴 수 없습니다."
        case .localOnly:
            return "이 기기에서 지웁니다. iCloud 에는 올라간 적이 없습니다. 되돌릴 수 없습니다."
        case .syncOff:
            return "이 기기에서 지웁니다. 되돌릴 수 없습니다.\n\n동기화를 꺼 두셔서 iCloud 에 올라가 있는 것은 그대로 남습니다. 나중에 동기화를 켜면 다시 내려올 수 있습니다."
        case .unreachable:
            return "지금 iCloud 에 닿지 못해 지울 수 없습니다.\n\n이 기기에서만 지우면 iCloud 에 남은 것이 나중에 다시 내려옵니다. 연결을 확인하고 다시 시도해 주세요."
        }
    }
}

/// 지우기 직전에 화면이 세워 두는 물음. 무엇을, 어떤 방식으로, 그리고 누르면 무엇을 할지.
struct EventDeletionRequest: Identifiable {
    let id = UUID()
    /// 알림 제목에 그대로 선다. 예: `"'회의' 삭제"`, `"일정 12개 삭제"`.
    let title: String
    let plan: EventDeletion
    /// 확인을 누르면 실제로 지우는 일. 실패하면 그 이유가 그대로 화면에 뜬다.
    let perform: () async -> Result<Void, Error>
}

extension View {
    /// 일정 삭제 확인. 다섯 자리가 같은 말을 하도록 여기 한 곳에서 낸다.
    /// `request` 에 값을 넣으면 물음이 뜨고, 답하면 저절로 비워진다.
    func confirmsEventDeletion(_ request: Binding<EventDeletionRequest?>) -> some View {
        modifier(EventDeletionConfirm(request: request))
    }
}

private struct EventDeletionConfirm: ViewModifier {

    @Binding var request: EventDeletionRequest?

    /// 지우지 못했을 때 그 이유. 조용히 삼키면 "눌렀는데 아무 일도 없다"가 된다.
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .alert(request?.title ?? "일정 삭제",
                   isPresented: Binding(get: { request != nil },
                                        set: { if !$0 { request = nil } }),
                   presenting: request) { asked in
                if asked.plan.isAllowed {
                    Button("삭제", role: .destructive) {
                        let perform = asked.perform
                        Task {
                            if case .failure(let error) = await perform() {
                                failure = error.localizedDescription
                            }
                        }
                    }
                    Button("취소", role: .cancel) { }
                } else {
                    // 막힌 경우에는 '삭제'를 내주지 않는다. 누를 수 있게 두고 막으면
                    // 왜 안 되는지 두 번 설명해야 한다.
                    Button("확인", role: .cancel) { }
                }
            } message: { asked in
                Text(asked.plan.message)
            }
            .alert("지우지 못했습니다",
                   isPresented: Binding(get: { failure != nil },
                                        set: { if !$0 { failure = nil } }),
                   presenting: failure) { _ in
                Button("확인", role: .cancel) { }
            } message: { reason in
                Text("iCloud 에서 지우지 못해 이 기기에서도 지우지 않았습니다. 한쪽만 지우면 나중에 다시 내려옵니다.\n\n\(reason)")
            }
    }
}
