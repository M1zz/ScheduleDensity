#!/usr/bin/env python3
"""App Store 크리에이티브 자산(제품 페이지 헤더 · 검색 결과) 생성: HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_creative_assets.py [언어 ...]     (없으면 전부)

자리
  docs/screenshots/creative/<스토어 로케일>/header.png   3840x1646  제품 페이지 맨 위
  docs/screenshots/creative/<스토어 로케일>/search.png   3840x2560  검색 결과 (없으면 스크린샷이 대신 보인다)

⚠️ 안전 영역 밖은 기기에 따라 잘린다. 글은 **반드시** 안전 영역 안에 둔다(배경 · 기기 그림은 넘쳐도 된다).
   수치는 Apple 공식 PSD 템플릿에서 잰 값이다(https://developer.apple.com/app-store/asset-best-practices/).
   아이폰에서 헤더는 가운데만 남고, 검색 결과는 약 385pt 폭으로 줄어 보인다. 그래서 글이 크다.

⚠️ 가격 · 할인 · 주소(URL) · 수상 · 다른 플랫폼 이름은 넣지 않는다(Apple 가이드).
"""
import os, signal, subprocess, sys, pathlib, tempfile, time
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
# 기기 화면 재료: 마케팅 스크린샷에서 **기기 화면 부분만** 잘라 쓴다(헤드라인은 넣지 않는다).
SHOTS = ROOT / "docs" / "screenshots" / "marketing"
OUT = ROOT / "docs" / "screenshots" / "creative"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 앱 언어 코드 → App Store Connect 로케일 (deploy.env LOCALES=ko,en,zh-Hant)
STORE = {"en": "en-US"}
# 마케팅 스크린샷 폴더 이름
SHOT_DIR = {"ko": "ko", "en": "en", "zh-Hant": "zh-Hant"}

# (가로, 세로, 안전 영역 left, top, right, bottom)
SPEC = {
    "header": (3840, 1646, (1097, 493, 2743, 1154)),
    "search": (3840, 2560, (836, 765, 3004, 1795)),
}

# 검색 결과는 스크린샷 1장(01-rainbow, "이번 주가 얼마나 빽빽한지")과 **같은 이야기**다.
# 눈썹글은 그 나라 사람이 검색창에 칠 말(APPSTORE.md 키워드에서).
SEARCH = {
    "ko":      ("일정관리", "이번 주가<br>얼마나 빽빽한지", "일정이 겹칠수록 색이 진해집니다"),
    "en":      ("Weekly planner", "See the week<br>before it lands", "The more plans overlap, the deeper the color"),
    "zh-Hant": ("行事曆", "這週有多滿<br>一眼就知道", "行程重疊越多，顏色就越深"),
}

# 헤더는 한 가지 약속: 빡빡한 주를 들어서기 전에 색으로 먼저 본다.
# ⚠️ 기계번역하지 않는다. 언어마다 따로 쓴다.
HEADER = {
    "ko":      ("주간 플래너", "빡빡한 한 주,<br>색으로 먼저 봅니다"),
    "en":      ("Week planner", "Know a busy week<br>before you're in it"),
    "zh-Hant": ("週計畫", "忙碌的一週，<br>先用顏色看見"),
}

# 무지개 격자 색(앱 RainbowPalette, AppStore/screenshots.html 과 같다)
RAINBOW = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#5856D6", "#AF52DE"]

