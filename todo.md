# ScheduleDensity 패밀리 — 할 일 목록

iOS 앱(ScheduleDensity)과 macOS 앱(WeekBlocks)을 하나의 Xcode 프로젝트에서
두 개의 타깃으로 관리하는 "같은 패밀리" 구조.

## 완료
- [x] 맥 계획표에 쓰는 길을 아예 없앰 (2026-09-03)
      "아이폰에서 만든 것은 맥에서 할 일에만 들어가고 어디에도 배정하지 말 것."
      확인해 보니 **이미 아무도 안 부르는 죽은 코드**였다(2026-08에 뜻이 틀려서 걷어냄).
      그래도 남겨 두면 다시 불리는 자리가 되므로 지웠다:
      `syncToday` / `assign` / `unassign` / `autoAssignedTitles` / `timeBand`.
      - 남은 것은 `titlesAssigned` 하나 — **읽기 전용**이고 위젯이 쓴다
      - 폰에서 적은 것은 맥의 `BacklogItem` 목록에만 들어간다. 어느 칸에 놓을지는
        맥에서 사람이 정한다
      - ⚠️ 다시 열더라도 **제목으로 맞추지 말 것.** PlanBlock 에 dragToken 같은
        안정적인 열쇠가 실린 뒤에 연다 — 제목으로 맞추면 맥에서 손으로 만든 블록을
        건드린다(전에 실제로 지웠다)

- [x] 사용 통계 — 앱 안에서 보고, 켜야만 나간다 (2026-09-03)
      "왜 사용 데이터 수집해서 통계로 안 보내?" → **안 하고 있던 게 아니라 안 하겠다고
      써 붙여 둔 상태였다** (privacy.html: "수집하거나 전송하지 않습니다").
      그리고 LeeoKit 에 `Usage/LeeoUsageReporter`·`LeeoUsageStatsView` 가 이미 있는데
      이 앱만 안 붙이고 있었다(`registerLaunch()` 만 부르고 report 는 안 했다).
      - `UsageDiary` — 앱을 연 **날짜만** App Group 에 적는다. 연속 일수·최근 30일
      - `UsageStats` — 꾸준함 / 쪼개기 습관 / 완주율 / 어디에 시간이 갔나
        `metrics` 는 **숫자만** 낸다. 분류 이름조차 안 보낸다(직접 지은 이름이라 사생활)
      - `UsageReporting` — 동의 스위치. **기본 꺼짐.** 끄면 적어 둔 날짜도 함께 버린다
      - `UsageStatsView` — 설정 > 사용 통계. **무료다** — 안에 동의 토글이 있는데
        페이월 뒤에 두면 돈 낸 사람에게만 동의를 묻는 꼴이 된다
      - privacy.html 6항 신설, 최종 업데이트 2026-09-03
      - ⚠️ App Store Connect 개인정보 라벨도 같이 고쳐야 한다 (선택적 사용 데이터)
      - ⚠️ CloudKit Dashboard 에 UsageSnapshot / UsageEvent 레코드 타입을
        Production 에 배포해야 실제로 쌓인다

- [x] 이름을 '무지개 Pro'로 (2026-09-03) — 설정·페이월·위젯 잠금 문구·Products.storekit
      ⚠️ App Store Connect 의 앱 내 구입 **표시 이름도 같이 바꿔야** 실제 결제 시트와
         앱 안의 말이 일치한다. 코드만으로는 안 된다.

- [x] `openMyItems` 가 전환에서만 돌던 것 (2026-09-03)
      `.onChange(of: purchases.isUnlocked)` 하나에만 걸려 있었다. 다른 기기에서 샀거나,
      지웠다 다시 깔았거나, 개발 빌드(`unlockedInDebug`)면 앱이 **이미 열린 채로 떠서**
      전환이 안 일어난다 → 잠겨 있을 때 적어 둔 줄이 영영 `isShared` 도장을 못 받고,
      그러면 맥에서 안 보인다. 켤 때도 한 번 부르게 했다(비어 있으면 무일).

- [x] 할 일 삭제 — 묻고, 딸린 것까지 함께 (2026-09-03)
      **"지웠는데 계속 나온다"의 범인.** 지우는 자리가 넷인데 하는 일이 다 달랐다:
        목록 스와이프        하위 단계 O  무지개 줄 O  확인 X
        길게 눌러 '삭제'     하위 단계 X  무지개 줄 X  확인 X  ← 여기
        상세의 스와이프      하위 단계 O  무지개 줄 X  확인 X
        완료 목록 스와이프    하위 단계 O  무지개 줄 X  확인 X
      메뉴의 '삭제'는 `context.delete(item)` 한 줄이라 하위 단계가 고아로 남고
      무지개에 그어 둔 Event 도 그대로 남았다. 그 Event 는 iOS 쪽 일정 스토어에만
      있어서 **맥에는 안 보이고 아이폰에만 보인다** — 사용자가 말한 그 증상이다.
      - `TodoDeletion.swift` 신설. 네 자리가 전부 이 한 함수를 지난다.
        무지개 줄 먼저, 할 일은 그 다음 (일정 삭제와 같은 순서)
      - 물음은 세어서 말한다 — "단계 3개도 함께 지웁니다 / 무지개 줄도 없어집니다"
      - `TodoEventBridge.clearRainbow`를 async + Result 로. 못 지웠으면 그 사실이
        올라온다. 조용히 삼키면 지운 줄 알았던 것이 무지개에 남는다
      - ⚠️ 이미 생긴 고아 Event 는 이 수정으로 안 사라진다. 일정 관리에서 지워야 한다

- [x] 일정 삭제 — 묻고 나서, 클라우드까지 (2026-09-03)
      전에는 스와이프 두 곳이 **묻지도 않고 지웠고**, iCloud 삭제는 실패해도 조용했다.
      `deleteEventFromCloudKit`이 동기화 꺼짐·iCloud 못 닿음·recordName 없음 세 경우에
      말없이 건너뛰는데, 로컬 삭제는 그와 무관하게 진행됐다 → 좀비 레코드가 남아
      다음 동기화에 되살아난다.
      - `EventDeletion.swift` 신설. 무슨 일이 벌어지는지(`bothSides`/`localOnly`/
        `syncOff`/`unreachable`)와 문구, `.confirmsEventDeletion` 모디파이어를 한 곳에
      - `ScheduleViewModel.deleteEvent`를 async 로. **iCloud 먼저, 이 기기는 그 다음.**
        저쪽이 실패하면 로컬도 안 지운다 — 순서가 이 함수의 전부다
      - `unreachable`이면 아예 막는다. 지워도 되살아나는 것은 삭제가 아니다
      - `CKError.unknownItem`은 성공으로 친다. 다른 기기가 먼저 지운 것을 실패로 읽으면
        이쪽에서는 영영 못 지우는 줄이 남는다
      - 지우는 자리 여섯 곳(관리 스와이프·하루 스와이프·길게 누르기·편집 화면·
        관리 전체삭제·설정 전체삭제)이 전부 같은 물음을 쓴다
      - `TodoEventBridge.clearRainbow`만 안 묻는다. 할 일 쪽에서 이미 답한 뒤라 잔소리다

- [x] 죽은 잠금 게이트 걷어내기 (2026-09-03) — `TodoAccess.canEdit` 폐기
      0a03eec가 canEdit을 항상 참으로 바꿔 두고 "지우는 것은 한 번에 하라"고 남긴 것을 지운다.
      - TodoView·TodoDetailView·DoneTodosView·TodoShareIntake의 `if canEdit` 40여 곳 제거.
        전부 열린 쪽으로만 흐르던 자리라 동작은 그대로다
      - `pendingSharedCount` 삭제 — 상자는 이제 늘 비워지므로 항상 0이었다
      - `editingPaywall`은 TodoView에만 남는다. 거기서만 살아 있는 길
        (건너가기 안내 줄 → 페이월)이고, 나머지 둘에서는 죽은 상태였다
      - TodoAccess 머리말이 아직 "선을 '적기'에 그었다"고 말하고 있어 다시 썼다

- [x] 유예(grandfather) 폐기 — 열림/잠김의 조건은 '샀는가' 하나 (2026-09-03)
      무료였던 앱이 유료가 된 것뿐이다. '쓰던 사람인가'라는 두 번째 질문을 없앤다.
      - 그 질문의 자격을 **로컬 데이터 개수**로 추측했는데, 할 일 스토어가 CloudKit
        미러(`WeekBlocksStore.sharedContainer`)라 동기화 타이밍이 결제 여부를 흔들었다.
        판정은 한 번뿐이고 도장을 먼저 찍어서, 한 번 어긋나면 되돌릴 길도 없었다
      - `ProEntitlement`: `grandfatheredKey`·`grandfatherCheckedKey`·
        `grandfathersExistingUsers`·`grandfatherIfNeeded`·`isGrandfathered` 삭제.
        `isUnlocked`는 `pro.purchased` 한 줄만 본다
      - `PurchaseManager.grandfatherIfNeeded` 삭제
      - `ScheduleDensityApp.grandfatherExistingUserIfNeeded` 삭제,
        `.task`는 `refresh()` 하나만 부른다
      - `SettingsView`: '쓰던 분이라…' 문구 삭제
      - ⚠️ **이미 1.1.0을 켜서 유예를 받은 사람은 이 업데이트로 잠긴다.** 알고 버린 것이다
      - 리베이스로 '파는 것은 건너가기다'(0a03eec) 위에 얹었다. 그쪽이 `sellsEditing`을
        폐기하고 `ProEntitlement.sellsSync`로 옮겼으므로, 유예 폐기는 그 위에서 그대로 선다

