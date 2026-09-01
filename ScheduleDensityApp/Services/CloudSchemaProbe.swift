//
//  CloudSchemaProbe.swift
//  ScheduleDensityApp
//
//  **CloudKit에 레코드 타입이 실제로 있는지 앱이 직접 물어본다.**
//
//  왜 필요하냐면 — CloudKit은 **Development에서만** 레코드 타입을 자동으로 만든다.
//  Production에서는 만들지 않는다. 그래서 맥에서 모델에 타입을 하나 더 넣고
//  개발 빌드로 잘 돌려 본 뒤 그대로 두면, Production에서는 그 타입이 아예 없어서
//  동기화가 **조용히** 안 된다. 코드는 멀쩡하고, 계정도 맞고, 에러도 안 보인다.
//  (양쪽 앱 다 `icloud-container-environment`를 Production으로 못박아 두었으므로
//   디버그 빌드로 확인해도 결과는 같다.)
//
//  콘솔에 들어가 Development/Production 스키마를 눈으로 비교하는 대신, 여기서
//  타입마다 빈 질의를 한 번씩 던진다. 타입이 없으면 CloudKit이 `unknownItem`으로
//  "Did not find record type"이라고 답한다. 그게 곧 '미배포'라는 뜻이다.
//
//  ⚠️ 판정을 못 한 것과 '없다'를 절대 섞지 않는다. 네트워크가 끊겼거나 질의 색인이
//     없어서 실패한 것을 '없음'으로 적으면, 멀쩡한 스키마를 배포하러 가게 만든다.
//     그래서 아는 코드만 이름을 붙이고 나머지는 원문을 그대로 보여준다.
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

    enum Result: Equatable {
        /// 타입이 있다. 질의가 통했다.
        case present
        /// 타입이 없다 — Production에 배포되지 않았다.
        case missing
        /// 존 자체가 없다. 아직 아무것도 안 올라간 상태다(타입 유무는 알 수 없다).
        case noZone
        /// 판정 못 함. 사유를 그대로 들고 있는다.
        case unknown(String)

        var label: String {
            switch self {
            case .present:          return "있음"
            case .missing:          return "없음 — 미배포"
            case .noZone:           return "존 없음"
            case .unknown(let why): return "확인 불가 (\(why))"
            }
        }

        /// 빨갛게 보여야 하는 답인지.
        var isProblem: Bool {
            if case .missing = self { return true }
            return false
        }
    }

    /// 여섯 타입을 차례로 물어본다. 한 번에 몰아 던지지 않는다 —
    /// 진단 한 번이 네트워크를 몰아치면 그것대로 결과가 흔들린다.
    static func probeAll() async -> [(type: String, result: Result)] {
        let database = CKContainer(identifier: WeekBlocksStore.containerID).privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        var out: [(String, Result)] = []
        for type in recordTypes {
            out.append((type, await probe(type, in: database, zoneID: zoneID)))
        }
        return out
    }

    private static func probe(_ type: String,
                              in database: CKDatabase,
                              zoneID: CKRecordZone.ID) async -> Result
    {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        do {
            // 한 건만, 값은 안 받는다. 있는지 없는지만 알면 된다.
            _ = try await database.records(matching: query, inZoneWith: zoneID,
                                           desiredKeys: [], resultsLimit: 1)
            return .present
        } catch let error as CKError {
            switch error.code {
            case .unknownItem:
                // CloudKit이 타입을 모른다 = Production에 없다.
                return .missing
            case .zoneNotFound, .userDeletedZone:
                return .noZone
            case .notAuthenticated:
                return .unknown("iCloud 로그인 안 됨")
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
                return .unknown("네트워크")
            case .invalidArguments:
                // 질의 색인이 없을 때도 여기로 온다. **타입이 없다는 뜻이 아니다** —
                // CloudKit이 타입을 모르면 그 전에 unknownItem으로 걸린다.
                return .unknown("질의 불가(색인 없음) — 타입 자체는 있는 것으로 본다")
            default:
                return .unknown("CKError \(error.code.rawValue)")
            }
        } catch {
            return .unknown(String(describing: error))
        }
    }
}
