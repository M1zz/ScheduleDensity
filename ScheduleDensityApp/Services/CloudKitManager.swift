//
//  CloudKitManager.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-22.
//

import Foundation
import CloudKit
import SwiftData

/// **옛 수동 iCloud 일정 백업/복원(이 파일)은 쉰다.**
///
/// 일정은 이제 맥·다른 아이폰과 공용 스토어의 `RainbowEvent`로 오간다 (→ RainbowBridge.swift).
/// 이 길을 같이 열어 두면 둘이 서로를 망가뜨린다.
///  · 'iCloud에서 복원'은 이 기기 일정을 `willDelete` 없이 통째로 지우고 다시 넣는다 → 다리는 그걸
///    '한꺼번에 사라짐'으로 보고 사본에서 되살린다 → 복원한 것까지 더해 두 벌, 지웠던 일정이 네 기기에 돌아온다.
///  · 일정을 고칠 때마다 올리는 레코드는 기기마다 따로 쌓인다(B 폰이 고친 일정은 B의 레코드가 하나 더).
/// 그래서 설정의 백업/복원 칸을 숨기고 저장 때 올리기도 멈춘다. 코드는 지우지 않는다 —
/// 이미 올라가 있는 레코드를 지우는 길(일정 삭제)은 그대로 쓰고, 되돌려야 하면 이 값만 바꾸면 된다.
enum LegacyEventCloud {
    static let isRetired = true
}

@Observable
class CloudKitManager {
    static let shared = CloudKitManager()

    var isAvailable: Bool = false
    var accountStatus: CKAccountStatus = .couldNotDetermine
    var statusMessage: String = String(localized: "확인 중...")

    // 앱 전체가 쓰는 메인 컨테이너로 통일 (Mac WeekBlocks·공유·할 일과 동일).
    // 과거 기본 컨테이너(iCloud.com.example.ScheduleDensityApp)는 placeholder 도메인이라 폐기.
    private let container = CKContainer(identifier: "iCloud.com.devkoan.ScheduleDensity")

    private init() {
        checkAccountStatus()
    }

    // iCloud 계정 상태 확인
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.accountStatus = status

