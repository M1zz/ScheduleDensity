//
//  PressHaptics.swift
//  ScheduleDensityApp
//
//  꾹 누르는 "동안" 계속 울리는 진동.
//
//  완료되는 순간에만 한 번 울리면, 손가락은 그때까지 아무 대답도 못 듣는다.
//  누르고 있는 내내 점점 세지는 진동이 있어야 "지금 잘 누르고 있구나"가 손으로 전해진다.
//

import CoreHaptics
import UIKit

/// 길게 누르는 동안의 연속 진동. 화면 어디서든 한 번에 하나만 울린다.
final class PressHaptics {
    static let shared = PressHaptics()

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    /// Core Haptics를 못 쓰는 기기에서 쓰는 대체 수단 — 약한 충격을 촘촘히 반복한다.
    private var fallbackTimer: Timer?
    private var fallbackStart: Date?

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {}

    /// 누르기 시작. `duration` 동안 점점 세지는 "드드드드드" 진동을 낸다.
    func begin(duration: TimeInterval) {
        stop()
        guard supportsHaptics else {
            beginFallback(duration: duration)
            return
        }

        do {
            let engine = try resolvedEngine()
            let pattern = try CHHapticPattern(events: rattleEvents(duration: duration), parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            self.player = player
        } catch {
            // 엔진이 안 뜨면 진동만 없을 뿐, 누르는 동작 자체는 그대로 되어야 한다.
            beginFallback(duration: duration)
        }
    }

    /// 촘촘한 딱딱임 + 그 사이를 메우는 낮은 진동.
    /// 매끈하게 이어지는 한 줄기 진동은 손끝에서 거의 안 느껴진다.
    /// 짧은 타격을 촘촘히 이어 붙여야 "드드드드드"로 잡힌다.
    private func rattleEvents(duration: TimeInterval) -> [CHHapticEvent] {
        var events: [CHHapticEvent] = []

        // 사이를 메우는 바닥 진동. 딱딱임만 있으면 사이가 비어 뚝뚝 끊겨 들린다.
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ],
            relativeTime: 0,
            duration: duration
        ))

        // 40ms 간격이면 초당 25번 — 하나하나가 아니라 한 줄기 떨림으로 느껴진다.
        let interval = 0.04
        var time = 0.0
        while time < duration {
            let progress = Float(time / duration)
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    // 처음부터 충분히 세게, 다 찰수록 더 세게.
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7 + 0.3 * progress),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65 + 0.35 * progress)
                ],
                relativeTime: time
            ))
            time += interval
        }
        return events
    }

    /// 손을 떼거나 완료됐을 때. 울리던 진동을 즉시 끊는다.
    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        fallbackStart = nil
    }

    /// 다 눌러서 실제로 잡혔을 때의 딱 소리. 차오르던 떨림을 끊고 한 번 세게 때린다.
    func complete() {
        stop()
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    // MARK: - 내부

    private func resolvedEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        let engine = try CHHapticEngine()
        // 앱이 백그라운드에 다녀오면 엔진이 멈춘다. 멈춘 엔진을 계속 쓰면 조용히 아무 일도 안 난다.
        engine.stoppedHandler = { [weak self] _ in self?.engine = nil }
        engine.resetHandler = { [weak self] in
            self?.engine = nil
            self?.player = nil
        }
        engine.playsHapticsOnly = true
        try engine.start()
        self.engine = engine
        return engine
    }

    private func beginFallback(duration: TimeInterval) {
        // Core Haptics가 없으면 짧은 타격을 되도록 촘촘히 반복하는 수밖에 없다.
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        let start = Date()
        fallbackStart = start
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self, let start = self.fallbackStart else {
                timer.invalidate()
                return
            }
            let progress = min(1, Date().timeIntervalSince(start) / duration)
            generator.impactOccurred(intensity: 0.7 + 0.3 * progress)
        }
    }
}
