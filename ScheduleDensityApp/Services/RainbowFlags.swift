//
//  RainbowFlags.swift
//  ScheduleDensityApp
//
//  **심사를 기다리지 않고 끌 수 있는 기능들** (원격 킬스위치, LeeoRemoteFlags).
//
//  피드백 허브와 같은 CloudKit 공개 DB의 레코드 하나(`flags_com.example.ScheduleDensityApp`)를
//  읽는다. 받아 오는 것은 켬/끔 값뿐이고 **이 기기에서 나가는 것은 없다** — 그래서 사용 통계
//  동의와 상관없이 읽어도 된다(개인정보 처리방침 6항의 "켜야만 나간다"와 어긋나지 않는다).
//
//  ⚠️ **조회 실패 = 켬.** 네트워크가 없다고 기능이 꺼지면 킬스위치가 장애 원인이 된다.
//  ⚠️ rawValue 가 곧 CloudKit 필드 이름이다. 이름을 바꾸면 대시보드에서 꺼도 앱은 켠 채로 돈다.
//  ⚠️ 끄는 것은 **기능**이지 데이터가 아니다. 꺼져 있는 동안에도 적어 둔 것은 그대로 남는다.
//
//  대시보드: 레코드 타입 `RemoteFlags`, 필드는 아래 rawValue 를 Int64(1=켬, 0=끔)로.
//

import Foundation
import LeeoKit

enum RainbowFlag: String, LeeoRemoteFlag, CaseIterable {
    /// 무지개 일정을 맥 '무지개 공방'과 함께 쓰는 사본과 맞추는 일 (→ RainbowBridge).
    /// 양쪽 스토어를 고치는 유일한 자동 경로라, 잘못 돌면 일정이 불어나거나 사라진다.
    case macBridge
    /// 시스템 캘린더의 일정을 무지개에 비추는 일 (→ CalendarMirror).
    /// EventKit 이 OS 업데이트로 다르게 굴면 무지개 탭 전체가 느려지거나 멈춘다.
    case calendarMirror
    /// 사용 통계를 허브로 보내는 일 (→ UsageReporting). 동의한 사람의 것만 나가지만,
    /// 허브 쪽 스키마가 바뀌는 동안 오류가 쏟아지면 잠깐 막을 수 있어야 한다.
    case usageReporting

    /// 지금 켜져 있는가. 네트워크를 타지 않고 캐시만 본다.
    var isOn: Bool { LeeoRemoteFlags.isEnabled(self) }
}

enum RainbowRemoteFlags {
    /// ⚠️ 인스턴스를 붙잡아 둔다. `refreshInBackground` 는 약한 참조로 조회를 띄우므로,
    ///    그 자리에서 만들고 버리면 조회가 시작되기도 전에 사라진다.
    private static let remote = LeeoRemoteFlags(spec: ScheduleDensityAppSpec.self)

    /// 앱이 뜰 때 한 번. 6시간 안에 받아 둔 값이 있으면 아무것도 하지 않는다.
    static func refresh() {
        remote.refreshInBackground(RainbowFlag.self)
    }
}
