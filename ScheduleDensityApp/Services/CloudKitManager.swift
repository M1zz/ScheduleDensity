//
//  CloudKitManager.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-22.
//

import Foundation
import CloudKit
import SwiftData

@Observable
class CloudKitManager {
    static let shared = CloudKitManager()

    var isAvailable: Bool = false
    var accountStatus: CKAccountStatus = .couldNotDetermine
    var statusMessage: String = "확인 중..."

    private let container = CKContainer(identifier: "iCloud.com.example.ScheduleDensityApp")

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
                    self?.statusMessage = "사용 가능"
                case .noAccount:
                    self?.isAvailable = false
                    self?.statusMessage = "Apple ID 미로그인"
                case .restricted:
                    self?.isAvailable = false
                    self?.statusMessage = "제한됨"
                case .couldNotDetermine:
                    self?.isAvailable = false
                    self?.statusMessage = "확인 불가"
                case .temporarilyUnavailable:
                    self?.isAvailable = false
                    self?.statusMessage = "일시적으로 사용 불가"
                @unknown default:
                    self?.isAvailable = false
                    self?.statusMessage = "알 수 없음"
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
            print("🔄 [CloudKit] Updating existing record: \(recordName)")
        } else {
            record = CKRecord(recordType: "Event")
            print("➕ [CloudKit] Creating new record")
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

        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CloudKit] Save failed: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    let recordName = savedRecord.recordID.recordName
                    print("✅ [CloudKit] Saved: \(recordName)")
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

        print("🗑️ [CloudKit] Deleting record: \(recordName)")

        database.delete(withRecordID: recordID) { deletedRecordID, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CloudKit] Delete failed: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ [CloudKit] Deleted: \(recordName)")
                    completion(.success(()))
                }
            }
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

        print("📤 [CloudKit] Starting batch save: \(totalCount) events")

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

            print("📝 [CloudKit] Created record: \(event.title)")
            return record
        }

        print("🔧 [CloudKit] Created \(records.count) records, creating operation...")

        // 단순화: 한 번에 모든 레코드 저장
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        print("✨ [CloudKit] Operation created")

        // 개별 레코드 저장 진행률 추적
        var savedCount = 0
        operation.perRecordSaveBlock = { recordID, result in
            print("🔄 [CloudKit] perRecordSaveBlock called for \(recordID)")
            DispatchQueue.main.async {
                switch result {
                case .success:
                    savedCount += 1
                    progress(savedCount, totalCount)
                    print("📦 [CloudKit] Saved \(savedCount)/\(totalCount)")
                case .failure(let error):
                    print("⚠️ [CloudKit] Record \(recordID) failed: \(error.localizedDescription)")
                }
            }
        }
        print("🎯 [CloudKit] perRecordSaveBlock set")

        operation.modifyRecordsResultBlock = { result in
            print("🏁 [CloudKit] modifyRecordsResultBlock called")
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ [CloudKit] All \(totalCount) events saved successfully")
                    print("✅ [CloudKit] Saved count: \(savedCount)")
                    completion(.success(()))
                case .failure(let error):
                    print("❌ [CloudKit] Save failed: \(error.localizedDescription)")
                    print("❌ [CloudKit] Error code: \((error as NSError).code)")
                    print("❌ [CloudKit] Error domain: \((error as NSError).domain)")
                    print("❌ [CloudKit] Error details: \(error)")
                    if let ckError = error as? CKError {
                        print("❌ [CloudKit] CKError code: \(ckError.errorCode)")
                        print("❌ [CloudKit] Partial errors: \(String(describing: ckError.partialErrorsByItemID))")
                    }
                    completion(.failure(error))
                }
            }
        }
        print("🎯 [CloudKit] modifyRecordsResultBlock set")

        // Quality of Service 설정
        operation.qualityOfService = .userInitiated
        print("⚙️ [CloudKit] QoS set to userInitiated")

        print("🚀 [CloudKit] Adding operation to database...")
        database.add(operation)
        print("✈️ [CloudKit] Operation added to database")
    }

    // CloudKit에서 모든 Event 가져오기
    func fetchEvents(completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let database = container.privateCloudDatabase

        print("📥 [CloudKit] Fetching events from iCloud...")
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
                print("📦 [CloudKit] Fetched record: \(record["title"] ?? "Unknown")")
            case .failure(let error):
                print("⚠️ [CloudKit] Failed to fetch record \(recordID): \(error.localizedDescription)")
            }
        }

        operation.queryResultBlock = { result in
            switch result {
            case .success(let cursor):
                if let cursor = cursor {
                    print("📥 [CloudKit] More records available, fetching... (current: \(allRecords.count))")
                    // 더 많은 레코드가 있으면 재귀 호출
                    self.fetchAllRecordsRecursively(database: database, recordType: recordType, cursor: cursor, existingRecords: allRecords, completion: completion)
                } else {
                    // 모든 레코드를 가져왔음
                    DispatchQueue.main.async {
                        print("✅ [CloudKit] Fetched \(allRecords.count) records total")
                        if allRecords.isEmpty {
                            print("⚠️ [CloudKit] WARNING: No records found in CloudKit!")
                            print("⚠️ [CloudKit] Possible reasons:")
                            print("   1. No data was saved yet")
                            print("   2. Container is empty")
                            print("   3. Permission issue")
                        }
                        completion(.success(allRecords))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ [CloudKit] Fetch failed: \(error.localizedDescription)")
                    print("❌ [CloudKit] Error code: \((error as NSError).code)")
                    print("❌ [CloudKit] Error domain: \((error as NSError).domain)")

                    // Error code 15 = Zone doesn't support this operation
                    if (error as NSError).code == 15 {
                        print("⚠️ [CloudKit] This is a zone compatibility error")
                        print("⚠️ [CloudKit] Trying alternative fetch method...")
                        // 대안: 레코드를 하나씩 가져오기는 비효율적이므로 에러 반환
                    }

                    if let ckError = error as? CKError {
                        print("❌ [CloudKit] CKError code: \(ckError.errorCode)")
                    }
                    completion(.failure(error))
                }
            }
        }

        database.add(operation)
    }

    // CloudKit에서 Event 복원 (CKRecord → Event 변환)
    func restoreEvents(progress: @escaping (Int, Int) -> Void, completion: @escaping (Result<[Event], Error>) -> Void) {
        print("🔄 [CloudKit] Starting restore process...")

        fetchEvents { result in
            switch result {
            case .success(let records):
                print("📦 [CloudKit] Converting \(records.count) records to Events...")

                var events: [Event] = []
                let totalCount = records.count

                for (index, record) in records.enumerated() {
                    // CKRecord에서 필드 추출
                    guard let title = record["title"] as? String,
                          let startDate = record["startDate"] as? Date,
                          let endDate = record["endDate"] as? Date,
                          let color = record["color"] as? String,
                          let hoursPerDay = record["hoursPerDay"] as? Double else {
                        print("⚠️ [CloudKit] Skipping invalid record: \(record.recordID)")
                        continue
                    }

                    let selectedWeekdays = record["selectedWeekdays"] as? [Int]
                    let importanceRaw = record["importanceRaw"] as? String ?? EventImportance.medium.rawValue
                    let isInfinite = record["isInfinite"] as? Bool ?? false

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

                    events.append(event)

                    DispatchQueue.main.async {
                        progress(index + 1, totalCount)
                        print("📦 [CloudKit] Converted \(index + 1)/\(totalCount): \(title)")
                    }
                }

                print("✅ [CloudKit] Successfully converted \(events.count) events")
                DispatchQueue.main.async {
                    completion(.success(events))
                }

            case .failure(let error):
                print("❌ [CloudKit] Restore failed: \(error.localizedDescription)")
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
