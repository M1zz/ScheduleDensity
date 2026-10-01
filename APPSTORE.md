# App Store 문구 — DeployBar 가 읽어 가는 원본

<!-- DeployBar 는 이 파일의 언어 절을 읽어 App Store Connect 칸을 채운다 (이미 글이 있는 칸은 --overwrite 일 때만).
     그 언어 페이지가 스토어에 아직 없으면 만들어 준다 (앱 정보 ▸ 현지화).
     자수 제한: 이름 30, 부제 30, 키워드 100(쉼표만, 공백 없이), 프로모션 170, 설명 4000.
     ⚠️ 쓰기 전에 앱이 실제로 하는 일인지 소스에서 확인한다. Pro 목록은 ProEntitlement.ProFeature,
        요금제는 ProEntitlement.productIDs, 사용 통계 기본값은 UsageReporting.isEnabled.
     docs/STORE_LISTING.md 는 옛 기록이다 — 이 파일이 원본이다. -->

## 한국어 (ko)

### 이름

```
욕망의 무지개
```

### 부제

```
5분 단위로 쪼개는 주간 플래너
```

### 키워드

<!-- 이름(욕망, 무지개)·부제(5분, 단위, 쪼개는, 주간, 플래너) 낱말은 다시 적지 않는다. -->

```
할일,투두리스트,할일목록,일정관리,시간관리,타임블로킹,체크리스트,위젯,캘린더,달력,ADHD,집중,미루기,루틴,스케줄,계획표,다이어리,업무관리,하루계획,마감,데드라인,타이머,생산성
```

### 프로모션 텍스트

```
이번 주가 얼마나 차 있는지 색으로 먼저 봅니다. 5분이 났을 때 집을 일은 늘 맨 위에 있습니다. 이제 타이머가 일정이 끝나는 시각까지 셉니다.
```

### 지원 URL

```
https://m1zz.github.io/ScheduleDensity/
```

### 개인정보처리방침 URL

```
https://m1zz.github.io/ScheduleDensity/privacy.html
```

### 마케팅 URL

```
https://m1zz.github.io/ScheduleDensity/
```

### 설명

