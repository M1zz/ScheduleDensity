#!/bin/bash
#
# 배포 전 검사 — 실패하면 0이 아닌 값으로 끝나 아카이브를 막는다.
#
# ⚠️ **이 앱에는 테스트 타겟이 없다.** 그래서 이 검사가 지킬 수 있는 것은
#    "적어도 컴파일은 된다"까지다. 초록불이 떠도 동작이 옳다는 뜻이 아니다.
#    테스트 타겟이 생기면 아래 build 를 test 로 바꾸고 -only-testing 을 붙인다.
#
# Release 로 짓는 이유: Debug 만 통과하고 Release 에서 깨지는 일이 실제로 있다
# (#if DEBUG 안에만 있는 코드를 밖에서 부르는 경우). 배포는 Release 로 나간다.

set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="ScheduleDensityApp.xcodeproj"
SCHEME="ScheduleDensityApp"

echo "🔍 배포 전 검사 — $SCHEME (Release)"

# 시뮬레이터는 **가장 최신 iOS 런타임의 iPhone** 으로 고른다.
# `grep iPhone | head -1` 로 고르면 구버전 런타임 기기가 먼저 잡혀
# "Unable to find a destination matching..." 로 죽는다.
DEST_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        if d.get("isAvailable") and "iPhone" in d.get("name", ""):
            if best is None or version > best[0]:
                best = (version, d["udid"])
print(best[1] if best else "")
')"

if [ -z "$DEST_ID" ]; then
  echo "❌ 사용 가능한 iPhone 시뮬레이터가 없습니다"
  xcrun simctl list devices available | head -30
  exit 1
fi

# 판정은 xcodebuild 의 종료 코드 하나로 한다. 로그를 grep 해서 판단하면
# 경고 문구에 "error:" 가 섞여 들어올 때 멀쩡한 빌드를 실패로 읽는다.
LOG="$(mktemp -t predeploy)"
if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
     -configuration Release -destination "id=$DEST_ID" \
     -quiet build > "$LOG" 2>&1; then
  echo "❌ Release 빌드 실패"
  tail -40 "$LOG"
  rm -f "$LOG"
  exit 1
fi
rm -f "$LOG"

echo "✅ Release 빌드 통과 (⚠️ 테스트 타겟이 없어 컴파일만 확인했습니다)"
