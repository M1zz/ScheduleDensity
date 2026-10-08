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

한국어, 영어, 중국어(간체·번체), 일본어, 독일어, 스페인어, 프랑스어 등 23개 언어를 지원하며 기기 언어를 따릅니다.

구독과 약관

연간·월간 구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 요금으로 자동 갱신되며, Apple 계정으로 결제됩니다. 해지와 관리는 App Store의 계정 설정에서 합니다. 평생 이용권은 구독이 아닌 한 번 결제입니다.

이용약관(EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
개인정보처리방침: https://m1zz.github.io/ScheduleDensity/privacy.html
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

Events from the calendars you pick appear on the rainbow and in your day, read only. Nothing is written back.

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

Rainbow Craft is a separate macOS app. On the same iCloud account, to-dos and weekly plans sync on their own.

PRIVACY

There is no server. What you write stays on your device and in your own private iCloud, where the developer cannot reach it. No advertising identifiers, no location, no sign-up. The app sends anonymous usage statistics to the developer, and you can turn that off in Settings.

Available in 23 languages, following your device language.

SUBSCRIPTIONS AND TERMS

Subscriptions renew automatically unless canceled at least 24 hours before the period ends, and are charged to your Apple Account. Manage or cancel them in App Store account settings.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://m1zz.github.io/ScheduleDensity/en/privacy.html
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

支援繁體中文、簡體中文、英文、日文、韓文等 23 種語言，會跟隨裝置語言。

訂閱與條款

年訂閱和月訂閱若未在當期結束前至少 24 小時取消，會以相同價格自動續訂，並向你的 Apple 帳號收費。你可以隨時在 App Store 的帳號設定中管理或取消訂閱。永久使用權是一次性購買，不是訂閱。

使用條款（EULA）：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
隱私權政策：https://m1zz.github.io/ScheduleDensity/zh-Hant/privacy.html
```

## 중국어 간체 (zh-Hans)

### 이름

```
欲望彩虹：待办清单与周计划
```

### 부제

```
日程密度一目了然，五分钟小步骤
```

### 키워드

```
任务管理,时间管理,计划表,日历,效率,自律,拖延,专注,ADHD,小组件,子任务,时间块,碎片时间,倒计时,计时器,截止日期,提醒,规划,生产力,todo,任务拆分,学习计划,工作,目标
```

### 프로모션 텍스트

```
一眼看出这周排得有多满，五分钟空档能做的事永远在最上面。计时器现在会一路倒计时到日程结束。
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
日历只告诉你某件事有没有排上，却不会告诉你这些事叠得有多高。欲望彩虹把每一周画成一张格子图，事情重叠得越多，颜色就越深，让你在走进忙碌的一周之前，就先看清它。

一周排满的时候，你需要的很少是更长的清单，而是一个足够小的步骤，小到在你手头那五分钟里就能做完。

彩虹

在一件事开始的那天按住空格，再在结束的那天按住一次，格子上就会画出一条线。真正动手的日子颜色深，其余日子保持浅色，因为没做完的事，哪怕那天没碰，也一样占着你。

同一行的格子，就是你那天同时在推进的事。一行排满时，只要一件事延误，整天都会被拖后。

你选择的日历中的日程也会显示在彩虹和当日页面上。只读取，不会写入日历。

两个问题，就这两个

把大任务拆成步骤，每个步骤再用两个问题来分类。

不用热身就能直接开始吗？如果得先回想上次做到哪里，五分钟的空档就全花在热身上了。

5 分钟内能一路做完吗？做到一半的事，会一直跟着你到下一个小时。

两题都答“是”的步骤才是碎片，五分钟空出来时顺手就能做。其余的都是整块，留给你专门腾出的时间。App 会根据你写下的文字和时间先替你作答，答错时你再改就好。

十二个五分钟不等于一小时。零碎时间加不成总量，所以能塞进空档的步骤，一开始就要单独标出来。

闪电

把一行向右滑动，贴上闪电，表示“这件现在就能做”。贴了闪电的事会插队排到最上面。有空档时只看最上面就行，不必把整张清单读一遍。

步骤顺序，只定一次

步骤之间要么互相等待，要么不必。你只需为整组决定一次，而不用一条条设置依赖关系。按顺序时，最上面是第一个还没完成的步骤；不限顺序时，最上面是现在就能做的碎片。

计时器

计时器会一路倒计时到日程结束的那一刻。日程重叠时，由你选择计哪一个，也能一键切换到另一个。灵动岛和锁定屏幕上也能看到。

小组件

可放在主屏幕和锁定屏幕上。待办事项小组件显示你正在做的事和其中的步骤；闪电小组件只列出现在五分钟内能做的事；彩虹小组件直接显示密度格子；计时器小组件显示剩余时间。

共享

发送邀请链接，可以只读共享你的日程，或开一份待办清单，与受邀的人一起查看和编辑。

免费与彩虹 Pro

App 的核心功能不收费。写待办、彩虹、拆分步骤、两个问题、步骤顺序和计时器全部免费，无需账号，也无需注册。与 Mac 一起使用同样免费。

主屏幕与锁定屏幕小组件、从日历导入、日程共享、日程统计和完整的账本，由彩虹 Pro 解锁。可选年订阅（首周免费试用）、月订阅，或一次性购买的永久版。

在 Mac 上

彩虹工坊是另一款 macOS App。登录同一个 iCloud 账户后，待办事项和每周计划会自动同步。

隐私

没有服务器。你写下的内容只保存在你的设备和你自己的私人 iCloud 中，开发者无法查看。没有广告标识符，不读取位置，也不需要注册。App 会向开发者发送匿名使用统计，你可以在设置中关闭。

支持 23 种语言，并跟随设备语言显示。

订阅与条款

年订阅和月订阅如未在当期结束前至少 24 小时取消，将按相同价格自动续订，费用从你的 Apple 账户扣除。你可以在 App Store 的账户设置中管理或取消订阅。永久版为一次性购买，不是订阅。

使用条款（EULA）：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
隐私政策：https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 일본어 (ja)

### 이름

```
Rainbow of Desire: 週間プランナー
```

### 부제

```
やることを5分のステップに分ける
```

### 키워드

```
ToDo,タスク管理,手帳,スケジュール,時間管理,タイムブロッキング,カレンダー,ウィジェット,ADHD,集中,先延ばし,習慣,ルーティン,チェックリスト,締め切り,タイマー,予定表,生産性,効率化
```

### 프로모션 텍스트

```
今週がどれだけ詰まっているか、まず色でひと目でわかります。5分のすき間に手に取れることは、いつもいちばん上に。タイマーは予定が終わる時刻までカウントダウンします。
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
カレンダーが教えてくれるのは、予定が入っているかどうかだけ。その上にどれだけ仕事が積み重なっているかまでは教えてくれません。Rainbow of Desireは1週間をマス目で描き、仕事が重なるほど色を濃く塗ります。詰まった週に足を踏み入れる前に、まず色で気づけます。

予定がいっぱいの週に必要なのは、もっと長いリストではありません。いま空いた5分で終わらせられるくらい小さな、次の一歩です。

虹

始まる日の空いたマスを長押しし、終わる日をもう一度長押しすると、マス目に線が引かれます。実際に手をつける日は濃く、それ以外の日は薄く残ります。終わっていない仕事は、手をつけない日にも頭の片すみを占めているからです。

横一列に並ぶマスは、その日に同時に回している仕事です。列が埋まると、ひとつずれただけで1日全体がずれ込みます。

選んだカレンダーの予定も、虹と1日の画面に一緒に表示されます。読み取るだけで、カレンダーには何も書き込みません。

問いは2つ、たった2つ

大きな仕事をステップに分けると、ステップごとに2つの問いで仕分けます。

準備運動なしで、すぐ始められるか。どこまでやったか思い出さなければならない仕事なら、5分は準備運動だけで終わります。

5分で最後までいけるか。やりかけの仕事は、次の1時間までついてきます。

両方「はい」のステップだけが「かけら」。5分空いたら手に取ることです。それ以外は「まとまった時間」が必要なステップで、確保した時間にやります。書いた言葉と時間から、アプリが先に答えておきます。違っていたときだけ直せばOKです。

5分を12回集めても1時間にはなりません。細切れの時間は足し合わせられないからこそ、すき間に入るステップは最初から分けて印を付けておく必要があります。

稲妻

やることを右にスワイプして稲妻を付けると、「今すぐできる」という自分だけの印になります。稲妻を付けたことは順番を飛び越えて、いちばん上に並びます。すき間時間ができたら、リスト全体を読まずにそこだけ見れば大丈夫です。

ステップの順番は一度決めるだけ

ステップ同士が待ち合うかどうかを1本ずつつなぐのではなく、グループごとに一度決めるだけ。「順番どおり」ならまだ終わっていない最初のステップが、「順不同」なら今すぐ手に取れるかけらが、いちばん上に来ます。

タイマー

タイマーは予定が終わる時刻までカウントダウンします。予定が重なったときは何を計るか選べて、ほかの予定にもすぐ切り替えられます。Dynamic Islandとロック画面にも表示されます。

ウィジェット

ホーム画面とロック画面に置けます。やることウィジェットは今取り組んでいる仕事とその中のステップを、稲妻ウィジェットは今5分で手に取れるものだけを、虹ウィジェットは密度のマス目を、タイマーウィジェットは残り時間を表示します。

共有

招待リンクを送って自分の予定を閲覧のみで共有したり、招待した人と一緒に読み書きできるやることリストを作ったりできます。

無料の範囲とRainbow Pro

アプリの中心となる機能は無料です。やることの記録、虹、ステップ分け、2つの問い、ステップの順番、タイマーはすべて無料で、アカウント登録も必要ありません。Macと一緒に使うのも無料です。

ホーム画面・ロック画面のウィジェット、カレンダーからの読み込み、予定の共有、予定の統計、回収帳のすべては、Rainbow Proで使えるようになります。年額（最初の1週間は無料トライアル）、月額、1回払いの買い切りから選べます。

Macでも

Rainbow Craftは別のmacOSアプリです。同じiCloudアカウントなら、やることと週の計画が自動で同期されます。

プライバシー

サーバーはありません。書いた内容はあなたのデバイスとあなた個人のiCloudにだけ保存され、開発者が見ることはできません。広告識別子も、位置情報も、アカウント登録もありません。匿名の利用統計を開発者に送信しますが、設定でオフにできます。

日本語を含む23の言語に対応し、デバイスの言語設定に合わせて表示されます。

サブスクリプションと利用規約

年額・月額のサブスクリプションは、期間終了の24時間前までに解約しない限り同じ料金で自動更新され、Apple Accountに請求されます。解約と管理はApp Storeのアカウント設定から行えます。買い切りはサブスクリプションではなく1回限りの支払いです。

利用規約（EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
プライバシーポリシー: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 독일어 (de)

### 이름

```
Rainbow of Desire: To-Do-Liste
```

### 부제

```
Wochenplaner in Minischritten
```

### 키워드

```
aufgaben,todo,adhs,zeitmanagement,kalender,timeblocking,checkliste,fokus,routine,widget,timer,planer
```

### 프로모션 텍스트

```
Sieh an der Farbe, wie voll deine Woche ist, bevor sie losgeht. Was in fünf freie Minuten passt, steht immer ganz oben. Neu: Der Timer zählt bis zum Ende des Termins.
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
Ein Kalender sagt dir, ob etwas eingeplant ist, aber nicht, wie viel sich stapelt. Rainbow of Desire zeichnet deine Wochen als Raster, das kräftiger wird, je mehr sich überschneidet. So siehst du die volle Woche, bevor du mittendrin steckst.

Ist die Woche voll, hilft keine längere Liste, sondern ein Schritt, der in die fünf Minuten passt, die du gerade hast.

Der Regenbogen

Halte am Starttag ein leeres Kästchen gedrückt, dann am Endtag, und eine Linie zieht sich durchs Raster. Tage, an denen du daran arbeitest, sind kräftig, die übrigen blass. Denn Unerledigtes bindet dich auch an Tagen, an denen du es nicht anrührst.

Eine Zeile zeigt, was du an dem Tag gleichzeitig jonglierst. Ist sie voll, verschiebt eine kleine Panne den ganzen Tag.

Termine aus Kalendern deiner Wahl erscheinen im Regenbogen und in der Tagesansicht, nur lesend.

Zwei Fragen, nur zwei

Teile eine große Aufgabe in Schritte. Jeder Schritt wird mit zwei Fragen eingeordnet.

Kannst du ohne Anlaufen loslegen? Musst du erst nachlesen, wo du warst, gehen fünf Minuten fürs Warmwerden drauf.

Ist es in fünf Minuten erledigt? Halb Fertiges verfolgt dich bis in die nächste Stunde.

Nur ein Schritt mit zweimal Ja ist ein Splitter, etwas für fünf freie Minuten zwischendurch. Alles andere braucht Fokuszeit, die du dir freihältst. Die App antwortet zuerst, anhand deiner Worte und der Dauer. Du greifst nur ein, wenn sie danebenliegt.

Zwölfmal fünf Minuten sind keine Stunde. Deshalb müssen Schritte, die in eine Lücke passen, von Anfang an markiert sein.

Der Blitz

Wisch eine Aufgabe nach rechts und setz einen Blitz, dein Zeichen für „jetzt sofort machbar“. Sie überspringt die Reihenfolge und steht ganz oben. Tut sich eine Lücke auf, schaust du nur dorthin.

Schrittfolge, einmal festgelegt

Ob Schritte aufeinander warten, legst du einmal pro Gruppe fest, statt Abhängigkeiten einzeln zu verknüpfen. „Der Reihe nach“ zeigt den ersten offenen Schritt, „Beliebig“ den Splitter, den du jetzt anpacken kannst.

Timer

Der Timer zählt bis zum Ende des Termins herunter. Überschneiden sich Termine, wählst du einen und wechselst mit einem Tippen. Auch in der Dynamic Island und auf dem Sperrbildschirm.

Widgets

Für Home- und Sperrbildschirm: Aufgaben zeigt, woran du bist, samt aktuellem Schritt. Blitz zeigt, was jetzt in fünf Minuten geht. Regenbogen zeigt das Dichteraster, Timer die Restzeit.

Teilen

Teile per Einladungslink deine Termine schreibgeschützt oder eine Aufgabenliste, die ihr gemeinsam bearbeitet.

Kostenlos und Rainbow Pro

Der Kern der App kostet nichts. Aufgaben, Regenbogen, Aufteilen in Schritte, die zwei Fragen, Schrittfolge und Timer sind kostenlos, ohne Account und Registrierung. Auch die Nutzung mit dem Mac ist kostenlos.

Rainbow Pro schaltet die Extras frei: Widgets, Import aus dem Kalender, Termine teilen, Terminstatistik und die volle Zeitbilanz. Jährlich mit Gratiswoche, monatlich oder einmal für immer.

Auf dem Mac

Rainbow Craft ist eine eigene macOS-App. Mit demselben iCloud-Account gleichen sich Aufgaben und Wochenpläne von selbst ab.

Datenschutz

Es gibt keinen Server. Was du schreibst, bleibt auf deinem Gerät und in deiner privaten iCloud, für den Entwickler unerreichbar. Keine Werbe-IDs, kein Standort, keine Registrierung. Anonyme Nutzungsstatistiken gehen an den Entwickler; das lässt sich in den Einstellungen ausschalten.

Rainbow of Desire gibt es in 23 Sprachen, darunter Deutsch, und folgt der Sprache deines Geräts.

Abos und Bedingungen

Jahres- und Monatsabos verlängern sich automatisch zum gleichen Preis, wenn sie nicht mindestens 24 Stunden vor Ende des Zeitraums gekündigt werden, und werden über deinen Apple Account abgerechnet. Verwalten und kündigen kannst du sie in den App Store-Accounteinstellungen. Der Kauf für immer ist eine Einmalzahlung, kein Abo.

Nutzungsbedingungen (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Datenschutzrichtlinie: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 스페인어 (es)

### 이름

```
Rainbow of Desire: Tareas
```

### 부제

```
Agenda semanal paso a paso
```

### 키워드

```
lista,pendientes,planificador,organizador,checklist,TDAH,productividad,rutina,calendario,foco,widget
```

### 프로모션 텍스트

```
Mira por colores cuánto se llena tu semana antes de empezarla. Lo que cabe en cinco minutos libres está siempre arriba. Y el temporizador cuenta hasta el fin del evento.
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
Un calendario te dice si algo está programado, no cuánto se te acumula encima. Rainbow of Desire pinta tus semanas en una cuadrícula que se oscurece cuanto más se superponen tus pendientes: ves la semana pesada antes de entrar en ella.

Y con la semana cargada no hace falta una lista más larga, sino un paso tan pequeño que quepa en los cinco minutos que de verdad tienes.

El arcoíris

Mantén pulsada una celda vacía el día en que algo empieza y otra vez el día en que acaba: se dibuja una línea. Los días en que trabajas en ello van en tono intenso; el resto, en tono claro, porque lo que no está terminado te ata aunque no lo toques.

Las celdas de una fila son lo que llevas a la vez ese día. Cuando la fila se llena, un solo retraso desplaza el día entero.

Los eventos de los calendarios que elijas también aparecen, solo en lectura: nunca se escribe nada en ellos.

Dos preguntas, y solo dos

Al dividir un trabajo en pasos, cada uno pasa por dos preguntas.

¿Puedes empezar sin calentar motores? Si hay que recordar dónde lo dejaste, los cinco minutos se van en arrancar.

¿Se termina en cinco minutos? Lo que dejas a medias te persigue hasta la hora siguiente.

Solo el paso con dos síes es un fragmento, para hacer en cuanto se abren cinco minutos. Lo demás es un tramo, para un tiempo que reservas aparte. La app responde primero según lo que escribiste; tú solo corriges cuando se equivoca.

Doce huecos de cinco minutos no son una hora: los ratos sueltos no se suman. Por eso los pasos que caben en un hueco se marcan desde el principio.

El rayo

Desliza una tarea a la derecha para ponerle un rayo: tu marca de que se puede hacer ya mismo. Lo que lleva rayo se salta la cola y sube arriba: cuando se abre un hueco, miras ahí y no toda la lista.

El orden de los pasos, una sola vez

Si los pasos se esperan entre sí lo decides una vez por grupo, sin enlazar dependencias una a una. En orden, arriba va el primer paso sin terminar; en cualquier orden, el fragmento que puedes hacer ya.

Temporizador

El temporizador cuenta hasta que acaba el evento. Si hay varios a la vez, eliges cuál y cambias con un toque. También se ve en la Dynamic Island y en la pantalla bloqueada.

Widgets

En la pantalla de inicio y la bloqueada. Tareas muestra lo que tienes entre manos y su paso actual. Rayo, solo lo que puedes hacer ahora en cinco minutos. Arcoíris, la cuadrícula de densidad. Temporizador, el tiempo que queda.

Compartir

Con un enlace de invitación, comparte tu agenda en solo lectura o abre una lista de tareas que editas junto a tus invitados.

Gratis, y Rainbow Pro

Lo esencial es gratis. Escribir tareas, el arcoíris, dividir en pasos, las dos preguntas, el orden de los pasos y el temporizador son gratis, sin cuenta ni registro. Usarla con el Mac también es gratis.

Rainbow Pro suma widgets de pantalla de inicio y bloqueada, importar de Calendario, compartir la agenda, estadísticas de eventos y el registro completo de tiempo recuperado. Anual con la primera semana gratis, mensual o de por vida con un único pago.

En el Mac

Rainbow Craft es una app aparte para macOS. Con la misma cuenta de iCloud, tareas y planes semanales se sincronizan solos.

Privacidad

Sin servidor. Lo que escribes se queda en tu dispositivo y en tu iCloud privado, fuera del alcance del desarrollador. Sin identificadores publicitarios, sin ubicación, sin registro. La app envía estadísticas de uso anónimas, que puedes desactivar en Ajustes.

Disponible en 23 idiomas; la app usa el idioma de tu dispositivo.

Suscripciones y condiciones

Las suscripciones anual y mensual se renuevan automáticamente salvo que las canceles al menos 24 horas antes del fin del periodo, y se cobran en tu cuenta de Apple. Gestiónalas en los ajustes de tu cuenta del App Store. El acceso de por vida es un pago único.

Condiciones de uso (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Política de privacidad: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 프랑스어 (fr)

### 이름

```
Rainbow of Desire : Planning
```

### 부제

```
Découpez vos tâches en étapes
```

### 키워드

```
todo,liste,agenda,semaine,hebdo,organiser,TDAH,calendrier,minuteur,widget,procrastination,checklist
```

### 프로모션 텍스트

```
Voyez d’un coup d’œil si votre semaine est pleine, avant d’y entrer. Ce qui tient dans cinq minutes reste toujours en haut de la liste.
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
Un calendrier dit si quelque chose est prévu, pas tout ce qui s’empile par-dessus. Rainbow of Desire dessine vos semaines en grille : plus vos projets se chevauchent, plus la couleur fonce. Vous voyez la semaine chargée avant d’y entrer.

Et quand la semaine déborde, il ne faut pas une liste plus longue, mais une étape assez petite pour les cinq minutes que vous avez vraiment.

L’ARC-EN-CIEL

Maintenez une case vide le jour du début, puis celui de la fin : un trait se dessine. Les jours où vous y travaillez sont foncés, les autres pâles, car un travail inachevé vous mobilise même quand vous n’y touchez pas.

Une ligne, c’est tout ce que vous menez de front ce jour-là. Pleine, un seul imprévu décale la journée.

Les événements des calendriers choisis s’affichent aussi, en lecture seule. Rien n’est écrit dans vos calendriers.

DEUX QUESTIONS, PAS UNE DE PLUS

Découpez un gros travail en étapes. Chacune passe par deux questions.

Se commence-t-elle à froid ? S’il faut se remettre dans le contexte, cinq minutes partent dans le démarrage.

Se termine-t-elle en cinq minutes ? Un travail laissé à moitié vous suit dans l’heure suivante.

Deux fois oui, c’est un fragment, à saisir dès que cinq minutes se libèrent. Le reste demande une plage de concentration, un temps protégé. L’app répond d’abord d’après vos mots et la durée notée ; vous corrigez seulement si elle se trompe.

Douze fois cinq minutes ne font pas une heure. Les bouts de temps ne s’additionnent pas : les étapes qui tiennent dans un creux doivent être repérées dès le départ.

L’ÉCLAIR

Balayez une tâche vers la droite pour lui ajouter un Éclair, votre marque pour dire : faisable tout de suite. Elle passe devant les autres, en haut. Quand un creux se présente, vous regardez là, sans relire toute la liste.

L’ORDRE DES ÉTAPES, DÉCIDÉ UNE FOIS

Les étapes s’attendent ou non : vous le décidez une fois pour le groupe. Dans l’ordre, la première étape inachevée est en haut ; en ordre libre, le fragment à saisir maintenant.

MINUTEUR

Le minuteur décompte jusqu’à la fin de l’événement. S’il y a chevauchement, choisissez lequel suivre. Visible aussi dans la Dynamic Island et sur l’écran verrouillé.

WIDGETS

Sur l’écran d’accueil et l’écran verrouillé. Tâches montre le travail en cours et son étape. Éclair, ce qui se fait en cinq minutes maintenant. Arc-en-ciel, la grille de densité. Minuteur, le temps restant.

PARTAGE

Un lien d’invitation partage vos événements en lecture seule, ou ouvre une liste de tâches à plusieurs.

GRATUIT, ET RAINBOW PRO

Le cœur de l’app est gratuit : tâches, Arc-en-ciel, découpage, deux questions, ordre des étapes et minuteur, sans compte ni inscription. L’usage avec le Mac aussi.

Rainbow Pro débloque les extras : widgets d’écran d’accueil et verrouillé, import depuis Calendrier, partage d’événements, statistiques des événements et Registre du temps récupéré complet. Au choix : annuel (première semaine offerte), mensuel ou achat unique à vie.

SUR MAC

Rainbow Craft est une app macOS à part. Avec le même compte iCloud, tâches et plannings se synchronisent seuls.

CONFIDENTIALITÉ

Aucun serveur. Ce que vous écrivez reste sur votre appareil et dans votre iCloud privé, hors de portée du développeur. Ni identifiant publicitaire, ni localisation, ni inscription. Des statistiques d’utilisation anonymes sont envoyées au développeur ; désactivables dans les réglages.

Disponible en 23 langues, dont le français. L’app suit la langue de votre appareil.

ABONNEMENTS ET CONDITIONS

Les abonnements annuel et mensuel se renouvellent automatiquement au même tarif, sauf résiliation au moins 24 heures avant la fin de la période, et sont facturés sur votre compte Apple. Gérez-les dans les réglages de votre compte App Store. L’accès à vie est un achat unique, pas un abonnement.

Conditions d’utilisation (EULA) : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Politique de confidentialité : https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 이탈리아어 (it)

### 이름

```
Rainbow of Desire: Agenda
```

### 부제

```
Planner settimanale e attività
```

### 키워드

```
cose,fare,lista,todo,promemoria,organizzare,tempo,ADHD,checklist,calendario,widget,routine,scadenze
```

### 프로모션 텍스트

```
Guarda quanto è piena la settimana prima di entrarci. Ciò che si fa in cinque minuti resta sempre in cima. E ora il timer conta fino alla fine dell’evento.
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
Il calendario ti dice se un impegno è fissato, non quanto ci si accumula sopra. Rainbow of Desire disegna la settimana come una griglia che si colora di più dove gli impegni si sovrappongono. Così vedi la settimana pesante prima di entrarci.

E quando la settimana è piena non serve un elenco più lungo, ma un passo abbastanza piccolo per i cinque minuti che hai davvero.

L’arcobaleno

Tieni premuta una cella vuota nel giorno di inizio, poi in quello di fine, e sulla griglia compare una riga. I giorni in cui ci lavori sono intensi, gli altri tenui: un lavoro non finito ti occupa anche quando non lo tocchi.

Le celle di una fila sono i lavori che porti avanti insieme quel giorno. Quando la fila è piena, basta un ritardo per far slittare tutta la giornata.

Gli eventi dei calendari scelti compaiono sull’arcobaleno e nella vista del giorno, in sola lettura.

Due domande, solo due

Suddividi un lavoro grande in fasi: ognuna viene valutata con due domande.

Riesci a iniziare senza tempo di avvio? Se devi ricordare dove eri rimasto, cinque minuti se ne vanno solo per ripartire.

Si finisce in cinque minuti? Un lavoro lasciato a metà ti segue nell’ora dopo.

Solo una fase con due sì è un frammento, da prendere quando si liberano cinque minuti. Il resto richiede tempo di concentrazione. L’app risponde per prima in base a parole e durata; tu intervieni solo se sbaglia.

Dodici volte cinque minuti non fanno un’ora. I ritagli di tempo non si sommano: per questo le fasi adatte ai momenti liberi vanno segnate da subito.

Il Fulmine

Scorri un’attività verso destra per aggiungere il Fulmine, il tuo segno per dire che si può fare subito. Le attività con il Fulmine saltano la fila e vanno in cima: nei momenti liberi guardi lì, senza rileggere tutto.

L’ordine delle fasi, deciso una volta

Le fasi si aspettano a vicenda oppure no: lo decidi una volta per il gruppo, senza collegarle una a una. In ordine, in cima c’è la prima fase non finita; in qualsiasi ordine, il frammento che puoi prendere adesso.

Timer

Il timer conta alla rovescia fino alla fine dell’evento. Se più eventi si sovrappongono scegli quale seguire e cambi con un tocco. Lo vedi anche nella Dynamic Island e sulla schermata di blocco.

Widget

Su Home e schermata di blocco. Attività mostra il lavoro in corso e la sua fase, Fulmine solo ciò che si fa adesso in cinque minuti, Arcobaleno la griglia della densità, Timer il tempo rimanente.

Condivisione

Con un link di invito condividi i tuoi eventi in sola lettura, oppure apri un elenco di attività da scrivere insieme a chi inviti.

Gratis, e Rainbow Pro

Il cuore dell’app è gratis: attività, arcobaleno, suddivisione in fasi, le due domande, ordine delle fasi e timer, senza account né registrazione. Anche l’uso con il Mac è gratuito.

Rainbow Pro sblocca gli extra: widget per Home e schermata di blocco, importazione da Calendario, condivisione e statistiche degli eventi, registro completo del tempo recuperato. Scegli tra annuale (prima settimana gratis), mensile o acquisto unico a vita.

Sul Mac

Rainbow Craft è un’app macOS a parte. Con lo stesso account iCloud, attività e piani settimanali si sincronizzano da soli.

Privacy

Nessun server. Ciò che scrivi resta sul tuo dispositivo e nel tuo iCloud privato, fuori dalla portata dello sviluppatore. Niente identificatori pubblicitari, posizione o registrazione. L’app invia statistiche d’uso anonime, disattivabili in Impostazioni.

Disponibile in 23 lingue: l’app segue la lingua del dispositivo.

Abbonamenti e condizioni

Gli abbonamenti annuale e mensile si rinnovano automaticamente allo stesso prezzo se non disdetti almeno 24 ore prima della fine del periodo, con addebito sul tuo Apple Account. Gestiscili o disdicili nelle impostazioni dell’account App Store. L’accesso a vita è un pagamento unico, non un abbonamento.

Condizioni d’uso (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Informativa sulla privacy: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 포르투갈어(브라질) (pt-BR)

### 이름

```
Rainbow of Desire: Tarefas
```

### 부제

```
Agenda semanal passo a passo
```

### 키워드

```
lista,afazeres,planner,organizador,checklist,TDAH,produtividade,rotina,calendário,foco,widget,prazos
```

### 프로모션 텍스트

```
Veja pela cor o quanto sua semana está cheia antes de ela começar. O que cabe em cinco minutos livres fica sempre no topo. E o timer agora conta até o fim do evento.
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
Um calendário diz se algo está agendado, não quanta coisa está empilhada em cima. O Rainbow of Desire pinta suas semanas numa grade que escurece quanto mais os compromissos se sobrepõem: você vê a semana pesada antes de entrar nela.

E quando a semana aperta, a saída não é uma lista maior, e sim uma etapa que caiba nos cinco minutos que você realmente tem.

O arco-íris

Toque e segure uma célula vazia no dia em que algo começa e de novo no dia em que termina: uma linha é desenhada. Os dias em que você trabalha nisso ficam em tom forte; o resto, em tom claro, porque o que não foi concluído prende você mesmo quando você nem mexe nele.

As células de uma linha são o que você está tocando ao mesmo tempo naquele dia. Quando a linha enche, um único atraso empurra o dia inteiro.

Os eventos dos calendários que você escolher também aparecem, só para leitura: nada é gravado neles.

Duas perguntas, só duas

Ao dividir um trabalho em etapas, cada uma passa por duas perguntas.

Dá para começar sem aquecer? Se precisa relembrar onde parou, os cinco minutos vão todos no aquecimento.

Termina em até cinco minutos? O que fica pela metade vai junto para a hora seguinte.

Só a etapa com dois sins é um fragmento, para fazer assim que surgem cinco minutos. O resto é período contínuo, para um tempo que você separa. O app responde primeiro, com base no que você escreveu; você só corrige quando ele erra.

Doze brechas de cinco minutos não são uma hora: pedacinhos de tempo não se somam. Por isso as etapas que cabem numa brecha são marcadas desde o início.

O raio

Deslize uma tarefa para a direita para colocar um raio: a sua marca de que dá para fazer agora mesmo. O que tem raio fura a fila e vai para o topo: quando surge uma brecha, você olha ali, não na lista inteira.

Ordem das etapas, decidida uma vez

Se as etapas esperam umas pelas outras, você decide uma vez por grupo, sem ligar dependências uma a uma. Em ordem, aparece no topo a primeira etapa não concluída; em qualquer ordem, o fragmento que dá para fazer agora.

Timer

O timer conta até o fim do evento. Se houver vários ao mesmo tempo, você escolhe qual e troca com um toque. Ele aparece também na Ilha Dinâmica e na Tela Bloqueada.

Widgets

Na Tela de Início e na Tela Bloqueada. Tarefas mostra o trabalho em que você está e a etapa da vez. Raio, só o que dá para fazer agora em cinco minutos. Arco-íris, a grade de densidade. Timer, o tempo restante.

Compartilhamento

Com um link de convite, compartilhe sua agenda só para leitura ou abra uma lista de tarefas que você edita junto com seus convidados.

Grátis, e Rainbow Pro

O essencial não custa nada. Escrever tarefas, o arco-íris, dividir em etapas, as duas perguntas, a ordem das etapas e o timer são grátis, sem conta e sem cadastro. Usar junto com o Mac também é grátis.

O Rainbow Pro libera widgets da Tela de Início e Bloqueada, importação do Calendário, compartilhamento da agenda, estatísticas de eventos e o registro completo de tempo recuperado. Anual com a primeira semana grátis, mensal ou vitalício com pagamento único.

No Mac

O Rainbow Craft é um app separado para macOS. Na mesma conta do iCloud, tarefas e planos semanais sincronizam sozinhos.

Privacidade

Sem servidor. O que você escreve fica no seu dispositivo e no seu iCloud privado, fora do alcance do desenvolvedor. Sem identificadores de publicidade, sem localização, sem cadastro. O app envia estatísticas de uso anônimas, que você pode desativar em Ajustes.

Disponível em 23 idiomas, seguindo o idioma do seu dispositivo.

Assinaturas e termos

As assinaturas anual e mensal são renovadas automaticamente, a menos que sejam canceladas pelo menos 24 horas antes do fim do período, e são cobradas na sua Conta Apple. Gerencie nos ajustes da sua conta na App Store. O acesso vitalício é um pagamento único.

Termos de Uso (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Política de Privacidade: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 러시아어 (ru)

### 이름

```
Rainbow of Desire: список дел
```

### 부제

```
Планер недели и разбивка задач
```

### 키워드

```
туду,ежедневник,планировщик,чеклист,СДВГ,календарь,расписание,таймер,виджет,дедлайн,фокус,todo,adhd
```

### 프로모션 텍스트

```
Сначала посмотрите по цвету, насколько заполнена неделя. А то, что можно сделать за пять минут, всегда наверху. Таймер теперь отсчитывает время до конца события.
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
Календарь показывает, запланировано ли дело, но не показывает, сколько всего навалено сверху. Rainbow of Desire рисует каждую неделю сеткой, и чем больше дела пересекаются, тем гуще цвет. Тяжёлую неделю видно ещё до её начала.

А когда неделя забита, помогает не длинный список, а один шаг, который влезает в пять свободных минут.

Радуга

Удерживайте пустую клетку в день начала дела, потом в день окончания, и на сетке появится полоса. Дни, когда вы им заняты, яркие, остальные бледные: незаконченное дело держит вас, даже когда вы его не трогаете.

Клетки в одном ряду показывают, сколько дел вы ведёте в этот день одновременно. Когда ряд заполнен, одна заминка сдвигает весь день.

События из выбранных календарей тоже видны на радуге и на экране дня, только для чтения.

Два вопроса, и только два

Разбейте большое дело на шаги. Каждый шаг проходит через два вопроса.

Можно начать без раскачки? Если сначала нужно вспомнить, на чём вы остановились, все пять минут уйдут на разгон.

Заканчивается за пять минут? Недоделанное тянется за вами в следующий час.

Шаг с двумя ответами «да» — это кусочек: его берут, когда выпадает пять минут. Остальному нужен цельный отрезок времени, отведённый заранее. Приложение отвечает первым, по словам и времени, которые вы записали. Исправлять нужно, только если оно ошиблось.

Двенадцать раз по пять минут — это не час. Обрывки времени не суммируются, поэтому шаги для пауз нужно отмечать с самого начала.

Молния

Смахните задачу вправо и поставьте молнию: это ваша собственная отметка «можно сделать прямо сейчас». Задача с молнией встаёт наверх вне очереди, и в паузу не нужно перечитывать весь список.

Порядок шагов задаётся один раз

Ждут ли шаги друг друга, вы решаете один раз для всей группы, а не связываете их по одному. По порядку: наверху первый незаконченный шаг. В любом порядке: кусочек, который можно взять прямо сейчас.

Таймер

Таймер отсчитывает время до конца события. Если события пересекаются, выберите, какое считать, и переключайтесь одним касанием. Таймер виден в Dynamic Island и на экране блокировки.

Виджеты

Для экрана «Домой» и экрана блокировки. Виджет задач показывает текущее дело и шаг внутри него. Молния показывает только то, что можно взять за пять минут прямо сейчас. Радуга показывает саму сетку плотности. Таймер показывает оставшееся время.

Совместный доступ

Отправьте ссылку-приглашение, чтобы показать свои события только для чтения или вести общий список задач вместе с приглашёнными.

Бесплатно и Rainbow Pro

Основа приложения бесплатна. Задачи, радуга, разбивка на шаги, два вопроса, порядок шагов и таймер доступны без оплаты, без учётной записи и без регистрации. Работа вместе с Mac тоже бесплатна.

Rainbow Pro открывает дополнения: виджеты, импорт из Календаря, доступ к событиям для других, статистику событий и полный журнал возвращённого времени. На выбор: годовая подписка с бесплатной первой неделей, ежемесячная подписка или разовая покупка навсегда.

На Mac

Rainbow Craft — отдельное приложение для macOS. С одной учётной записью iCloud задачи и планы на неделю синхронизируются сами.

Конфиденциальность

Сервера нет. Всё, что вы пишете, хранится только на устройстве и в вашем личном iCloud, разработчику это недоступно. Никаких рекламных идентификаторов, геолокации и регистрации. Приложение отправляет разработчику анонимную статистику использования, её можно выключить в настройках.

Приложение поддерживает 23 языка и автоматически следует языку устройства.

Подписки и условия

Годовая и ежемесячная подписки продлеваются автоматически по той же цене, если не отменить их не позднее чем за 24 часа до конца периода. Оплата списывается с вашего Apple Account. Управлять подпиской и отменить её можно в настройках учётной записи App Store. Покупка навсегда — разовый платёж, а не подписка.

Условия использования (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Политика конфиденциальности: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 체코어 (cs)

### 이름

```
Rainbow of Desire: plánovač
```

### 부제

```
Úkoly rozložené na malé kroky
```

### 키워드

```
todo,seznam,týdenní,diář,kalendář,ADHD,produktivita,rozvrh,časovač,widget,checklist,soustředění,cíle
```

### 프로모션 텍스트

```
Barvy vám předem ukážou, jak nabitý je váš týden. To, co stihnete za pět volných minut, máte vždy hned nahoře. Časovač teď odpočítává až do konce události.
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
Kalendář vám řekne, jestli je něco naplánované. Neřekne vám ale, kolik toho je navršeno jedno na druhém. Rainbow of Desire kreslí váš týden jako mřížku, která tmavne, čím víc se práce překrývá. Náročný týden tak uvidíte dřív, než do něj vstoupíte.

A když je týden nabitý, nepomůže delší seznam. Pomůže jeden krok tak malý, že ho zvládnete za pět minut, které právě máte.

Duha

Podržte prázdné políčko v den, kdy něco začíná, a pak klepněte na den, kdy to končí. Do mřížky se nakreslí čára. Dny, kdy na tom opravdu pracujete, jsou syté, ostatní zůstanou bledé. Nedokončená práce vás totiž drží i ve dnech, kdy na ni nesáhnete.

Políčka v jednom řádku jsou věci, které ten den táhnete zároveň. Když se řádek zaplní, stačí jedno zdržení a posune se celý den.

Události z kalendářů, které vyberete, se zobrazí v Duze i v přehledu dne. Aplikace je jen čte a do kalendáře nic nezapisuje.

Dvě otázky, jen dvě

Velký úkol rozložte na kroky. U každého kroku pak padnou dvě otázky.

Dokážete začít bez rozjezdu? Pokud si musíte znovu vybavovat, kde jste skončili, celých pět minut padne na rozjezd.

Je to hotové do pěti minut? Napůl rozdělaná práce se s vámi táhne i do další hodiny.

Jen krok se dvěma ano je střípek, který vezmete, když se uvolní pět minut. Všechno ostatní potřebuje souvislý čas, který si vyhradíte předem. Aplikace odpoví sama podle toho, co a na jak dlouho jste napsali. Opravíte ji, jen když se splete.

Dvanáct pětiminutových mezer není hodina. Útržky času se nesčítají, a proto je potřeba kroky, které se do nich vejdou, označit hned od začátku.

Blesk

Přejeďte po úkolu doprava a přidejte mu Blesk, svou značku pro „tohle jde udělat hned“. Úkol s Bleskem přeskočí frontu a stojí nahoře. Když se otevře chvilka, stačí se podívat tam.

Pořadí kroků jednou provždy

Jestli na sebe kroky čekají, rozhodnete jednou pro celou skupinu. Při možnosti Popořadě je nahoře první nedokončený krok, při možnosti Libovolně střípek, do kterého se můžete pustit hned.

Časovač

Časovač odpočítává do chvíle, kdy událost končí. Když se události překrývají, vyberete, kterou měřit, a jedním klepnutím přepnete na jinou. Zobrazí se i v Dynamic Islandu a na zamčené obrazovce.

Widgety

Na plochu i na zamčenou obrazovku. Widget Úkoly ukazuje práci, na které jste, a krok v ní. Widget Blesk jen to, co teď stihnete za pět minut. Widget Duha samotnou mřížku hustoty. Widget Časovač zbývající čas.

Sdílení

Pošlete odkaz s pozvánkou a sdílejte svůj rozvrh jen pro čtení, nebo otevřete seznam úkolů, který s pozvanými lidmi společně čtete i upravujete.

Zdarma a Rainbow Pro

Jádro aplikace je zdarma. Úkoly, Duha, rozkládání na kroky, dvě otázky, pořadí kroků i časovač nic nestojí a nepotřebujete účet ani registraci. Používání spolu s Macem je také zdarma.

Rainbow Pro odemkne doplňky: widgety na ploše a zamčené obrazovce, import z Kalendáře, sdílení rozvrhu, statistiky událostí a celý Deník získaného času. Vybrat si můžete roční předplatné s prvním týdnem zdarma, měsíční nebo jednorázový doživotní nákup.

Na Macu

Rainbow Craft je samostatná aplikace pro macOS. Na stejném účtu iCloud se úkoly a týdenní plány synchronizují samy.

Soukromí

Žádný server neexistuje. Co napíšete, zůstane ve vašem zařízení a ve vašem soukromém iCloudu, kam vývojář nevidí. Žádné reklamní identifikátory, žádná poloha, žádná registrace. Aplikace posílá vývojáři anonymní statistiky používání, které můžete vypnout v Nastavení.

Aplikace je ve 23 jazycích včetně češtiny a řídí se jazykem vašeho zařízení.

Předplatné a podmínky

Roční a měsíční předplatné se automaticky obnovuje za stejnou cenu, pokud ho nezrušíte alespoň 24 hodin před koncem období. Platba se strhává z vašeho Apple účtu. Předplatné spravujete a rušíte v nastavení účtu v App Storu. Doživotní nákup není předplatné, platíte ho jen jednou.

Podmínky použití (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Zásady ochrany soukromí: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 덴마크어 (da)

### 이름

```
Rainbow of Desire: Ugeplan
```

### 부제

```
Del opgaver op i små trin
```

### 키워드

```
todo,huskeliste,opgaveliste,planlægger,kalender,tidsstyring,adhd,fokus,tjekliste,widget,timer,rutine
```

### 프로모션 텍스트

```
Se med farver, hvor fyldt ugen er, før du går ind i den. Det, du kan nå på fem minutter, ligger altid øverst. Nu tæller timeren ned til begivenhedens slut.
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
En kalender fortæller dig, om noget er planlagt. Den fortæller ikke, hvor meget der ligger oven på det. Rainbow of Desire tegner dine uger som et gitter, hvor farven bliver mørkere, jo mere dine opgaver overlapper, så du ser den tunge uge, før du går ind i den.

Og når ugen er tung, er svaret sjældent en længere liste. Det er ét trin, der er lille nok til de fem minutter, du faktisk har.

Regnbuen

Tryk og hold på et tomt felt den dag, noget begynder, og igen den dag, det slutter, så tegnes en linje ned gennem gitteret. De dage, du faktisk arbejder på det, er mørke. Resten forbliver blege, for uafsluttet arbejde binder dig, også de dage, du ikke rører ved det.

Begivenheder fra de kalendere, du vælger, vises på regnbuen og i din dag. De læses kun, og intet skrives tilbage.

To spørgsmål, kun to

Del en stor opgave op i trin. Hvert trin sorteres derefter med to spørgsmål.

Kan du gå i gang uden opvarmning? Skal du først læse dig ind på, hvor du slap, går de fem minutter med at komme i gang.

Bliver den færdig inden for fem minutter? Arbejde, der står halvfærdigt, følger dig ind i den næste time.

Kun et trin med ja til begge er en tidslomme, noget du tager, når der opstår fem minutter. Alt andet er en fokusblok og hører hjemme i tid, du har sat af. Appen svarer først ud fra de ord og den tid, du har skrevet. Du griber kun ind, når den tager fejl.

Tolv huller på fem minutter er ikke én time. Småbidder af tid lægges ikke sammen, og derfor skal trin, der passer i et hul, markeres fra starten.

Lynet

Swipe en opgave til højre for at give den et lyn, din egen markering for, at den er klar lige nu. En opgave med lyn springer køen over og står øverst, så når der opstår et hul, kigger du dér i stedet for at læse hele listen.

Trinrækkefølge, besluttet én gang

Om trinnene venter på hinanden, beslutter du én gang for hele gruppen, ikke ét for ét. I rækkefølge viser det første ufærdige trin. Vilkårlig rækkefølge viser den tidslomme, du kan tage lige nu.

Timer

Timeren tæller ned til det øjeblik, begivenheden slutter. Ved overlap vælger du, hvilken der tælles, og skifter med ét tryk. Den vises også i Dynamic Island og på låseskærmen.

Widgets

Til hjemme- og låseskærmen. Opgaver viser den opgave, du er i gang med, og trinnet i den. Lyn viser kun det, du kan tage på fem minutter lige nu. Regnbue viser selve tæthedsgitteret. Timer viser den resterende tid.

Deling

Send et invitationslink for at dele dine begivenheder skrivebeskyttet eller for at åbne en opgaveliste, som du og dem, du inviterer, læser og skriver i sammen.

Gratis og Rainbow Pro

Kernen i appen koster intet. Opgaver, regnbuen, opdeling i trin, de to spørgsmål, trinrækkefølge og timeren er gratis uden konto og uden tilmelding. Det er også gratis at bruge den sammen med din Mac.

Rainbow Pro åbner for det ekstra: widgets til hjemme- og låseskærmen, import fra Kalender, deling af begivenheder, statistik over begivenheder og hele ugens tidsregnskab. Vælg årligt med en gratis første uge, månedligt eller et engangskøb med livstidsadgang.

På din Mac

Rainbow Craft er en separat macOS-app. Med den samme iCloud-konto synkroniseres opgaver og ugeplaner af sig selv.

Privatliv

Der er ingen server. Det, du skriver, bliver på din enhed og i din egen private iCloud, hvor udvikleren ikke kan se det. Ingen reklame-id, ingen lokalitet, ingen tilmelding. Appen sender anonym brugsstatistik til udvikleren, og det kan du slå fra i Indstillinger.

Appen findes på 23 sprog, herunder dansk, og følger din enheds sprog.

Abonnementer og vilkår

Årlige og månedlige abonnementer fornyes automatisk til samme pris, medmindre de opsiges senest 24 timer før periodens udløb, og de opkræves via din Apple-konto. Du administrerer og opsiger dem i dine kontoindstillinger i App Store. Livstidsadgang er en engangsbetaling, ikke et abonnement.

Brugsbetingelser (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Anonymitetspolitik: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 그리스어 (el)

### 이름

```
Rainbow of Desire: Εργασίες
```

### 부제

```
Εβδομαδιαίο πλάνο σε βήματα
```

### 키워드

```
todo,λίστα,ατζέντα,ημερολόγιο,πρόγραμμα,οργάνωση,ΔΕΠΥ,ADHD,προθεσμία,ρουτίνα,χρονόμετρο,checklist
```

### 프로모션 텍스트

```
Δες πόσο γεμάτη είναι η εβδομάδα σου πριν μπεις σε αυτήν. Ό,τι χωράει σε ένα πεντάλεπτο κενό μένει πάντα στην κορυφή. Και το χρονόμετρο μετρά ως το τέλος του συμβάντος.
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
Το ημερολόγιο σου λέει αν κάτι είναι προγραμματισμένο, όχι πόσα έχουν στοιβαχτεί από πάνω του. Το Rainbow of Desire σχεδιάζει την εβδομάδα σου ως πλέγμα που σκουραίνει όσο επικαλύπτονται οι δουλειές σου, για να δεις τη βαριά εβδομάδα πριν μπεις σε αυτήν.

Κι όταν η εβδομάδα είναι βαριά, η λύση σπάνια είναι μια μεγαλύτερη λίστα, αλλά ένα βήμα αρκετά μικρό για τα πέντε λεπτά που πραγματικά έχεις.

Το ουράνιο τόξο

Πάτα παρατεταμένα ένα κενό κελί τη μέρα που ξεκινά κάτι και ξανά τη μέρα που τελειώνει: σχεδιάζεται μια γραμμή. Οι μέρες που πραγματικά δουλεύεις είναι σκούρες. Οι υπόλοιπες μένουν αχνές, γιατί μια ημιτελής δουλειά σε κρατά ακόμη κι όταν δεν την αγγίζεις.

Τα κελιά μιας σειράς είναι όσα τρέχεις ταυτόχρονα εκείνη τη μέρα. Όταν η σειρά γεμίσει, μία καθυστέρηση μετακινεί όλη τη μέρα.

Εμφανίζονται και τα συμβάντα των ημερολογίων που επιλέγεις, μόνο για ανάγνωση.

Δύο ερωτήσεις, μόνο δύο

Χώρισε μια μεγάλη δουλειά σε βήματα και κάθε βήμα κρίνεται με δύο ερωτήσεις.

Μπορείς να ξεκινήσεις χωρίς ζέσταμα; Αν πρέπει να θυμηθείς πού είχες μείνει, το πεντάλεπτο χάνεται στο ζέσταμα.

Τελειώνει μέσα σε πέντε λεπτά; Μια δουλειά που μένει στη μέση σε ακολουθεί και στην επόμενη ώρα.

Μόνο ένα βήμα με δύο «ναι» είναι κομμάτι, κάτι που πιάνεις μόλις ανοίξουν πέντε λεπτά. Τα άλλα θέλουν συνεχές διάστημα, χρόνο που κράτησες στην άκρη. Η εφαρμογή απαντά πρώτη και εσύ διορθώνεις μόνο όταν κάνει λάθος.

Δώδεκα πεντάλεπτα δεν κάνουν μία ώρα. Γι’ αυτό ό,τι χωράει σε ένα κενό πρέπει να σημειώνεται από την αρχή.

Η Αστραπή

Σύρε μια εργασία δεξιά για να της βάλεις Αστραπή, τη δική σου σήμανση ότι γίνεται αμέσως. Προσπερνά την ουρά και στέκεται στην κορυφή, οπότε σε ένα κενό κοιτάς μόνο εκεί.

Σειρά βημάτων, μία φορά

Αν τα βήματα περιμένουν το ένα το άλλο, το αποφασίζεις μία φορά για όλη την ομάδα. Με σειρά, στην κορυφή είναι το πρώτο ημιτελές βήμα· χωρίς σειρά, το κομμάτι που πιάνεις τώρα.

Χρονόμετρο

Το χρονόμετρο μετρά αντίστροφα ως το τέλος του συμβάντος. Όταν συμβάντα επικαλύπτονται, διαλέγεις ποιο θα μετρήσεις. Φαίνεται και στο Dynamic Island και στην οθόνη κλειδώματος.

Γραφικά στοιχεία

Στην οθόνη αφετηρίας και κλειδώματος. Οι Εργασίες δείχνουν τη δουλειά και το βήμα της, η Αστραπή μόνο ό,τι πιάνεται σε πέντε λεπτά, το Ουράνιο τόξο το πλέγμα πυκνότητας και το Χρονόμετρο τον χρόνο που απομένει.

Κοινή χρήση

Με έναν σύνδεσμο πρόσκλησης μοιράζεσαι τα συμβάντα σου μόνο για ανάγνωση ή ανοίγεις μια κοινή λίστα εργασιών με όσους προσκαλείς.

Δωρεάν και Rainbow Pro

Η καρδιά της εφαρμογής είναι δωρεάν: εργασίες, ουράνιο τόξο, χωρισμός σε βήματα, οι δύο ερωτήσεις, σειρά βημάτων και χρονόμετρο, χωρίς λογαριασμό και εγγραφή. Δωρεάν είναι και η χρήση μαζί με το Mac.

Το Rainbow Pro ξεκλειδώνει τα επιπλέον: γραφικά στοιχεία οθόνης αφετηρίας και κλειδώματος, εισαγωγή από το Ημερολόγιο, κοινή χρήση συμβάντων, στατιστικά συμβάντων και ολόκληρο το εβδομαδιαίο Καθολικό ανακτημένου χρόνου. Ετήσια συνδρομή με δωρεάν πρώτη εβδομάδα, μηνιαία ή εφάπαξ αγορά εφ’ όρου ζωής.

Στο Mac

Το Rainbow Craft είναι ξεχωριστή εφαρμογή macOS. Με τον ίδιο λογαριασμό iCloud, εργασίες και εβδομαδιαία πλάνα συγχρονίζονται μόνα τους.

Απόρρητο

Δεν υπάρχει διακομιστής. Ό,τι γράφεις μένει στη συσκευή σου και στο δικό σου ιδιωτικό iCloud, όπου ο προγραμματιστής δεν έχει πρόσβαση. Χωρίς διαφημιστικά αναγνωριστικά, χωρίς τοποθεσία. Η εφαρμογή στέλνει ανώνυμα στατιστικά χρήσης στον προγραμματιστή· τα απενεργοποιείς στις Ρυθμίσεις.

Διαθέσιμη σε 23 γλώσσες· ακολουθεί τη γλώσσα της συσκευής σου.

Συνδρομές και όροι

Οι ετήσιες και μηνιαίες συνδρομές ανανεώνονται αυτόματα με την ίδια τιμή, εκτός αν ακυρωθούν τουλάχιστον 24 ώρες πριν λήξει η περίοδος, και χρεώνονται στον Λογαριασμό Apple. Διαχείριση και ακύρωση γίνονται στις ρυθμίσεις λογαριασμού του App Store. Η αγορά εφ’ όρου ζωής είναι εφάπαξ πληρωμή, όχι συνδρομή.

Όροι χρήσης (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Πολιτική απορρήτου: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 핀란드어 (fi)

### 이름

```
Rainbow of Desire: Tehtävät
```

### 부제

```
Viikkoplanneri pienin askelin
```

### 키워드

```
tehtävälista,todo,adhd,kalenteri,aikataulu,ajanhallinta,muistilista,widget,määräaika,ajastin,viikko
```

### 프로모션 텍스트

```
Näe väreistä, kuinka täynnä viikkosi on, ennen kuin astut siihen. Viiteen minuuttiin mahtuvat asiat ovat aina ylimpänä. Ajastin laskee nyt tapahtuman loppuun.
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
Kalenteri kertoo, onko jokin aikataulussa. Se ei kerro, kuinka paljon sen päälle on kasautunut. Rainbow of Desire piirtää viikkosi ruudukoksi, joka tummuu, mitä enemmän menot menevät päällekkäin, joten näet raskaan viikon ennen kuin astut siihen.

Kun viikko on täynnä, ratkaisu on harvoin pidempi lista. Se on askel, joka mahtuu niihin viiteen minuuttiin, jotka sinulla oikeasti on.

Sateenkaari

Paina pitkään tyhjää ruutua alkupäivänä ja sitten päättymispäivänä, niin ruudukkoon piirtyy viiva. Päivät, joina oikeasti teet työtä, ovat tummia. Muut jäävät haaleiksi, koska keskeneräinen työ pitää sinua otteessaan silloinkin, kun et koske siihen.

Saman rivin ruudut ovat asiat, joita pyörität sinä päivänä yhtä aikaa. Kun rivi täyttyy, yksikin viivästys siirtää koko päivää.

Valitsemiesi kalenterien tapahtumat näkyvät sateenkaaressa ja päivänäkymässä vain luku -muodossa.

Kaksi kysymystä, vain kaksi

Pilko iso työ vaiheiksi. Jokainen vaihe lajitellaan kahdella kysymyksellä.

Pääsetkö alkuun ilman lämmittelyä? Jos pitää ensin muistella, mihin jäit, koko rako kuluu lämmittelyyn.

Valmistuuko se viidessä minuutissa? Kesken jäänyt työ seuraa sinua seuraavaan tuntiin.

Vain vaihe, jossa molempiin vastataan kyllä, on pätkä: siihen tartut, kun viisi minuuttia vapautuu. Kaikki muu on jakso ja kuuluu varaamaasi aikaan. Appi vastaa ensin kirjoittamiesi sanojen ja ajan perusteella. Puutut asiaan vain, kun se on väärässä.

Kaksitoista viiden minuutin rakoa ei ole tunti. Ajan sirpaleet eivät summaudu, ja juuri siksi rakoon mahtuvat vaiheet täytyy merkitä alusta asti.

Salama

Pyyhkäise riviä oikealle, niin siihen tulee salama: oma merkintäsi siitä, että tämän voi tehdä heti. Merkitty rivi ohittaa jonon ja nousee ylimmäksi, joten raon auetessa katsot vain sinne.

Vaiheiden järjestys, päätetty kerran

Päätät kerran koko ryhmälle, odottavatko vaiheet toisiaan, etkä kytke riippuvuuksia yksitellen. Järjestyksessä näyttää ensimmäisen keskeneräisen vaiheen. Vapaa järjestys näyttää pätkän, johon voit tarttua nyt.

Ajastin

Ajastin laskee alaspäin tapahtuman loppuun asti. Päällekkäisistä tapahtumista valitset ajastettavan ja vaihdat toiseen yhdellä napautuksella. Se näkyy myös Dynamic Islandissa ja lukitusnäytöllä.

Widgetit

Koti- ja lukitusnäytölle. Tehtävät näyttää työn, jota teet, ja sen sisällä olevan vaiheen. Salama näyttää vain sen, mihin voit tarttua nyt viidessä minuutissa. Sateenkaari näyttää itse tiheysruudukon. Ajastin näyttää jäljellä olevan ajan.

Jakaminen

Jaa tapahtumasi kutsulinkillä vain luku -muodossa tai avaa tehtävälista, jota muokkaatte yhdessä.

Ilmainen ja Rainbow Pro

Apin ydin on maksuton. Tehtävät, sateenkaari, pilkkominen, kaksi kysymystä, vaiheiden järjestys ja ajastin ovat ilmaisia, eikä tiliä tarvita. Käyttö Macin kanssa on myös ilmaista.

Rainbow Pro avaa lisäominaisuudet: koti- ja lukitusnäytön widgetit, tuonnin kalenterista, tapahtumien jakamisen, tapahtumatilastot ja koko tilikirjan. Valitse vuositilaus (ensimmäinen viikko ilmainen), kuukausitilaus tai kertaostona elinikäinen käyttöoikeus.

Macilla

Rainbow Craft on erillinen macOS-appi. Samalla iCloud-tilillä tehtävät ja viikkosuunnitelmat synkronoituvat itsestään.

Tietosuoja

Palvelinta ei ole. Kirjoittamasi pysyy laitteellasi ja yksityisessä iCloudissasi, jonne kehittäjä ei pääse. Ei mainostunnisteita, ei sijaintia, ei rekisteröitymistä. Appi lähettää kehittäjälle nimettömiä käyttötilastoja, ja voit laittaa sen pois päältä Asetuksissa.

Appi on saatavilla 23 kielellä, myös suomeksi, ja se noudattaa laitteesi kieltä.

Tilaukset ja ehdot

Vuosi- ja kuukausitilaukset uusiutuvat automaattisesti samaan hintaan, ellei niitä peruta viimeistään 24 tuntia ennen jakson loppua, ja ne veloitetaan Apple-tililtäsi. Hallitse tai peru tilauksia App Storen tiliasetuksissa. Elinikäinen käyttöoikeus on kertaosto, ei tilaus.

Käyttöehdot (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Tietosuojakäytäntö: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 인도네시아어 (id)

### 이름

```
Rainbow of Desire: To Do List
```

### 부제

```
Planner Mingguan & Pecah Tugas
```

### 키워드

```
jadwal,agenda,catatan,pengingat,kalender,produktivitas,fokus,ADHD,rutinitas,checklist,timer,widget
```

### 프로모션 텍스트

```
Lihat dulu sepadat apa minggu Anda lewat warna. Hal yang bisa selesai dalam lima menit luang selalu ada di paling atas. Kini timer menghitung sampai jadwal berakhir.
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
Kalender hanya memberi tahu apa yang sudah dijadwalkan, bukan seberapa banyak yang menumpuk. Rainbow of Desire menggambar minggu Anda sebagai kisi yang makin pekat saat pekerjaan bertumpuk, jadi minggu yang padat terlihat sebelum Anda menjalaninya.

Saat minggu padat, Anda tidak butuh daftar yang lebih panjang, melainkan satu langkah kecil yang selesai dalam lima menit yang ada.

Pelangi

Tekan lama sel kosong di hari mulai, lalu ketuk hari selesai, dan garis tergambar di kisi. Hari yang benar-benar Anda kerjakan tampil pekat, sisanya pucat. Pekerjaan yang belum selesai tetap membebani, bahkan di hari Anda tidak menyentuhnya.

Satu baris sel adalah pekerjaan yang berjalan bersamaan hari itu. Saat baris penuh, satu hal molor menggeser seluruh hari.

Acara dari kalender pilihan Anda juga muncul di Pelangi dan tampilan harian. App hanya membacanya, tanpa menulis apa pun ke kalender.

Dua pertanyaan, cukup dua

Pecah pekerjaan besar menjadi langkah, lalu setiap langkah diuji dengan dua pertanyaan.

Bisa mulai tanpa pemanasan? Kalau harus mengingat lagi sampai mana terakhir kali, lima menit habis untuk pemanasan.

Selesai dalam lima menit? Pekerjaan setengah jadi terus terbawa sampai jam berikutnya.

Hanya langkah dengan dua jawaban ya yang menjadi kepingan, untuk diambil saat ada lima menit luang. Sisanya adalah sesi fokus untuk waktu yang sudah Anda sisihkan. App menjawab lebih dulu dari kata dan durasi yang Anda tulis, dan Anda cukup mengoreksi saat keliru.

Dua belas kali lima menit bukan satu jam. Waktu sela tidak bisa dijumlahkan, jadi tandai sejak awal langkah yang muat di sana.

Kilat

Geser tugas ke kanan untuk memberinya Kilat, tanda bahwa tugas ini bisa dikerjakan sekarang juga. Tugas berkilat melompat ke paling atas, jadi saat ada waktu luang, cukup lihat di sana.

Urutan langkah, cukup sekali

Cukup tentukan sekali per kelompok apakah langkahnya saling menunggu. Jika Berurutan, langkah pertama yang belum selesai ada di atas. Jika Bebas urutan, kepingan yang bisa diambil sekarang naik ke atas.

Timer

Timer menghitung mundur sampai jadwal berakhir. Jika jadwal bertumpuk, pilih yang mau dihitung dan ganti dengan sekali ketuk. Juga tampil di Dynamic Island dan Layar Terkunci.

Widget

Untuk Layar Utama dan Layar Terkunci. Widget Tugas menampilkan pekerjaan yang sedang Anda pegang beserta langkahnya, widget Kilat hanya yang bisa diambil dalam lima menit, widget Pelangi kisi kepadatan, dan widget Timer sisa waktu.

Berbagi

Kirim tautan undangan untuk membagikan jadwal dalam mode baca saja, atau buka daftar tugas yang diedit bersama orang yang Anda undang.

Gratis, dan Rainbow Pro

Inti app ini gratis. Tugas, Pelangi, memecah langkah, dua pertanyaan, urutan langkah, dan timer semuanya gratis, tanpa akun atau pendaftaran. Memakainya bersama Mac juga gratis.

Rainbow Pro membuka widget Layar Utama dan Layar Terkunci, impor dari Kalender, berbagi jadwal, statistik jadwal, dan Catatan Waktu Kembali lengkap. Pilih tahunan dengan minggu pertama gratis, bulanan, atau seumur hidup sekali bayar.

Di Mac

Rainbow Craft adalah app macOS tersendiri. Dengan akun iCloud yang sama, tugas dan rencana mingguan tersinkron otomatis.

Privasi

Tidak ada server. Catatan Anda hanya ada di perangkat dan iCloud pribadi Anda, dan pengembang tidak bisa melihatnya. Tanpa pengenal iklan, lokasi, atau pendaftaran. App mengirim statistik penggunaan anonim ke pengembang, yang bisa dimatikan di Pengaturan.

Tersedia dalam 23 bahasa dan mengikuti bahasa perangkat Anda.

Langganan dan ketentuan

Langganan tahunan dan bulanan diperpanjang otomatis dengan harga sama kecuali dibatalkan paling lambat 24 jam sebelum periode berakhir, dan ditagihkan ke Akun Apple Anda. Kelola atau batalkan di pengaturan akun App Store. Paket seumur hidup adalah pembayaran satu kali, bukan langganan.

Ketentuan Penggunaan (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Kebijakan Privasi: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 노르웨이어(보크말) (nb)

### 이름

```
Rainbow of Desire: Ukeplan
```

### 부제

```
Del oppgaver opp i små trinn
```

### 키워드

```
todo,huskeliste,gjøremål,oppgaveliste,planlegger,kalender,tidsstyring,adhd,fokus,sjekkliste,rutine
```

### 프로모션 텍스트

```
Se i farger hvor full uken er før du går inn i den. Det du rekker på fem minutter, ligger alltid øverst. Nå teller tidtakeren ned til hendelsen er slutt.
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
En kalender forteller deg om noe er planlagt. Den forteller ikke hvor mye som ligger oppå det. Rainbow of Desire tegner ukene dine som et rutenett der fargen blir mørkere jo mer oppgavene overlapper, så du ser den tunge uken før du går inn i den.

Og når uken er tung, er svaret sjelden en lengre liste. Det er ett trinn som er lite nok for de fem minuttene du faktisk har.

Regnbuen

Trykk og hold på en tom rute den dagen noe starter, og igjen den dagen det slutter, så tegnes en linje nedover rutenettet. Dagene du faktisk jobber med det, er mørke. Resten er bleke, for uavsluttet arbeid binder deg også de dagene du ikke tar i det.

Hendelser fra kalenderne du velger, vises på regnbuen og i dagen din. De leses bare, og ingenting skrives tilbake.

To spørsmål, bare to

Del en stor oppgave opp i trinn. Hvert trinn sorteres deretter med to spørsmål.

Kan du begynne uten oppvarming? Må du først lese deg inn på hvor du slapp, går de fem minuttene med til å komme i gang.

Blir den ferdig innen fem minutter? Arbeid som blir stående halvferdig, følger deg inn i neste time.

Bare et trinn med ja på begge er en tidslomme, noe du tar når det åpner seg fem minutter. Alt annet er en fokusblokk og hører hjemme i tid du har satt av. Appen svarer først ut fra ordene og tiden du har skrevet. Du griper bare inn når den tar feil.

Tolv luker på fem minutter er ikke én time. Småbiter av tid kan ikke legges sammen, og nettopp derfor må trinnene som passer i en luke, merkes fra starten.

Lynet

Sveip en oppgave til høyre for å gi den et lyn, ditt eget merke for at den er klar akkurat nå. En oppgave med lyn hopper over køen og står øverst, så når det åpner seg en luke, ser du der i stedet for å lese hele listen.

Trinnrekkefølge, bestemt én gang

Om trinnene venter på hverandre, bestemmer du én gang for hele gruppen, ikke ett for ett. I rekkefølge viser det første uferdige trinnet. Valgfri rekkefølge viser tidslommen du kan ta akkurat nå.

Tidtaker

Tidtakeren teller ned til øyeblikket hendelsen slutter. Overlapper hendelser, velger du hvilken som skal tas tiden på, og bytter med ett trykk. Den vises også i Dynamic Island og på låseskjermen.

Widgeter

For Hjem- og låseskjermen. Oppgaver viser oppgaven du holder på med, og trinnet i den. Lyn viser bare det du kan ta på fem minutter akkurat nå. Regnbue viser selve tetthetsrutenettet. Tidtaker viser gjenværende tid.

Deling

Send en invitasjonslenke for å dele hendelsene dine skrivebeskyttet, eller for å åpne en oppgaveliste som du og de du inviterer, leser og skriver i sammen.

Gratis og Rainbow Pro

Kjernen i appen koster ingenting. Oppgaver, regnbuen, oppdeling i trinn, de to spørsmålene, trinnrekkefølge og tidtakeren er gratis, uten konto og uten registrering. Det er også gratis å bruke den sammen med Macen.

Rainbow Pro låser opp det ekstra: widgeter for Hjem- og låseskjermen, import fra Kalender, deling av hendelser, hendelsesstatistikk og hele ukens tidsregnskap. Velg årlig med en gratis første uke, månedlig eller et engangskjøp med livstidstilgang.

På Macen

Rainbow Craft er en egen macOS-app. Med samme iCloud-konto synkroniseres oppgaver og ukeplaner av seg selv.

Personvern

Det finnes ingen server. Det du skriver, blir på enheten din og i din egen private iCloud, der utvikleren ikke kan se det. Ingen reklame-ID, ingen posisjon, ingen registrering. Appen sender anonym bruksstatistikk til utvikleren, og det kan du slå av i Innstillinger.

Appen finnes på 23 språk, blant dem norsk, og følger språket på enheten din.

Abonnementer og vilkår

Årlige og månedlige abonnementer fornyes automatisk til samme pris med mindre de sies opp senest 24 timer før perioden utløper, og de belastes Apple-kontoen din. Du administrerer og sier dem opp i kontoinnstillingene i App Store. Livstidstilgang er en engangsbetaling, ikke et abonnement.

Bruksvilkår (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Personvernerklæring: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 네덜란드어 (nl)

### 이름

```
Rainbow of Desire: weekplanner
```

### 부제

```
Grote taken in kleine stappen
```

### 키워드

```
todo,takenlijst,planner,agenda,planning,adhd,focus,uitstelgedrag,timeblocking,tijdmanagement,widget
```

### 프로모션 텍스트

```
Zie aan de kleur hoe vol je week is voordat je erin stapt. Wat in vijf minuten kan, staat altijd bovenaan. En de timer telt nu af tot het einde van je activiteit.
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
Een agenda vertelt je of er iets gepland staat, niet hoeveel er op elkaar gestapeld ligt. Rainbow of Desire tekent je weken als een raster dat donkerder kleurt naarmate je werk overlapt, zodat je een zware week ziet voordat je erin stapt.

En als de week vol zit, heb je geen langere lijst nodig. Je hebt één stap nodig die klein genoeg is voor de vijf minuten die je echt hebt.

De regenboog

Houd een leeg vakje ingedrukt op de begindag en daarna op de einddag: er komt een lijn in het raster. Dagen waarop je er echt aan werkt, zijn donker. De rest blijft licht, want onaf werk houdt je ook bezig op dagen dat je het niet aanraakt.

De vakjes in één rij zijn de klussen die je die dag tegelijk draaiende houdt. Zit de rij vol, dan schuift de hele dag op als er één uitloopt.

Activiteiten uit de agenda's die je kiest, staan ook op de regenboog, alleen-lezen. Er wordt niets in je agenda gezet.

Twee vragen, niet meer

Splits een grote klus op in stappen. Elke stap krijgt twee vragen.

Kun je beginnen zonder opstarttijd? Moet je eerst teruglezen waar je was, dan gaan je vijf minuten op aan opstarten.

Is het binnen vijf minuten klaar? Half werk neem je mee naar het volgende uur.

Alleen een stap met twee keer ja is een fragment: iets wat je oppakt zodra er vijf minuten vrijkomen. Al het andere is een brok, en hoort in tijd die je hebt vrijgehouden. De app antwoordt eerst zelf, op basis van wat je opschreef. Klopt het niet, dan pas je het aan.

Twaalf keer vijf minuten is geen uur. Daarom markeer je meteen welke stappen in een gaatje passen.

De bliksem

Veeg een taak naar rechts om er een bliksem op te zetten: je eigen teken dat dit nu meteen kan. Een taak met een bliksem slaat de rij over en staat bovenaan. Is er een gaatje, dan kijk je alleen daar.

Stapvolgorde, één keer bepaald

Of stappen op elkaar wachten, bepaal je één keer per groep in plaats van per stap. ‘Op volgorde’ toont de eerste onafgemaakte stap, ‘Willekeurig’ toont het fragment dat je nu kunt oppakken.

Timer

De timer telt af tot de activiteit eindigt. Overlappen er meer, dan kies je welke en wissel je met één tik. Je ziet hem ook in Dynamic Island en op het toegangsscherm.

Widgets

Voor je beginscherm en toegangsscherm. Taken toont de klus waar je mee bezig bent en de stap daarin, Bliksem alleen wat nu in vijf minuten kan, Regenboog het dichtheidsraster en Timer de resterende tijd.

Delen

Deel met een uitnodigingslink je planning alleen-lezen, of open een takenlijst waarin je samen met anderen leest en schrijft.

Gratis, en Rainbow Pro

De kern van de app kost niets. Taken, de regenboog, opsplitsen in stappen, de twee vragen, de stapvolgorde en de timer zijn gratis, zonder account of registratie. Ook het gebruik met de Mac is gratis.

Rainbow Pro ontgrendelt de extra's: widgets voor beginscherm en toegangsscherm, importeren uit Agenda, je planning delen, planningsstatistieken en het volledige tijdlogboek. Kies jaarlijks met een gratis eerste week, maandelijks, of een eenmalige aankoop voor altijd.

Op de Mac

Rainbow Craft is een aparte macOS-app. Met hetzelfde iCloud-account synchroniseren taken en weekplannen vanzelf.

Privacy

Er is geen server. Wat je schrijft, staat alleen op je apparaat en in je eigen iCloud, buiten bereik van de ontwikkelaar. Geen advertentie-ID's, geen locatie, geen registratie. De app stuurt anonieme gebruiksstatistieken naar de ontwikkelaar; dat kun je uitzetten in Instellingen.

Beschikbaar in 23 talen. De app volgt de taal van je apparaat.

Abonnementen en voorwaarden

Abonnementen worden automatisch tegen dezelfde prijs verlengd, tenzij je uiterlijk 24 uur voor het einde van de periode opzegt. Ze worden afgerekend via je Apple Account. Beheren of opzeggen doe je in je accountinstellingen van de App Store. Levenslang is een eenmalige betaling, geen abonnement.

Gebruiksvoorwaarden (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacybeleid: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 폴란드어 (pl)

### 이름

```
Rainbow of Desire: Lista zadań
```

### 부제

```
Planer tygodnia krok po kroku
```

### 키워드

```
todo,organizer,terminarz,kalendarz,adhd,produktywność,checklista,widżet,timer,skupienie,harmonogram
```

### 프로모션 텍스트

```
Kolory pokażą Ci, jak zapełniony jest tydzień, zanim w niego wejdziesz. To, co zrobisz w pięć minut, zawsze czeka na górze listy.
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
Kalendarz mówi, czy coś jest zaplanowane, ale nie, ile spraw piętrzy się naraz. Rainbow of Desire rysuje tydzień jako siatkę, która ciemnieje tam, gdzie zadania się nakładają, więc ciężki tydzień widzisz, zanim w niego wejdziesz.

A gdy tydzień jest pełny, nie pomoże dłuższa lista. Pomoże jeden krok tak mały, że zmieści się w pięciu minutach, które naprawdę masz.

Tęcza

Przytrzymaj pustą komórkę w dniu, w którym coś się zaczyna, potem w dniu, w którym się kończy, a na siatce pojawi się linia. Dni, w które naprawdę nad tym pracujesz, są ciemne. Reszta zostaje jasna, bo niedokończona sprawa trzyma Cię także wtedy, gdy jej nie dotykasz.

Wiersz to sprawy toczone tego dnia naraz. Gdy się zapełni, jedno opóźnienie przesuwa cały dzień.

Wydarzenia z wybranych kalendarzy też widać na tęczy i w widoku dnia, tylko do odczytu.

Dwa pytania i nic więcej

Podziel dużą sprawę na kroki, a każdy krok przejdzie przez dwa pytania.

Czy da się zacząć bez rozruchu? Jeśli najpierw musisz sobie przypomnieć, gdzie skończyłeś, pięć minut pójdzie na rozgrzewkę.

Czy skończysz to w pięć minut? Praca zostawiona w połowie ciągnie się za Tobą do następnej godziny.

Tylko krok z dwoma „tak” jest okruchem: bierzesz go, gdy pojawi się pięć wolnych minut. Reszta to ciągłe odcinki na czas, który sobie zarezerwujesz. Aplikacja odpowiada pierwsza, na podstawie słów i czasu, które wpiszesz. Poprawiasz ją tylko wtedy, gdy się pomyli.

Dwanaście razy po pięć minut to nie godzina. Okruchy czasu się nie sumują, dlatego kroki mieszczące się w luce trzeba oznaczyć od początku.

Błyskawica

Przesuń zadanie w prawo, aby dodać Błyskawicę, Twój znak, że to da się zrobić od razu. Zadanie z Błyskawicą omija kolejkę i staje na górze. Gdy pojawi się luka, nie czytasz całej listy, tylko patrzysz tam.

Kolejność kroków ustalasz raz

Zamiast łączyć zależności jedna po drugiej, decydujesz raz dla całej grupy, czy kroki na siebie czekają. Przy kolejności „po kolei” na górze stoi pierwszy nieukończony krok, przy „dowolnie” okruch, który możesz wziąć teraz.

Timer

Timer odlicza czas do końca wydarzenia. Gdy wydarzenia się nakładają, wybierasz, które liczyć, i zmieniasz je jednym stuknięciem. Widać go też w Dynamic Island i na ekranie blokady.

Widżety

Na ekranie początkowym i ekranie blokady. Zadania pokazują bieżącą sprawę i jej krok. Błyskawica pokazuje tylko to, co zrobisz teraz w pięć minut. Tęcza pokazuje siatkę gęstości, a Timer pozostały czas.

Udostępnianie

Wyślij link z zaproszeniem, aby udostępnić wydarzenia tylko do odczytu albo prowadzić z innymi wspólną listę zadań.

Za darmo i Rainbow Pro

Serce aplikacji nic nie kosztuje. Zadania, tęcza, dzielenie na kroki, dwa pytania, kolejność kroków i timer są za darmo, bez konta i rejestracji. Praca z Makiem też jest darmowa.

Rainbow Pro odblokowuje widżety na ekranie początkowym i blokady, import z Kalendarza, udostępnianie wydarzeń, statystyki wydarzeń i pełny rejestr odzyskanego czasu. Do wyboru: plan roczny (pierwszy tydzień za darmo), miesięczny lub dożywotni.

Na Macu

Rainbow Craft to osobna aplikacja na macOS. Na tym samym koncie iCloud zadania i plany tygodnia synchronizują się same.

Prywatność

Nie ma serwera. Twoje wpisy zostają na urządzeniu i w Twoim prywatnym iCloud, poza zasięgiem dewelopera. Bez identyfikatorów reklamowych, lokalizacji i rejestracji. Aplikacja wysyła deweloperowi anonimowe statystyki użycia, które możesz wyłączyć w Ustawieniach.

Aplikacja działa w 23 językach, w tym po polsku, i używa języka urządzenia.

Subskrypcje i warunki

Subskrypcja roczna i miesięczna odnawia się automatycznie w tej samej cenie, jeśli nie anulujesz jej co najmniej 24 godziny przed końcem okresu. Opłata jest pobierana z Twojego Apple Account. Zarządzasz nią w ustawieniach konta App Store. Dostęp dożywotni to jednorazowa płatność, nie subskrypcja.

Warunki korzystania (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Polityka prywatności: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 스웨덴어 (sv)

### 이름

```
Rainbow of Desire: Att göra
```

### 부제

```
Veckoplanerare i små steg
```

### 키워드

```
todo,lista,adhd,planering,kalender,schema,checklista,fokus,widget,deadline,rutin,timer,uppgift,vecka
```

### 프로모션 텍스트

```
Se i färg hur full veckan är innan du kliver in i den. Det du hinner på fem minuter ligger alltid överst. Timern räknar nu ned till att händelsen slutar.
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
En kalender visar om något är inplanerat. Den visar inte hur mycket som ligger staplat ovanpå. Rainbow of Desire ritar dina veckor som ett rutnät där färgen blir djupare ju mer dina åtaganden överlappar, så att du ser den tunga veckan innan du kliver in i den.

Och när veckan är full är svaret sällan en längre lista. Det är ett steg som är litet nog att ta under de fem minuter du faktiskt har.

Regnbågen

Tryck länge på en tom ruta den dag något börjar och sedan på dagen det slutar, så dras en linje i rutnätet. Dagar du faktiskt jobbar med det blir mörka. Resten förblir bleka, för ett ofärdigt jobb håller fast dig även de dagar du inte rör det.

Rutorna i en rad är det du jonglerar samtidigt den dagen. När raden är full skjuter en enda försening hela dagen.

Händelser från kalendrarna du väljer syns i regnbågen och i dagsvyn, skrivskyddat.

Två frågor, bara två

Dela upp ett stort jobb i steg. Varje steg sorteras sedan med två frågor.

Kan du börja utan uppstart? Måste du först minnas var du slutade går hela luckan åt till uppstart.

Blir det klart inom fem minuter? Det som lämnas halvfärdigt följer med dig in i nästa timme.

Bara ett steg med ja på båda är ett ministeg, något du tar när fem minuter dyker upp. Allt annat kräver fokustid, i tid du har avsatt. Appen svarar först, utifrån orden och tiden du skrev. Du rättar bara när den har fel.

Tolv femminutersluckor blir inte en timme. Småbitar av tid går inte att lägga ihop, och just därför måste stegen som ryms i en lucka märkas ut från början.

Blixten

Svep en rad åt höger för att sätta en blixt, din egen markering för att det här går att göra direkt. En rad med blixt går före i kön och står överst, så när en lucka öppnar sig tittar du där i stället för att läsa hela listan.

Stegordning, bestämd en gång

Om stegen väntar på varandra bestämmer du en gång för hela gruppen, i stället för att koppla ihop beroenden ett och ett. I ordning visar det första ofärdiga steget. Valfri ordning visar det ministeg du kan ta just nu.

Timer

Timern räknar ned till den stund händelsen slutar. När händelser överlappar väljer du vilken som ska räknas och byter till en annan med ett tryck. Den syns också i Dynamic Island och på låsskärmen.

Widgetar

För hem- och låsskärmen. Uppgifter visar jobbet du håller på med och steget i det. Blixt visar bara det du kan ta på fem minuter just nu. Regnbåge visar själva täthetsrutnätet. Timer visar tiden som är kvar.

Delning

Dela dina händelser skrivskyddat via en inbjudningslänk, eller öppna en uppgiftslista som ni läser och skriver i tillsammans.

Gratis och Rainbow Pro

Kärnan i appen kostar ingenting. Uppgifter, regnbågen, uppdelning i steg, de två frågorna, stegordning och timern är gratis, utan konto. Att använda appen tillsammans med Mac är också gratis.

Rainbow Pro låser upp extrafunktionerna: widgetar för hem- och låsskärmen, import från Kalender, delning av händelser, händelsestatistik och hela tidsliggaren. Välj årsvis med en gratis första vecka, månadsvis eller ett engångsköp för livstid.

På Mac

Rainbow Craft är en separat macOS-app. Med samma iCloud-konto synkas uppgifter och veckoplaner av sig själva.

Integritet

Det finns ingen server. Det du skriver stannar på din enhet och i din privata iCloud, där utvecklaren inte når det. Inga annonsidentifierare, ingen plats, ingen registrering. Appen skickar anonym användningsstatistik till utvecklaren, och du kan stänga av det i Inställningar.

Appen finns på 23 språk, bland annat svenska, och följer språket på din enhet.

Prenumerationer och villkor

Års- och månadsprenumerationer förnyas automatiskt till samma pris om de inte sägs upp senast 24 timmar innan perioden tar slut, och debiteras ditt Apple-konto. Hantera eller säg upp dem i kontoinställningarna i App Store. Livstidsköpet är en engångsbetalning, inte en prenumeration.

Användarvillkor (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Integritetspolicy: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 태국어 (th)

### 이름

```
Rainbow of Desire: แพลนเนอร์
```

### 부제

```
แตกงานเป็นขั้นตอน 5 นาที
```

### 키워드

```
สิ่งที่ต้องทำ,ตารางงาน,จัดการเวลา,ปฏิทิน,วิดเจ็ต,สมาธิ,ADHD,ผัดวันประกันพรุ่ง,กิจวัตร,ตัวจับเวลา
```

### 프로모션 텍스트

```
ดูก่อนด้วยสีว่าสัปดาห์นี้แน่นแค่ไหน งานที่หยิบทำได้ในช่องว่าง 5 นาทีอยู่บนสุดเสมอ และตอนนี้ตัวจับเวลานับถอยหลังจนถึงเวลาที่กิจกรรมจบ
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
ปฏิทินบอกได้แค่ว่ามีนัดหรือไม่ แต่ไม่ได้บอกว่างานซ้อนทับกันอยู่มากแค่ไหน Rainbow of Desire วาดแต่ละสัปดาห์เป็นตาราง และระบายสีให้เข้มขึ้นเมื่องานซ้อนกันมากขึ้น คุณจึงเห็นสัปดาห์ที่แน่นเอี้ยดก่อนจะก้าวเข้าไป

เมื่อสัปดาห์แน่นเต็มที่ สิ่งที่ต้องการไม่ใช่รายการที่ยาวขึ้น แต่คือก้าวเล็ก ๆ หนึ่งก้าวที่ทำจบได้ใน 5 นาทีที่คุณมีอยู่ตอนนี้

สายรุ้ง

กดค้างที่ช่องว่างในวันที่งานเริ่ม แล้วกดค้างอีกครั้งที่วันที่งานจบ เส้นหนึ่งจะถูกขีดลงบนตาราง วันที่ลงมือทำจริงจะเป็นสีเข้ม วันอื่นเป็นสีจาง เพราะงานที่ยังไม่จบยังคงรั้งคุณไว้แม้ในวันที่ไม่ได้แตะมัน

ช่องที่เรียงในแถวเดียวกันคืองานที่คุณหมุนพร้อมกันในวันนั้น เมื่อแถวเต็ม แค่งานเดียวเลื่อนก็ทำให้ทั้งวันเลื่อนตาม

กิจกรรมจากปฏิทินที่คุณเลือกจะแสดงบนสายรุ้งและในมุมมองรายวันด้วย แอปอ่านอย่างเดียว ไม่เขียนสิ่งใดลงในปฏิทิน

สองคำถาม แค่สองข้อ

เมื่อแบ่งงานใหญ่เป็นขั้นตอน แต่ละขั้นตอนจะถูกคัดแยกด้วยสองคำถาม

เริ่มได้ทันทีโดยไม่ต้องวอร์มเครื่องไหม ถ้าต้องนึกย้อนว่าทำถึงไหนแล้ว 5 นาทีจะหมดไปกับการวอร์มเครื่อง

ทำจบได้ใน 5 นาทีไหม งานที่ค้างไว้ครึ่งทางจะตามไปรบกวนชั่วโมงถัดไป

ขั้นตอนที่ตอบว่าใช่ทั้งสองข้อเท่านั้นคือชิ้นย่อย เป็นงานที่หยิบทำได้เมื่อมี 5 นาทีว่าง ที่เหลือต้องใช้ช่วงเวลายาวที่คุณกันไว้ แอปจะตอบให้ก่อนจากคำและเวลาที่คุณเขียน คุณแค่แก้เมื่อแอปตอบผิด

ห้านาทีสิบสองครั้งไม่ใช่หนึ่งชั่วโมง เวลาเศษเล็กเศษน้อยรวมกันไม่ได้ ขั้นตอนที่ใส่ในช่องว่างได้จึงต้องแยกทำเครื่องหมายไว้ตั้งแต่แรก

สายฟ้า

ปัดสิ่งที่ต้องทำไปทางขวาเพื่อติดสายฟ้า เป็นเครื่องหมายของคุณเองว่างานนี้ทำได้ทันที งานที่ติดสายฟ้าจะลัดคิวขึ้นไปอยู่บนสุด เมื่อมีช่องว่าง แค่มองตรงนั้นโดยไม่ต้องอ่านทั้งรายการ

ลำดับขั้นตอน ตั้งครั้งเดียว

ไม่ต้องโยงทีละขั้นว่าขั้นไหนต้องรอขั้นไหน แค่ตั้งครั้งเดียวต่อกลุ่ม ถ้าเลือกตามลำดับ ขั้นตอนแรกที่ยังไม่เสร็จจะอยู่บนสุด ถ้าเลือกไม่เรียงลำดับ ชิ้นย่อยที่หยิบทำได้ตอนนี้จะขึ้นมาก่อน

ตัวจับเวลา

ตัวจับเวลานับถอยหลังจนถึงเวลาที่กิจกรรมจบ เมื่อกิจกรรมซ้อนกัน คุณเลือกได้ว่าจะจับเวลาอันไหน และสลับไปกิจกรรมอื่นได้ในแตะเดียว แสดงใน Dynamic Island และบนหน้าจอล็อกด้วย

วิดเจ็ต

วางบนหน้าจอโฮมและหน้าจอล็อกได้ วิดเจ็ตสิ่งที่ต้องทำแสดงงานที่คุณทำอยู่และขั้นตอนข้างใน วิดเจ็ตสายฟ้าแสดงเฉพาะสิ่งที่หยิบทำได้ใน 5 นาทีตอนนี้ วิดเจ็ตสายรุ้งแสดงตารางความหนาแน่น วิดเจ็ตตัวจับเวลาแสดงเวลาที่เหลือ

แชร์

ส่งลิงก์คำเชิญเพื่อแชร์กิจกรรมของคุณแบบอ่านอย่างเดียว หรือเปิดรายการสิ่งที่ต้องทำที่คุณกับคนที่เชิญอ่านและเขียนร่วมกันได้

ใช้ฟรี และ Rainbow Pro

หัวใจของแอปใช้ได้ฟรี การจดสิ่งที่ต้องทำ สายรุ้ง การแบ่งขั้นตอน สองคำถาม ลำดับขั้นตอน และตัวจับเวลา ฟรีทั้งหมด ไม่ต้องมีบัญชีหรือสมัครสมาชิก ใช้ร่วมกับ Mac ก็ฟรี

วิดเจ็ตบนหน้าจอโฮมและหน้าจอล็อก การนำเข้าจากปฏิทิน การแชร์กิจกรรม สถิติกิจกรรม และสมุดเวลาที่ได้คืนฉบับเต็ม ปลดล็อกด้วย Rainbow Pro เลือกได้ทั้งรายปี (ทดลองใช้ฟรีสัปดาห์แรก) รายเดือน หรือแบบตลอดชีพที่จ่ายครั้งเดียว

บน Mac

Rainbow Craft เป็นแอป macOS แยกต่างหาก เมื่อใช้บัญชี iCloud เดียวกัน สิ่งที่ต้องทำและแผนรายสัปดาห์จะซิงค์กันเอง

ความเป็นส่วนตัว

ไม่มีเซิร์ฟเวอร์ สิ่งที่คุณเขียนอยู่แค่ในอุปกรณ์และ iCloud ส่วนตัวของคุณ ผู้พัฒนาเข้าถึงไม่ได้ ไม่มีตัวระบุโฆษณา ไม่ใช้ตำแหน่ง ไม่ต้องสมัคร แอปส่งสถิติการใช้งานแบบไม่ระบุตัวตนให้ผู้พัฒนา และปิดได้ในการตั้งค่า

รองรับ 23 ภาษา รวมถึงภาษาไทย และแสดงตามภาษาของอุปกรณ์

การสมัครสมาชิกและข้อกำหนด

การสมัครสมาชิกรายปีและรายเดือนจะต่ออายุอัตโนมัติในราคาเดิม เว้นแต่จะยกเลิกอย่างน้อย 24 ชั่วโมงก่อนสิ้นสุดรอบ และเรียกเก็บเงินผ่านบัญชี Apple ของคุณ จัดการหรือยกเลิกได้ในการตั้งค่าบัญชีของ App Store แบบตลอดชีพเป็นการชำระครั้งเดียว ไม่ใช่การสมัครสมาชิก

ข้อกำหนดการใช้งาน (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
นโยบายความเป็นส่วนตัว: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 튀르키예어 (tr)

### 이름

```
Rainbow of Desire: Planlayıcı
```

### 부제

```
Görevleri Böl, Haftanı Gör
```

### 키워드

```
yapılacaklar,liste,todo,ajanda,takvim,haftalık,zaman,yönetimi,adhd,odak,verimlilik,widget,erteleme
```

### 프로모션 텍스트

```
Haftanızın ne kadar dolu olduğunu önce renklerle görün. Beş dakikalık bir boşlukta yapılacak iş hep en üstte. Zamanlayıcı artık etkinliğin bittiği ana kadar sayıyor.
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
Takvim size bir işin planlanıp planlanmadığını söyler. Üst üste ne kadar iş yığıldığını söylemez. Rainbow of Desire haftalarınızı bir ızgara olarak çizer ve işler çakıştıkça rengi koyulaştırır; yoğun bir haftaya girmeden önce onu görürsünüz.

Hafta dolu olduğunda çözüm daha uzun bir liste değildir. Elinizdeki beş dakikada atılabilecek kadar küçük tek bir adımdır.

GÖKKUŞAĞI

Bir işin başladığı gündeki boş hücreye basılı tutun, sonra bittiği güne bir kez daha; ızgaraya bir çizgi çekilir. Gerçekten çalıştığınız günler koyu, diğerleri soluk kalır. Çünkü bitmemiş iş, el atmadığınız günlerde bile sizi bağlı tutar.

Bir satırdaki hücreler o gün aynı anda yürüttüğünüz işlerdir. Satır dolunca tek bir aksama bütün günü kaydırır.

Seçtiğiniz takvimlerdeki etkinlikler de gökkuşağında ve gün görünümünde yer alır; takvimlerinize hiçbir şey yazılmaz.

İKİ SORU, YALNIZCA İKİ

Büyük bir işi adımlara bölün. Her adım iki soruyla ayrılır.

Isınmadan başlayabilir misiniz? Nerede kaldığınızı yeniden hatırlamanız gerekiyorsa beş dakikanın tamamı ısınmaya gider.

Beş dakika içinde biter mi? Yarım kalan iş sizi bir sonraki saate kadar izler.

İki soruya da evet diyen adım bir parçadır; beş dakika açıldığında ele alınır. Gerisi odak süresi ister ve ayırdığınız zamana aittir. Siz yazarken uygulama, sözcüklerinize ve süreye bakıp önce kendisi yanıtlar. Yalnızca yanıldığında düzeltirsiniz.

On iki kez beş dakika bir saat etmez. Parça zamanlar toplanmaz; bu yüzden bir boşluğa sığan adımlar baştan işaretlenmelidir.

ŞİMŞEK

Bir görevi sağa kaydırıp Şimşek ekleyin; bu, "bu iş hemen yapılabilir" diyen kendi işaretinizdir. Şimşekli işler sırayı atlayıp en üste geçer. Boşluk açılınca bütün listeyi değil, yalnızca orayı okursunuz.

ADIM SIRASI, BİR KEZ

Adımların birbirini bekleyip beklemediğine tek tek değil, her grup için bir kez karar verirsiniz. Sırayla seçeneğinde henüz bitmemiş ilk adım, sırasız seçeneğinde şu an alınabilecek parça en üstte durur.

ZAMANLAYICI

Zamanlayıcı, etkinliğin bittiği ana kadar geri sayar. Etkinlikler çakışırsa hangisinin sayılacağını seçer, tek dokunuşla diğerine geçersiniz. Dynamic Island’da ve Kilitli Ekran’da da görünür.

ARAÇ TAKIMLARI

Ana Ekran’a ve Kilitli Ekran’a ekleyin. Görevler, üzerinde çalıştığınız işi ve içindeki adımı; Şimşek, yalnızca şu an beş dakikada yapılabilecekleri; Gökkuşağı, yoğunluk ızgarasını; Zamanlayıcı ise kalan süreyi gösterir.

PAYLAŞIM

Bir davet bağlantısı gönderip etkinliklerinizi salt okunur olarak paylaşın ya da davet ettiğiniz kişilerle birlikte okuyup yazdığınız bir görev listesi açın.

ÜCRETSİZ OLANLAR VE RAINBOW PRO

Uygulamanın özü ücretsizdir. Görev yazmak, gökkuşağı, adımlara bölme, iki soru, adım sırası ve zamanlayıcı ücretsizdir; hesap ya da kayıt gerekmez. Mac ile birlikte kullanmak da ücretsizdir.

Ana Ekran ve Kilitli Ekran araç takımları, takvimden içe aktarma, etkinlik paylaşımı, etkinlik istatistikleri ve Geri Kazanım Defteri’nin tamamı Rainbow Pro ile açılır. Yıllık (ilk hafta ücretsiz deneme), aylık ya da tek seferlik ömür boyu satın alma arasından seçin.

MAC’TE

Rainbow Craft ayrı bir macOS uygulamasıdır. Aynı iCloud hesabında görevleriniz ve haftalık planlarınız kendiliğinden eşzamanlanır.

GİZLİLİK

Sunucu yoktur. Yazdıklarınız yalnızca aygıtınızda ve kendi özel iCloud’unuzda durur; geliştirici bunlara erişemez. Reklam kimliği yok, konum yok, kayıt yok. Uygulama geliştiriciye anonim kullanım istatistikleri gönderir; bunu Ayarlar’dan kapatabilirsiniz.

Türkçe dahil 23 dili destekler ve aygıtınızın dilini izler.

ABONELİK VE KOŞULLAR

Yıllık ve aylık abonelikler, dönem bitmeden en az 24 saat önce iptal edilmezse aynı fiyattan otomatik olarak yenilenir ve Apple Hesabınızdan ücretlendirilir. Yönetim ve iptal App Store hesap ayarlarından yapılır. Ömür boyu satın alma abonelik değil, tek seferlik ödemedir.

Kullanım Koşulları (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Gizlilik Politikası: https://m1zz.github.io/ScheduleDensity/privacy.html
```

## 베트남어 (vi)

### 이름

```
Rainbow of Desire: Lịch tuần
```

### 부제

```
Chia nhỏ việc, mỗi bước 5 phút
```

### 키워드

```
todo,danh,sách,cần,làm,kế,hoạch,quản,lý,thời,gian,planner,nhắc,tập,trung,ADHD,năng,suất,hẹn,giờ
```

### 프로모션 텍스트

```
Nhìn màu là biết tuần này kín đến đâu. Việc làm được trong năm phút rảnh luôn nằm trên cùng. Giờ bộ hẹn giờ đếm ngược đến đúng lúc sự kiện kết thúc.
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
Lịch chỉ cho biết một việc đã được xếp hay chưa, không cho biết bao nhiêu việc đang chồng lên nhau. Rainbow of Desire vẽ mỗi tuần thành một lưới ô, việc càng chồng lên nhau thì màu càng đậm, để bạn thấy trước một tuần nặng nề trước khi bước vào.

Khi tuần đã kín, bạn không cần danh sách dài hơn, mà cần một bước đủ nhỏ để làm trong năm phút đang có.

Cầu vồng

Nhấn giữ ô trống vào ngày bắt đầu, rồi nhấn giữ ngày kết thúc, một đường sẽ được vẽ trên lưới. Ngày thực sự làm hiện đậm, ngày còn lại hiện nhạt, vì việc chưa xong vẫn giữ chân bạn cả vào những ngày không đụng tới.

Các ô trên cùng một hàng là những việc bạn đang cùng lúc xoay xở trong ngày. Khi hàng đã kín, chỉ một việc trễ cũng đẩy lùi cả ngày.

Sự kiện từ các lịch bạn chọn cũng hiện trên cầu vồng và màn hình ngày, chỉ đọc, không ghi gì vào lịch.

Hai câu hỏi, chỉ hai thôi

Chia việc lớn thành các bước, mỗi bước được phân loại bằng hai câu hỏi.

Có bắt đầu được ngay mà không cần khởi động không? Nếu phải nhớ lại mình đã làm tới đâu, năm phút sẽ tiêu hết vào việc khởi động.

Có xong trong năm phút không? Việc làm dở sẽ theo bạn sang cả giờ tiếp theo.

Chỉ bước nào trả lời có cho cả hai mới là một mảnh, thứ bạn làm ngay khi có năm phút rảnh. Còn lại là quãng, dành cho khoảng thời gian bạn giữ riêng. Ứng dụng tự trả lời trước dựa trên chữ và thời gian bạn ghi, bạn chỉ sửa khi nó sai.

Mười hai lần năm phút không bằng một giờ. Thời gian vụn không cộng dồn được, nên bước vừa một khoảng trống phải được đánh dấu riêng từ đầu.

Tia chớp

Vuốt một việc sang phải để gắn Tia chớp, dấu riêng của bạn cho biết việc này làm được ngay bây giờ. Việc có Tia chớp được chen lên đầu danh sách, nên khi có khoảng trống bạn chỉ cần nhìn lên đó.

Thứ tự bước, đặt một lần

Bạn chỉ quyết định một lần cho cả nhóm: các bước có chờ nhau hay không, thay vì nối từng bước một. Theo thứ tự thì bước đầu tiên chưa xong nằm trên cùng. Tùy ý thì mảnh nào làm được ngay sẽ lên trên cùng.

Bộ hẹn giờ

Bộ hẹn giờ đếm ngược đến lúc sự kiện kết thúc. Khi sự kiện chồng nhau, bạn chọn đếm cho sự kiện nào và đổi chỉ với một chạm. Thời gian còn lại hiện cả trên Dynamic Island và Màn hình khóa.

Tiện ích

Đặt trên Màn hình chính và Màn hình khóa. Tiện ích Việc cần làm hiện việc bạn đang làm và bước bên trong nó. Tiện ích Tia chớp chỉ hiện những gì làm được trong năm phút ngay lúc này. Tiện ích Cầu vồng hiện lưới mật độ. Tiện ích Hẹn giờ hiện thời gian còn lại.

Chia sẻ

Gửi liên kết mời để chia sẻ sự kiện ở chế độ chỉ xem, hoặc mở một danh sách việc cần làm để cùng đọc, cùng ghi với người được mời.

Miễn phí và Rainbow Pro

Phần cốt lõi của ứng dụng hoàn toàn miễn phí. Ghi việc cần làm, Cầu vồng, chia bước, hai câu hỏi, thứ tự bước và bộ hẹn giờ đều miễn phí, không cần tài khoản hay đăng ký. Dùng cùng Mac cũng miễn phí.

Tiện ích trên Màn hình chính và Màn hình khóa, nhập từ Lịch, chia sẻ sự kiện, thống kê sự kiện và toàn bộ Sổ thời gian được mở khóa với Rainbow Pro. Bạn chọn gói năm (miễn phí tuần đầu), gói tháng hoặc gói trọn đời thanh toán một lần.

Trên Mac

Rainbow Craft là một ứng dụng macOS riêng. Cùng tài khoản iCloud thì việc cần làm và kế hoạch tuần tự đồng bộ.

Quyền riêng tư

Không có máy chủ. Những gì bạn ghi chỉ nằm trên thiết bị và trong iCloud riêng của bạn, nhà phát triển không thể xem. Không có mã định danh quảng cáo, không dùng vị trí, không cần đăng ký. Ứng dụng gửi thống kê sử dụng ẩn danh cho nhà phát triển, và bạn có thể tắt trong Cài đặt.

Hỗ trợ 23 ngôn ngữ, trong đó có tiếng Việt, và tự hiển thị theo ngôn ngữ của thiết bị.

Gói đăng ký và điều khoản

Gói năm và gói tháng tự động gia hạn với cùng mức giá nếu không hủy ít nhất 24 giờ trước khi kỳ hạn kết thúc, và được tính phí vào Tài khoản Apple của bạn. Bạn quản lý hoặc hủy trong phần cài đặt tài khoản App Store. Gói trọn đời là thanh toán một lần, không phải gói đăng ký.

Điều khoản sử dụng (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Chính sách quyền riêng tư: https://m1zz.github.io/ScheduleDensity/privacy.html
```