```
캘린더는 일정이 잡혔는지만 알려 줍니다. 그 일들이 얼마나 겹겹이 쌓였는지는 알려 주지 않습니다. 욕망의 무지개는 한 주를 격자로 그리고, 일이 겹칠수록 색을 짙게 칠합니다. 빡빡한 주를 들어서기 전에 먼저 봅니다.

주가 꽉 찼을 때 필요한 건 더 긴 목록이 아닙니다. 지금 난 5분 안에 끝낼 수 있을 만큼 작은 한 걸음입니다.

무지개

일이 시작되는 날의 빈칸을 길게 누르고, 끝나는 날을 한 번 더 누르면 격자에 줄이 그어집니다. 실제로 손대는 날은 진하게, 나머지 날은 옅게 남습니다. 끝나지 않은 일은 손대지 않는 날에도 나를 붙잡고 있기 때문입니다.

한 줄에 놓인 칸은 그날 동시에 굴리는 일입니다. 줄이 다 차면 하나만 밀려도 하루 전체가 밀립니다.

고른 캘린더의 일정도 무지개와 하루 화면에 함께 보입니다. 읽기만 하고, 캘린더에는 아무것도 쓰지 않습니다.

물음 둘, 딱 둘

큰 일을 단계로 쪼개면, 단계마다 두 가지를 묻습니다.

시동 없이 바로 시작되나요? 어디까지 했는지 다시 떠올려야 하는 일이라면 5분은 시동 거는 데 다 씁니다.

5분 안에 끝까지 가나요? 반쯤 하다 둔 일은 다음 한 시간까지 따라옵니다.

둘 다 예인 단계만 조각입니다. 5분이 비면 집는 일입니다. 나머지는 덩어리이고, 따로 떼어 둔 시간에 합니다. 적을 때 앱이 쓴 말과 시간을 보고 먼저 답해 둡니다. 틀렸을 때만 고치면 됩니다.

5분이 열두 번 나도 한 시간이 되지는 않습니다. 조각난 시간은 합쳐지지 않습니다. 그래서 짬에 들어가는 단계는 처음부터 따로 표시해 둬야 합니다.

번개

할 일을 오른쪽으로 밀어 번개를 붙이면, 지금 바로 할 수 있다는 내 표시가 됩니다. 번개 붙은 일은 줄을 건너뛰어 맨 위에 섭니다. 짬이 나면 목록 전체를 읽지 않고 거기만 보면 됩니다.

단계 순서는 한 번만

단계끼리 서로 기다리는지 아닌지를 하나하나 잇지 않고, 묶음마다 한 번만 정합니다. 순서대로면 아직 안 끝난 첫 단계가, 아무 순서면 지금 집을 수 있는 조각이 맨 위에 섭니다.

타이머

타이머는 일정이 끝나는 시각까지 셉니다. 일정이 겹치면 무엇을 셀지 고르고, 다른 일정으로 바로 바꿀 수 있습니다. 다이나믹 아일랜드와 잠금 화면에서도 보입니다.

위젯

홈 화면과 잠금 화면에 둡니다. 할 일 위젯은 지금 붙잡은 일과 그 안의 단계를, 번개 위젯은 지금 5분에 집을 수 있는 것만, 무지개 위젯은 밀도 격자를, 타이머 위젯은 남은 시간을 보여 줍니다.

공유

초대 링크를 보내 내 일정을 읽기 전용으로 나누거나, 초대한 사람과 함께 읽고 쓰는 할 일 목록을 엽니다.

무료와 무지개 Pro

본체는 값을 받지 않습니다. 할 일 적기, 무지개, 단계 쪼개기, 두 질문, 단계 순서, 타이머는 모두 무료이고 계정도 가입도 필요 없습니다. 맥과 함께 쓰는 것도 무료입니다.

홈·잠금 화면 위젯, 캘린더에서 가져오기, 일정 공유, 일정 통계, 회수 장부 전체는 무지개 Pro로 엽니다. 연간(첫 1주 무료 체험), 월간, 한 번 결제하는 평생 이용권 중에서 고릅니다.

맥에서

무지개 공방은 따로 있는 macOS 앱입니다. 같은 iCloud 계정이면 할 일과 주간 계획이 저절로 오갑니다.

개인정보

서버가 없습니다. 적은 내용은 내 기기와 내 개인 iCloud에만 있고, 개발자는 볼 수 없습니다. 광고 식별자도, 위치도, 가입도 없습니다. 익명 사용 통계를 개발자에게 보내며, 설정에서 끌 수 있습니다.

한국어, 영어, 번체 중국어를 지원하며 기기 언어를 따릅니다.
```

## English (U.S.)

<!-- 2026-09-30 ASO: 미국 검색 상위 200위 안에 이름 말고는 걸린 검색어가 하나도 없었다 — todo list,
     week planner, time blocking 같은 큰 말은 Structured·Tiimo 가 꽉 잡고 있다. 그래서 경쟁이 덜하고
     이 앱이 실제로 하는 일(할 일을 단계로 쪼갠다)에 맞는 task breakdown 을 부제에 세운다.
     부제 낱말(task, breakdown, week, planner)과 이름 낱말은 키워드에 다시 적지 않는다.
     week ≠ weekly 로 따로 잡힌다(맥에서 week planner 는 걸리고 weekly planner 는 안 걸렸다). -->

### 이름

```
Rainbow of Desire
```

### 부제

```
Task Breakdown & Week Planner
```

### 키워드

```
todo,list,adhd,weekly,overview,timeboxing,time,blocking,subtask,checklist,schedule,focus,widget
```

### 프로모션 텍스트

```
See how full your week is before you walk into it, and keep what fits a five-minute gap at the top. Timers now count down to the moment an event ends.
```

