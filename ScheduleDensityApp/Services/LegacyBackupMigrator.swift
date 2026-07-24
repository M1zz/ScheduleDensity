//
//  LegacyBackupMigrator.swift
//  ScheduleDensityApp
//
//  ⚠️⚠️ 일회성 마이그레이션 — 이전 완료 후 DEPRECATE 예정 ⚠️⚠️
//
//  구 백업 컨테이너 `iCloud.com.example.ScheduleDensityApp`(placeholder 도메인)에 남아 있던
//  Event 백업 레코드를, 통일된 메인 컨테이너 `iCloud.com.devkoan.ScheduleDensity`로 복사한다.
//  앱 시작 시 1회 실행되며(성공하면 플래그로 재실행 차단), 로컬 SwiftData 원본은 건드리지 않는다.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  [디프리케이트(제거) 체크리스트] — 사용자 기기 대부분이 이전 완료되었다고 판단되면:
//    1) 이 파일 삭제
//    2) ScheduleDensityApp.swift 의 `LegacyBackupMigrator.shared.runIfNeeded()` 호출 제거
//    3) ScheduleDensityApp.entitlements 에서 `iCloud.com.example.ScheduleDensityApp` 제거
//       (지금은 구 컨테이너를 '읽기' 위해 임시로 다시 넣어 둔 상태)
//    4) (선택) 구 컨테이너를 CloudKit Dashboard에서 비우거나 삭제
//  ─────────────────────────────────────────────────────────────────────────────
//

import Foundation
import CloudKit

@MainActor
final class LegacyBackupMigrator {
    static let shared = LegacyBackupMigrator()

    private static let oldContainerID = "iCloud.com.example.ScheduleDensityApp"
    private static let newContainerID = "iCloud.com.devkoan.ScheduleDensity"
    private static let recordType = "Event"
    /// 완료 플래그. 마이그레이션 로직이 바뀌면 v2, v3 … 로 올려 재실행.
    private static let doneKey = "legacyBackupMigration.v1.done"

    private var oldDB: CKDatabase { CKContainer(identifier: Self.oldContainerID).privateCloudDatabase }
    private var newDB: CKDatabase { CKContainer(identifier: Self.newContainerID).privateCloudDatabase }

    /// 앱 시작 시 호출. 이미 완료했으면 즉시 반환. 실패하면 플래그를 남기지 않아 다음 실행 때 재시도.
    func runIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: Self.doneKey) else { return }

        do {
            // 새 컨테이너 기준 iCloud 계정이 준비돼 있을 때만 진행.
            let status = try await CKContainer(identifier: Self.newContainerID).accountStatus()
            guard status == .available else {
                print("ℹ️ [Migration] iCloud 미준비 — 다음 실행에서 재시도")
                return
            }

            // 1) 구 컨테이너의 Event 백업 전부 읽기.
            let oldRecords: [CKRecord]
            do {
                oldRecords = try await fetchAllEvents(from: oldDB)
            } catch {
                if Self.isMissingRecordType(error) {
                    // 구 컨테이너에 Event 타입이 아예 없음 = 옮길 백업 없음 → 완료 처리.
                    UserDefaults.standard.set(true, forKey: Self.doneKey)
                    print("✅ [Migration] 구 컨테이너에 백업 없음 — 완료 처리")
                    return
                }
                throw error
            }

            guard !oldRecords.isEmpty else {
                UserDefaults.standard.set(true, forKey: Self.doneKey)
                print("✅ [Migration] 옮길 Event 없음 — 완료 처리")
                return
            }

            // 2) 새 컨테이너에 이미 있는 Event 키 수집(중복 복사 방지).
            let existingKeys = try await existingEventKeys(in: newDB)
            let toCopy = oldRecords.filter { !existingKeys.contains(Self.dedupeKey(for: $0)) }

            // 3) 없는 것만 새 컨테이너에 복사.
            if !toCopy.isEmpty {
                let clones = toCopy.map(Self.cloneForNewContainer)
                try await save(clones, to: newDB)
            }

            UserDefaults.standard.set(true, forKey: Self.doneKey)
            print("✅ [Migration] Legacy 백업 이전 완료: \(toCopy.count)/\(oldRecords.count)개 복사")
        } catch {
            // 플래그를 세우지 않으므로 다음 앱 실행 때 다시 시도한다.
            print("⚠️ [Migration] 이전 보류(다음에 재시도): \(error.localizedDescription)")
        }
    }

    // MARK: - 읽기

    /// 기본 존의 Event 레코드를 커서 기반으로 전부 가져온다.
    private func fetchAllEvents(from db: CKDatabase) async throws -> [CKRecord] {
        var all: [CKRecord] = []
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        var response = try await db.records(matching: query,
                                            resultsLimit: CKQueryOperation.maximumResults)
        while true {
            for (_, result) in response.matchResults {
                if let record = try? result.get() { all.append(record) }
            }
            guard let cursor = response.queryCursor else { break }
            response = try await db.records(continuingMatchFrom: cursor,
                                            resultsLimit: CKQueryOperation.maximumResults)
        }
        return all
    }

    /// 새 컨테이너에 이미 있는 Event들의 중복 판별 키 집합.
    /// 레코드 타입이 아직 없으면(=백업 처음) 빈 집합, 그 외 오류는 상위로 전달해 마이그레이션을 미룬다.
    private func existingEventKeys(in db: CKDatabase) async throws -> Set<String> {
        do {
            let records = try await fetchAllEvents(from: db)
            return Set(records.map(Self.dedupeKey))
        } catch {
            if Self.isMissingRecordType(error) { return [] }
            throw error
        }
    }

    // MARK: - 쓰기

    private func save(_ records: [CKRecord], to db: CKDatabase) async throws {
        // CKModifyRecordsOperation 배치 상한(400)에 여유를 두고 청크 저장.
        for start in stride(from: 0, to: records.count, by: 200) {
            let chunk = Array(records[start..<min(start + 200, records.count)])
            let op = CKModifyRecordsOperation(recordsToSave: chunk, recordIDsToDelete: nil)
            op.savePolicy = .allKeys
            op.qualityOfService = .utility
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                op.modifyRecordsResultBlock = { cont.resume(with: $0) }
                db.add(op)
            }
        }
    }

    // MARK: - 헬퍼

    /// 새 컨테이너 기본 존에 넣을 복제본. 모든 필드를 그대로 복사하고 recordID는 새로 발급.
    private static func cloneForNewContainer(_ source: CKRecord) -> CKRecord {
        let copy = CKRecord(recordType: source.recordType)
        for key in source.allKeys() {
            copy[key] = source[key]
        }
        return copy
    }

    /// 제목+시작일+종료일로 같은 일정인지 판별(recordID는 컨테이너마다 달라 못 씀).
    private static func dedupeKey(for record: CKRecord) -> String {
        let title = record["title"] as? String ?? ""
        let start = (record["startDate"] as? Date)?.timeIntervalSinceReferenceDate ?? 0
        let end = (record["endDate"] as? Date)?.timeIntervalSinceReferenceDate ?? 0
        return "\(title)|\(start)|\(end)"
    }

    /// "해당 레코드 타입이 존재하지 않음" 류의 오류인지.
    private static func isMissingRecordType(_ error: Error) -> Bool {
        guard let ck = error as? CKError else { return false }
        switch ck.code {
        case .unknownItem, .invalidArguments:
            return true
        default:
            return false
        }
    }
}