- [x] 잠금의 진실을 한 벌로 합침 (2026-09-03) — "적기는 되는데 설정은 '무료 버전'"
      증상: 실시간으로 App Group을 읽는 쪽(`TodoAccess.canEdit`, 위젯 3종)은 열려 있는데
      캐시를 읽는 쪽(설정 라벨·일정 통계·캘린더 가져오기·공유 탭·회수 장부)만 잠긴 채였다.
      원인: `PurchaseManager.isUnlocked`가 싱글턴 생성 때 한 번 읽고 캐시하는 저장 프로퍼티였다.
      유예(grandfather)는 앱이 뜬 **뒤** `.task`에서 켜지고, 캐시를 고치는 `apply`는
      `refresh()`의 `Transaction.currentEntitlements` 조회가 끝나야 불린다.
      그 조회가 늦으면(망이 느리거나 App Store에 못 닿으면) 그 실행 내내 캐시만 낡은 채 남는다.
      - `PurchaseManager.isUnlocked`를 계산 프로퍼티로 — `ProEntitlement.isUnlocked`를 그대로 비춘다.
        `access(keyPath:)`로 관찰을 걸고, 값이 실제로 바뀔 때만 `withMutation`으로 알린다
      - `mutatingEntitlement(_:)` 신설: App Group의 한 줄을 고치는 일은 전부 여기를 지난다.
        위젯 새로 그리기도 여기로 모았다
      - `PurchaseManager.grandfatherIfNeeded(hasExistingData:)` 신설.
        `ScheduleDensityApp`이 `ProEntitlement`를 직접 부르지 않고 이쪽을 거친다 —
        직접 부르면 화면에 알려 줄 사람이 없어 그 어긋남이 그대로 돌아온다
      - `ProEntitlement`의 두 쓰기 함수에 "PurchaseManager만 부른다" 경고 주석

- [x] '적기' 판매 개시 — `TodoAccess.sellsEditing` = true (2026-09-02, 1.1.0)
      - 이번 버전부터 실제로 판다. 안 산 기기는 읽기 전용, 잠기는 것 6가지
      - 유예(`grandfathersExistingUsers = true`)와 반드시 함께 켜져 있어야 한다 —
        끄면 1.0.9까지 무료로 적던 사람들이 이 업데이트로 못 적게 된다
      - `ProFeature.sold` 신설(TodoAccess.swift): 페이월·설정이 `allCases`가 아니라
        '오늘 파는 것'을 읽는다. 스위치 하나로 5↔6이 저절로 바뀐다

- [x] 잠금이 새던 자리 전부 막음 (2024 판매 개시에 딸림) — **읽기 전용으로 통일**
      기준: `canEdit`의 정의가 "적고 **고칠** 수 있는가"이고 완료 표시가 이미 잠겨 있었다.
      들어가서 **보는 길은 열어 둔다** (더 쪼개기, 쪼개기 도우미, 완료 목록 보기).
      - TodoView: 줄 눌러 완료/되돌리기(advance), 길게 눌러 뜨는 메뉴(itemMenu — 데드라인·
        '바로' 표시·무지개에서 빼기·되돌리기·분류·삭제), '무지개에 걸려 있는 일' 누르면
        새 할 일 생기던 것
      - TodoDetailView: 요약 카드 → 설정 시트(이름·시간·기간·분류), 단계 완료 토글,
        스와이프 삭제·이름, 순서 위/아래, 끌어 옮기기, 단계 적는 빈 줄, 접근성 동작
      - DoneTodosView: 통째로 열려 있었다 — 눌러 되돌리기, 밀어 지우기
      - 제어센터 '할 일 적기': 죽은 버튼이던 것 → 페이월
      - 공유 시트: `TodoShareIntake.drain`이 잠기면 **상자를 비우지 않는다**.
        `TodoShareInbox.pendingCount()` 신설, 잠금 안내에 "공유로 받아 둔 N개가
        기다리고 있습니다" 한 줄 — 조용히 버리면 공유가 고장 난 것으로 읽힌다

- [x] 공유(가족) 할 일도 같은 규칙으로 잠금 — **결제 안 하면 공유 못 한다**
      - 잠금: 공유 시작, 초대 링크 보내기, 목록 체크(toggle), 삭제, 적는 빈 줄
      - 열어 둠: 목록 보기, **공유 중지·나가기** — 값을 안 냈다고 이미 시작한 공유에서
        빠져나오지 못하면 그건 가두는 것이다
      - 잠긴 안내 줄(`readOnlyNotice`)을 두 목록이 함께 쓴다. 다만 내 목록에서만 뜻이 있는
        숫자(받은 상자·안 보이는 줄)는 `showsMyListCounts: false`로 끈다
      - 빈 화면 문구도 갈랐다: 잠기면 "초대하세요" 대신 "참여하는 것은 그대로 됩니다"

  잠금 규칙 한 줄: **보는 것과 빠져나오는 것은 되고, 적고 고치고 넓히는 것은 안 된다.**
  (위젯·일정 공유 탭은 원래부터 `purchases.isUnlocked`로 잠겨 있어 손대지 않았다)
- [x] 설정 맨 위에 "내 버전" 표시 (2026-09-02)
      - 무료인지 열려 있는지를 설정 첫 줄에서 답한다. 전에는 이 상태가 설정 바닥에 있어
        끝까지 내려가야 알 수 있었다 — 기존 '모두 열기' 섹션을 통째로 맨 위로 옮겼다.
      - 잠김: 자물쇠 + "무료 버전" + "무지개·쪼개기·두 질문·단계 순서는 그대로 쓰십니다,
        곁다리 N가지가 잠겨 있습니다" (N은 `ProFeature.allCases.count`에서 읽는다)
      - 열림: 초록 도장 + "모두 열림" + 산 것인지(`한 번 사서`) 유예인지(`쓰던 분이라`) 구분
      - 잠긴 기능 목록을 손으로 적던 것을 `ProFeature.allCases`에서 읽게 바꿈 —
        전에는 다섯 개만 적혀 있어 나중에 들어온 '이 기기에서 적기'가 빠져 있었다
