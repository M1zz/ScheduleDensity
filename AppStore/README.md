# App Store screenshots — English (en-US)

여섯 장. `en-US/01-rainbow.png` … `en-US/06-free.png`, 각 **1290 × 2796** (6.9" iPhone).
App Store Connect는 6.9" 한 세트만 올리면 나머지 iPhone 크기에 자동으로 쓴다.
이 앱은 `TARGETED_DEVICE_FAMILY: "1"` (iPhone 전용)이라 iPad 세트는 필요 없다.

| | 파일 | 무엇을 보여주나 | 헤드라인 |
|---|---|---|---|
| 1 | `01-rainbow.png` | 날짜 × 레인 밀도 격자 | See the week before it lands |
| 2 | `02-list.png` | 할 일 목록, 맨 위 '바로 하면 되는 일' | Start with what you can start |
| 3 | `03-two-questions.png` | 단계 시트의 두 질문 | Two questions, and it's settled |
| 4 | `04-steps.png` | 단계 · 순서 스위치 · 아래에서 위로 쌓는 시간 | Break it down. Time adds itself up. |
| 5 | `05-widgets.png` | 홈 화면 위젯 세 개 (번개 · 무지개 · 할 일) | Got five minutes? Here's what fits. |
| 6 | `06-free.png` | 무료인 본체와 '모두 열기' 다섯 | The heart of it is free |

## 다시 만들기

```sh
npm i -D playwright          # 전역 설치가 이미 있으면 생략 가능
node AppStore/render.mjs
```

`screenshots.html` 하나가 여섯 장의 아트보드를 담고, `render.mjs`가 Chromium으로
`.shot` 요소마다 PNG를 굽는다. 아트보드는 **430 × 932 CSS px**로 짜고
`deviceScaleFactor: 3`으로 찍어 1290 × 2796이 된다.

프레임 안의 화면은 **393 × 852 (iPhone 16 Pro의 pt)** 로 그린 뒤 축소한다.
그래서 40pt 격자 칸, 50pt 날짜 칸, 17pt 본문 같은 치수가 앱과 1:1로 맞는다.
색은 `ScheduleDensityApp/Shared/ColorHex.swift`의 `RainbowPalette`와 같은 hex를 쓴다.

문구·데이터를 고치려면 `screenshots.html` 아래쪽의 화면 함수
(`rainbowScreen`, `todoScreen`, `questionsScreen`, `stepsScreen`,
`widgetScreen`, `priceScreen`)와 맨 끝의 `shot({...})` 목록을 고친다.

## ⚠️ 올리기 전에

이 스크린샷의 UI 글자는 **영어**인데, 앱에는 아직 영어 현지화가 없다
(`.lproj` · `.xcstrings` 없음 — 문자열이 한국어로 박혀 있다).
영어 App Store 페이지에 이대로 올리면 실제 앱과 화면이 다르다.
둘 중 하나를 먼저 해야 한다.

1. 앱을 영어로 현지화한다 (이 스크린샷의 문구를 그대로 쓰면 된다), 또는
2. 영어권 페이지에도 한국어 UI 스크린샷을 쓰고, 캡션만 영어로 둔다
   (`screenshots.html`의 화면 함수만 한국어 문자열로 되돌리면 된다).

앱 이름 **"Rainbow of Desire"**(욕망의 무지개)도 임시로 고른 영어 이름이다.
App Store Connect에 등록할 이름이 정해지면 캡션에는 이름이 안 들어가므로
스크린샷은 그대로 두면 된다.
