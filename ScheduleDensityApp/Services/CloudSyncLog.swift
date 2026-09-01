//
//  CloudSyncLog.swift
//  ScheduleDensityApp
//
//  **동기화 엔진이 스스로 남기는 말을 받아 적는다.**
//
//  지금까지 진단은 전부 '결과'만 봤다 — 몇 개 있나, 어디에 저장되나. 그런데 결과만
//  보면 "안 온다"까지는 알아도 **왜** 안 오는지는 끝내 모른다. 올려 보내다 실패한 것과
//  받아 오다 실패한 것과 아예 시작을 못 한 것이 화면에서는 똑같이 '0개'다.
//
//  NSPersistentCloudKitContainer는 준비(setup)·받기(import)·보내기(export)를 할 때마다
//  성공 여부와 에러를 알림으로 내보낸다. SwiftData도 속으로 이 컨테이너를 쓰므로 같은
//  알림이 온다. 그걸 여기서 받아 마지막 것만 들고 있는다.
//
//  이게 있으면 추측을 멈출 수 있다. "스키마가 없나 봐요" 대신 엔진이 적어 준 사유를
//  그대로 읽으면 된다.
//

import Foundation
import CoreData

@Observable
final class CloudSyncLog {
    static let shared = CloudSyncLog()

    struct Entry {
        let succeeded: Bool
        let at: Date
        /// 실패했을 때 엔진이 준 사유. 성공이면 비어 있다.
        let error: String?
    }

    /// 준비 / 받기 / 보내기 각각의 마지막 결과.
    private(set) var setup: Entry?
    private(set) var importing: Entry?
    private(set) var exporting: Entry?

    private var observer: NSObjectProtocol?

    private init() {}

    /// 앱이 뜰 때 한 번 건다. 두 번 걸어도 알림이 두 번 쌓이지 않게 막는다.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            // 시작할 때도 알림이 온다(endDate == nil). 끝난 것만 적는다 —
            // 진행 중인 것을 실패로 읽으면 멀쩡한 동기화가 빨갛게 보인다.
            guard event.endDate != nil else { return }

            let entry = Entry(succeeded: event.succeeded,
                              at: event.endDate ?? Date(),
                              error: event.error.map { String(describing: $0) })
            switch event.type {
            case .setup:  self?.setup = entry
            case .import: self?.importing = entry
            case .export: self?.exporting = entry
            @unknown default: break
            }
        }
    }
}
