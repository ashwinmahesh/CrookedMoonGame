#!/usr/bin/env /usr/bin/python3
"""Dark placeholder pictures for the R10 cutscenes whose art is still in the image queue: art/cutscenes/<id>.jpg, 1792 x 1024, a deep indigo
wash with a pale crescent and the picture's id. A real picture of the same name replaces each (tools/content/fetch_cutscenes.py);
a placeholder is never overwritten the other way round. docs/PLACEHOLDERS.md lists them."""
import json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[2]
# The prompt lists whose pictures get a stand-in: R10's, R12's and R13's (a list on the command line replaces them all).
LISTS = sys.argv[1:] or ["tools/content/ghostlight_cutscenes.json", "tools/content/crooked_house_cutscenes.json", "tools/content/foxwillow_cutscenes.json", "tools/content/maidenmist_cutscenes.json"]
pics: dict = {}
for lst in LISTS:
    if (ROOT / lst).exists():
        pics.update(json.loads((ROOT / lst).read_text())["pictures"])
out = ROOT / "art/cutscenes"
out.mkdir(parents=True, exist_ok=True)
for cid, desc in pics.items():
    p = out / f"{cid}.jpg"
    if p.exists():
        continue
    im = Image.new("RGB", (1792, 1024), (14, 12, 38))
    d = ImageDraw.Draw(im)
    for y in range(1024):
        t = y / 1024
        d.line((0, y, 1792, y), fill=(int(14 + 20 * t), int(12 + 10 * t), int(38 + 26 * (1 - t))))
    d.ellipse((1380, 120, 1560, 300), fill=(226, 222, 190))
    d.ellipse((1410, 100, 1590, 280), fill=(18, 16, 44))
    try:
        f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia.ttf", 34)
    except Exception:
        f = ImageFont.load_default()
    d.text((96, 880), cid, fill=(200, 196, 220), font=f)
    d.text((96, 930), "placeholder: the picture is in the image queue", fill=(120, 116, 150), font=f)
    im.save(p, quality=85)
print("placeholders:", len(list(out.glob("*.jpg"))))
