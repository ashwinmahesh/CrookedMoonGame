#!/usr/bin/env python3
"""The Fated Tarot's card pictures into the game: each picked card in the asset root's tarot/ folder (the image service's
<job>.png beside its <job>.json, whose last tag is the card id from data/tarot/cards.json) is cropped to its illustration and
written to art/tarot/<card id>.png, where the reading looks (data/campaign.json reading.art; the engine's ReadingDeck.art). The crop
drops the drawn frame's number medallion and title banner: the image model misspells titles and numbers, and the card face the
engine draws already names the card under its picture. Needs Pillow (/usr/bin/python3 on the Mac has it).
    /usr/bin/python3 tools/art/tarot_cards.py [--check]
--check only lists the deck's cards that have no picture yet."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from asset_root import asset_root  # noqa: E402

REPO = HERE.parents[1]
## The illustration inside the drawn frame, as fractions of the 1024 x 1792 card: below the corner moons and the number,
## inside the gold border; the bottom stops above the pale title banner, found per card (it sits at 88 to 91% of the height).
LEFT, TOP, RIGHT = 0.095, 0.125, 0.905
HEIGHT = 720   # shown at most 170 px tall on the card face; room for the bigger reading view and HiDPI


def banner_top(im) -> int:
    """The first of 12 pale rows (the title banner) between 78% and 97% of the card's height, less the gold rule above it."""
    g = im.convert("L")
    w, h = g.size
    x0, x1 = int(w * 0.2), int(w * 0.8)
    run = 0
    for y in range(int(h * 0.78), int(h * 0.97)):
        run = run + 1 if sum(g.crop((x0, y, x1, y + 1)).getdata()) / (x1 - x0) > 175 else 0
        if run >= 12:
            return y - 12 - int(h * 0.012)
    return int(h * 0.89)


def main(argv) -> int:
    deck = [str(c["id"]) for c in json.loads((REPO / "data/tarot/cards.json").read_text())["cards"]]
    src, when = {}, {}
    for meta in (asset_root() / "tarot").glob("[0-9a-f]*.json"):
        d = json.loads(meta.read_text())
        card = str(d["tags"][-1])
        if card in deck and meta.with_suffix(".png").exists() and float(d.get("created", 0)) >= when.get(card, -1.0):
            src[card], when[card] = meta.with_suffix(".png"), float(d.get("created", 0))   # a redraw wins: the newest take
    missing = [c for c in deck if c not in src]
    if "--check" not in argv:
        from PIL import Image
        out = REPO / "art/tarot"
        out.mkdir(parents=True, exist_ok=True)
        for card, png in src.items():
            im = Image.open(png).convert("RGB")
            w, h = im.size
            im = im.crop((round(LEFT * w), round(TOP * h), round(RIGHT * w), banner_top(im)))
            im = im.resize((round(im.width * HEIGHT / im.height), HEIGHT), Image.LANCZOS)
            im.save(out / f"{card}.png", optimize=True)
    print(f"tarot cards: {len(src)} of {len(deck)} have a picture" + (f"; missing {', '.join(missing)}" if missing else ""))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
