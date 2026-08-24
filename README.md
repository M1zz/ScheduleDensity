# 욕망의 무지개 (iOS)

일정이 겹칠수록 색이 진해지는 주간 밀도 뷰와, 지금 시작할 수 있는 것부터 집는 할 일 관리.

- **소개 페이지** — https://m1zz.github.io/ScheduleDensity/
- **개인정보 처리방침** — https://m1zz.github.io/ScheduleDensity/privacy.html
- **릴리즈 노트** — [docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md)

맥앱 **무지개 공방(macOS)** 은 별도 저장소입니다 → https://github.com/M1zz/WeekBlocks
같은 CloudKit 컨테이너를 쓰므로 두 앱을 함께 수정해야 하는 변경이 많습니다.

## 화면

- **무지개** — 일정의 밀도를 날짜 x 시간대 격자로. 겹칠수록 진하게, 종료일까지 옅게 이어짐.
- **할 일** — 할 일을 단계로 쪼개고, 단계마다 착수 조건 하나만 고른다.
- **공유** — 일정 공유(읽기 전용). 설정에서 켤 때만 노출.

## 착수 조건

쪼갤 때 묻는 것은 "이 단계가 전체의 몇 %냐"가 아니라 **"지금 시작할 수 있나"** 다.
근거는 [`TodoSplitAdvisor.swift`](ScheduleDensityApp/Shared/TodoSplitAdvisor.swift) 머리주석에 있다.

| 속성 | 뜻 | 기본 시간 |
|---|---|---|
| 바로 | 먼저 할 것도 정할 것도 없다 | 15분 |
| 펼치고 | 자료를 펼쳐야 시작된다 | 30분 |
| 몰입해서 | 끊기면 다시 올라와야 한다 | 1시간 |
| 정하고 | 안 정한 것이 막고 있다 | 30분 |
| 기다림 | 내 손을 떠나 있다 | 내 시간 아님 |

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
│   ├── TodoSplitAdvisor.swift   착수 조건 정의 + 쪼개기 조언
│   ├── TodoTree.swift           단계 트리, 시간 합산, 진행률
│   ├── BacklogItem+Label.swift  저장값 -> 착수 조건
│   ├── TodoTips.swift           TipKit 팁
│   ├── TodoLabelChip.swift      속성 칩 (익스텐션도 씀)
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
- `BacklogItem+Label.swift`

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

mizzking75@gmail.com
