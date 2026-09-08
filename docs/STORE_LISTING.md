# 스토어 등록 정보

App Store Connect 에 넣는 값을 여기 적어 둔다. **웹 화면이 원본이 아니라 이 파일이 원본이다** —
전에는 어디에도 안 남아 있어서 고칠 때마다 콘솔을 열어 읽어야 했다.

- 이름·부제는 **앱 정보**(앱 단위)에, 설명·키워드·URL 은 **버전 정보**(버전마다)에 들어간다.
- 자수 제한: 이름 30, 부제 30, 키워드 100, 설명 4000, 프로모션 텍스트 170.
- 키워드는 쉼표로만 가른다. **쉼표 뒤에 공백을 넣지 않는다** — 그 한 칸도 100자에서 깎인다.
- 이름과 부제의 낱말은 이미 검색에 잡히므로 키워드에 다시 적지 않는다.

---

## English (U.S.)

### 이름 (17자)

```
Rainbow of Desire
```

### 부제 (28자)

```
Week planner, 5-minute steps
```

### 키워드 (99자)

```
todo,list,task,manager,checklist,schedule,calendar,time,blocking,focus,adhd,workload,subtask,widget
```

### 지원 URL

```
https://m1zz.github.io/ScheduleDensity/en/
```

### 개인정보 처리방침 URL

```
https://m1zz.github.io/ScheduleDensity/en/privacy.html
```

### 마케팅 URL (선택)

```
https://m1zz.github.io/ScheduleDensity/en/
```

### 설명 (3344자)

<!-- 그대로 붙여넣는 글이다. 글머리표·이모지를 넣지 않는다 — 소제목은 대문자 한 줄로만 세운다. -->

```
A calendar tells you whether something is scheduled. It does not tell you how much of it is stacked on top of itself. Rainbow of Desire draws your weeks as a grid where the color deepens the more your work overlaps, so you can see the heavy week before you walk into it.

And when the week is heavy, the answer is rarely a longer list. It is having one step small enough to take in the five minutes you actually have.

THE RAINBOW

Press and hold an empty cell for the day something starts, then again for the day it ends, and a line is drawn down the grid. Days you actually work on it are dark. The rest stay pale, because work that is not finished still holds you, even on the days you do not touch it.

Cells across a row are the jobs you are rolling at once that day. When the row fills up, one slip pushes the whole day.

TWO QUESTIONS, AND ONLY TWO

Split a large job into steps. Each step is then sorted by two questions.

Does it start with no warm-up? If you have to reload where you left off, a five-minute gap is spent warming up and nothing else.

Does it run all the way through in five minutes? Work you leave half done follows you into the next hour.

Only a step that answers yes to both is a fragment, something to take when five minutes open up. Everything else is a block, and belongs in time you have set aside. The app answers first, from the words and the time you wrote. You step in only when it is wrong.

Twelve five-minute gaps are not an hour. Fragments of time do not add up into a total, which is exactly why the steps that fit in a gap have to be marked apart from the start.

THE BOLT

Swipe a row to the right to add a Bolt, your own mark saying this one is ready right now. A bolted row jumps the queue and stands at the top, so when a gap opens you look up there instead of reading the whole list.

STEP ORDER, DECIDED ONCE

Steps either wait for each other or they do not, and you decide that once for the group instead of wiring up dependencies one by one. In order stands the first unfinished step. Any order stands whichever fragment you could pick up now.

WIDGETS

Three of them, on the Home and Lock Screen. To-Do shows the job you are on and the step inside it. Bolt lists only what you could pick up in five minutes right now. Rainbow shows the density grid itself.

SHARING

Send an invite link to share your events read-only, or to open one to-do list that you and the people you invite read and write together.

WHAT IS FREE

The heart of the app costs nothing. Writing to-dos, the Rainbow, splitting into steps, the two questions, and step order are all free, with no account and no sign-up.

Rainbow Pro is one purchase, not a subscription, and it opens six extras: using the app alongside the Mac, Home and Lock Screen widgets, importing from Calendar, sharing events, event stats, and the weekly Ledger.

ON THE MAC

Rainbow Workshop is a separate macOS app. On the same iCloud account, to-dos and weekly plans carry across on their own.

PRIVACY

There is no server. What you write stays on your device and in your own private iCloud, where the developer cannot reach it. No advertising identifiers, no analytics, no location, no sign-up. Anonymous usage statistics exist as a switch in Settings, and it is off unless you turn it on.

Korean and English. The app follows your device language.
```

---

## 한국어

### 이름

```
욕망의 무지개
```

### 부제

⚠️ 지금 스토어에 무엇이 들어가 있는지 이 레포에 기록이 없다. 콘솔에서 확인해 여기 옮겨 적을 것.
영어와 맞추려면 아래를 쓴다 (15자).

```
일정 밀도와 5분짜리 할 일
```

### 키워드

⚠️ 미기록. 콘솔에서 확인해 옮겨 적을 것.

### 지원 URL

```
https://m1zz.github.io/ScheduleDensity/
```

### 개인정보 처리방침 URL

```
https://m1zz.github.io/ScheduleDensity/privacy.html
```

### 설명

⚠️ 미기록. 콘솔에서 확인해 옮겨 적을 것.

---

## 웹 페이지

| 언어 | 소개(지원 URL) | 개인정보 처리방침 |
|---|---|---|
| 한국어 | `docs/index.html` | `docs/privacy.html` |
| English | `docs/en/index.html` | `docs/en/privacy.html` |

GitHub Pages 가 `docs/` 를 뿌리로 서비스한다. 두 언어가 서로를 링크하고 `hreflang` 도 걸어 두었다.

앱 안의 '개인정보 처리방침·문의' 링크는 기기 언어를 따라 둘 중 하나로 간다
(→ `ScheduleDensityApp/ScheduleDensityAppSpec.swift` 의 `siteRoot`).
**웹 주소를 옮기면 그 파일과 이 표를 함께 고쳐야 한다.**

> ⚠️ `docs/index.html`(한국어)은 앱보다 오래된 글이다. 지금은 없는 '착수 조건'
> (바로·펼치고·몰입해서·정하고·기다림)을 설명하고 있다. 영어판 `docs/en/index.html`
> 은 현재 앱(두 질문 · 조각/덩어리 · 번개)에 맞춰 새로 썼다. 한국어판도 맞춰야 한다.

---

## 아직 없는 것

- 영어 스크린샷 (한국어 스크린샷만 있다)
- 영어 프로모션 텍스트 (선택 항목, 170자)
- 인앱 구입 'Rainbow Pro' 의 영어 현지화 — App Store Connect ▸ 기능 ▸ 앱 내 구입.
  `ScheduleDensityApp/Products.storekit` 의 영어는 시뮬레이터용이라 실제 구매 시트와 무관하다.