### 지원 URL

```
https://m1zz.github.io/ScheduleDensity/en/
```

### 개인정보처리방침 URL

```
https://m1zz.github.io/ScheduleDensity/en/privacy.html
```

### 마케팅 URL

```
https://m1zz.github.io/ScheduleDensity/en/
```

### 설명

```
A calendar tells you whether something is scheduled. It does not tell you how much is stacked on top of it. Rainbow of Desire draws your weeks as a grid where the color deepens the more your work overlaps, so you see the heavy week before you walk into it.

And when the week is heavy, the answer is rarely a longer list. It is one step small enough to take in the five minutes you actually have.

THE RAINBOW

Press and hold an empty cell on the day something starts, then again on the day it ends, and a line is drawn down the grid. Days you actually work on it are dark. The rest stay pale, because unfinished work still holds you, even on the days you do not touch it.

Cells across a row are the jobs you are juggling that day. When the row fills up, one slip pushes the whole day.

Events from the calendars you pick show up on the rainbow and in your day, too. Read only. Nothing is ever written back to your calendar.

TWO QUESTIONS, AND ONLY TWO

Split a large job into steps. Each step is then sorted by two questions.

Can you start it cold? If you have to reload where you left off, a five-minute gap goes entirely to warming up.

Does it run all the way through in five minutes? Work left half done follows you into the next hour.

Only a step that answers yes to both is a fragment, something to grab when five minutes open up. Everything else is a block, and belongs in time you set aside. The app answers first, from the words and time you wrote. You step in only when it is wrong.

Twelve five-minute gaps are not an hour. Scraps of time do not add up, which is exactly why the steps that fit a gap have to be marked from the start.

THE BOLT

Swipe a row to the right to add a Bolt, your own mark that says this one is ready right now. A bolted row jumps the queue and stands at the top, so when a gap opens you look there instead of reading the whole list.

STEP ORDER, DECIDED ONCE

Steps either wait for each other or they do not, and you decide that once for the group instead of wiring up dependencies one by one. In order shows the first unfinished step. Any order shows whichever fragment you could pick up now.

TIMER

The timer counts down to the moment the event ends. When events overlap, pick which one to time, and switch to another in a tap. It shows in the Dynamic Island and on the Lock Screen too.

WIDGETS

On the Home and Lock Screen. To-Do shows the job you are on and the step inside it. Bolt lists only what you could pick up in five minutes right now. Rainbow shows the density grid itself. Timer shows the time left.

SHARING

Send an invite link to share your events read only, or to open a to-do list that you and the people you invite read and write together.

FREE, AND RAINBOW PRO

The heart of the app costs nothing. To-dos, the Rainbow, splitting into steps, the two questions, step order and the timer are all free, with no account and no sign-up. Using it alongside the Mac is free too.

Rainbow Pro opens the extras: Home and Lock Screen widgets, importing from Calendar, sharing events, event stats, and the full weekly Ledger. Choose yearly with a free first week, monthly, or a one-time lifetime purchase.

ON THE MAC

Rainbow Craft is a separate macOS app. On the same iCloud account, to-dos and weekly plans carry across on their own.

PRIVACY

There is no server. What you write stays on your device and in your own private iCloud, where the developer cannot reach it. No advertising identifiers, no location, no sign-up. The app sends anonymous usage statistics to the developer, and you can turn that off in Settings.

Available in English, Korean and Traditional Chinese. The app follows your device language.
```

## 중국어 번체 (zh-Hant)

### 이름

```
欲望彩虹
```

### 부제

```
一週行程密度，五分鐘小步驟
```

### 키워드

```
待辦事項,待辦清單,清單,任務管理,任務清單,工作清單,週計畫,計畫表,規劃,行事曆,時間管理,專注,拖延,ADHD,小工具,子任務,時間塊,碎片時間,生產力,效率,計時器,倒數,截止日,提醒
```

