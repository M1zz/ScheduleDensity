//
//  CloudSchemaProbe.swift
//  ScheduleDensityApp
//
//  **iCloud 존에 실제로 무엇이 들어 있는지 앱이 직접 세어 본다.**
//
//  "맥 할 일이 아이폰에 안 온다"를 팔 때 제일 먼저 갈라야 하는 것은
//  **아직 안 올라간 것이냐, 올라왔는데 못 읽는 것이냐**다. 이 둘은 고치는 데가
//  완전히 다른데, 앱 화면만 보면 둘 다 똑같이 '없음'으로 보인다.
//
//  그래서 CloudKit 존을 통째로 훑어 타입별로 센다.
//    - 존에 BacklogItem이 0개  → 맥이 **못 올린** 것이다.
//      (Production에 레코드 타입이 없는 경우가 제일 흔하다. CloudKit은 Development
//       에서만 타입을 자동으로 만들고, Production에는 콘솔에서 배포해야 생긴다.)
//    - 존에는 있는데 앱 목록이 비었다 → **못 읽는** 것이다. 모델·스토어 쪽 문제다.
//
//  ⚠️ 예전에는 타입마다 CKQuery를 던져 존재를 물었는데 **안 된다.**
//     NSPersistentCloudKitContainer는 질의를 쓰지 않고 존 변경 토큰으로 동기화해서,
//     자동 생성된 스키마에 `recordName` 질의 색인이 없다. 그래서 타입이 있든 없든
//     전부 invalidArguments로 떨어져 아무것도 못 가른다. 존을 훑는 이 방식은
//     색인이 필요 없다.
//

import Foundation
import CloudKit

enum CloudSchemaProbe {

    /// 맥 '무지개 공방'과 함께 쓰는 여섯 타입.
    /// SwiftData는 레코드 타입 이름 앞에 `CD_`를 붙인다.
    static let recordTypes = ["CD_Routine", "CD_PlanBlock", "CD_BacklogItem",
                              "CD_BacklogCategory", "CD_RoutineOccurrence", "CD_QuotaPlacement"]

    /// NSPersistentCloudKitContainer가 쓰는 존.
    static let zoneName = "com.apple.coredata.cloudkit.zone"

    enum Outcome: Equatable {
        /// 존을 훑었다. 타입별 개수(0개인 타입도 들어 있다).
        case counted([String: Int])
        /// 존 자체가 없다. 이 계정에서 아직 아무것도 안 올라갔다는 뜻이다.
        case noZone
        /// 못 훑었다. 사유를 그대로 들고 있는다.
        case failed(String)
    }

    /// 존을 통째로 훑어 타입별로 센다.
    static func census() async -> Outcome {
        let database = CKContainer(identifier: WeekBlocksStore.containerID).privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        // 값은 안 받는다. 무슨 타입이 몇 개인지만 알면 된다.
        configuration.desiredKeys = []

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration])
        operation.fetchAllChanges = true

        var counts: [String: Int] = Dictionary(uniqueKeysWithValues: recordTypes.map { ($0, 0) })

        return await withCheckedContinuation { continuation in
            var finished = false
            /// 콜백이 여러 번 올 수 있다. 답은 한 번만 돌려준다.
            func settle(_ outcome: Outcome) {
                guard !finished else { return }
                finished = true
                continuation.resume(returning: outcome)
            }

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    // 우리가 세는 여섯 말고 다른 타입이 있어도 함께 담는다 —
                    // 모르는 것이 섞여 있으면 그것도 알아야 할 정보다.
                    counts[record.recordType, default: 0] += 1
                }
            }

            operation.recordZoneFetchResultBlock = { _, result in
                if case .failure(let error) = result {
                    settle(Self.describe(error))
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:            settle(.counted(counts))
                case .failure(let error): settle(Self.describe(error))
                }
            }

            database.add(operation)
        }
    }

    /// 실패를 이름 붙인다. **모르는 것을 '없음'으로 적지 않는다** —
    /// 네트워크가 끊긴 것을 미배포로 읽으면 멀쩡한 스키마를 배포하러 가게 된다.
    private static func describe(_ error: Error) -> Outcome {
        guard let ckError = error as? CKError else { return .failed(String(describing: error)) }
        switch ckError.code {
        case .zoneNotFound, .userDeletedZone:
            return .noZone
        case .notAuthenticated:
            return .failed("iCloud 로그인 안 됨")
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            return .failed("네트워크")
        case .permissionFailure:
            return .failed("권한 없음")
        default:
            return .failed("CKError \(ckError.code.rawValue): \(ckError.localizedDescription)")
        }
    }
}