- [x] 빌드 지뢰 제거 — `project.yml`의 `excludes` 목록 폐기 (2026-09-02)
      - 배경: 깨진 화면 5개를 타깃 소스에서 제외해 숨겨둔 상태였다. 빌드는 통과했지만
        제외 목록이 유일한 방어선이라, 재생성이나 파일 추가 한 번이면 11개 에러가 터졌다.
      - 삭제(대체돼 죽은 화면): `InsightCardsView.swift`(TimelineDensityView 1769~과 100% 동일),
        `WeekView.swift`(삭제된 `EventInstance`/`TimeSlot`에 의존),
        `RecommendationView.swift`(삭제된 `Recommendation` 타입 의존 — 추천 UI는 AddEventView로 옮겨감)
      - 수정 후 타깃 복귀: `DensityChartView.swift`(`getDensityData()` → `getAllDensityData()`),
        `WeekDensityView.swift`(`getWeekDensityData()` → `weekDensity()`, 중복 `EventListCard` 제거)
      - 두 파일에서 지역 `Color(hex:)` 재선언 제거 → `Shared/ColorHex.swift` 한 곳으로 통일
      - 경고 0으로: EventKit `.authorized`(iOS 17 deprecated) → `.fullAccess`,
        존재하지 않는 애셋을 가리키던 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` 제거
      - 검증: Debug 시뮬레이터 / Release 실기기 / 서명 아카이브 모두 에러·경고 0
- [x] WeekBlocks 소스를 `WeekBlocks/` 폴더로 흡수
- [x] `ScheduleDensityApp.xcodeproj`에 macOS 타깃 `WeekBlocks` 추가
- [x] WeekBlocks 타깃에 macOS 빌드 설정(SDKROOT/배포타깃) 오버라이드
- [x] 두 타깃 모두 빌드 성공 검증 (iOS / macOS)
- [x] 명명 전면 통일: macOS 번들 ID `com.devkoan.ScheduleDensityApp`, 표시이름 `ScheduleDensity`
- [x] WeekBlocks iCloud(CloudKit) 연동: 공유 컨테이너 `iCloud.com.devkoan.ScheduleDensity`
      (entitlements + SwiftData `cloudKitDatabase: .private(...)`, 빌드/서명 검증, 컨테이너 자동 등록됨)
- [x] iOS 기준 디자인 통일 (표시이름 "무지개 공방")
      - 컬러: `Theme.swift` 신설 — iOS laneColors와 동일한 7색 무지개 hex 팔레트 + `Color(hex:)` + 밀도 색 스케일
      - `paletteColor`/`routineColorOptions`를 iOS 시스템 색 hex로 통일, AccentColor = 시스템 블루 #007AFF
      - 톤: 전 UI 반말 → iOS 존댓말로 통일 (ContentView/BlockEditor/ConcretenessChecker/Backlog/Reflection/Routines)
      - UX: 툴바에 설정(gearshape)·더보기(ellipsis.circle: 루틴 추가/샘플/전체 삭제) 추가, `SettingsView` 신설(iOS Form/Section 미러링)

- [x] 고정 루틴 워크플로 강제 (macOS)
      - 고정 루틴 추가 시 주간 그리드에 자동 배치 (`onChange(routines.count)` → 즉시 occurrence 시딩)
      - 고정 루틴 삭제 잠금: RoutineRow 휴지통 → 잠금 아이콘, 편집기 삭제 버튼 숨김 (이름·요일 편집은 가능)
      - 게이트: 고정 루틴이 하나라도 있어야 백로그·계획 블록 추가 가능 (없으면 잠금 + 안내)
      - 레이아웃: 루틴 섹션을 그리드/백로그 위로 이동 (루틴 먼저 → 계획 흐름)
- [x] 요일별 하루 24시간 타임라인 (`DayTimelineView.swift`)
      - 7요일 가로 막대 + 0/6/12/18/24 축, 시간 격자(24칸)
      - 고정 루틴 정확한 시각 배치(자정 넘김 분할), 계획 블록은 시간대 빈 구간 패킹
      - 요일별 "자유 Xh"(초과 시 빨강) 표시
      - 절대 겹침 없음: 통합 그리디 패킹(루틴+계획 모두 통째로, 빈 구간에만 배치, 시각은 근사치)
- [x] 주간 쿼터 자동 계산 표시 (일 평균 + 회당)
      - Routine에 `sessionsPerDay`(하루 횟수) 추가, `dailyQuotaHours` + `formatDuration` 헬퍼
      - scheduleDescription: "주 17.5h · 일 평균 2시간 30분 · 회당 약 50분"
      - 편집기에 하루 횟수 스테퍼 + 실시간 계산 미리보기, 기본 식사 시드 = 3회

- [x] 백로그 주(week) 단위 재구성
      - BacklogItem에 weekStartDate 추가, 메인 백로그는 "이번 주"만 표시
      - "전체 백로그" 시트(AllBacklogView): 주별 그룹, 지난 주 미완료 → "이번 주로 가져오기", 헤더에 이월 개수 배지
      - "할 일 작성" 시트(BacklogComposerView): TODO식 입력(Enter 연속 추가), 행별 카테고리·시간 편집, 카테고리 관리 포함
      - 메인의 인라인 빠른추가 바 제거(동선 단축)

- [x] App Store 심사 Guideline 4(Design) 대응 — 창 닫은 뒤 다시 열기 (macOS)
      - `WeekBlocksApp.swift`: `WindowGroup` → `Window("무지개 공방", id: "main")` 단일 창 씬으로 교체
      - 윈도우 메뉴에 "무지개 공방" 항목이 자동 등록되어 창을 닫아도 메뉴/Dock 클릭으로 재오픈 가능
      - macOS 빌드 검증 완료

- [x] WeekBlocks 지원 페이지 제작 + GitHub Pages 배포
      - `docs/index.html`: 기능/사용법/FAQ/개인정보/문의 (무지개 팔레트·존댓말)
      - Pages 소스 = main `/docs`, URL https://m1zz.github.io/ScheduleDensity/
      - README(main·dev)에 지원 페이지 링크 추가

## 완료 (2026-07-08)
- [x] iOS 앱(ScheduleDensityApp)도 같은 공유 컨테이너로 iCloud 연동
      - entitlements `iCloud.com.devkoan.ScheduleDensity` + Background Modes(Remote notifications)
      - WeekBlocks 모델 6종을 iOS 타깃에 공유 컴파일, `cloudKitDatabase: .private(...)`
      - Event는 별도 로컬 전용 ModelConfiguration으로 유지 (CloudKit 미적용 — 기존 데이터 그대로)
- [x] iOS에 '할 일' 탭 추가 — 간단 Todo(내 할 일: 맥 백로그와 동기화, isCompleted 체크)
      - Event 스토어·WeekBlocksStore 미러와 분리된 별도 컨테이너("WeekBlocksTodos", BacklogItem·BacklogCategory만 CloudKit private)
- [x] 가족 공유 — CloudKit 커스텀 존("FamilyTodos") + 존 전체 CKShare
      - `FamilyShareStore.swift`(공용): 소유자=개인 DB, 참가자=공유 DB, 초대 링크(publicPermission .readWrite)
      - iOS: 할 일 탭 안 '가족' 세그먼트 / macOS: '가족 할 일' 섹션
      - 초대 수락: iOS SceneDelegate·macOS NSApplicationDelegate + `CKSharingSupported`
      - ⚠️ 프로덕션 배포 전 CloudKit Console에서 스키마 deploy 필요 (BacklogItem 새 필드 + FamilyTodo 레코드 타입)
- [x] 일정 공유(가족 공유와 별개, 사람 대 사람) — CloudKit 커스텀 존("SharedSchedule") + 존 전체 CKShare(읽기 전용)
      - `ScheduleShareStore.swift`: 내보내기=내 개인 DB 존에 Event 미러(전량 교체 publish), publicPermission `.readOnly`
      - 받기=공유 DB의 여러 존을 사람별로 묶어 읽기 전용 표시(`sharedWithMe`), 여러 명에게서 동시에 받기 가능
      - iOS: 새 '공유' 탭(`ScheduleShareView`) — 내 일정 공유/링크 보내기/업데이트/중지 + 공유받은 일정 사람별 조회
      - 초대 수락: SceneDelegate가 존 이름으로 라우팅(SharedSchedule→일정, FamilyTodos→할 일)
      - ⚠️ 프로덕션 배포 전 CloudKit Console에서 SharedEvent 레코드 타입 + SharedSchedule 존 스키마 deploy 필요
- [x] iCloud 컨테이너 통일 — Event 백업/복원(`CloudKitManager`)을 placeholder 컨테이너
      `iCloud.com.example.ScheduleDensityApp` → 메인 `iCloud.com.devkoan.ScheduleDensity`로 이전
      - entitlements에서 example 컨테이너 제거(더 이상 참조 없음)
      - 구 컨테이너 Event 백업은 `LegacyBackupMigrator`(일회성)가 앱 시작 시 새 컨테이너로 복사
- [x] 일회성 마이그레이션 — `LegacyBackupMigrator.swift`
      - example 컨테이너의 Event 레코드를 devkoan으로 복사(제목+시작+종료 키로 중복 방지, 성공 시 플래그로 재실행 차단)
      - 읽기 위해 entitlements에 example 컨테이너 **임시 재추가**(주석 표시)
      - ⚠️ DEPRECATE 예정: 파일 상단 체크리스트대로 파일·앱 시작 호출·example entitlement 제거

- [x] 번들 ID 실제 도메인으로 정리: `com.example.ScheduleDensityApp` → `com.devkoan.ScheduleDensityApp`
      (project.yml `bundleIdPrefix: com.devkoan`·`PRODUCT_BUNDLE_IDENTIFIER`)
      - FeedbackHub `appIdentifier`는 기존 피드백 데이터 연속성 위해 `com.example...` 유지(의도적)
      - ⚠️ 번들 ID 변경 = 앱 스토어상 새 앱 취급. 프로비저닝 프로필 재발급 필요할 수 있음

## 할 일 뎁스(단계) — 2026-08-22, iOS·맥 동시 구현 (양쪽 빌드 성공)
할 일 하나를 100%로 놓고, 그 안을 '일이 되어야 하는 순서대로' 쪼갠다.
체크로 끝내는 게 아니라 **탭하면 다음 단계로 바뀐다**. 비중은 예상 시간 비율로 자동.

- [x] 공유 코어 `TodoTree.swift` — 순수 로직, iOS `Shared/`와 맥 `WeekBlocks/`에 **같은 파일로 복제**
      (부모-자식 색인 / 잎 순서 / 시간 합 / 비중 / 진행률 / advance·rewind / 조상 롤업)
      - 비중 = 예상 시간 비율. 중첩되면 조상 비중이 곱해진다 (50% 안의 60% → 30%)
      - 부모 완료 = 자식 전부 완료(자동 롤업), 부모 시간 = 자식 시간 합(자동 재계산)
      - 부모가 사라진 고아 단계는 최상위로 취급, 순환 참조는 깊이 12에서 멈춤
      - swiftc 단독 검증 통과 (비중·진행률·탭 전진·되돌리기·시간 변경·순환)
- [x] 모델: `BacklogItem.parentToken: String?` 추가 (부모의 dragToken). 양쪽 동일
- [x] iOS 할 일 탭: 목록은 최상위만, 한 줄에 '지금 할 단계 + 진행률 + n단계 중 m번째'
      - 체크 원 탭 = 지금 단계 끝내고 다음으로 / 완료된 줄 다시 탭 = 마지막 단계 되돌리기
      - 줄을 누르면 `TodoDetailView` — 단계 트리, 추가·이름/시간 수정·순서 이동·삭제
      - '오늘로 배정'은 제목은 최상위 그대로(배지·취소가 계속 맞아야 함), 시간만 현재 단계 기준
- [x] 위젯: 스냅샷에 `stepTitle`·`progress` 추가(옛 스냅샷 호환), 홈 위젯 2줄·잠금 인라인에 단계 표시
- [x] 맥 백로그: 카드에 지금 할 단계·진행률, 카드의 단계 버튼/컨텍스트 메뉴로 전진·되돌리기
      - `TodoStepsView` 시트에서 단계 추가·시간(스테퍼)·순서·삭제
      - 요일로 드래그: 단계가 있으면 **지금 단계만** 블록으로 올리고 항목은 백로그에 남긴다
        (단계가 없는 할 일은 종전대로 통째로 옮겨지고 백로그에서 사라진다)
      - 할 일 작성 시트·전체 백로그도 최상위만 나열, 이월·삭제는 단계까지 통째로

- [ ] ⚠️ 배포 전 CloudKit Console에서 `BacklogItem.parentToken` 필드 스키마 deploy
- [ ] 런타임 검증 미완 — 실제 기기에서 맥↔아이폰 단계 동기화 확인 필요
- [ ] 가족 할 일(FamilyTodo, CKRecord 별도 타입)은 아직 1뎁스 그대로

### 쪼개기 도우미 — 조각 시간 연구 반영 (2026-08-23)
사용자가 감으로 쪼개지 않도록 앱이 판정과 힌트를 준다. 공유 코어 `TodoSplitAdvisor.swift`
(iOS `Shared/` ↔ 맥 `WeekBlocks/`, 같은 파일 복제).

- [x] 단계 판정: 조각(≤15분) / 짧은 덩어리 / 덩어리(≥45분) + 제목 낱말 사전
      - 시동 비용 큰 낱말(쓰기·구현·설계·학습…)이 조각 시간에 들어가면 경고 (Mark 2008, 재개 23분)
      - 2시간 넘는 잎 단계는 "한 번에 안 끝남" 경고 (Leroy 2009, 주의 잔여물)
      - 결정 낱말(정하기·고민·검토)은 조각에서 안 닫힘 → 덩어리로 안내
      - 몸 낱말(운동·스트레칭·계단)은 조각 OK (Stamatakis 2022 VILPA)
      - 배수구 낱말(SNS·유튜브·피드)은 "일이 아니라 조각이 새는 곳"
- [x] 구성 조언: 조각 단계 없음 / 마감(닫기) 단계 없음 / 너무 큰 단계 /
      짧게 잡힌 덩어리 작업 다수 / 결정이 작업 뒤에 있음 / 잘 쪼갠 경우 칭찬
- [x] 쪼개기 도우미 뼈대 4단계 (결정→준비→작업→마감) 한 번에 생성 — 양쪽
- [x] 표시: 단계 행·입력 중 실시간 판정·수정 시트(iOS)·맥 시트와 백로그 카드에 조각/덩어리 태그
      할 일 목록(iOS)·백로그 카드(맥)의 '지금 할 단계'에도 태그 → 5분 생겼을 때 집을 것이 보인다
- [x] swiftc 단독 검증 (판정 10종·구성 조언 3종)
- [x] (아이디어) "지금 5분 있어요" 필터 — 아래 라벨 필터로 구현

### 시간을 위에서 아래로 + 라벨 (2026-08-23)
"상위 일이 몇 시간 걸리는지 예상치를 꼭 받고, 하위 일들이 그걸 나눠 가진다."
시간의 방향이 뒤집혔다 — 전에는 부모 시간 = 자식들 합(아래→위)이었다.

- [x] `TodoTree` 예산 계산 재작성 (양쪽 레포 동일 파일)
      - 부모의 예상 시간이 100%. 자식들의 합은 **언제나** 부모의 시간
      - 새 단계는 기본 N분의 1 (`giveInitialShare`), 첫 단계는 부모 전체를 물려받음
      - 한 단계를 직접 조정하면(`setHours`/`setWeight`) 나머지가 남은 몫을 다시 나눔 → 합계 100%
      - 직접 정한 단계는 `isManualWeight`로 잠기고 자동 재분배에서 빠짐 (`releaseManual`로 해제)
      - `setTotalHours` = 전체 시간 변경 시 아래 단계들이 비율 유지한 채 함께 조정
      - `splitEvenly`(N분의 1 리셋) / `fit`(삭제·동기화 어긋남 복구)
      - 분 단위 정수 계산 + 남는 분 앞에서부터 배분 → 60분을 7단계로 나눠도 합이 정확히 100%
      - `rollUp`은 완료 상태만 굴린다(시간은 더 이상 위로 안 올라감), `syncHours` 제거
      - swiftc 단독 검증 통과 (N분의 1·직접 조정·잠금 유지·전체 시간 변경·나머지 분·삭제·리셋·진행률)
- [x] 라벨 = 예상 시간 (`TodoLabel`: 지금 바로 15분 / 앉아서 한 번 30분 / 집중 한 판 1시간 /
      시간 잡고 2시간 / 반나절 4시간). 적을 때 **반드시 하나 고르게** 해서 예상치를 꼭 받는다
      - 모델: `BacklogItem.labelRaw`·`isManualWeight` 추가 (옵셔널/기본값 = 라이트웨이트 마이그레이션)
      - 라벨 없는 옛 항목은 예상 시간에서 가장 가까운 라벨로 짐작 (`TodoLabel.nearest`)
- [x] 화면을 '라벨 먼저'로 — 작은 조언 글이 너무 많아 바로 못 하던 문제
      - 목록·단계 행에 라벨 칩(아이콘+이름+시간), 단계 행에 비중 막대 + 큰 % 숫자
      - 긴 쪼개기 조언은 접어 두고(경고 개수만 표시), 행에는 경고 한 줄만
      - iOS 상세 헤더에서 전체 예상 시간을 바로 고침, 단계 섹션에 'N분의 1로' 버튼
      - 단계 추가 시 '자동 N분의 1' 또는 라벨을 골라 그만큼 떼어 주기
- [x] "지금 5분 있어요" 필터 — 목록 위 라벨 칩으로 걸러 보기 (지금 할 단계의 라벨 기준)
- [ ] ⚠️ 배포 전 CloudKit Console에서 `BacklogItem.labelRaw`·`isManualWeight` 스키마 deploy
- [ ] 런타임 검증 미완 — 실기기에서 맥↔아이폰 비중·라벨 동기화 확인 필요


### 조언은 전부 TipKit으로 (2026-08-23)
화면에 조언을 상시로 깔면 정보가 많아 못 시작한다. 알려줘야 하는 건 전부 팁으로 뺐다.
공유 파일 `TodoTips.swift` (iOS `Shared/` ↔ 맥 `WeekBlocks/`, 같은 내용 복제, 두 pbxproj에 등록).

- [x] `TodoTips.configure()` — 앱 진입점(`ScheduleDensityApp.init` / `WeekBlocksApp.init`)에서 한 번
      (`displayFrequency: .immediate` — 어차피 팁마다 한 번 닫으면 끝)
- [x] 규칙 있는 팁 (`@Parameter`로 조건 저장, 조건 맞을 때만 등장)
      - `LabelPickTip` — 라벨을 한 번도 안 골라봤을 때 "라벨이 곧 예상 시간입니다"
      - `FragmentFilterTip` — 할 일 3개 이상 쌓이면 "지금 10분 났을 때" 라벨 필터 안내
      - `ShareSplitTip` — 단계가 둘 이상 생기면 N분의 1·합계 100% 규칙 설명
      - `LockedShareTip` — 비중을 처음 직접 정하면 자물쇠의 뜻 설명
- [x] 내용이 그때그때 다른 팁 (id를 종류별로 따로 둬서, 닫으면 **그 종류만** 안 뜬다)
      - `SplitHintTip` — 구성 조언(`SplitHint`) 중 가장 중요한 하나. `SplitHint.code` 신설이 팁 id
      - `StepWarningTip` — 단계 경고는 **지금 할 단계 하나**에만. 모든 줄에 깔지 않는다
- [x] 걷어낸 것: 상세 화면의 '쪼개기 조언' 섹션(DisclosureGroup)과 `HintRow`,
      단계 줄마다 붙던 경고·이유 문구, 입력 중 실시간 판정 문구
- [x] 팁이 이미 닫힌 자리에 빈 줄이 남지 않도록 `shouldDisplay`로 걸러서 그린다
- [x] 설정 > 조언 > '할 일 조언 다시 보기' (`Tips.resetDatastore`) — 양쪽 앱
- [x] 시뮬레이터 실행 확인: TipKit 데이터스토어 로드 OK, 실행 중 오류 없음
- [ ] 팁이 실제로 뜨는 모습은 손으로 확인 필요 (입력창에 제목 입력 → 라벨 줄 위)

## 적는 자리를 목록 안으로 (2026-08-24) — iOS 빌드·시뮬레이터 확인

하단 입력 바에 적으면 '폼을 채워 제출하는' 느낌이라 목록에 한 줄 얹는 감이 안 났다.
미리 알림처럼 **목록 맨 아래 빈 줄**에 바로 적는 방식으로 바꿨다.

- [x] TodoView: `.safeAreaInset(.bottom)` 입력 바 제거 → '이번 주' 섹션 끝의 `newTodoRow`
      - 라벨 필수(추가 버튼 비활성) 해제. 라벨은 줄 안 칩 메뉴이고 지난 값이 따라온다(`@AppStorage`)
      - 필터가 걸려 있으면 새 줄도 그 라벨을 따라간다 (적은 게 필터에 걸려 사라지지 않게)
      - 엔터 = 한 줄 확정 + 빈 줄 유지 / 빈 줄에서 엔터 = 키보드 내림
      - 툴바 `+`는 빈 줄로 포커스, ScrollViewReader로 빈 줄을 계속 보이게 따라감
      - '할 일이 없습니다' 빈 화면 제거 — 빈 줄 자체가 적는 자리다(섹션 footer로 안내)
- [x] TodoDetailView: 같은 방식으로 단계 목록 끝에 `newStepRow`
      - 몫은 '자동 N분의 1' 기본 + 칩 메뉴로 라벨 선택. 하위 단계는 들여쓰기로 표시
      - '첫 단계 추가하기' 버튼 제거(빈 줄이 대신), 쪼개기 도우미는 빈 줄 아래로
- [x] 팁이 입력 줄 위로 끼어들며 포커스가 풀리던 문제 — TipView를 입력 섹션 밖으로 빼고
      추가 후 다음 런루프에 포커스 재확보. `.scrollDismissesKeyboard(.interactively)`
- [x] LabelPickTip은 적기 시작한 뒤에만 (앱 켜자마자 뜨던 것 수정)

- [x] 빈 줄 안내말 '다음 단계' → '세부 단계'
- [x] 세부 단계 줄에 비중 슬라이더 (정적 막대를 대체)
      - 부모 안에서 차지할 몫을 5~100%(5단위)로 직접 끈다. 손을 뗀 순간에만 반영 —
        매 틱마다 저장하면 형제가 계속 다시 계산돼 손잡이가 튄다
      - `tree.setWeight` → 나머지 단계가 남은 몫을 다시 나눠 합계는 언제나 100%
      - 형제가 있을 때만 나온다 (혼자면 언제나 100%라 만질 게 없다)
      - 직접 정하면 자물쇠가 붙고, **자물쇠를 누르면** 자동 N분의 1로 돌아간다
        (팁이 이미 그렇게 말하고 있었는데 실제로는 눌리지 않았다)
      - 끄는 동안만 % 숫자가 뜨고, 값이 반영되면 지운다 — `onEditingChanged`의
        끝을 못 받는 경우가 있어 `onChange(of: shareInParent)`로 확실히 턴다

## 무지개에서 고정 루틴 빼기 (2026-08-24)
- [x] `WeekBlocksStore.loadVisualEvents`에서 **루틴을 종류 불문 전부 제외**(계획 블록만 그린다).
      처음엔 `kind == .fixed`만 뺐는데 '식사'가 그대로 보였다 — 쿼터 루틴은 시각이 유연해서
      7일 평균 부하 밴드로 **모든 요일에** 깔리기 때문. 고정이든 쿼터든 매일 바닥에 깔려
      이번 주에 정한 일의 밀도를 덮는다. 맥 타임라인에는 그대로 남는다.
      어댑터의 루틴 변환 코드는 그대로 두고 입력만 비웠다(되살리기 쉽게). 설정 토글 설명에도 명시.
- [ ] ⚠️ 실제 WeekBlocks 데이터가 있는 기기에서 눈으로 확인 필요 (시뮬레이터엔 미러 없음)

## 무지개를 종료일까지 이어 칠하기 (2026-08-24) — 시뮬레이터 확인

주 1회 연습이라도 두 달 뒤 공연이면 그 두 달은 이 일에 매여 있는 시간이다.
연습하는 날만 칠하면 무지개에서 그 두 달이 비어 보여, 실제로 짊어진 무게가 안 보였다.

- [x] `Event.spansOn(date:)` — 시작일~종료일(무한 반복이면 +365일) 안인지.
      요일·35일 패턴은 보지 않는다. 단 '이 날짜만 제외'로 손수 뺀 날은 뺀다.
- [x] `DayDensity.spanEvents` — 하는 날은 아니지만 기간 안인 이벤트들(시작일 순 고정).
      **`density`에는 넣지 않는다** — 그날 실제로 손을 쓰는 양이 아니라서,
      넣으면 자유시간 분석·추천·통계가 통째로 부풀어 버린다.
- [x] `DateRow.getEventForLane` → `(event, isOccurring)`.
      **하는 날이 우선** — 한 레인을 여러 일정이 번갈아 쓰는(gap filling) 경우
      진한 칸이 옅은 칸에 밀리면 안 된다.
- [x] `SpanFillBlock` — opacity 0.20, 기간 첫날·마지막날만 모서리를 둥글게.
      실제로 하는 날(`EventLaneBlock`, 0.65~1.0)이 먼저 읽히도록 충분히 옅게.
- [x] 설정 > '종료일까지 이어서 표시' (기본 켜짐, `fillSpanToEndDate`)
- 확인: 주 1회(수) · 2달짜리 일정 → 8/24~10/23이 옅게 이어지고 매주 수요일만 진하게,
  10/24부터는 빈칸. 매일 하는 일정(selectedWeekdays == nil)은 달라지는 게 없다.

## ⚠️ 두 레포 공유 모델 드리프트 (2026-08-22 확인)
맥에 `전파 계약`(287f17f)이 들어가면서 공유 모델이 갈라졌다. iOS는 아직 못 따라감:
- `BacklogItem` — 맥에만 전파 필드 13개 (needsBroadcast/deadline/latestDate/…)
- `PlanBlock` / `BacklogCategory` / `Routine` — 맥이 더 많음
- iOS에 없는 필드라 아이폰에서는 전파 항목이 그냥 일반 할 일로 보인다 (데이터는 안 깨짐)
- [ ] iOS에 전파 계약 모델·화면 반영 여부 결정 (모델만 맞출지, 화면까지 낼지)

## 정리 필요
- [ ] 기존 독립 프로젝트 `/Users/leeo/Documents/workspace/code/WeekBlocks` 제거 (이 저장소로 흡수 완료 후)
- [ ] (선택) WeekBlocks 내부 타깃/스킴명도 ScheduleDensity 계열로 변경 — Xcode에서 rename 권장(수기 pbxproj 위험)

## iOS 시각화 연동 (WeekBlocks 데이터 → 욕망의 무지개 밀도 뷰)
방향 확정: **같은 iCloud 계정(private DB)** 전제, iOS는 **읽기 전용 소비자**.
WeekBlocks `Routine`/`PlanBlock`을 메모리상 `Event`로 변환해 기존 밀도 파이프라인 재사용.

- [ ] 1. 공유 모델: `WeekBlocks/`의 `Models.swift`·`Routine.swift`·`PlanBlock.swift`(+필요 시 BacklogItem 등)를 iOS 타깃 멤버십에 추가 (복붙 금지, 단일 소스)
      - ⚠️ `Theme.swift`(Rainbow/Color(hex:))도 함께 필요 — iOS에 같은 헬퍼가 있으면 중복 정의 충돌 점검
- [ ] 2. 별도 읽기 전용 store: iOS에 WeekBlocks 모델용 `ModelConfiguration`(CloudKit private, 컨테이너 `iCloud.com.devkoan.ScheduleDensity`) 추가. 기존 `Event` store는 **그대로 둠**
      - entitlements에 iCloud/CloudKit + 컨테이너 ID + Background Modes(Remote notifications)
- [x] 3a. 어댑터 순수 코어: `WeekBlocksAdapter`(타깃 의존성 없음) — `WBRoutineInput`/`WBBlockInput` → `WBVisualEvent`
      - PlanBlock → 해당 주 단일일(weekStart+요일, hoursPerDay=durationHours)
      - Routine.fixed → 주간 반복(selectedWeekdays, hoursPerDay=durationHours)
      - Routine.quota → 7일 평균 부하 밴드(hoursPerDay=weeklyHours/7)
      - 요일 변환 mon0→iOS weekday, 날짜·색·필터 모두 swiftc로 단위 검증 통과 ✅
- [x] 1·2. 모델 공유·store: Models/Routine/PlanBlock을 iOS 타깃에 포함, Routine 색상헬퍼는 Theme(macOS)로 분리.
      `WeekBlocksStore`(Services) = 별도 읽기전용 CloudKit 컨테이너(`iCloud.com.devkoan.ScheduleDensity`), Event 스토어와 분리.
      entitlements 컨테이너 추가 + Background Modes(Remote notifications). pbxproj에 어댑터/스토어 정식 포함.
- [x] 3b. 배선: WeekBlocksStore.loadVisualEvents()가 Routine/PlanBlock→어댑터→[Event](insert 금지).
- [x] 4. 표시: ScheduleViewModel.fetchEvents()에 합쳐 투입(전 화면 반영) + SettingsView "무지개 공방 계획 표시" 토글(기본 ON).
- [ ] ⚠️ 런타임 검증 미완: 같은 iCloud 계정 실기기/시뮬레이터에서 Mac↔iOS 실제 동기화 확인 필요.
- [ ] 5. 동기화 상태: iCloud 미로그인/첫 다운로드 지연/오프라인 빈 상태 UI 처리, 원격 변경 시 갱신(현재는 캐시가 dataRefreshTrigger에만 반응).
- [ ] (개선) 어댑터가 쿼터를 7일 평균으로 뭉갬 → '하루 흐름'까지 보이려면 TimelineLayout 공유 코어화.
- [ ] 6. (보류) successCriteria·deliverable·reviewStatus 노출 여부 결정

## macOS(WeekBlocks) 피드백 반영 (2026-06-23) — macOS 빌드 성공
- [x] 1. 타임라인 격자 6h → 3h 세분화 (DayTimelineRow 격자 major 3h, HourAxis 0·3·6…24)
- [x] 2. 짧은 블록 텍스트 — 임계값 30→18 + minimumScaleFactor + 툴팁에 계획 이름 노출
- [x] 3. 유연 쿼터 대비 강화 — 고정 위에 겹칠 때 흰 테두리 링 + 채움 0.20→0.32
- [x] 4. '구체성 체크' 버튼 제거 — 편집기 진입 시 항상 실시간 피드백
- [x] 5. 계획 블록을 다른 요일로 드래그 이동 (BlockChip draggable + 드롭에서 day 변경)
- [x] 6. '이번 주 계획' 순서 = '요일별 하루' 타임라인 순서 일치
      - DayPlanItem을 occurrence 기반으로(고정/끼니세션/블록) 재정의, TimelineLayout.segments의 seg.start로 정렬
      - 자정 넘긴 고정 루틴(수면)은 조각마다 따로 → 위·아래 두 번 표시
      - 유연 쿼터(끼니)는 다른 일정과 안 겹치는 세션만 자기 시각에 표시(겹치면 접음), 부제에 세션 시각

## WeekBlocks 기능 백로그 (흡수)
- [ ] ConcretenessChecker Level 2 — 측정 가능 패턴 정규식
- [ ] ConcretenessChecker Level 3 — Claude API 판정
- [ ] 시간 그리드 / 블록 드래그 이동 / 반복 계획 블록
- [ ] 알림 / 메뉴바 위젯

## 공유 세그먼트 감추기 (2026-08-24)
- [x] 할 일 화면: 공유 중도 아니고 받은 공유 항목도 없으면 '내 할 일 / 공유' 세그먼트를 통째로 감춤
      (TodoView.showsFamilyTab / visibleTab, 공유가 끊기면 선택도 '내 할 일'로 복귀)
- [ ] ⚠️ 결과: 앱 안에서 '할 일 공유 시작'으로 들어갈 길이 없음 — 상대의 초대 링크로 참여해야 세그먼트가 다시 보임.
      내가 먼저 공유를 시작할 진입점이 필요해지면 설정에 항목 추가 검토.

## 조각 시간 연구 재점검 — 앱이 연구와 어긋나던 곳 고치기 (2026-08-25) — iOS 빌드·시뮬레이터 확인

판정 로직(TodoSplitAdvisor·TodoLabel)은 연구를 잘 옮겨 놨는데, 그 위에 얹힌 **집계와 추천**이
반대 방향으로 가고 있었다. 여섯 군데를 고쳤다.

### 1. 합계를 내지 않는다 (조각 ≠ 덩어리)
`TodoView` 헤더가 `items.reduce { totalHours }`로 **조각과 덩어리를 더해** 한 숫자로 보여줬다.
'바로 15분' 넷 + '몰입해서 1시간' = "2시간". 그 2시간은 어느 쪽으로도 쓸 수 없는 숫자다.
- [x] `TodoTree.tally(of:)` / `currentTally(of:)` + `LabelTally` 신설 — 착수 조건별로 갈라 세고
      **하나로 접지 않는다.** 정렬은 언제나 `TodoLabel` 선언 순서(항목이 줄어도 칩이 자리를 안 바꾸게).
- [x] 목록 헤더 = 개수만. 시간은 조건별 칩이 말한다. 상세 헤더의 "다 하면 N시간"도 '남은 몫' 칩으로 교체
- [x] `TodoLabelChip`에 `count` 추가 (개수·시간이 **한 조건 안에서만** 짝이 맞으므로 칩 안에 함께 둔다)

### 2. "지금 5분 있어요" 필터 복구
8/24 '적는 자리를 목록 안으로' 개편 때 필터 UI가 통째로 사라졌었다. `FragmentFilterTip`은
살아 있는데 `itemCount`를 세팅하는 데가 없어 **영영 안 뜨는 팁**이었고, 떴어도 없는 기능을 안내했다.
if-then 계획의 '만약' 쪽이 빠진 상태였다 (Gollwitzer & Sheeran 2006, d = .65).
- [x] 목록 위 칩 줄 = 갈라 센 셈이자 곧 필터. **셈과 필터가 같은 칩인 것이 요점** —
      "바로 2"를 보고 누르면 정확히 그 2줄이 남는다 (`currentTally` ↔ `facingStep` 기준을 맞췄다)
- [x] 셈은 언제나 필터 **이전** 집합으로 낸다 (걸러진 것으로 세면 다른 칩이 0이 되어 못 돌아온다)
- [x] 필터가 걸려 있으면 칩 줄을 반드시 남긴다 — 마지막 한 줄을 끝낸 순간 줄이 사라지면
      필터를 풀 길이 없어 목록이 빈 채로 잠긴다
- [x] 빈 줄의 조건도 필터를 따라가고, 다른 조건을 골라 적으면 필터를 푼다(방금 적은 게 안 사라지게)
- [x] `refreshTipRules`에서 `FragmentFilterTip.itemCount` 세팅

### 3. 라벨을 고르게 해놓고 낱말로 다시 판정하던 것
`hints(rootTitle:steps:)`가 `label`을 안 받아서, 사용자가 '바로'라고 골라 둔 단계를 앞에 두고도
제목에 조각 낱말이 없으면 "5분에 집을 단계가 없습니다"라고 했다.
- [x] `steps`에 `label` 추가. 조각/덩어리 판정과 '결정이 작업 뒤에 있다'는 **라벨이 정한다**
- [x] 낱말 사전은 **경고에만** 남긴다 (제목과 시간이 어긋나는 경우 — "원고 쓰기"에 15분)
- [x] 라벨을 안 고른 옛 항목은 낱말 폴백이 그대로 받아준다
- [x] swiftc 단독 검증 10종 통과 (라벨 우선·기다림은 조각 아님·decision-late·폴백·경고 유지)

### 4. 점유율 분모가 24시간이던 것 + 추천기의 상한
`getWeekInsights`는 `totalHours / 24.0`, 같은 파일 `analyzeFreeTime`은 `24 - sleep`.
**두 군데가 다른 분모**를 썼고, 6시간 잡힌 하루가 25% → "한가해요"로 읽혔다.
- [x] `LoadLevel` 신설 — 기준은 '꽉 찼나'가 아니라 **'80% 선을 넘었나'** (DeMarco, *Slack*:
      80→90%에서 대기 시간 2배, 100%에서 사실상 무한대). easy/normal/tight/over
- [x] `DayInsight.capacityHours` = 24 − 잘 시간. 점유율은 1.0을 넘을 수 있게 두고 막대만 자른다
- [x] 인사이트 카드 색·문구를 `LoadLevel`로 통일 (0.3/0.6 하드코딩 제거, 4장 × 2파일)
- [x] '가장 한가한 날' → '여유가 가장 많은 날' + 잡힌 시간 대신 **남은 여유**를 적는다
- [x] `recommendScheduleSlots`: `slotScore += avgAvailableHours * 5.0` 제거.
      그건 "가장 한가한 날에 넣으세요"라는 뜻이고 상한이 없어 가동률을 100%로 민다
      (시간 사용 리바운드 효과). 지금은 **넣고 난 뒤의 가동률**을 보고 80% 위로는 가파르게 감점
- [x] `FreeTimeSlot.projectedUtilization` 추가 → `AddEventView`가 "넣으면 72%"를 색과 함께 표시
- [x] 점수 복제본으로 수치 확인: 85%짜리 날이 63.5점 → 4.5점으로 밀려남, 103%는 −139.9점

### 5·6. 회복 칸과 회수 장부 — `WeekLedger` + `WeekLedgerView` (할 일 툴바 왼쪽)
앱에 일·계획·루틴만 있어서, 휴식은 **아무것도 안 한 시간**으로만 보였다.
- [x] `Shared/WeekLedger.swift` — 주 단위 장부. **회수는 조각/블록 두 칸으로 끝까지 따로 센다**
      (합치면 "50분 벌었는데 왜 아무것도 못 했지"가 된다). 회복은 횟수·분을 성과와 분리해 적는다
- [x] `Views/WeekLedgerView.swift` — 남은 몫(갈라 센 것) · 회수 · 회복 세 칸.
      회복 footer에 Albulescu 2022 수치를 그대로 적었다 (활력 d=.36 · 피로 d=.35 ·
      **성과는 유의하지 않음** d=.16, p=.116) — 성과를 기대하니까 헛되게 느껴지는 것이라서
- [x] 저장은 App Group UserDefaults. **CloudKit 스키마를 안 건드린다** → 배포 전 deploy 불필요,
      맥앱·기존 데이터와 무관. 대신 기기 간에 따라다니지 않는다

### 남은 것
- [ ] ⚠️ **두 레포 동시 수정 필요** — `TodoSplitAdvisor.swift`(hints 시그니처)·`TodoTree.swift`(tally)·
      `TodoLabelChip.swift`(count)·`TodoTips.swift`(FragmentFilterTip 문구)가 맥 레포와 갈라졌다.
      맥 `hints` 호출부도 `label`을 넘기도록 같이 고쳐야 한다
      (로컬 `~/Documents/workspace/code/WeekBlocks`는 287f17f로 단계 작업 이전 상태 — 먼저 pull)
- [ ] 손으로 확인 필요: 칩 탭 → 필터 전환, 결산 시트 세 칸, AddEventView '넣으면 N%' 줄.
      시뮬레이터에서 **렌더링은 확인**했으나(칩 줄·헤더·팁), SwiftUI 버튼이 합성 클릭에 반응하지 않아
      탭 이후 동작은 자동으로 못 눌러봤다
- [ ] (선택) 회복·회수를 적는 자리가 결산 시트 안에만 있다. 그 순간에 바로 누를 자리가 필요하면
      목록 스와이프나 위젯으로 뺄 것

## 단계 순서(순서대로 / 아무거나) — 2026-08-31, iOS 빌드 성공

지금까지 앱은 **모든 쪼개기를 사슬로 봤다.** `currentStep`이 '첫 번째 미완료 잎'이라
'초고 → 퇴고 → 발행'이든 '업체 예약 / 주소 이전 / 짐 싸기'든 똑같이 줄을 세웠다.
뒤의 것은 셋 다 지금 할 수 있는데 하나만 보여주니, 5분이 났을 때 집을 게 화면에 없었다.

**단계마다 걸지 않고 묶음마다 건다.** 사람이 손으로 쪼갠 네댓 줄에서 일부만 순서가 있는
경우는 드물다 — 대개 통째로 사슬이거나 통째로 자루다. 단계마다 의존성을 걸면 그건
그래프이고 화살표와 관리 부담이 따라온다. 1비트로 끝나는 것을 그렇게 살 이유가 없다.

- [x] `Shared/BacklogItem+StepOrder.swift` — `StepOrder{sequential, free}`.
      저장은 **묶음의 `labelRaw`에 `order:` 접두어** (`pick:`을 그렇게 넣었던 것과 같은 수).
      `pick:`은 잎에만, `order:`는 묶음에만 쓰여 겹치지 않는다 — 묶음의 조각 판정은
      앱이 아예 안 읽는다. **CloudKit 스키마 변경 없음 → 배포 전 deploy 불필요**
- [x] `TodoTree.currentStep` 재작성: 층마다 제 스위치를 본다.
      `.sequential`은 첫 번째(예전과 동일), `.free`는 **조각인 것 먼저**.
      순서를 걷어내고 나서야 두 질문의 판정이 '다음에 뭘 세울까'에 실제로 쓰인다.
      묶음이 섞여도 각 층이 제 스위치를 따른다
- [x] 데이터가 어긋났을 때(동기화 중 묶음만 완료 표시) 잎을 직접 훑는 대비책.
      없으면 그 할 일이 목록에서 '다 끝난 것'처럼 사라진다
- [x] `lastDoneStep`: `.free`에서는 목록 마지막이 아니라 **`completedAt`이 가장 늦은 것**을 되돌린다
- [x] `currentStepNumber`는 `.free`에서 nil. 세는 말은 `stepProgressPhrase`가
      "3단계 중 2번째" / "3개 중 1개 끝"으로 나눠 낸다 (VoiceOver 문구도 여기로)
- [x] `TodoDetailView`: 단계 섹션 헤더 오른쪽 메뉴(직계 자식이 둘 이상일 때만),
      하위 묶음은 줄 컨텍스트 메뉴에서. `.free`면 ▶︎ 화살표·주황 배경을 안 단다
      (기다릴 차례가 없는데 차례처럼 보이면 그게 거짓말이다). 헤더 칩은 '지금 집을 것'
- [x] `StepEditSheet`에 묶음 분기: 시간·조각 판정을 감춘다.
      **묶음의 `labelRaw`를 판정이 덮어쓰면 순서가 지워지기 때문이다.**
      같은 이유로 `TodoView.setMarked`도 묶음에 직접 쓰지 않게 막았다(단계가 다 끝난 경우)

### 남은 것
- [ ] ⚠️ **맥앱은 아직 이 값을 모른다.** 옛 코드가 `order:free`를 읽으면 `pick:` 접두어가
      없으니 '답 없음'으로 지나가 **깨지지는 않는다.** 맥에 옮길 때
      `BacklogItem+StepOrder.swift`를 그대로 복제하고 `currentStep`도 같이 고칠 것
- [ ] 손으로 확인 필요: 헤더 메뉴로 순서 전환 → ▶︎가 사라지는지, 목록 줄에 조각인 단계가
      먼저 서는지. 시뮬레이터에서 **빌드·기동은 확인**했으나 합성 키 입력이 기기에 전달되지 않아
      할 일을 만들지 못했다(이전 작업과 같은 한계)

## 부분 유료 — '모두 열기' 평생 1회 구매 (2026-08-31, iOS 빌드 성공)

**유료로 가른 것은 곁다리뿐이다.** 무지개·할 일 쪼개기·두 질문·단계 순서는 전부 무료다.
값을 받겠다고 핵심을 잠그면 앱이 무엇인지가 흐려진다.

잠그는 다섯: 홈·잠금 화면 위젯 / 캘린더에서 가져오기 / 일정 공유 / 일정 통계 / 회수 장부.

- [x] `Shared/ProEntitlement.swift` — `ProFeature` 목록 + App Group에 구운 열림 한 줄.
      **위젯 익스텐션은 결제를 조회할 수 없으므로** 앱이 적고 위젯은 읽기만 한다
      (스냅샷을 넘기는 방식과 같다). 위젯 타깃 sources에 이 파일만 추가
- [x] `Services/PurchaseManager.swift` — StoreKit 2, 비소모성 하나.
      권한의 근거는 언제나 `Transaction.currentEntitlements`이고, App Group의 한 줄은
      위젯용 거울이라 앱이 켜질 때·활성화될 때마다 덮어쓴다. `Transaction.updates` 구독,
      `AppStore.sync()` 복원(심사 요구), pending(가족 공유 승인 대기)은 실패로 안 적는다
- [x] `Views/PaywallView.swift` — **무엇이 무료인지 먼저 말한다.** 잠긴 것부터 늘어놓으면
      안 사는 사람이 앱을 못 쓴다고 오해하고 지운다. 값·버튼은 하단 고정,
      상품을 못 받아오면 값을 지어내지 않고 버튼을 막는다
- [x] 게이트: 설정(통계·캘린더 가져오기·공유 탭 토글) / 할 일 툴바(회수 장부) /
      앱 루트(공유 탭 자체 — 설정 스위치만 막으면 전에 켜 둔 사람이 그냥 통과한다) /
      위젯 둘(잠금 화면 인라인·원형은 자리가 좁아 문구를 따로)
- [x] 위젯 갤러리 미리보기(`context.isPreview`)에서는 잠그지 않는다 — 뭘 얻는지 보여줘야
      살지 말지를 정한다
- [x] `Products.storekit` + 스킴 `storeKitConfiguration` (시뮬레이터 결제 시험용)
- [x] **기존 사용자 유예.** 이 다섯은 1.0.9까지 무료로 배포돼 있었다. 업데이트 한 번으로
      쓰던 기능이 잠기면 값을 받는 게 아니라 뺏는 것이다. 이 버전 첫 실행 때 이미 적어 둔
      일정·할 일이 있으면 영구히 열어 둔다 (`ProEntitlement.grandfathersExistingUsers`)

### 남은 것
- [ ] **App Store Connect에 상품 등록 필요** — 비소모성 `com.example.ScheduleDensityApp.pro`,
      이름 '모두 열기'. 등록 전에는 페이월 버튼이 '값을 불러오는 중…'으로 막혀 있다
- [ ] 값 정하기. `Products.storekit`의 4,900원은 개발용 흉내다
- [ ] 개인정보 처리방침·소개 페이지(docs/)에 결제 문구 추가 여부
- [ ] 손으로 확인 필요: 시뮬레이터 결제 흐름(구매→열림→위젯 갱신), 구매 복원.
      **잠금 상태는 확인했다** — 새 설치에서 할 일 툴바 왼쪽이 자물쇠로 뜬다

## 번개 위젯 — 지금 집을 수 있는 조각만 (2026-08-31, iOS 빌드 성공)

'할 일' 위젯은 **최상위 할 일 하나에 한 줄**이고 그 안의 '지금 할 단계'를 접어 넣는다.
그런데 5분이 났을 때 필요한 건 '무슨 일이 남았나'가 아니라 **'지금 집을 게 뭐가 있나'** 다.
목록의 단위가 달라서 기존 위젯을 고쳐 쓸 수 없었다 — 그래서 위젯을 따로 냈다.

- [x] `TodoTree.availableSteps(of:)` — **지금 손댈 수 있는 단계 전부.**
      표시해 둔 단계(`isMarkedNow`)가 먼저, `.sequential` 묶음은 첫 번째 하나,
      `.free` 묶음은 남은 것 전부. **순서 스위치가 여기서 값을 한다** —
      순서 없는 묶음은 남은 조각이 전부 지금 집을 수 있는 것이다
- [x] `TodoWidgetSnapshot.Fragment` + `fragments`/`fragmentCount`.
      **같은 스냅샷 파일에 얹었다** — 통로를 하나로 두면 갱신 지점도 하나다
- [x] ⚠️ `TodoWidgetSnapshot`에 명시적 `init(from:)` 추가.
      새 키가 없는 옛 파일에서 디코딩이 실패하면 `read()`가 `.empty`를 돌려주는데,
      그러면 앱을 한 번 열기 전까지 **할 일 위젯까지 같이 빈다**.
      `swiftc`로 옛/더옛 JSON 두 벌 디코딩 + 새 스냅샷 왕복을 직접 확인했다
- [x] `TodoWidgetSync.makeFragments` — 위젯은 판정을 안 한다(사전을 안 들고 있다).
      앱이 `availableSteps` × `TodoSplitAdvisor.advice(...).isFragment`로 걸러 굽는다.
      **사람이 표시한 것이 앱의 짐작보다 앞선다**(안정 정렬)
- [x] `TodoWidget/FragmentWidget.swift` — 홈(소·중·대) + **잠금 화면(가로형·인라인·원형)**.
      원형도 넣었다. '할 일' 위젯에서는 원 안에 개수밖에 못 넣어서 뺐지만,
      여기서는 **개수가 곧 전언**이다("지금 집을 게 몇 개 있나")
- [x] 채운 번개 = 사람이 표시한 것, 빈 번개 = 앱 판정. 색은 `TodoView.nowGreen`과 같은 값 —
      두 화면에서 같은 것을 가리키므로
- [x] 빈 상태를 빈 화면으로 두지 않는다 — "지금 집을 조각이 없어요" + 어떻게 채우는지 한 줄
- [x] `ProEntitlement` 게이트 + 갤러리 미리보기는 안 잠금 (다른 위젯과 같은 규칙)
- [x] 딥링크 호스트 `rainbow://fragment` 를 따로 뒀다. 지금은 '할 일' 탭에 내리지만,
      조각만 보는 자리가 생기면 위젯을 안 고치고 앱에서만 갈아끼운다

