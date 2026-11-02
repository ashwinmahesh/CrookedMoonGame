#!/usr/bin/env /usr/bin/python3
"""Builds the Crooked Moon's second leaf atlas (art/plants/cards2.png, boxes in art/plants/cards2.json; a plant's `leaf2` material).

Each card's picture (a photoreal cut-out on white, tools/art/specs/photoreal/plant_cards3.json, named by tools/art/photoreal_fetch.py) is
cut from its white ground, trimmed to what it draws and fitted exactly to its box, its colour bled into the clear pixels round it so
mipmaps never fringe (tools/art/plant_cards.py's cut and bleed). A card with no picture yet gets a plain stand-in drawn here, so the
models can be shot before the pictures are in.

  /usr/bin/python3 tools/art/plant_cards2.py                       the atlas from <asset root>/plantcards_photo3/, stand-ins where missing
  /usr/bin/python3 tools/art/plant_cards2.py --from <dir>          the pictures from another folder
  /usr/bin/python3 tools/art/plant_cards2.py --sheet out.png       a contact sheet of the atlas on grey
"""
from __future__ import annotations
import json
import math
import random
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plant_cards as pc  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "art/plants/cards2.png"
CARDS = ROOT / "art/plants/cards2.json"
PAINTINGS = Path("/Volumes/ASH-SSD/CrookedMoon/assets/plantcards_photo3")
# The studio pictures keep a soft grey shadow under the plant that the white-ground cut leaves behind as pale patches; they are cleared
# (neutral grey and light) from every card but the moss and hair, whose own threads are neutral and light.
KEEP_NEUTRAL = ("moss_strand", "hair_strand")
# How far from grey a pixel may be and still count as shadow: the tassel's shadow is warm.
SPREAD = {"corn_tassel": 34, "corn_ear": 22, "briar_leaf": 22}


def clear_shadow(card: Image.Image, spread: int = 16) -> Image.Image:
    """Clears the neutral light-grey pixels (the studio shadow) from a cut-out and any specks they leave, so only the plant is left."""
    px = card.load()
    w, h = card.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and max(r, g, b) - min(r, g, b) < spread and (r + g + b) / 3 > 135:
                px[x, y] = (r, g, b, 0)
    alpha = card.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    out = card.copy()
    out.putalpha(alpha)
    return out


def _wavy(d: ImageDraw.ImageDraw, rng: random.Random, x: float, y0: float, y1: float, amp: float, col, width: int) -> None:
    pts = []
    n = 24
    ph = rng.uniform(0, math.tau)
    for i in range(n + 1):
        t = i / n
        pts.append((x + math.sin(ph + t * rng.uniform(6, 11)) * amp * (0.4 + t), y0 + (y1 - y0) * t))
    d.line(pts, fill=col, width=width)


