#!/usr/bin/env /usr/bin/python3
"""Swaps the plain moon of the look-P title picture for the grinning Crooked Moon (art/sky/moon_smirk.png): the new moon is laid
over the old one a little higher and larger, so the grin (low on the disc) stays above the Oak's crown, and the crown's near-black
pixels are kept in front of it. The originals stay under the asset root.
  /usr/bin/python3 tools/art/title_moon.py <title_original.png> <out.png> [cx cy r]"""
import sys
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
src, out = Path(sys.argv[1]), Path(sys.argv[2])
cx, cy, r = (float(v) for v in sys.argv[3:6]) if len(sys.argv) >= 6 else (1048.5, 162.0, 160.0)
base = Image.open(src).convert("RGB")
W, H = base.size
bp = base.load()
moon = Image.open(ROOT / "art/sky/moon_smirk.png").convert("RGBA").resize((round(r * 2), round(r * 2)), Image.LANCZOS)
x0, y0 = round(cx - r), round(cy - r)
# what stands in front of the moon: the crown's near-black wood below the moon's top (the pale faces are left to the moon)
front = Image.new("L", base.size, 0)
fp = front.load()
for y in range(max(0, y0), min(H, y0 + moon.height)):
    for x in range(max(0, x0), min(W, x0 + moon.width)):
        rr, gg, bb = bp[x, y]
        if y > 235 and 0.3 * rr + 0.59 * gg + 0.11 * bb < 42:
            fp[x, y] = 255
front = front.filter(ImageFilter.GaussianBlur(0.8))
alpha = Image.new("L", base.size, 0)
alpha.paste(moon.getchannel("A"), (x0, y0))
from PIL import ImageChops
alpha = ImageChops.subtract(alpha, front)
layer = Image.new("RGB", base.size)
layer.paste(moon.convert("RGB"), (x0, y0))
base.paste(layer, (0, 0), alpha)
base.save(out)
print(out, base.size)
