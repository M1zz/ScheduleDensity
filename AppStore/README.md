# App Store 스크린샷

언어 스물네 벌 × 크기 세 벌 × 다섯 장 = 360장. 언어 목록은 `render.mjs` 의 `ALL_LOCALES`. `<언어>/<크기>/01-rainbow.png` … `05-widgets.png`.

```
AppStore/
├── ko/       1290x2796/  1284x2778/  1242x2688/     ← 그대로 올리면 됩니다
├── en-US/    1290x2796/  1284x2778/  1242x2688/     ← 앱 영어 현지화 후에
└── zh-Hant/  1290x2796/  1284x2778/  1242x2688/     ← 번체 중국어(대만), 앱 zh-Hant 현지화 후에
```

| 픽셀 | App Store Connect 슬롯 | 기준 기기 |
|---|---|---|
| **1290 × 2796** | 6.9" | iPhone 17 Pro Max · 16 Pro Max |
| **1284 × 2778** | 6.5" / 6.7" | iPhone 14 Plus · 12–13 Pro Max |
| **1242 × 2688** | 6.5" | iPhone 11 Pro Max · XS Max |
| **1398 × 2034** | iPhone Duo 바깥 화면 | iPhone Duo (접은 채) |

**6.5" 슬롯은 1290 × 2796을 안 받는다.** "스크린샷 크기는 1242 × 2688px … 이어야 합니다"가
뜨면 `1284x2778/`이나 `1242x2688/`을 올리면 된다. 6.9" 슬롯에는 `1290x2796/`.
이 앱은 `TARGETED_DEVICE_FAMILY: "1"` (iPhone 전용)이라 iPad 세트는 없다.

| | 파일 | 무엇을 보여주나 | 한국어 헤드라인 | 번체 중국어(zh-Hant) 헤드라인 |
|---|---|---|---|---|
| 1 | `01-rainbow` | 날짜 × 레인 밀도 격자 | 이번 주가 얼마나 빡빡한지 | 這週有多滿　一眼就知道 |
| 2 | `02-list` | 할 일 목록, 맨 위 '바로 하면 되는 일' | 지금 집을 수 있는 것부터 | 從現在　能做的開始 |
| 3 | `03-two-questions` | 단계 시트의 두 질문 | 물음 둘이면 갈립니다 | 兩個問題　就能分辨 |
| 4 | `04-steps` | 단계 · 순서 스위치 · 아래에서 위로 쌓는 시간 | 쪼개면 시간이 쌓입니다 | 拆成步驟　時間自然累加 |
| 5 | `05-widgets` | 홈 화면 위젯 세 개 (번개 · 무지개 · 할 일) | 5분 났을 때 집을 것 | 有 5 分鐘時　可以做的事 |

## 다시 만들기

```sh
sudo apt-get install -y fonts-noto-cjk   # Linux에서만: 한글·한자 렌더링 (Noto Sans CJK KR/TC)
npm i -D playwright                       # 전역 설치가 이미 있으면 생략 가능
node AppStore/render.mjs                  # 54장을 한 번에 굽는다
node AppStore/render.mjs zh-Hant          # 한 언어만 (lang 또는 폴더 이름, 여러 개 가능)
```

레포 밖에 설치한 playwright를 쓰려면 `PLAYWRIGHT_DIR=/경로/node_modules/playwright`를 앞에 붙인다.

CJK 폰트가 없으면 한국어·중국어 세트의 글자가 두부(□)로 나온다. 영어 세트는 영향 없다.
macOS에는 Apple SD Gothic Neo와 PingFang TC가 있어 따로 설치할 것이 없다.

### iPhone Duo 바깥 화면

`?size=1398x2034` 이면 화면이 접은 Duo 의 바깥 화면(466 × 678 pt)으로 바뀐다. 시계와 탭 막대가
위·아래 가장자리를 떠나 오른쪽 92 pt 세로줄에 서고(실기기 모양 그대로), 내용은 왼쪽 374 pt 안에 둔다.
장면·순서·헤드라인은 아이폰 세트와 같다(같은 `STRINGS`).

```sh
SIZE=1398x2034 node AppStore/render.mjs      # Duo 만 다시 굽는다 (SIZE 없으면 네 크기 모두)
```