### 프로모션 텍스트

```
一眼看出這週有多滿，五分鐘空檔能做的事永遠排在最上面。計時器現在會一路倒數到行程結束。
```

### 지원 URL

```
https://m1zz.github.io/ScheduleDensity/zh-Hant/
```

### 개인정보처리방침 URL

```
https://m1zz.github.io/ScheduleDensity/zh-Hant/privacy.html
```

### 마케팅 URL

```
https://m1zz.github.io/ScheduleDensity/zh-Hant/
```

### 설명

```
行事曆告訴你某件事有沒有排上，卻不會告訴你這些事疊得有多高。欲望彩虹把每一週畫成一張格子圖，工作重疊得越多，顏色就越深，讓你在走進忙碌的一週之前，就先看見它。

一週很滿的時候，解方很少是更長的清單，而是有一個夠小的步驟，小到在你真正擁有的那五分鐘裡就能完成。

彩虹

在某件事開始的那天長按空格，再在結束的那天長按一次，格子上就會畫出一條線。真正動手的日子顏色較深，其餘的日子保持淡色，因為沒做完的事，即使那天沒碰，也一樣佔著你。

同一列的格子，就是你那天同時在推的事。一列排滿時，一個延誤就會拖垮整天。

你選擇的行事曆行程也會一起顯示在彩虹和當日畫面上，只讀取，不寫入。

兩個問題，就這兩個

把大工作拆成步驟，每個步驟再用兩個問題分類。

能不能不用暖身就開始？如果得先回想上次做到哪裡，五分鐘的空檔就全花在暖身上了。

能不能在五分鐘內一口氣做完？做到一半的事，會一路跟著你到下一個小時。

兩題都答「是」的步驟才是碎片，適合在五分鐘空出來時順手拿起。其他的都是整塊，屬於你特地留出的時間。App 會先依你寫下的文字和時間作答，只有答錯時才需要你出手。

十二個五分鐘不等於一小時。零碎的時間加不成總數，所以能塞進空檔的步驟，一開始就要分開標出來。

閃電

把一列往右滑，加上閃電，表示「這件現在就能做」。加了閃電的項目會插隊站到最上面，空檔一來，你只要往上看，不必把整張清單讀完。

步驟順序，只決定一次

步驟之間不是要互相等待，就是不必。你只要替整組決定一次，而不是一條一條接上相依關係。依序時，最上面是第一個還沒完成的步驟；不限順序時，是現在就能拿起的碎片。

計時器

計時器會一路倒數到行程結束的那一刻。行程重疊時，由你選要計哪一個。也能在動態島、主畫面和鎖定畫面上看到。

小工具

放在主畫面和鎖定畫面。待辦事項顯示你正在做的事和其中的步驟；閃電只列出現在五分鐘內能拿起的事；彩虹直接顯示密度格子；計時器顯示剩下的時間。

共享

傳送邀請連結，可以唯讀共享你的行程，或開一份待辦清單，讓你和受邀的人一起讀寫。

免費的部分

App 的核心不收費。寫待辦、彩虹、拆成步驟、兩個問題和步驟順序都免費，不需要帳號，也不需要註冊。

主畫面與鎖定畫面小工具、從行事曆匯入與顯示、共享行程、行程統計和完整的每週帳本，屬於彩虹 Pro。可選年訂閱（首週免費試用）、月訂閱或一次購買的永久使用權。和 Mac 一起使用不另外收費。

在 Mac 上

彩虹工坊是另一個 macOS App。使用同一個 iCloud 帳號時，待辦事項和每週計畫會自動同步。

隱私

沒有伺服器。你寫下的內容只存在你的裝置和你自己的私人 iCloud，開發者無法取得。沒有廣告識別碼，不讀取位置，也不需要註冊。App 會傳送匿名使用統計給開發者，你可以在設定中關閉。

支援繁體中文、韓文和英文，會跟隨裝置語言。
```
