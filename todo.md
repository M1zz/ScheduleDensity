# ScheduleDensity 패밀리 — 할 일 목록

iOS 앱(ScheduleDensity)과 macOS 앱(WeekBlocks)을 하나의 Xcode 프로젝트에서
두 개의 타깃으로 관리하는 "같은 패밀리" 구조.

## 완료
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
