# App Store 스크린샷

언어 두 벌 × 크기 세 벌 = 36장. `<언어>/<크기>/01-rainbow.png` … `06-free.png`.

```
AppStore/
├── ko/       1290x2796/  1284x2778/  1242x2688/     ← 그대로 올리면 됩니다
└── en-US/    1290x2796/  1284x2778/  1242x2688/     ← 앱 영어 현지화 후에
```

| 픽셀 | App Store Connect 슬롯 | 기준 기기 |
|---|---|---|
| **1290 × 2796** | 6.9" | iPhone 17 Pro Max · 16 Pro Max |
| **1284 × 2778** | 6.5" / 6.7" | iPhone 14 Plus · 12–13 Pro Max |
| **1242 × 2688** | 6.5" | iPhone 11 Pro Max · XS Max |

**6.5" 슬롯은 1290 × 2796을 안 받는다.** "스크린샷 크기는 1242 × 2688px … 이어야 합니다"가
뜨면 `1284x2778/`이나 `1242x2688/`을 올리면 된다. 6.9" 슬롯에는 `1290x2796/`.
이 앱은 `TARGETED_DEVICE_FAMILY: "1"` (iPhone 전용)이라 iPad 세트는 없다.

| | 파일 | 무엇을 보여주나 | 한국어 헤드라인 |
|---|---|---|---|
| 1 | `01-rainbow` | 날짜 × 레인 밀도 격자 | 이번 주가 얼마나 빡빡한지 |
| 2 | `02-list` | 할 일 목록, 맨 위 '바로 하면 되는 일' | 지금 집을 수 있는 것부터 |
| 3 | `03-two-questions` | 단계 시트의 두 질문 | 물음 둘이면 갈립니다 |
| 4 | `04-steps` | 단계 · 순서 스위치 · 아래에서 위로 쌓는 시간 | 쪼개면 시간이 쌓입니다 |
| 5 | `05-widgets` | 홈 화면 위젯 세 개 (번개 · 무지개 · 할 일) | 5분 났을 때 집을 것 |
| 6 | `06-free` | 무료인 본체와 '모두 열기' 다섯 | 본체는 값을 받지 않습니다 |

## 다시 만들기

```sh
sudo apt-get install -y fonts-noto-cjk   # 한글 렌더링에 필요 (Noto Sans CJK KR)
npm i -D playwright                       # 전역 설치가 이미 있으면 생략 가능
node AppStore/render.mjs                  # 36장을 한 번에 굽는다
```

한글 폰트가 없으면 한국어 세트의 글자가 두부(□)로 나온다. 영어 세트는 영향 없다.

## 구조

`screenshots.html` 하나가 두 언어를 다 담는다. `?lang=ko` / `?lang=en`로 갈리고,
**화면에 나가는 글자는 전부 파일 위쪽 `STRINGS` 표에만** 있다 — 레이아웃을 고치면
두 언어에 동시에 적용된다. 한국어 문자열은 앱의 것을 그대로 옮겨 왔다
(`TimelineDensityView` · `TodoView` · `TodoDetailView` · `TodoSplitAdvisor` · `FragmentMark`).

`render.mjs`가 Chromium으로 `.shot` 요소마다 PNG를 굽는다. 아트보드는
`deviceScaleFactor: 3`으로 찍으므로 CSS px × 3 = 나오는 픽셀이다
(430 × 932 → 1290 × 2796, 414 × 896 → 1242 × 2688). 구운 뒤 파일마다
폴더 이름과 실제 픽셀이 맞는지 확인하고, 어긋나면 거기서 멈춘다.

크기가 바뀌면 캡션 높이와 기기 크기도 따라 바뀌어야 한다. 그 숫자를 손으로
다시 재지 않도록 `fitLayout()`이 레이아웃이 끝난 뒤 **여섯 장 중 가장 높은 캡션**을
재서 기기를 그 아래 같은 간격에 세우고, 남은 높이에 화면을 맞춘다.
크기를 하나 더 넣으려면 `SIZES`에 CSS px(픽셀 ÷ 3)만 적으면 된다.

프레임 안의 화면은 **393 × 852 (iPhone 16 Pro의 pt)** 로 그린 뒤 축소한다.
그래서 40pt 격자 칸, 50pt 날짜 칸, 17pt 본문 같은 치수가 앱과 1:1로 맞는다.
색은 `ScheduleDensityApp/Shared/ColorHex.swift`의 `RainbowPalette`와 같은 hex를 쓴다.

한글은 라틴보다 세로로 크고 어절 중간에서 끊기면 안 되므로, `body.ko`에
`word-break: keep-all`과 별도의 캡션 행간을 준다. 캡션 줄바꿈은 `<br>`로 직접 잡았다.

문구·데이터를 고치려면 `STRINGS`를, 화면 구성을 고치려면 화면 함수
(`rainbowScreen`, `todoScreen`, `questionsScreen`, `stepsScreen`,
`widgetScreen`, `priceScreen`)를 고친다.

## ⚠️ 영어 세트는 아직 올리면 안 된다

**`ko/`는 그대로 올리면 된다** — 앱에 실제로 뜨는 문구다.

**`en-US/`는 아직 아니다.** 앱에 영어 현지화가 없다
(`.lproj` · `.xcstrings` 없음 — 문자열이 한국어로 박혀 있다).
UI가 영어인 이 스크린샷을 영어 App Store 페이지에 올리면 실제 앱과 화면이 다르다.
둘 중 하나를 먼저 해야 한다.

1. 앱을 영어로 현지화한다 — `STRINGS.en`이 그대로 번역 초안이 된다, 또는
2. 영어권 페이지에도 `ko/` 스크린샷을 쓰고 캡션만 영어로 둔다
   (`STRINGS.en`의 화면 문자열만 한국어로 되돌리고 `shots`는 영어로 두면 된다).

앱 이름 **"Rainbow of Desire"**(욕망의 무지개)도 임시로 고른 영어 이름이다.
캡션에는 이름이 안 들어가므로 이름이 정해져도 스크린샷은 그대로 두면 된다.
