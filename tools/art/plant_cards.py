#!/usr/bin/env /usr/bin/python3
"""Repaints leaf cards of the plant atlas (art/plants/cards.png, cards.json) with look P paintings (PIL only, macOS /usr/bin/python3).

The atlas is four 512 px cells wide and `rows` tall; every plant model's UVs point into a cell's drawn box (cards.json), so a card
is repainted in place: the new painting (on a plain white ground) is cut out, fitted exactly to the cell's box (the old art filled
it too, so the models' card quads keep their shape) and laid into an otherwise cleared cell, its colour bled into the transparent
pixels around it so mipmaps never fringe. The original atlas is kept once under the asset root (plantcards/cards_original.png).

  /usr/bin/python3 tools/art/plant_cards.py                 repaints every card whose picture is under <asset root>/plantcards/
  /usr/bin/python3 tools/art/plant_cards.py grass_dry ...   only these
  /usr/bin/python3 tools/art/plant_cards.py --sheet out.png contact sheet of the atlas on grey

The paintings come from tools/art/specs/plant_cards.json via tools/art/generate_local.py (kind `plantcards`).
Which model uses which card: bracken `fern_brown`, the grass tufts `grass_a`/`grass_b`/`grass_dry`, `sedge`, willow_a `willow_strand`,
vine `vine_leaves`, the oaks `oak_leaves`, birches `birch_leaves`, reeds `reeds`, spruces `fir_spray_*`.
"""
from __future__ import annotations
import json
import math
import shutil
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "art/plants/cards.png"
BACKUP = Path("/Volumes/ASH-SSD/CrookedMoon/assets/plantcards/cards_original.png")
CARDS = ROOT / "art/plants/cards.json"
PAINTINGS = Path("/Volumes/ASH-SSD/CrookedMoon/assets/plantcards")
CELL = 512


def cut(src: Path) -> Image.Image:
    """The painting on its white ground as RGBA: near white is clear, a little off it is a soft edge."""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    out = Image.new("RGBA", (w, h))
    po = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            d = math.sqrt(((255 - r) ** 2 + (255 - g) ** 2 + (255 - b) ** 2) / 3.0) / 255.0
            t = min(1.0, max(0.0, (d - 0.05) / 0.12))
            a = t * t * (3 - 2 * t)
            if 0.0 < a < 1.0:
                r = max(0, min(255, int(255 - (255 - r) / a)))
                g = max(0, min(255, int(255 - (255 - g) / a)))
                b = max(0, min(255, int(255 - (255 - b) / a)))
            po[x, y] = (r, g, b, 255 if a > 0.5 else 0)
    return out


def bleed(img: Image.Image, levels: int = 7) -> Image.Image:
    """Spreads the colour of the opaque pixels into the transparent ones (alpha unchanged), coarse to fine."""
    base = img.convert("RGBA")
    w, h = base.size
    pre = base.convert("RGBa")
    fill = None
    for lv in range(levels, 0, -1):
        small = pre.resize((max(1, w >> lv), max(1, h >> lv)), Image.BOX).convert("RGBA")
        small_rgb = Image.new("RGBA", small.size)
        small_rgb.paste(small.convert("RGB"), (0, 0), small.getchannel("A").point(lambda v: 255 if v > 0 else 0))
        up = small_rgb.resize((w, h), Image.BILINEAR)
        if fill is None:
            fill = up
        else:
            fill = Image.alpha_composite(fill, up)
    out = Image.alpha_composite(fill, base) if fill is not None else base
    rgb = out.convert("RGB")
    rgb.putalpha(base.getchannel("A"))
    return rgb


def put(atlas: Image.Image, name: str, box: list[float], picture: Path, rows: int) -> Image.Image:
    u0, v0, u1, v1 = box
    aw, ah = atlas.size
    x0, y0, x1, y1 = round(u0 * aw), round(v0 * ah), round(u1 * aw), round(v1 * ah)
    cell_x, cell_y = (x0 // CELL) * CELL, (y0 // CELL) * CELL
    card = cut(picture)
    bb = card.getchannel("A").getbbox()
    if bb is None:
        raise SystemExit(f"{name}: nothing in the painting")
    card = card.crop(bb).resize((x1 - x0, y1 - y0), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.paste(card, (x0 - cell_x, y0 - cell_y))
    cell = bleed(cell)
    atlas.paste(cell, (cell_x, cell_y))
    return atlas


def main(argv: list[str]) -> None:
    cards = json.loads(CARDS.read_text())
    if "--sheet" in argv:
        im = Image.open(ATLAS).convert("RGBA")
        bg = Image.new("RGBA", im.size, (90, 90, 96, 255))
        bg.alpha_composite(im)
        bg.convert("RGB").resize((im.width // 2, im.height // 2)).save(argv[argv.index("--sheet") + 1])
        return
    only = [a for a in argv if not a.startswith("-")]
    if not BACKUP.exists():
        shutil.copy(ATLAS, BACKUP)
    atlas = Image.open(ATLAS).convert("RGBA")
    done = []
    for name, box in cards["cells"].items():
        if only and name not in only:
            continue
        pic = PAINTINGS / f"{name}.png"
        if not pic.exists():
            continue
        atlas = put(atlas, name, box, pic, int(cards["rows"]))
        done.append(name)
    atlas.save(ATLAS)
    print("repainted", ", ".join(done) or "nothing", atlas.size)


if __name__ == "__main__":
    main(sys.argv[1:])
