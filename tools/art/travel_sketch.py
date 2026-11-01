#!/usr/bin/env /usr/bin/python3
"""The layout sketch under the Wickermoor Hollow travel map (plan 8.4, docs/PLACEHOLDERS.md): the land in flat colours with every
place of data/travel/wickermoor_hollow.json drawn at its `pos` fraction, the roads between them, the river and the rail line.
The painting is made over it (an edit or a variation of this picture, tools/art/look_map.py), so each place lands where the data
puts the marker. Needs only PIL (macOS /usr/bin/python3).

  /usr/bin/python3 tools/art/travel_sketch.py [out.png]      default: <asset root>/maps/wickermoor_hollow_sketch.png
Drawn at 2048 x 1408 (a size the image service takes); the painting is stretched to the map's 2528 x 1696 afterwards.
"""
import json, math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
W, H = 2048, 1408
DATA = json.loads((ROOT / "data/travel/wickermoor_hollow.json").read_text())
POS = {p["id"]: p["pos"] for p in DATA["places"]}

LAND = (84, 104, 66)
MOOR = (96, 96, 70)
FOREST = (28, 66, 40)
TOXIC = (30, 92, 92)
WATER = (46, 84, 140)
SNOW = (206, 208, 220)
HILLS = (128, 98, 70)
CORN = (214, 178, 58)
SWAMP = (58, 84, 70)
YARD = (118, 120, 132)
ROAD = (196, 164, 112)
RAIL = (40, 30, 30)

rng = random.Random(1103)


def px(fx: float, fy: float) -> tuple[float, float]:
    return fx * W, fy * H


def blob(img: Image.Image, cx: float, cy: float, rx: float, ry: float, colour: tuple, wobble: float = 0.22, soften: int = 14) -> None:
    """A lumpy flat-coloured patch (fractions of the canvas for centre and radii), softened at its edge."""
    layer = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(layer)
    n = 48
    ph = [rng.uniform(0, math.tau) for _ in range(4)]
    pts = []
    for i in range(n):
        a = math.tau * i / n
        k = 1.0 + wobble * (math.sin(2 * a + ph[0]) * 0.5 + math.sin(3 * a + ph[1]) * 0.35 + math.sin(5 * a + ph[2]) * 0.25)
        pts.append((cx * W + math.cos(a) * rx * W * k, cy * H + math.sin(a) * ry * H * k))
    d.polygon(pts, fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(soften))
    img.paste(Image.new("RGB", (W, H), colour), (0, 0), layer)


def curve(points: list[tuple[float, float]], steps: int = 24) -> list[tuple[float, float]]:
    """A smooth line through the points (Catmull-Rom), in pixels."""
    p = [px(*q) for q in points]
    p = [p[0]] + p + [p[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for s in range(steps):
            t = s / steps
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t ** 3) for k in (0, 1)))
    out.append(p[-2])
    return out


def road(img: Image.Image, a: str, b: str, bend: float = 0.03, width: int = 9) -> None:
    ax, ay = POS[a]
    bx, by = POS[b]
    mx, my = (ax + bx) / 2, (ay + by) / 2
    nx, ny = -(by - ay), (bx - ax)
    ln = math.hypot(nx, ny) or 1.0
    mid = (mx + nx / ln * bend, my + ny / ln * bend)
    ImageDraw.Draw(img).line(curve([(ax, ay), mid, (bx, by)]), fill=ROAD, width=width, joint="curve")


