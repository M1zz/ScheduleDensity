//
//  ScheduleShareStore.swift
//  ScheduleDensityApp
//
//  일정(캘린더 이벤트) 공유 — "가족 공유"와는 별개의, 사람 대 사람 공유.
//  - 내보내기(소유자): 내 개인 DB의 커스텀 존("SharedSchedule")에 내 일정을 미러링하고,
//    존 전체를 CKShare로 공유한다. 링크를 받은 사람은 **읽기 전용**(publicPermission .readOnly).
//  - 받기(참가자): 초대 링크를 수락하면 상대의 존이 공유 DB(sharedCloudDatabase)에 나타난다.
//    여러 사람에게서 받을 수 있으므로, 사람별로 묶어 읽기 전용으로 보여준다.
//
//  ⚠️ SwiftData의 Event(로컬 전용) 원본은 건드리지 않는다. 공유용 미러만 CloudKit에 올린다.
//

import Foundation
import CloudKit
import Observation

/// 공유용 일정 한 건 (CKRecord 미러, 읽기 전용 표시).
struct SharedEvent: Identifiable, Equatable {
    let id: CKRecord.ID
    var title: String
    var startDate: Date
    var endDate: Date
    var color: String
    var hoursPerDay: Double
    var importanceRaw: String
    var isInfinite: Bool
    var selectedWeekdays: [Int]?
}

/// 한 사람이 나에게 공유한 일정 묶음.
struct SharedScheduleGroup: Identifiable, Equatable {
    let id: String          // 공유 존의 소유자 식별자(zoneID.ownerName) — 안정적인 키
    var personName: String
    var events: [SharedEvent]
}

@MainActor
@Observable
final class ScheduleShareStore {
    static let shared = ScheduleShareStore()

    static let containerID = "iCloud.com.devkoan.ScheduleDensity"
    static let zoneName = "SharedSchedule"
    static let recordType = "SharedEvent"

    // MARK: 내 공유(내보내기) 상태
    /// 내 일정 존 전체 공유(CKShare)가 만들어져 있는지.
    private(set) var isSharing = false
    private(set) var shareURL: URL? = nil
    /// 현재 공유에 올라간 내 일정 개수.
    private(set) var publishedCount = 0

    // MARK: 공유받은 일정(들어오기)
    private(set) var sharedWithMe: [SharedScheduleGroup] = []

    // MARK: 공통 상태
    private(set) var isBusy = false
    private(set) var iCloudAvailable = true
    var errorMessage: String? = nil

    private let container = CKContainer(identifier: ScheduleShareStore.containerID)
    private let myZoneID = CKRecordZone.ID(zoneName: ScheduleShareStore.zoneName)
    private var myZoneExists = false

    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    // MARK: - 새로고침

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let status = try await container.accountStatus()
            iCloudAvailable = (status == .available)
            guard iCloudAvailable else { return }

            await fetchMyShareState()
            await fetchSharedWithMe()
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    /// 내 존의 공유(CKShare) 존재 여부와 올라간 일정 수를 확인한다.
    private func fetchMyShareState() async {
        var count = 0
        var share: CKShare? = nil
        var token: CKServerChangeToken? = nil
        do {
            while true {
                let result = try await privateDB.recordZoneChanges(inZoneWith: myZoneID, since: token)
                for modification in result.modificationResultsByID.values {
                    guard let record = try? modification.get().record else { continue }
                    if let s = record as? CKShare {
                        share = s
                    } else if record.recordType == Self.recordType {
                        count += 1
                    }
                }
                token = result.changeToken
                if !result.moreComing { break }
            }
            myZoneExists = true
            publishedCount = count
            isSharing = (share != nil)
            shareURL = share?.url
        } catch let ck as CKError where ck.code == .zoneNotFound || ck.code == .userDeletedZone {
            // 아직 아무것도 공유하지 않은 상태.
            myZoneExists = false
            publishedCount = 0
            isSharing = false
            shareURL = nil
        } catch {
            handle(error)
        }
    }

    /// 공유 DB에 나타난 다른 사람들의 존을 사람별로 묶어 읽는다.
    private func fetchSharedWithMe() async {
        do {
            let zones = try await sharedDB.allRecordZones()
            var groups: [SharedScheduleGroup] = []

            for zone in zones where zone.zoneID.zoneName == Self.zoneName {
                var events: [SharedEvent] = []
                var personName = "공유한 사람"
                var token: CKServerChangeToken? = nil
                do {
                    while true {
                        let result = try await sharedDB.recordZoneChanges(inZoneWith: zone.zoneID, since: token)
                        for modification in result.modificationResultsByID.values {
                            guard let record = try? modification.get().record else { continue }
                            if let share = record as? CKShare {
                                if let name = share.owner.userIdentity.nameComponents {
                                    personName = PersonNameComponentsFormatter().string(from: name)
                                }
                            } else if record.recordType == Self.recordType {
                                events.append(Self.event(from: record))
                            }
                        }
                        token = result.changeToken
                        if !result.moreComing { break }
                    }
                } catch let ck as CKError where ck.code == .zoneNotFound {
                    continue
                }
                events.sort { $0.startDate < $1.startDate }
                groups.append(SharedScheduleGroup(id: zone.zoneID.ownerName,
                                                  personName: personName,
                                                  events: events))
            }
            sharedWithMe = groups.sorted { $0.personName < $1.personName }
        } catch {
            handle(error)
        }
    }