### 남은 것
- [ ] 손으로 확인 필요: 위젯 갤러리에 '번개'가 뜨는지, 잠금 화면 세 자리 렌더링.
      **빌드·앱 기동·스냅샷 하위 호환은 확인**했으나, 위젯을 홈 화면에 얹는 건
      합성 입력으로 못 했다(이전 작업과 같은 한계)
- [ ] (선택) 조각만 보는 자리를 앱에 만들면 `rainbow://fragment`를 거기로 돌릴 것

## 단계를 끌어서 옮기기 (2026-08-31, iOS 빌드 성공)

- [x] `stepsSection`의 `ForEach`에 `.onMove(perform: moveRows)`.
      적는 빈 줄은 `.moveDisabled(true)` — 언제나 단계들 맨 아래여야 한다
- [x] ⚠️ **줄의 `.contextMenu`를 걷어냈다.** 롱 프레스를 컨텍스트 메뉴가 가져가면
      끌어서 옮길 수가 없다. 메뉴에 있던 것은 전부 다른 데 있다 —
      하위 단계·이름·삭제는 스와이프, 묶음의 단계 순서는 편집 시트, 위로/아래로는 드래그
- [x] `moveRows` — **형제끼리만 옮긴다.** 목록은 트리를 평평하게 편 것이라 놓은 자리
      하나로는 '그 줄 다음'인지 '그 줄 안으로'인지를 못 가린다. 가로 위치까지 보면
      손이 조금만 흔들려도 남의 묶음 안으로 들어간다. 놓은 자리는 **가장 가까운 형제 경계**로.
      묶음을 끌면 하위도 같이 간다(`parentToken`은 안 건드리고 `sortIndex`만 다시 매김)