def sketch() -> Image.Image:
    img = Image.new("RGB", (W, H), LAND)
    # The land, west to east. Everything is a soft patch; the painting turns each into its own country.
    blob(img, 0.50, 0.50, 0.30, 0.30, MOOR, 0.3, 40)          # the hollow's moor
    blob(img, 0.06, 0.56, 0.085, 0.2, WATER, 0.18)              # Lake Moonsong
    blob(img, 0.11, 0.5, 0.03, 0.04, LAND, 0.3, 6)              # Memory's Rest isle
    blob(img, 0.03, 0.30, 0.07, 0.2, SNOW, 0.25)                # western peaks
    blob(img, 0.12, 0.74, 0.12, 0.08, SNOW, 0.25)               # peaks south of Dawn's Gate
    blob(img, 0.60, 0.04, 0.17, 0.07, SNOW, 0.3)                # northern peaks
    blob(img, 0.52, 0.13, 0.08, 0.05, HILLS, 0.3)               # barren foothills
    blob(img, 0.24, 0.37, 0.12, 0.1, HILLS, 0.3)                # the mine hills
    blob(img, 0.17, 0.18, 0.13, 0.12, TOXIC, 0.28)              # Hartsblight
    blob(img, 0.40, 0.28, 0.06, 0.05, FOREST, 0.3)              # burnt trees round the wreck
    blob(img, 0.82, 0.18, 0.10, 0.09, FOREST, 0.3)              # the Wytchwood edge
    blob(img, 0.84, 0.50, 0.17, 0.2, CORN, 0.25)                # Foxwillow's corn
    blob(img, 0.66, 0.73, 0.08, 0.07, YARD, 0.28)               # Maidenmist
    blob(img, 0.50, 0.90, 0.24, 0.12, SWAMP, 0.28)              # the bayou
    blob(img, 0.56, 0.42, 0.045, 0.06, HILLS, 0.25, 8)          # the estate's hill
    blob(img, 0.88, 0.80, 0.12, 0.12, FOREST, 0.3)              # woods in the south east
    # The Silverbell: out of the lake, past the village and down into the bayou.
    ImageDraw.Draw(img).line(curve([(0.14, 0.62), (0.28, 0.6), (0.42, 0.64), (0.47, 0.74), (0.5, 0.84), (0.52, 0.93)]),
                             fill=WATER, width=22, joint="curve")
    # The rail line the Ghostlight Express ran on, ending at the wreck.
    rail = curve([(0.30, 0.0), (0.34, 0.12), (0.37, 0.24), (0.36, 0.33)])
    ImageDraw.Draw(img).line(rail, fill=RAIL, width=10, joint="curve")
    # Roads: every road of the data.
    for r in DATA["roads"]:
        if r["from"] in POS and r["to"] in POS:
            road(img, r["from"], r["to"], bend=0.02 if r["hours"] < 8 else 0.05, width=9 if r["hours"] < 20 else 7)
    return img


def marks(img: Image.Image) -> None:
    """A small shape at each place so the painter draws something there (the engine draws the pin over it)."""
    d = ImageDraw.Draw(img)

    def at(pid: str) -> tuple[float, float]:
        return px(*POS[pid])

    def box(c, w, h, fill):
        d.rectangle([c[0] - w / 2, c[1] - h / 2, c[0] + w / 2, c[1] + h / 2], fill=fill, outline=(20, 16, 20), width=3)

    x, y = at("wickermoor_village")                       # a ring of crooked roofs round the oak
    for i in range(9):
        a = math.tau * i / 9
        box((x + math.cos(a) * 52, y + math.sin(a) * 36), 26, 22, (150, 70, 50))
    d.ellipse([x - 12, y - 12, x + 12, y + 12], fill=(70, 50, 30))
    x, y = at("druskenvald_estate")                       # the crooked house on its hill
    box((x, y - 10), 40, 40, (120, 90, 140))
    d.polygon([(x - 26, y - 28), (x, y - 62), (x + 26, y - 28)], fill=(70, 40, 80), outline=(20, 16, 20))
    x, y = at("ghostlight_wreckage")                      # a wrecked train: three cars askew
    for k in range(3):
        d.polygon([(x - 50 + k * 34, y - 8 + k * 6), (x - 20 + k * 34, y - 16 + k * 6), (x - 14 + k * 34, y + 10 + k * 6),
                   (x - 44 + k * 34, y + 18 + k * 6)], fill=(90, 40, 40), outline=(20, 16, 20))
    x, y = at("foxwillow")                                # a windmill among the corn
    box((x, y + 8), 24, 40, (220, 214, 200))
    d.line([(x - 40, y - 28), (x + 40, y + 44)], fill=(60, 40, 30), width=6)
    d.line([(x + 40, y - 28), (x - 40, y + 44)], fill=(60, 40, 30), width=6)
    x, y = at("dawns_gate")                               # a monastery with a tower
    box((x, y), 56, 34, (170, 172, 184))
    box((x + 30, y - 22), 18, 54, (150, 152, 166))
    x, y = at("memorys_rest")                             # a pale sanatorium on the shore
    box((x, y), 40, 26, (206, 232, 222))
    x, y = at("hartsblight_forest")                       # a giant glowing toadstool
    d.ellipse([x - 44, y - 40, x + 44, y + 10], fill=(150, 40, 150), outline=(20, 16, 20), width=3)
    d.rectangle([x - 8, y + 6, x + 8, y + 46], fill=(190, 200, 170))
    x, y = at("sk_camp")                                  # a mine headframe
    d.polygon([(x - 30, y + 30), (x, y - 40), (x + 30, y + 30)], outline=(40, 30, 20), width=6)
    x, y = at("maidenmist_gate")                          # headstones in a walled yard
    for k in range(5):
        box((x - 40 + k * 20, y + (k % 2) * 14), 12, 20, (200, 200, 208))
    x, y = at("dc_murkwater")                             # a riverboat with two stacks
    box((x, y), 62, 22, (200, 190, 170))
    box((x - 14, y - 22), 10, 24, (50, 40, 40))
    box((x + 14, y - 22), 10, 24, (50, 40, 40))


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/Volumes/ASH-SSD/CrookedMoon/assets/maps/wickermoor_hollow_sketch.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    im = sketch()
    marks(im)
    im.save(out)
    print(out, im.size)
