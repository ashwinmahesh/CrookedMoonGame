#!/usr/bin/env python3
"""Dialogue busts from the photoreal portraits (vault Build/Talking Figures.md).

Usage: /usr/bin/python3 tools/art/build_portrait_busts.py [--only id ...] [--sheet out.png]

The engine's DialogueBusts shows art/busts/<id>.webp large beside the conversation box, the hero on the left and whoever
they talk to on the right, both behind the box. Its busts were drawn on white and cut out; a photoreal portrait has its
own night scene behind it, so instead each art/portraits/<id>.png is cropped to the bust's 2:3 and its edges fade into
the dark: the sides and the top melt away, the bottom stays solid behind the box. Saved as webp with alpha (Git LFS).
Portraits are drawn facing the viewer, so data/busts/facing.json lists the people of the place (not the companions) as
drawn facing left: a person on the right then shows as drawn, never mirrored, and so does a companion on the left.
After new busts: make import, then `git add -f` their .import files.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "portraits"
OUT = ROOT / "art" / "busts"
FACING = ROOT / "data" / "busts" / "facing.json"
PREGENS = ROOT / "data" / "pregens"
## The bust's shape (DialogueBusts lays each out 0.66 as wide as tall).
ASPECT = 2.0 / 3.0
## How far in each fade reaches, as a share of the bust's width (sides) and height (top), and how soft it is.
SIDE_FADE = 0.2
TOP_FADE = 0.12
SOFT = 0.08
QUALITY = 88
## The old game's drawn heroes (placeholders, not photoreal): no bust, so they show only their small portrait in the box.
DRAWN = {"godrick_pendlebrook", "hedda_ironvow", "ilse_varga", "kip_smudgewick", "liriel_dawnsong", "ratatoille",
         "silvain_aster", "tamsin_tealeaf", "thistle", "wren_featherfoot"}


def mask(w, h):
    """White where the bust shows, fading to black at the sides and top; an oval over the head and shoulders."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    sx, ty = int(w * SIDE_FADE * 0.55), int(h * TOP_FADE * 0.4)
    # A tall oval for the head on a body that runs to the bottom edge.
    d.ellipse([sx, ty, w - sx, int(h * 1.35)], fill=255)
    d.rectangle([sx, int(h * 0.62), w - sx, h], fill=255)
    return m.filter(ImageFilter.GaussianBlur(w * SOFT))


def bust(src, dst):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    cw = min(w, int(round(h * ASPECT)))
    ch = int(round(cw / ASPECT))
    left = (w - cw) // 2
    im = im.crop((left, 0, left + cw, ch))
    a = mask(cw, ch)
    # The bottom row stays solid behind the box whatever the blur did to it.
    solid = Image.new("L", (cw, ch), 0)
    ImageDraw.Draw(solid).rectangle([int(cw * SIDE_FADE * 0.55), int(ch * 0.9), cw - int(cw * SIDE_FADE * 0.55), ch], fill=255)
    a = ImageChops.lighter(a, solid.filter(ImageFilter.GaussianBlur(cw * 0.04)))
    im.putalpha(a)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "WEBP", quality=QUALITY, method=6)
    return im


def companions():
    return {p.stem for p in PREGENS.glob("*.json")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--sheet", default="")
    args = ap.parse_args()
    ids = sorted(p.stem for p in SRC.glob("*.png") if p.stem not in DRAWN and (not args.only or p.stem in args.only))
    made = []
    for pid in ids:
        made.append(bust(SRC / f"{pid}.png", OUT / f"{pid}.webp"))
        print(f"bust {pid}")
    party = companions()
    data = json.loads(FACING.read_text())
    facing = {p.stem: "left" for p in sorted(OUT.glob("*.webp")) if p.stem not in party}
    data["_doc"] = ("Which way each dialogue bust faces as drawn (art/busts/<id>[_<mood>].webp). The busts are the photoreal "
                    "portraits, drawn facing the viewer (tools/art/build_portrait_busts.py): the people of the place are listed "
                    "as facing left so they show on the right as drawn; the companions face right, the default.")
    data["facing"] = facing
    FACING.write_text(json.dumps(data, indent=2) + "\n")
    if args.sheet and made:
        tw = 180
        th = int(tw / ASPECT)
        cols = 10
        sheet = Image.new("RGB", (tw * cols, th * ((len(made) + cols - 1) // cols)), (40, 44, 52))
        for i, im in enumerate(made):
            t = im.resize((tw, th))
            sheet.paste(t, ((i % cols) * tw, (i // cols) * th), t)
        sheet.save(args.sheet)


if __name__ == "__main__":
    main()