                switch status {
                case .available:
                    self?.isAvailable = true
                    self?.statusMessage = String(localized: "사용 가능")
                case .noAccount:
                    self?.isAvailable = false
                    self?.statusMessage = String(localized: "Apple ID 미로그인")
                case .restricted:
                    self?.isAvailable = false
                    self?.statusMessage = String(localized: "제한됨")
                case .couldNotDetermine:
                    self?.isAvailable = false
                    self?.statusMessage = String(localized: "확인 불가")
                case .temporarilyUnavailable:
                    self?.isAvailable = false
                    self?.statusMessage = String(localized: "일시적으로 사용 불가")
                @unknown default:
                    self?.isAvailable = false
                    self?.statusMessage = String(localized: "알 수 없음")
                }
            }
        }
    }

    // CloudKit에 개별 Event 저장 (추가 또는 업데이트) - 증분 동기화
    func saveEvent(_ event: Event, completion: @escaping (Result<String, Error>) -> Void) {
        let database = container.privateCloudDatabase

        // recordName이 있으면 기존 레코드 업데이트, 없으면 새로 생성
        let record: CKRecord
        if let recordName = event.cloudKitRecordName {
            let recordID = CKRecord.ID(recordName: recordName)
            record = CKRecord(recordType: "Event", recordID: recordID)
            AppLog.sync.trace("🔄 [CloudKit] Updating existing record: \(recordName)")
        } else {
            record = CKRecord(recordType: "Event")
            AppLog.sync.trace("➕ [CloudKit] Creating new record")
        }

        record["title"] = event.title as CKRecordValue
        record["startDate"] = event.startDate as CKRecordValue
        record["endDate"] = event.endDate as CKRecordValue
        record["color"] = event.color as CKRecordValue
        record["hoursPerDay"] = event.hoursPerDay as CKRecordValue
        record["importanceRaw"] = event.importanceRaw as CKRecordValue
        record["isInfinite"] = event.isInfinite as CKRecordValue

        if let weekdays = event.selectedWeekdays {
            record["selectedWeekdays"] = weekdays as CKRecordValue
        }

        if let excludedDatesData = event.excludedDatesData {
            record["excludedDatesData"] = excludedDatesData as CKRecordValue
        }

        if let weeklyPatternData = event.weeklyPatternData {
            record["weeklyPatternData"] = weeklyPatternData as CKRecordValue
        }

        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLog.sync.trace("❌ [CloudKit] Save failed: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    let recordName = savedRecord.recordID.recordName
                    AppLog.sync.trace("✅ [CloudKit] Saved: \(recordName)")
                    completion(.success(recordName))
                } else {
                    completion(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record returned"])))
                }
            }
        }
    }

    // CloudKit에서 개별 Event 삭제
    func deleteEvent(recordName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: recordName)

        AppLog.sync.trace("🗑️ [CloudKit] Deleting record: \(recordName)")

        database.delete(withRecordID: recordID) { deletedRecordID, error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLog.sync.trace("❌ [CloudKit] Delete failed: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    AppLog.sync.trace("✅ [CloudKit] Deleted: \(recordName)")
                    completion(.success(()))
                }
            }
        }
    }

    /// 위 것을 async 로 감싼다. **로컬을 지우기 전에 저쪽이 끝난 것을 확인해야** 해서 필요하다.
    ///
    /// ⚠️ 이미 없는 레코드(`unknownItem`)는 성공으로 친다. 다른 기기에서 먼저 지운 것을
    ///    실패로 읽으면, 이쪽에서는 영영 못 지우는 줄만 남는다.
    func deleteEvent(recordName: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            deleteEvent(recordName: recordName) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        AppLog.sync.trace("✅ [CloudKit] 이미 없는 레코드다: \(recordName)")
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// 전체 삭제를 async 로 감싼 것.
    func deleteAllEvents() async throws {
        try await withCheckedThrowingContinuation { continuation in
            deleteAllEvents { continuation.resume(with: $0) }
        }
    }

    // 여러 Event를 배치로 CloudKit에 저장
    func saveEvents(_ events: [Event], progress: @escaping (Int, Int) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        let database = container.privateCloudDatabase
        let totalCount = events.count

        guard totalCount > 0 else {
            completion(.success(()))
            return
        }

        AppLog.sync.trace("📤 [CloudKit] Starting batch save: \(totalCount) events")

        // CKRecord 배열 생성
        let records = events.map { event -> CKRecord in
            let record = CKRecord(recordType: "Event")
            record["title"] = event.title as CKRecordValue
            record["startDate"] = event.startDate as CKRecordValue
            record["endDate"] = event.endDate as CKRecordValue
            record["color"] = event.color as CKRecordValue
            record["hoursPerDay"] = event.hoursPerDay as CKRecordValue
            record["importanceRaw"] = event.importanceRaw as CKRecordValue
            record["isInfinite"] = event.isInfinite as CKRecordValue

            if let weekdays = event.selectedWeekdays {
                record["selectedWeekdays"] = weekdays as CKRecordValue
            }

            if let excludedDatesData = event.excludedDatesData {
                record["excludedDatesData"] = excludedDatesData as CKRecordValue
            }

            if let weeklyPatternData = event.weeklyPatternData {
                record["weeklyPatternData"] = weeklyPatternData as CKRecordValue
            }

            AppLog.sync.trace("📝 [CloudKit] Created record: \(event.title)")
            return record
        }

        AppLog.sync.trace("🔧 [CloudKit] Created \(records.count) records, creating operation...")

        // 단순화: 한 번에 모든 레코드 저장
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        AppLog.sync.trace("✨ [CloudKit] Operation created")

        // 개별 레코드 저장 진행률 추적
        var savedCount = 0
        operation.perRecordSaveBlock = { recordID, result in
            AppLog.sync.trace("🔄 [CloudKit] perRecordSaveBlock called for \(recordID)")
            DispatchQueue.main.async {
                switch result {
                case .success:
                    savedCount += 1
                    progress(savedCount, totalCount)
                    AppLog.sync.trace("📦 [CloudKit] Saved \(savedCount)/\(totalCount)")
                case .failure(let error):
                    AppLog.sync.trace("⚠️ [CloudKit] Record \(recordID) failed: \(error.localizedDescription)")
                }
            }
        }
        AppLog.sync.trace("🎯 [CloudKit] perRecordSaveBlock set")

        operation.modifyRecordsResultBlock = { result in
            AppLog.sync.trace("🏁 [CloudKit] modifyRecordsResultBlock called")
            DispatchQueue.main.async {
                switch result {
                case .success:
                    AppLog.sync.trace("✅ [CloudKit] All \(totalCount) events saved successfully")
                    AppLog.sync.trace("✅ [CloudKit] Saved count: \(savedCount)")
                    completion(.success(()))
                case .failure(let error):
                    AppLog.sync.trace("❌ [CloudKit] Save failed: \(error.localizedDescription)")
                    AppLog.sync.trace("❌ [CloudKit] Error code: \((error as NSError).code)")
                    AppLog.sync.trace("❌ [CloudKit] Error domain: \((error as NSError).domain)")
                    AppLog.sync.trace("❌ [CloudKit] Error details: \(error)")
                    if let ckError = error as? CKError {
                        AppLog.sync.trace("❌ [CloudKit] CKError code: \(ckError.errorCode)")
                        AppLog.sync.trace("❌ [CloudKit] Partial errors: \(String(describing: ckError.partialErrorsByItemID))")
                    }
                    completion(.failure(error))
                }
            }
        }
        AppLog.sync.trace("🎯 [CloudKit] modifyRecordsResultBlock set")

        // Quality of Service 설정
        operation.qualityOfService = .userInitiated
        AppLog.sync.trace("⚙️ [CloudKit] QoS set to userInitiated")

        AppLog.sync.trace("🚀 [CloudKit] Adding operation to database...")
        database.add(operation)
        AppLog.sync.trace("✈️ [CloudKit] Operation added to database")
    }

    // CloudKit에서 모든 Event 가져오기
    func fetchEvents(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let database = container.privateCloudDatabase

        AppLog.sync.trace("📥 [CloudKit] Fetching events from iCloud...")
        // 쿼리 대신 레코드를 직접 스캔하는 방식
        fetchAllRecordsRecursively(database: database, recordType: "Event", cursor: nil, existingRecords: []) { result in
            completion(result)
        }
    }

    // 재귀적으로 모든 레코드 가져오기 (커서 기반)
    private func fetchAllRecordsRecursively(database: CKDatabase, recordType: String, cursor: CKQueryOperation.Cursor?, existingRecords: [CKRecord], completion: @escaping (Result<[CKRecord], Error>) -> Void) {

        var allRecords = existingRecords

        let operation: CKQueryOperation
        if let cursor = cursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            // 초기 쿼리 - predicateValue를 사용하여 인덱스 없이 모든 레코드 가져오기
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            operation = CKQueryOperation(query: query)
        }

        operation.resultsLimit = CKQueryOperation.maximumResults

        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                allRecords.append(record)
                AppLog.sync.trace("📦 [CloudKit] Fetched record: \(record["title"] ?? "Unknown")")
            case .failure(let error):
                AppLog.sync.trace("⚠️ [CloudKit] Failed to fetch record \(recordID): \(error.localizedDescription)")
            }
        }

        operation.queryResultBlock = { result in
            switch result {
            case .success(let cursor):
                if let cursor = cursor {
                    AppLog.sync.trace("📥 [CloudKit] More records available, fetching... (current: \(allRecords.count))")
                    // 더 많은 레코드가 있으면 재귀 호출
                    self.fetchAllRecordsRecursively(database: database, recordType: recordType, cursor: cursor, existingRecords: allRecords, completion: completion)
                } else {
                    // 모든 레코드를 가져왔음
                    DispatchQueue.main.async {
                        AppLog.sync.trace("✅ [CloudKit] Fetched \(allRecords.count) records total")
                        if allRecords.isEmpty {
                            AppLog.sync.trace("⚠️ [CloudKit] WARNING: No records found in CloudKit!")
                            AppLog.sync.trace("⚠️ [CloudKit] Possible reasons:")
                            AppLog.sync.trace("   1. No data was saved yet")
                            AppLog.sync.trace("   2. Container is empty")
                            AppLog.sync.trace("   3. Permission issue")
                        }
                        completion(.success(allRecords))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    AppLog.sync.trace("❌ [CloudKit] Fetch failed: \(error.localizedDescription)")
                    AppLog.sync.trace("❌ [CloudKit] Error code: \((error as NSError).code)")
                    AppLog.sync.trace("❌ [CloudKit] Error domain: \((error as NSError).domain)")

                    // Error code 15 = Zone doesn't support this operation
                    if (error as NSError).code == 15 {
                        AppLog.sync.trace("⚠️ [CloudKit] This is a zone compatibility error")
                        AppLog.sync.trace("⚠️ [CloudKit] Trying alternative fetch method...")
                        // 대안: 레코드를 하나씩 가져오기는 비효율적이므로 에러 반환
                    }

                    if let ckError = error as? CKError {
                        AppLog.sync.trace("❌ [CloudKit] CKError code: \(ckError.errorCode)")
                    }
                    completion(.failure(error))
                }
            }
        }

        database.add(operation)
    }

    // CloudKit에서 Event 복원 (CKRecord → Event 변환)
    func restoreEvents(progress: @escaping (Int, Int) -> Void, completion: @escaping (Result<[Event], Error>) -> Void) {
        AppLog.sync.trace("🔄 [CloudKit] Starting restore process...")

        fetchEvents { result in
            switch result {
            case .success(let records):
                AppLog.sync.trace("📦 [CloudKit] Converting \(records.count) records to Events...")

                var events: [Event] = []
                let totalCount = records.count

                for (index, record) in records.enumerated() {
                    // CKRecord에서 필드 추출
                    guard let title = record["title"] as? String,
                          let startDate = record["startDate"] as? Date,
                          let endDate = record["endDate"] as? Date,
                          let color = record["color"] as? String,
                          let hoursPerDay = record["hoursPerDay"] as? Double else {
                        AppLog.sync.trace("⚠️ [CloudKit] Skipping invalid record: \(record.recordID)")
                        continue
                    }

                    let selectedWeekdays = record["selectedWeekdays"] as? [Int]
                    let importanceRaw = record["importanceRaw"] as? String ?? EventImportance.medium.rawValue
                    let isInfinite = record["isInfinite"] as? Bool ?? false
                    let excludedDatesData = record["excludedDatesData"] as? Data
                    let weeklyPatternData = record["weeklyPatternData"] as? Data

                    // recordName도 함께 저장하여 증분 동기화 가능하도록
                    let event = Event(
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                        color: color,
                        hoursPerDay: hoursPerDay,
                        selectedWeekdays: selectedWeekdays,
                        cloudKitRecordName: record.recordID.recordName,
                        importance: EventImportance(rawValue: importanceRaw) ?? .medium,
                        isInfinite: isInfinite
                    )

                    // Set excluded dates and weekly pattern after creation
                    event.excludedDatesData = excludedDatesData
                    event.weeklyPatternData = weeklyPatternData

                    events.append(event)

                    DispatchQueue.main.async {
                        progress(index + 1, totalCount)
                        AppLog.sync.trace("📦 [CloudKit] Converted \(index + 1)/\(totalCount): \(title)")
                    }
                }

                AppLog.sync.trace("✅ [CloudKit] Successfully converted \(events.count) events")
                DispatchQueue.main.async {
                    completion(.success(events))
                }

            case .failure(let error):
                AppLog.sync.trace("❌ [CloudKit] Restore failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // CloudKit의 모든 Event 삭제
    func deleteAllEvents(completion: @escaping (Result<Void, Error>) -> Void) {
        fetchEvents { result in
            switch result {
            case .success(let records):
                guard !records.isEmpty else {
                    completion(.success(()))
                    return
                }

                let recordIDs = records.map { $0.recordID }
                let database = self.container.privateCloudDatabase

                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)

                operation.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }

                database.add(operation)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