- [x] 자기 하위 단계 위에 놓으면 no-op (하위는 형제가 아니라 안 세어져 `to == from + 1`)
- [x] **드래그는 눈으로 하는 일이라 VoiceOver로는 안 잡힌다** → 줄에
      `.accessibilityAction(named:)` 으로 위로/아래로를 남겼다 (로터의 '동작')
- [x] 편집 시트에 '자리' 섹션 — 위로/아래로 + "3개 중 2번째". 끌기가 안 되는 상황
      (스위치 컨트롤 등)과 손이 미끄러지는 경우의 길. 양 끝에서는 그 방향 버튼을 막는다
- [x] 단계 섹션 footer에 "길게 눌러 끌면 순서가 바뀝니다" 한 줄

손으로 검증한 자리 매핑 (root 아래 A, B[B1,B2], C → 평평한 목록 5줄):
맨 뒤로 / 맨 앞으로 / 남의 묶음 한가운데(→ 그 묶음 뒤) / 제 하위 위(→ no-op) /
하위끼리 맞바꾸기 / 하위를 목록 맨 위로(→ 제 묶음 안에서만) — 6가지 전부 의도대로.

### 남은 것
- [ ] 손으로 확인 필요: **롱 프레스로 실제 드래그가 시작되는지.**
      `List` + `ForEach.onMove`는 iOS 15+에서 편집 모드 없이 롱 프레스 끌기가 되고,
      막고 있던 `.contextMenu`도 걷었지만 **시뮬레이터에서 못 눌러봤다**
      (합성 키 입력이 안 먹어 단계를 만들지 못함 — 이전 작업과 같은 한계).
      혹시 안 되면 툴바에 `EditButton`을 하나 두는 게 최소 수정이다