    private static func event(from record: CKRecord) -> SharedEvent {
        SharedEvent(
            id: record.recordID,
            title: record["title"] as? String ?? "",
            startDate: record["startDate"] as? Date ?? Date(),
            endDate: record["endDate"] as? Date ?? Date(),
            color: record["color"] as? String ?? "#FF3B30",
            hoursPerDay: record["hoursPerDay"] as? Double ?? 0,
            importanceRaw: record["importanceRaw"] as? String ?? EventImportance.medium.rawValue,
            isInfinite: (record["isInfinite"] as? Int64 ?? 0) != 0,
            selectedWeekdays: record["selectedWeekdays"] as? [Int]
        )
    }

    // MARK: - 내 일정 올리기(퍼블리시)

    /// 현재 내 일정 전체를 공유 존에 미러링한다(전량 교체 — 목록이 작아 단순·안전).
    func publish(events: [Event]) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let status = try await container.accountStatus()
            iCloudAvailable = (status == .available)
            guard iCloudAvailable else {
                errorMessage = "iCloud에 로그인하면 일정을 공유할 수 있습니다."
                return
            }

            try await ensureZone()

            // 기존 미러 레코드 전부 수집(삭제 대상).
            var oldIDs: [CKRecord.ID] = []
            var token: CKServerChangeToken? = nil
            do {
                while true {
                    let result = try await privateDB.recordZoneChanges(inZoneWith: myZoneID, since: token)
                    for modification in result.modificationResultsByID.values {
                        guard let record = try? modification.get().record else { continue }
                        if record.recordType == Self.recordType {
                            oldIDs.append(record.recordID)
                        }
                    }
                    token = result.changeToken
                    if !result.moreComing { break }
                }
            } catch let ck as CKError where ck.code == .zoneNotFound {
                // 존은 방금 ensureZone으로 만들어졌을 수 있음 — 기존 레코드 없음.
            }

            let newRecords = events.map { Self.record(from: $0, zoneID: myZoneID) }

            try await modify(save: newRecords, delete: oldIDs, in: privateDB)
            publishedCount = events.count
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    private static func record(from event: Event, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        )
        record["title"] = event.title as CKRecordValue
        record["startDate"] = event.startDate as CKRecordValue
        record["endDate"] = event.endDate as CKRecordValue
        record["color"] = event.color as CKRecordValue
        record["hoursPerDay"] = event.hoursPerDay as CKRecordValue
        record["importanceRaw"] = event.importanceRaw as CKRecordValue
        record["isInfinite"] = Int64(event.isInfinite ? 1 : 0) as CKRecordValue
        if let weekdays = event.selectedWeekdays {
            record["selectedWeekdays"] = weekdays as CKRecordValue
        }
        return record
    }

    /// CKModifyRecordsOperation를 async로 감싼다.
    private func modify(save: [CKRecord], delete: [CKRecord.ID], in database: CKDatabase) async throws {
        let op = CKModifyRecordsOperation(recordsToSave: save,
                                          recordIDsToDelete: delete)
        op.savePolicy = .allKeys
        op.qualityOfService = .userInitiated
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }

    private func ensureZone() async throws {
        guard !myZoneExists else { return }
        _ = try await privateDB.save(CKRecordZone(zoneID: myZoneID))
        myZoneExists = true
    }

    // MARK: - 공유 관리(내보내기)

    /// 내 일정 존 전체 공유를 만들거나 기존 공유의 초대 URL을 돌려준다.
    @discardableResult
    func startSharing() async -> URL? {
        isBusy = true
        defer { isBusy = false }
        do {
            try await ensureZone()

            let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: myZoneID)
            if let existing = try? await privateDB.record(for: shareID),
               let share = existing as? CKShare {
                isSharing = true
                shareURL = share.url
                return share.url
            }

            let share = CKShare(recordZoneID: myZoneID)
            share[CKShare.SystemFieldKey.title] = "내 일정" as CKRecordValue
            // 링크를 받은 사람은 읽기만 가능(내 일정을 남이 못 고치게).
            share.publicPermission = .readOnly
            let saved = try await privateDB.save(share)
            isSharing = true
            shareURL = (saved as? CKShare)?.url
            errorMessage = nil
            return shareURL
        } catch {
            handle(error)
            return nil
        }
    }

    /// 공유 중지 — 받은 사람 전원의 접근이 해제된다. 미러 데이터는 내 존에 남는다.
    func stopSharing() async {
        do {
            let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: myZoneID)
            _ = try await privateDB.deleteRecord(withID: shareID)
            isSharing = false
            shareURL = nil
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    // MARK: - 받은 공유 관리(참가자)

    /// 초대 링크 수락 (씬 델리게이트에서 호출).
    func accept(_ metadata: CKShare.Metadata) async {
        isBusy = true
        do {
            _ = try await container.accept(metadata)
            isBusy = false
            errorMessage = nil
            await refresh()
        } catch {
            isBusy = false
            handle(error)
        }
    }

    /// 특정 사람이 공유한 일정에서 나간다(목록에서 제거).
    func leave(_ group: SharedScheduleGroup) async {
        do {
            let zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: group.id)
            _ = try await sharedDB.deleteRecordZone(withID: zoneID)
            sharedWithMe.removeAll { $0.id == group.id }
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    // MARK: -

    private func handle(_ error: Error) {
        if let ck = error as? CKError {
            switch ck.code {
            case .notAuthenticated:
                iCloudAvailable = false
                errorMessage = "iCloud에 로그인하면 일정을 공유할 수 있습니다."
                return
            case .networkUnavailable, .networkFailure:
                errorMessage = "네트워크 연결을 확인해주세요."
                return
            default:
                break
            }
        }
        errorMessage = "동기화 오류: \(error.localizedDescription)"
    }
}
