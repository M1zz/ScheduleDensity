#!/usr/bin/env python3
"""욕망의 무지개 아이콘 — 원래 아이콘(무지개 벽돌 네 줄)을 Icon Composer 층으로 다시 그린다.

줄 하나가 유리 한 겹이다. 실행하면 ScheduleDensityApp/AppIcon.icon/Assets 의 PNG 를 새로 만든다.
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "ScheduleDensityApp/AppIcon.icon/Assets"
S, K = 1024, 4                      # 캔버스, 매끄러운 가장자리용 확대 배수
LEFT, RIGHT, H, GAP = 187, 837, 104, 27
TOP = 512 - (4 * H + 3 * 26) // 2   # 원본은 위로 19px 치우쳐 있었다 — 가운데로

R, O, Y, G = "#FF3128", "#FF7718", "#FFC417", "#27C25E"
B, SKY, I = "#006BB2", "#009DE4", "#424FCD"
ROWS = [  # (폭 비율, 색) — 짧은 칸은 반 벽돌
    [(2, R), (2, O), (2, Y)],
    [(1, R), (2, O), (2, Y), (1, B)],
    [(2, O), (2, Y), (2, G)],
    [(1, Y), (2, G), (2, SKY), (1, I)],
]

OUT.mkdir(parents=True, exist_ok=True)
for i, row in enumerate(ROWS):
    im = Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    unit = (RIGHT - LEFT - GAP * (len(row) - 1)) / sum(w for w, _ in row)
    x, y = LEFT, TOP + i * (H + 26)
    for w, color in row:
        d.rounded_rectangle([x * K, y * K, (x + w * unit) * K, (y + H) * K], radius=22 * K, fill=color)
        x += w * unit + GAP
    im.resize((S, S), Image.LANCZOS).save(OUT / f"row{i + 1}.png")
print("ok", OUT)

# iOS 26 아래에서 보이는 평면 아이콘 — 유리 렌더를 아이콘 바탕 위에 얹은 꽉 찬 정사각형(알파 없음).
import subprocess, tempfile
ICON = OUT.parent
SET = ICON.parent / "Assets.xcassets/AppIcon.appiconset"
ICTOOL = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

def render(rendition):
    f = Path(tempfile.mkdtemp()) / "i.png"
    subprocess.run([ICTOOL, str(ICON), "--export-image", "--output-file", str(f), "--platform", "iOS",
                    "--rendition", rendition, "--width", "1024", "--height", "1024", "--scale", "1"],
                   check=True, stdout=subprocess.DEVNULL)
    return Image.open(f).convert("RGBA")

def gradient(top, bottom):
    g = Image.new("RGBA", (S, S))
    for y in range(S):
        t = y / (S - 1)
        g.paste(tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,), (0, y, S, y + 1))
    return g

for name, rendition, top, bottom in [
    ("AppIcon", "Default", (45, 26, 64), (22, 12, 33)),      # icon.json 기본 바탕
    ("AppIcon-Dark", "Dark", (21, 12, 30), (8, 4, 12)),      # icon.json 다크 바탕
    ("AppIcon-Tinted", "ClearDark", (0, 0, 0), (0, 0, 0)),
]:
    bg = gradient(top, bottom)
    bg.alpha_composite(render(rendition))
    out = bg.convert("L") if "Tinted" in name else bg.convert("RGB")
    out.save(SET / f"{name}.png")
    print("wrote", name)