def stand_in(name: str, w: int, h: int) -> Image.Image:
    """A plain painting on white for a card whose picture has not come yet."""
    rng = random.Random(name)
    im = Image.new("RGB", (w, h), (255, 255, 255))
    d = ImageDraw.Draw(im)
    if name.startswith("corn_blade"):
        top = [(0, h * 0.55), (w * 0.3, h * 0.2), (w * 0.7, h * 0.28), (w, h * 0.5)]
        bot = [(w, h * 0.5), (w * 0.7, h * 0.62), (w * 0.3, h * 0.78), (0, h * 0.55)]
        d.polygon(top + bot, fill=(96, 138, 58))
        d.line([(0, h * 0.55), (w * 0.5, h * 0.46), (w, h * 0.5)], fill=(190, 205, 140), width=max(2, h // 16))
    elif name in ("moss_strand", "hair_strand"):
        col = (150, 156, 128) if name == "moss_strand" else (206, 204, 196)
        for _ in range(26):
            _wavy(d, rng, rng.uniform(w * 0.2, w * 0.8), rng.uniform(0, h * 0.2), rng.uniform(h * 0.7, h), w * 0.12, col, 3)
    elif name == "corn_ear":
        d.polygon([(w * 0.3, h), (w * 0.15, h * 0.45), (w * 0.5, h * 0.1), (w * 0.85, h * 0.45), (w * 0.7, h)], fill=(104, 140, 62))
        d.polygon([(w * 0.4, h * 0.55), (w * 0.6, h * 0.55), (w * 0.55, h * 0.2), (w * 0.45, h * 0.2)], fill=(222, 184, 70))
        d.line([(w * 0.5, h * 0.1), (w * 0.5, 0)], fill=(150, 110, 70), width=6)
    elif name == "corn_tassel":
        for _ in range(16):
            ang = rng.uniform(-0.9, 0.9)
            d.line([(w * 0.5, h), (w * 0.5 + math.sin(ang) * w * 0.5, h * (0.1 + 0.4 * abs(ang)))], fill=(205, 186, 110), width=4)
    elif name == "briar_leaf":
        d.line([(w * 0.1, h * 0.9), (w * 0.5, h * 0.5), (w * 0.9, h * 0.2)], fill=(90, 56, 60), width=8)
        for i in range(5):
            cx, cy = w * (0.2 + 0.17 * i), h * (0.8 - 0.14 * i)
            d.ellipse([cx - w * 0.13, cy - h * 0.1, cx + w * 0.13, cy + h * 0.1], fill=(70, 100, 52))
    elif name.startswith("shelf"):
        for i in range(4):
            y = h * (0.15 + 0.2 * i)
            d.pieslice([w * (0.05 + 0.05 * i), y - h * 0.15, w * (0.95 - 0.05 * i), y + h * 0.4], 180, 360, fill=(204, 156, 84))
            d.arc([w * (0.05 + 0.05 * i), y - h * 0.15, w * (0.95 - 0.05 * i), y + h * 0.4], 190, 350, fill=(120, 190, 176), width=5)
    elif name.startswith("cypress_frond"):
        d.line([(0, h * 0.5), (w, h * 0.5)], fill=(110, 80, 60), width=6)
        for i in range(34):
            x = w * i / 34
            L = h * 0.42 * (1.0 - 0.5 * i / 34)
            d.line([(x, h * 0.5), (x + w * 0.02, h * 0.5 - L)], fill=(140, 170, 80), width=5)
            d.line([(x, h * 0.5), (x + w * 0.02, h * 0.5 + L)], fill=(140, 170, 80), width=5)
    return im


def main(argv: list[str]) -> None:
    global PAINTINGS
    if "--from" in argv:
        PAINTINGS = Path(argv[argv.index("--from") + 1])
    cards = json.loads(CARDS.read_text())
    if "--sheet" in argv:
        im = Image.open(ATLAS).convert("RGBA")
        bg = Image.new("RGBA", im.size, (90, 90, 96, 255))
        bg.alpha_composite(im)
        bg.convert("RGB").resize((im.width // 2, im.height // 2)).save(argv[argv.index("--sheet") + 1])
        return
    W, H = int(cards["width"]), int(cards["height"])
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    real, fake = [], []
    for name, (u0, v0, u1, v1) in cards["cells"].items():
        x0, y0, x1, y1 = round(u0 * W), round(v0 * H), round(u1 * W), round(v1 * H)
        pic = PAINTINGS / f"{name}.png"
        if pic.exists():
            card = pc.cut(pic)
            if name not in KEEP_NEUTRAL:
                card = clear_shadow(card, SPREAD.get(name, 16))
            real.append(name)
        else:
            tmp = Image.new("RGB", (x1 - x0, y1 - y0))
            card = pc.cut_image(stand_in(name, x1 - x0, y1 - y0)) if hasattr(pc, "cut_image") else None
            if card is None:
                p = Path("/tmp/claude-501") / f"standin_{name}.png"
                stand_in(name, x1 - x0, y1 - y0).save(p)
                card = pc.cut(p)
            fake.append(name)
        bb = card.getchannel("A").getbbox()
        if bb is None:
            raise SystemExit(f"{name}: nothing in the painting")
        card = card.crop(bb).resize((x1 - x0, y1 - y0), Image.LANCZOS)
        pad = 24
        region = Image.new("RGBA", (x1 - x0 + 2 * pad, y1 - y0 + 2 * pad), (0, 0, 0, 0))
        region.paste(card, (pad, pad))
        region = pc.bleed(region)
        atlas.alpha_composite(region.crop((pad, pad, pad + x1 - x0, pad + y1 - y0)), (x0, y0))
    atlas.save(ATLAS)
    print("pictures:", ", ".join(real) or "none", "| stand-ins:", ", ".join(fake) or "none", atlas.size)


if __name__ == "__main__":
    main(sys.argv[1:])