- [ ] (선택) 다른 묶음으로 옮기기(재부모)는 안 된다. 지금도 없던 기능이라 잃은 건 없지만,
      필요하면 놓는 자리의 가로 위치를 같이 보는 방식으로

## 분류를 만들고 고치는 자리 (2026-08-31, iOS 빌드·시뮬레이터 확인)

분류는 **고를 수는 있는데 만들 데가 없었다** — 처음 쓰는 사람에게는 고를 것이 하나도 없는
메뉴만 열렸다.

- [x] `Views/CategoryManagerView.swift` — 목록·만들기·고치기·삭제·순서(드래그).
      이름 옆에 **그 분류를 쓰는 할 일 수**를 적는다(지울지 말지를 거기서 판단한다)
- [x] 색은 `Rainbow.spectrum` 7색 그대로, 기호는 `categoryIconOptions` 16개.
      이름칸 왼쪽에 **고른 색·기호가 합쳐진 모습**을 미리 보여준다
- [x] ⚠️ 지울 때 그 분류를 쓰던 할 일의 `categoryID`를 **같이 끊는다.**
      안 끊으면 어디에도 없는 uuid가 남아, 나중에 같은 uuid가 생기면 되살아난다.
      지우기 전에 몇 개가 미분류로 바뀌는지 먼저 말해준다
