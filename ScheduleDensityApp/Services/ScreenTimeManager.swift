//
//  ScreenTimeManager.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-11-14.
//

import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

// 스크린 타임 앱 카테고리
struct ScreenTimeCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let totalMinutes: Int

    var hours: Double {
        Double(totalMinutes) / 60.0
    }
}

@Observable
class ScreenTimeManager {
    var isAuthorized = false
    var categories: [ScreenTimeCategory] = []
    var errorMessage: String?

    private let center = AuthorizationCenter.shared

    // 권한 상태 확인
    func checkAuthorization() {
        isAuthorized = (center.authorizationStatus == .approved)
    }

    // 권한 요청
    func requestAuthorization() async throws {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                isAuthorized = (center.authorizationStatus == .approved)
                print("✅ Screen Time 권한 승인됨")
            }
        } catch {
            await MainActor.run {
                errorMessage = "권한 요청 실패: \(error.localizedDescription)"
                print("❌ Screen Time 권한 거부됨: \(error)")
            }
            throw error
        }
    }

    // 스크린 타임 데이터 가져오기 (시뮬레이션)
    // 실제로는 DeviceActivityReport를 사용해야 하지만, 이는 extension에서만 작동
    // 따라서 여기서는 예시 데이터를 생성합니다
    func fetchScreenTimeData() async {
        await MainActor.run {
            // 실제 API에서는 지난 7일간의 평균을 계산
            // 여기서는 예시 데이터 생성
            categories = [
                ScreenTimeCategory(
                    name: "소셜 미디어",
                    icon: "bubble.left.and.bubble.right.fill",
                    totalMinutes: 120  // 2시간
                ),
                ScreenTimeCategory(
                    name: "엔터테인먼트",
                    icon: "play.rectangle.fill",
                    totalMinutes: 90   // 1.5시간
                ),
                ScreenTimeCategory(
                    name: "게임",
                    icon: "gamecontroller.fill",
                    totalMinutes: 60   // 1시간
                ),
                ScreenTimeCategory(
                    name: "생산성",
                    icon: "briefcase.fill",
                    totalMinutes: 45   // 0.75시간
                ),
                ScreenTimeCategory(
                    name: "웹 브라우징",
                    icon: "safari.fill",
                    totalMinutes: 30   // 0.5시간
                )
            ]

            print("📊 Screen Time 데이터 로드됨: \(categories.count)개 카테고리")
        }
    }
}
