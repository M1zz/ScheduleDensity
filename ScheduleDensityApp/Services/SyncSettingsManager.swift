//
//  SyncSettingsManager.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-22.
//

import Foundation
import SwiftUI

@Observable
class SyncSettingsManager {
    static let shared = SyncSettingsManager()

    private let syncEnabledKey = "iCloudSyncEnabled"
    private let lastSyncDateKey = "lastSyncDate"

    var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: syncEnabledKey)
        }
    }

    var lastSyncDate: Date? {
        didSet {
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncDateKey)
        }
    }

    private init() {
        // 기본값은 동기화 꺼짐
        self.isSyncEnabled = UserDefaults.standard.object(forKey: syncEnabledKey) as? Bool ?? false
        self.lastSyncDate = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date
    }

    func toggleSync() {
        isSyncEnabled.toggle()
    }

    func updateLastSyncDate() {
        lastSyncDate = Date()
    }

    var lastSyncDateString: String {
        guard let date = lastSyncDate else {
            return "동기화된 적 없음"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
