#!/bin/zsh
# iPad 13" 스토어 스크린샷 — 꾸미지 않은 2064×2752 를 docs/screenshots/marketing/<스토어 로케일>/ipad-0N-….png 에 둔다.
# (아이폰 제출본과 한 폴더 — DeployBar 가 크기로 기기를 가른다)
#
# 사용법: zsh scripts/capture_ipad.sh <iPad 시뮬레이터 UDID> [앱 언어 ...]   (언어를 안 주면 24개 모두)
#   - Debug 빌드가 build/dd/Build/Products/Debug-iphonesimulator/ScheduleDensityApp.app 에 있어야 한다(-iPadDemo 는 DEBUG 전용 → IPadScreenshotDemo.swift).
#   - 일부만 다시: ONLY="todo" zsh scripts/capture_ipad.sh <UDID> de
# 넓은 아이패드는 펼친 아이폰 듀오처럼 무지개 격자 | 고른 날의 하루, 할 일 | 고른 일의 단계 두 쪽이다(FoldPanes.swift 의 WidePadPanes).
set -u
cd "$(dirname "$0")/.."

DEV=$1; shift
APP=build/dd/Build/Products/Debug-iphonesimulator/ScheduleDensityApp.app
BUNDLE=com.example.ScheduleDensityApp
ALL=(ko en en-GB ja zh-Hans zh-Hant ru es de fr it pt-BR th vi cs da el fi id nb nl pl sv tr)
if (( $# )); then LANGS=($@); else LANGS=($ALL); fi

# 장면 이름 → 실행 인자. 처음 안내들은 본 것으로 둔다(UserDefaults 인자 도메인).
SCENES=(todo rainbow)   # 예시는 첫 실행(할 일)에서 들어가고, 무지개는 다음 실행에서 저장된 일정을 읽는다
SEEN=(-iPadDemo YES -hasSeenRainbowOnboarding YES -hasSeenBoltOnboarding YES -hasSeenSplitOnboarding YES)
args_of() { [[ $1 == rainbow ]] && echo "-iPadDemoTab rainbow" || echo "-iPadDemoTab todo"; }

t() { perl -e 'alarm shift; exec @ARGV' "$@"; }   # 시뮬레이터가 멈추면 기다리지 않는다

# 아이패드 상태 막대(시각·날짜)가 그려졌는가 — 앱을 띄운 직후엔 가끔 통째로 비어 찍힌다
has_bar() { python3 -c "import sys;from PIL import Image;p=list(Image.open(sys.argv[1]).convert('L').crop((40,12,420,52)).getdata());sys.exit(max(p)-min(p)<40)" $1; }

locale_of() {
  case $1 in
    ko) echo ko_KR ;; en) echo en_US ;; en-GB) echo en_GB ;; zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;;
    ja) echo ja_JP ;; ru) echo ru_RU ;; es) echo es_ES ;; de) echo de_DE ;; fr) echo fr_FR ;; it) echo it_IT ;;
    pt-BR) echo pt_BR ;; th) echo th_TH ;; vi) echo vi_VN ;; cs) echo cs_CZ ;; da) echo da_DK ;; el) echo el_GR ;;
    fi) echo fi_FI ;; id) echo id_ID ;; nb) echo nb_NO ;; nl) echo nl_NL ;; pl) echo pl_PL ;; sv) echo sv_SE ;;
    tr) echo tr_TR ;; *) echo en_US ;;
  esac
}

t 120 xcrun simctl boot $DEV 2>/dev/null
t 300 xcrun simctl bootstatus $DEV -b >/dev/null
t 60 xcrun simctl status_bar $DEV override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --batteryState charged --batteryLevel 100 >/dev/null 2>&1
for lang in $LANGS; do
  echo "▸ $lang"
  # 아이패드 상태 막대의 날짜(Sat Nov 14)와 창 이름은 앱이 아니라 시스템 언어를 따른다 → 언어마다 바꾸고 홈을 다시 띄운다
  t 30 xcrun simctl spawn $DEV defaults write .GlobalPreferences AppleLanguages -array $lang
  t 30 xcrun simctl spawn $DEV defaults write .GlobalPreferences AppleLocale $(locale_of $lang)
  t 30 xcrun simctl spawn $DEV launchctl stop com.apple.SpringBoard
  # 홈이 다시 서고 상태 막대가 돌아올 때까지 — 짧으면 첫 그림에 상태 막대가 비어 나온다
  sleep 30; t 60 xcrun simctl status_bar $DEV override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100 >/dev/null 2>&1
  # 예시 일정 · 할 일은 처음 켤 때 그 언어로 한 번만 쓰인다 → 언어마다 지우고 새로 깐다
  t 120 xcrun simctl uninstall $DEV $BUNDLE 2>/dev/null
  t 300 xcrun simctl install $DEV $APP || { echo "설치 실패"; exit 1; }
  out=docs/screenshots/marketing/$lang; mkdir -p $out   # 이 앱은 스토어 로케일 폴더가 앱 언어 그대로다
  n=0
  for scene in $SCENES; do
    n=$((n+1))
    [[ -n ${ONLY:-} && " $ONLY " != *" $scene "* ]] && continue
    file=$out/ipad-0$n-$scene.png
    for try in 1 2 3 4; do
      t 180 xcrun simctl launch --terminate-running-process $DEV $BUNDLE $SEEN ${=$(args_of $scene)} \
        -AppleLanguages "($lang)" -AppleLocale $(locale_of $lang) >/dev/null 2>&1 || continue
      sleep 8
      # 시뮬레이터는 Documents 아래에 직접 못 쓸 때가 있다 → 임시 파일로 찍고 옮긴다
      tmp=${TMPDIR:-/tmp}/rainbow-shot-$$.png
      t 90 xcrun simctl io $DEV screenshot $tmp >/dev/null 2>&1 && has_bar $tmp && mv -f $tmp $file && break
    done
    [[ -f $file ]] && echo "  $file" || echo "  ✗ $file"
  done
done