- [x] 진입 둘: **할 일 상세의 '분류' 메뉴 맨 아래**(정하려다 '없네'를 알게 되는 자리)와
      **설정 > 할 일**
- [x] ⚠️ 설정은 **일정 스토어**에서 도는데 분류는 할 일 스토어에 있다.
      시트에 `TodoEventBridge.shared.todoContainer`를 붙여야 목록이 보인다

## 적자마자 번개가 뜨던 것 + 목록 아래 셈 (2026-08-31, 시뮬레이터 확인)

- [x] `TodoSplitAdvisor`: `durationHours <= 0`이 질문 둘에 **'예'**를 주고 있었다.
      낱말도 안 걸리면 질문 하나도 기본 '예'라, **새로 적은 줄이 전부 조각(⚡︎)**이 됐다 —
      아무 근거 없이 "이건 5분에 집을 수 있다"고 단언한 셈이다.
      '모른다'로 바꿨다. 조각은 낱말(전화·주문·예약·챙기기…)이나 적어 둔 시간이 만든다.
      ⚠️ 두 레포 공유 파일 — 맥에도 같이 옮길 것
- [x] 목록 아래 셈줄을 **기호+숫자**로 (⚡︎2 ◌3 🕐5 ✓1). 말 세 줄이 다 같은 회색이라
      정작 세려던 숫자가 글 속에 묻혀 있었다
- [x] 색·스와이프 설명 두 줄은 `ListLegendTip`(TipKit)으로. 한 번 뜨고 닫으면 안 뜬다
- [x] 셈이 빠진 빈 화면에는 다음에 뭘 하면 되는지 한 줄

### 남은 것
- [ ] 손으로 확인 필요: **단계 롱 프레스 드래그.** 시뮬레이터에서 온보딩 오버레이 버튼이
      합성 클릭에 반응하지 않아 단계를 만드는 데까지 못 갔다
      (`hasSeenSplitOnboarding` 플래그로 우회해 상세 화면까지는 확인)
