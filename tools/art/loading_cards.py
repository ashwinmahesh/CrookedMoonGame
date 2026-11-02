#!/usr/bin/env /usr/bin/python3
"""The loading cards' pictures (data/loading/cards.json, plan 8.4): one establishing look-P picture per region, from
tools/art/specs/loading_cards.json via tools/art/generate_local.py (kind `loading`), saved as art/cutscenes/load_<region>.jpg at
1792 x 1024; and load_default.jpg, the title picture without its crooked moon's text (there is none) as the default every other
region falls back to. PIL only (macOS /usr/bin/python3).
  /usr/bin/python3 tools/art/loading_cards.py"""
import glob
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = Path("/Volumes/ASH-SSD/CrookedMoon/assets/loading")
OUT = ROOT / "art/cutscenes"


def cover(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    k = max(size[0] / im.width, size[1] / im.height)
    im = im.resize((max(size[0], round(im.width * k)), max(size[1], round(im.height * k))), Image.LANCZOS)
    x, y = (im.width - size[0]) // 2, (im.height - size[1]) // 2
    return im.crop((x, y, x + size[0], y + size[1]))


for f in sorted(glob.glob(str(SRC / "load_*.png"))):
    name = Path(f).stem
    cover(Image.open(f).convert("RGB"), (1792, 1024)).save(OUT / f"{name}.jpg", quality=88)
    print(name)
cover(Image.open(ROOT / "art/ui/title_backdrop.png").convert("RGB"), (1792, 1024)).save(OUT / "load_default.jpg", quality=88)
print("load_default")