Duo 세트는 `AppStore/<언어>/1398x2034/` 와 함께 `docs/screenshots/marketing/<스토어 로케일>/duo-01-....png`
에도 놓인다. DeployBar 는 픽셀로 기기를 가른다(1398x2034 = APP_IPHONE_DUO).
확인: `DeployBar --shotplan 욕망의 무지개` 에 언어마다 "iPhone Duo (APP_IPHONE_DUO)" 묶음. 안쪽(펼친) 화면 세트는 없다.

## 구조

`screenshots.html` 하나가 세 언어를 다 담는다. `?lang=ko` / `?lang=en` / `?lang=zh-Hant`로 갈리고,
**화면에 나가는 글자는 전부 파일 위쪽 `STRINGS` 표에만** 있다 — 레이아웃을 고치면
모든 언어에 동시에 적용된다. 한국어 문자열은 앱의 것을 그대로 옮겨 왔다
(`TimelineDensityView` · `TodoView` · `TodoDetailView` · `TodoSplitAdvisor` · `FragmentMark`).

`render.mjs`가 Chromium으로 `.shot` 요소마다 PNG를 굽는다. 아트보드는
`deviceScaleFactor: 3`으로 찍으므로 CSS px × 3 = 나오는 픽셀이다
(430 × 932 → 1290 × 2796, 414 × 896 → 1242 × 2688). 구운 뒤 파일마다
폴더 이름과 실제 픽셀이 맞는지 확인하고, 어긋나면 거기서 멈춘다.

크기가 바뀌면 캡션 높이와 기기 크기도 따라 바뀌어야 한다. 그 숫자를 손으로
다시 재지 않도록 `fitLayout()`이 레이아웃이 끝난 뒤 **다섯 장 중 가장 높은 캡션**을
재서 기기를 그 아래 같은 간격에 세우고, 남은 높이에 화면을 맞춘다.
크기를 하나 더 넣으려면 `SIZES`에 CSS px(픽셀 ÷ 3)만 적으면 된다.

프레임 안의 화면은 **393 × 852 (iPhone 16 Pro의 pt)** 로 그린 뒤 축소한다.
그래서 40pt 격자 칸, 50pt 날짜 칸, 17pt 본문 같은 치수가 앱과 1:1로 맞는다.
색은 `ScheduleDensityApp/Shared/ColorHex.swift`의 `RainbowPalette`와 같은 hex를 쓴다.

한글은 라틴보다 세로로 크고 어절 중간에서 끊기면 안 되므로, `body.ko`에
`word-break: keep-all`과 별도의 캡션 행간을 준다. 캡션 줄바꿈은 `<br>`로 직접 잡았다.

번체 중국어 세트(`body.zh-Hant`)는 `PingFang TC` → `Noto Sans CJK TC` → `Noto Sans TC` 순으로
글꼴을 잡고, 그 세트에서만 `<html lang="zh-Hant">`를 건다. 그래야 한자가 일본어·한국어
자형으로 섞여 나오지 않는다. 한자는 글자 사이 어디서나 끊기므로 `keep-all`은 쓰지 않고,
`line-break: strict`로 전각 구두점이 줄 첫머리에 오지 않게 한다. 용어는 앱 zh-Hant 번역과
맞췄다 — 欲望彩虹 · 彩虹 · 待辦 · 步驟 · 碎片 · 整塊 · 閃電 · 帳本 · 行程 · 小工具 ·
主畫面 · 鎖定畫面 · 依序 · 不限順序.

문구·데이터를 고치려면 `STRINGS`를, 화면 구성을 고치려면 화면 함수
(`rainbowScreen`, `todoScreen`, `questionsScreen`, `stepsScreen`,
`widgetScreen`)를 고친다.

⚠️ 가격 장(`06-free`)은 뺐다. '무료' · '무료 체험' · '평생' 같은 말도 가격 표기로 보고
2.3.7(Accurate Metadata)로 리젝한다 (1.1.13, 2026-10-17). 스크린샷 · 미리보기 영상 · 앱 이름 ·
부제에는 넣지 않고, 가격 이야기는 설명글에만 쓴다. `priceScreen`과 `S.price`는 남아 있지만 싣지 않는다.

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
