# 욕망의 무지개 (iOS)

일정이 겹칠수록 색이 진해지는 주간 밀도 뷰와, 지금 시작할 수 있는 것부터 집는 할 일 관리.

- **소개 페이지** — https://m1zz.github.io/ScheduleDensity/
- **개인정보 처리방침** — https://m1zz.github.io/ScheduleDensity/privacy.html
- **릴리즈 노트** — [docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md)

맥앱 **무지개 공방(macOS)** 은 별도 저장소입니다 → https://github.com/M1zz/WeekBlocks
같은 CloudKit 컨테이너를 쓰므로 두 앱을 함께 수정해야 하는 변경이 많습니다.

## 화면

- **무지개** — 일정의 밀도를 날짜 x 시간대 격자로. 겹칠수록 진하게, 종료일까지 옅게 이어짐.
- **할 일** — 할 일을 단계로 쪼개고, 조각인지 덩어리인지는 두 질문으로 갈린다.
- **공유** — 일정 공유(읽기 전용). 설정에서 켤 때만 노출.

## 두 질문

조각(5분에 집을 것)과 덩어리(지켜 둔 시간에 할 것)를 가르는 기준은 두 물음뿐이다.
근거는 [`TodoSplitAdvisor.swift`](ScheduleDensityApp/Shared/TodoSplitAdvisor.swift) 머리주석에 있다.

| | 묻는 것 | 아니면 |
|---|---|---|
| 하나 | 시동 없이 바로 시작되나 | 조각에서 시동만 걸다 끝난다 (Mark 2008) |
| 둘 | 5분 안에 끝까지 가나 | 잔여물이 다음 시간까지 따라온다 (Leroy 2009) |

**둘 다 '예'인 단계만 조각이다.** 답은 앱이 낱말과 시간으로 먼저 적어 두고, 사용자는
틀렸을 때만 뒤집는다(단계 시트의 두 줄). 적을 때는 아무것도 묻지 않는다 —
옛 '착수 조건'(바로/펼치고/몰입해서)을 걷어낸 이유와 같다.

- 뒤집은 답은 `BacklogItem.labelRaw`에 `pick:` 접두어로 저장한다
  → [`BacklogItem+Fragment.swift`](ScheduleDensityApp/Shared/BacklogItem+Fragment.swift)
- 사용자가 직접 표시한 줄·단계는 목록 **맨 위 '바로 하면 되는 일'** 칸에 모인다.
  큰 일 안의 단계여도 차례를 기다리지 않는다.
- 목록에서 '몇 번째 단계인가'는 왼쪽 원을 단계 수만큼 자른 도넛이 말한다.

시간은 **아래에서 위로** 쌓인다. 상위 할 일의 시간은 단계들의 합이다.

## 타깃

| 타깃 | 번들 ID | 설명 |
|---|---|---|
| `ScheduleDensityApp` | `com.example.ScheduleDensityApp` | 본체 (iOS 17+) |
| `TodoWidgetExtension` | `...TodoWidget` | 홈/잠금 화면 할 일 위젯 |
| `TodoShareExtension` | `...TodoShare` | 공유 시트에서 할 일 추가 |

> ⚠️ 번들 ID `com.example.*` 는 App Store에 이미 배포된 실제 값이다. placeholder처럼 보여도 바꾸지 말 것.

## 빌드

프로젝트 파일은 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 생성한다.

```sh
xcodegen generate --spec ScheduleDensityApp.project.yml
xcodebuild -project ScheduleDensityApp.xcodeproj -scheme ScheduleDensityApp \
  -destination 'generic/platform=iOS Simulator' build
```

`.xcodeproj`를 직접 고치지 말고 `ScheduleDensityApp.project.yml`을 고친 뒤 재생성한다.

## 구조

```
ScheduleDensityApp/
├── Models/          Event 등 SwiftData 모델
├── Shared/          두 앱이 함께 쓰는 것 (아래 주의 참고)
│   ├── TodoSplitAdvisor.swift   두 질문 판정 + 쪼개기 조언
│   ├── TodoTree.swift           단계 트리, 시간 합산, 진행률
│   ├── BacklogItem+Fragment.swift  두 질문에 직접 답한 것(labelRaw 재사용)
│   ├── TodoTips.swift           TipKit 팁
│   └── TodoShareInbox.swift     공유 익스텐션 -> 앱 통로
├── Views/           화면
├── Services/        위젯 스냅샷, 공유 받은 것 처리
TodoWidget/          위젯 익스텐션
TodoShare/           공유 익스텐션
docs/                GitHub Pages (소개 · 개인정보 · 릴리즈 노트)
```

## 두 저장소를 함께 고쳐야 하는 것

다음 파일은 [WeekBlocks](https://github.com/M1zz/WeekBlocks) 저장소에 **같은 내용으로 복제**되어 있다.
한쪽만 고치면 두 앱의 동작이 갈라진다.

- `TodoSplitAdvisor.swift`
- `TodoTree.swift`
- `TodoTips.swift`
- `BacklogItem+Fragment.swift`

`BacklogItem` / `BacklogCategory` 는 같은 CloudKit 스키마를 쓰므로 **필드 추가·삭제는 반드시 양쪽 동시에** 한다.
맥에만 있는 전파 계약 필드처럼 한쪽에만 있는 필드는 옵셔널 또는 기본값이어야 한다.

## 데이터

- 할 일: SwiftData `WeekBlocksTodos` 스토어, CloudKit `iCloud.com.devkoan.ScheduleDensity` (private)
- 일정: SwiftData 기본 스토어, **로컬 전용** (`cloudKitDatabase: .none`)
- 위젯·공유 통로: App Group `group.com.devkoan.ScheduleDensity`

> ⚠️ 모든 `ModelConfiguration`에 `groupContainer: .none` 이 명시돼 있다.
> App Group entitlement가 붙으면 SwiftData 기본 저장 위치가 옮겨가서,
> 이미 배포된 사용자의 스토어를 못 찾고 데이터가 사라진 것처럼 보인다. 빼지 말 것.

## 문의

leeo@kakao.com