# ⚠️ 바탕 · 글자색은 마케팅 스크린샷 1장(AppStore/screenshots.html 01-rainbow)과 같다.
BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:linear-gradient(175deg,#f2f6ff 0%%,#dfe8ff 100%%); position:relative;
  -webkit-font-smoothing:antialiased;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", sans-serif; }
:lang(zh-Hant) body, body:lang(zh-Hant) { font-family:"PingFang TC", -apple-system, sans-serif; line-break:strict; }
.wash { position:absolute; left:0; right:0; bottom:0; background:linear-gradient(180deg, transparent, rgba(0,122,255,.20)); }
.glow { position:absolute; border-radius:50%%; filter:blur(160px); pointer-events:none; }
.text { position:absolute; display:flex; flex-direction:column; justify-content:center; }
.eyebrow { font-weight:700; color:#007AFF; letter-spacing:.02em; line-height:1.15; }
.headline { font-weight:800; color:#101534; letter-spacing:-0.02em; line-height:1.14; text-wrap:balance; }
.sub { font-weight:500; color:#4b5578; letter-spacing:-0.01em; line-height:1.4; text-wrap:balance; }
:lang(zh) .headline, :lang(zh) .eyebrow, :lang(zh) .sub { letter-spacing:.01em; }
:lang(ko) .headline { line-height:1.2; }
:lang(ko) .headline, :lang(ko) .sub, :lang(ko) .eyebrow { word-break:keep-all; }
.phone { position:absolute;
  background:linear-gradient(160deg,#3a3a3f,#111114 30%%,#141418 70%%,#45454b);
  box-shadow: 0 60px 160px rgba(16,21,52,.28); }
.phone .scr { width:100%%; aspect-ratio: 1 / 2.17; overflow:hidden; background:#f2f2f7; }
.phone img { width:100%%; display:block; }
.tile { position:absolute; border-radius:22%%; }
"""

# 글이 상자를 넘지 않을 때까지 줄인다. 잘리는 글은 없다 - 끝까지 안 맞으면 표시하고 멈춘다.
FIT_JS = """
<script>
// 문구에 적은 줄(<br>)보다 더 쪼개지면 "Rispondi / con un / tocco" 처럼 읽기가 끊긴다.
// 적은 줄 수를 지킬 때까지 줄인다.
function lines(el) {
  return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight));
}
function fit(box, el, max, min) {
  const want = el.querySelectorAll('br').length + 1;
  let size = max;
  el.style.fontSize = size + 'px';
  while (size > min && (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 ||
         lines(el) > want)) {
    size -= 4; el.style.fontSize = size + 'px';
  }
  if (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 || lines(el) > want)
    document.body.dataset.overflow = '1';
}
document.fonts.ready.then(() => {
  const box = document.querySelector('.text');
  const h = document.querySelector('.headline');
  fit(box, h, +h.dataset.max, +h.dataset.min);
  document.body.dataset.done = '1';
});
</script>
"""


TMP = pathlib.Path(tempfile.gettempdir()) / "rainbow-of-desire-creative"
# ⚠️ 프로필을 따로 쓴다. 기본 프로필을 다른 Chrome 과 같이 쓰면 잠금에 걸려 멈춘다.
PROFILE = TMP / "chrome-profile"


def screen(lang, name):
    """마케팅 스크린샷에서 기기 화면만 잘라 낸다. 기기는 언어마다 자리가 조금 달라 픽셀로 찾는다:
    가운데 줄에서 검은 테두리 안쪽(밝은 화면)의 좌우, 가운데 세로줄에서 테두리 아래 화면 위끝."""
    src = SHOTS / SHOT_DIR[lang] / f"{name}.png"
    im = Image.open(src).convert("RGB")
    W, H = im.size
    row = [sum(im.getpixel((x, 1500))) for x in range(W)]
    dark = [x for x, v in enumerate(row) if v < 200]
    left = next(x for x in range(dark[0], W // 2) if row[x] > 300)
    right = max(x for x in range(W // 2, dark[-1]) if row[x] > 300)
    cx = (left + right) // 2
    col = [sum(im.getpixel((cx, y))) for y in range(H)]
    y = 500
    while not all(v < 200 for v in col[y:y + 15]):
        y += 1
    while col[y] < 200:
        y += 1
    TMP.mkdir(exist_ok=True)
    out = TMP / f"{lang}-{name}.png"
    im.crop((left, y, right + 1, H)).save(out)
    return out.as_uri()


def phone(img, left, top, width, rotate=0):
    pad = round(width * 0.035)
    return (f'<div class="phone" style="left:{left}px;top:{top}px;width:{width}px;padding:{pad}px;'
            f'border-radius:{round(width * 0.155)}px;transform:rotate({rotate}deg)">'
            f'<div class="scr" style="border-radius:{round(width * 0.125)}px"><img src="{img}"></div></div>')


def tiles(spec):
    # 무지개 격자 칸을 흩어 둔다(장식, 안전 영역 밖이라 잘려도 된다).
    return "".join(f'<div class="tile" style="left:{x}px;top:{y}px;width:{w}px;height:{w}px;'
                   f'background:{RAINBOW[c]};opacity:{o};transform:rotate({r}deg)"></div>'
                   for x, y, w, c, o, r in spec)


def search_html(lang):
    W, H, (l, t, r, b) = SPEC["search"]
    eyebrow, headline, sub = SEARCH[lang]
    sw, sh = r - l, b - t
    col = int(sw * 0.58)
    ph_w = 1000
    ph_left = l + col + int(sw * 0.03)
    deco = tiles([(3330, 300, 150, 0, .85, 8), (3520, 560, 110, 2, .85, -6), (3380, 820, 130, 3, .8, 4),
                  (3600, 1150, 120, 4, .75, -10), (3300, 1520, 100, 5, .7, 6), (3560, 1850, 140, 6, .7, -4),
                  (300, 2050, 120, 1, .55, -8), (520, 2280, 90, 4, .5, 10)])
    return f"""
<div class="wash" style="height:900px"></div>
<div class="glow" style="left:{ph_left - 300}px;top:700px;width:1600px;height:1600px;background:rgba(88,86,214,.14)"></div>
{deco}
{phone(screen(lang, "01-rainbow"), ph_left, t - 420, ph_w, 0)}
<div class="text" style="left:{l}px;top:{t}px;width:{col}px;height:{sh}px">
  <div class="eyebrow" style="font-size:92px">{eyebrow}</div>
  <div class="headline" data-max="230" data-min="130" style="margin-top:40px">{headline}</div>
  <div class="sub" style="font-size:80px;margin-top:56px">{sub}</div>
</div>"""


def header_html(lang):
    W, H, (l, t, r, b) = SPEC["header"]
    eyebrow, headline = HEADER[lang]
    sw, sh = r - l, b - t
    deco = tiles([(120, 120, 130, 0, .8, -10), (360, 60, 95, 1, .8, 6), (980, 140, 80, 2, .75, 12),
                  (60, 1330, 110, 3, .7, 8), (3600, 90, 130, 4, .8, 10), (3380, 260, 90, 5, .75, -8),
                  (2780, 110, 85, 6, .75, 6), (3700, 1300, 110, 2, .7, -12)])
    return f"""
<div class="wash" style="height:700px"></div>
<div class="glow" style="left:{l - 200}px;top:{t - 400}px;width:{sw + 400}px;height:{sh + 800}px;background:rgba(255,255,255,.6)"></div>
{deco}
{phone(screen(lang, "01-rainbow"), 330, 380, 640, -8)}
{phone(screen(lang, "02-list"), 2870, 380, 640, 8)}
<div class="text" style="left:{l}px;top:{t}px;width:{sw}px;height:{sh}px;align-items:center;text-align:center">
  <div class="eyebrow" style="font-size:76px">{eyebrow}</div>
  <div class="headline" data-max="200" data-min="110" style="margin-top:26px">{headline}</div>
</div>"""


def html_lang(lang):
    return {"zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant"}.get(lang, lang)


def chrome(args, log, done, timeout=300):
    """헤드리스 Chrome 을 띄우고 done() 이 참이 되면 끈다.
    ⚠️ 이 맥에서는 Chrome 이 일을 다 하고도 끝나지 않고 매달려 있는 일이 있다(업데이터 자식 프로세스).
       그래서 끝나기를 기다리지 않고 결과(DOM 출력·PNG 파일)가 나오면 프로세스 묶음을 통째로 끈다."""
    TMP.mkdir(exist_ok=True)
    with open(log, "w") as out:
        proc = subprocess.Popen([CHROME, "--headless=new", f"--user-data-dir={PROFILE}", "--no-first-run",
                                 "--disable-component-update", *args],
                                stdout=out, stderr=subprocess.DEVNULL, start_new_session=True)
        ok = False
        end = time.time() + timeout
        while time.time() < end:
            time.sleep(1)
            if done():
                ok = True
                break
            if proc.poll() is not None:
                ok = done()
                break
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            proc.kill()
        # 이 프로필을 쓰는 남은 Chrome 프로세스(렌더러 등)도 끈다
        subprocess.run(["pkill", "-9", "-f", f"--user-data-dir={PROFILE}"], capture_output=True)
        proc.wait()
    return ok


def render(lang, kind):
    W, H, _ = SPEC[kind]
    body = search_html(lang) if kind == "search" else header_html(lang)
    page = (f'<!doctype html><html lang="{html_lang(lang)}"><head><meta charset="utf-8"><style>'
            f'{BASE_CSS % {"W": W, "H": H}}</style></head><body>{body}{FIT_JS}</body></html>')
    html_path = pathlib.Path(tempfile.gettempdir()) / f"rainbow-of-desire-creative-{lang}-{kind}.html"
    html_path.write_text(page, encoding="utf-8")
    # 글이 끝까지 안 맞으면 그림을 만들지 않는다(잘린 글이 스토어에 올라가는 것보다 낫다).
    flags = [f"--window-size={W},{H}", "--force-device-scale-factor=1", "--disable-gpu",
             "--virtual-time-budget=3000", "--allow-file-access-from-files"]
    dom_txt = TMP / f"{lang}-{kind}.dom"
    chrome(["--dump-dom", *flags, html_path.as_uri()], dom_txt,
           lambda: "</html>" in dom_txt.read_text(errors="ignore"))
    dom = dom_txt.read_text(errors="ignore")
    if 'data-done="1"' not in dom:
        raise SystemExit(f"글 맞추기가 끝나지 않았다: {lang} {kind}")
    if 'data-overflow="1"' in dom:
        raise SystemExit(f"글이 안전 영역을 넘는다: {lang} {kind} - 문구를 줄일 것")
    out_dir = OUT / STORE.get(lang, lang)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_png = out_dir / f"{kind}.png"
    out_png.unlink(missing_ok=True)
    sizes = []

    def written():
        sizes.append(out_png.stat().st_size if out_png.exists() else 0)
        return len(sizes) > 2 and sizes[-1] > 0 and sizes[-1] == sizes[-2] == sizes[-3]
    if not chrome([f"--screenshot={out_png}", "--hide-scrollbars", *flags, html_path.as_uri()],
                  TMP / f"{lang}-{kind}.log", written):
        raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
    print(f"rendered {out_png}")


if __name__ == "__main__":
    langs = sys.argv[1:] or list(SEARCH)
    for lang in langs:
        if lang not in SEARCH:
            raise SystemExit(f"모르는 언어: {lang} (아는 것: {', '.join(SEARCH)})")
        for kind in ("header", "search"):
            render(lang, kind)
