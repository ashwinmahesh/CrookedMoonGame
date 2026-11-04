#!/usr/bin/env /usr/bin/python3
"""ONE-SHOT (fun pass, lane D). The battle grounds the road encounter tables (data/random_encounters/) fight on: six stretches of
road in the lands the roads cross, painted as land (layout + height pictures at 20 px a square) into docs/plans/road_grounds/<id>/,
with each location file written beside them (everything but `map`). Then the `make sketch` line for each lays the land into the
file's `map`, and `--check` reports any spawn, exit or foe spot the land closed:
    /usr/bin/python3 tools/content/road_grounds.py docs/plans/road_grounds
    make sketch HEIGHT=docs/plans/road_grounds/<id>/height.png LAYOUT=docs/plans/road_grounds/<id>/layout.png SIZE=WxH TOP=n LOC=data/locations/<id>.json
    /usr/bin/python3 tools/content/road_grounds.py --check"""
import json, math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

S = 20
ROOT = Path(__file__).resolve().parents[2]
WATER, WOODS, ROCK, BRAMBLE, FENCE, OPEN = "#0000ff", "#006400", "#808080", "#8b4513", "#ffff00", "#e8e8e8"
W, H = 34, 24


class Canvas:
    def __init__(self, gid, base_h=80, swell=70):
        self.gid = gid
        self.lay = Image.new("RGB", (W * S, H * S), OPEN); self.hei = Image.new("L", (W * S, H * S), base_h)
        self.L, self.H = ImageDraw.Draw(self.lay), ImageDraw.Draw(self.hei)
        self.r = random.Random(sum(map(ord, gid)))
        ph = self.r.uniform(0, 6)
        for y in range(H * S):          # a gentle swell, so open ground is never dead flat
            self.H.line((0, y, W * S, y), fill=int(base_h + swell * math.sin(y / (S * 5.0) + ph)))

    def blob(self, cx, cy, rx, ry, fill=None, wob=0.25, n=22, height=None):
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n; k = 1 + self.r.uniform(-wob, wob)
            pts.append(((cx + math.cos(a) * rx * k) * S, (cy + math.sin(a) * ry * k) * S))
        if fill: self.L.polygon(pts, fill=fill)
        if height is not None: self.H.polygon(pts, fill=height)

    def band(self, pts, width, fill=None, height=None):
        """A winding strip (a road, a creek, a causeway) through `pts` (squares), `width` squares wide."""
        px = [(x * S + S / 2, y * S + S / 2) for (x, y) in pts]
        if fill: self.L.line(px, fill=fill, width=int(width * S), joint="curve")
        if height is not None: self.H.line(px, fill=height, width=int(width * S), joint="curve")
        for (x, y) in px:
            if fill: self.L.ellipse((x - width * S / 2, y - width * S / 2, x + width * S / 2, y + width * S / 2), fill=fill)
            if height is not None: self.H.ellipse((x - width * S / 2, y - width * S / 2, x + width * S / 2, y + width * S / 2), fill=height)

    def cell(self, x, y, fill):
        self.L.rectangle((x * S, y * S, (x + 1) * S - 1, (y + 1) * S - 1), fill=fill)

    def edge(self, rows_top, rows_bottom, fill=WOODS):
        """Ragged woods (or rock) along the north and south edges, `rows_top`/`rows_bottom` squares deep on average, rising
        and falling in a slow wave with knots of trees standing out from it, so the edge never reads as a straight band."""
        ph1, ph2 = self.r.uniform(0, 6), self.r.uniform(0, 6)
        for x in range(W):
            t = rows_top + 1.6 * math.sin(x / 2.7 + ph1) + self.r.uniform(-0.6, 0.6)
            b = rows_bottom + 1.6 * math.sin(x / 3.1 + ph2) + self.r.uniform(-0.6, 0.6)
            for y in range(max(1, round(t))): self.cell(x, y, fill)
            for y in range(H - max(1, round(b)), H): self.cell(x, y, fill)
        for _ in range(5):
            self.blob(self.r.uniform(1, W - 2), self.r.choice((rows_top + 1.5, H - rows_bottom - 1.5)), self.r.uniform(0.9, 1.6), 1.0, fill)

    def scatter(self, n, fill, rx=(0.8, 1.5), keep=(), box=(2, 2, W - 3, H - 3)):
        x0, y0, x1, y1 = box
        for _ in range(n):
            cx, cy = self.r.uniform(x0, x1), self.r.uniform(y0, y1)
            if any(math.hypot(cx - kx, cy - ky) < kr for (kx, ky, kr) in keep): continue
            r = self.r.uniform(*rx); self.blob(cx, cy, r, r * self.r.uniform(0.8, 1.2), fill)

    def clear(self, cell, rad=2):
        x, y = cell
        self.L.rectangle((max(0, x - rad) * S, max(0, y - rad) * S, (min(W - 1, x + rad) + 1) * S - 1, (min(H - 1, y + rad) + 1) * S - 1), fill=OPEN)

    def finish(self, g, out):
        for cell in list(g["spawns"].values()) + [e["cell"] for e in g["exits"]]:
            self.clear(cell, 1)
        for cell in g["foe_spots"]:
            self.clear(cell, 0)
        d = out / self.gid; d.mkdir(parents=True, exist_ok=True)
        self.lay.save(d / "layout.png"); self.hei.filter(ImageFilter.GaussianBlur(S * 0.9)).save(d / "height.png")


def road_exits(west, east, back="Back along the road", on="On along the road"):
    return [{"id": "road_west", "cell": list(west), "to": "travel", "spawn": "default", "label": back},
            {"id": "road_east", "cell": list(east), "to": "travel", "spawn": "default", "label": on}]


def decor(gid, items):
    """Props from (name, model, x, y[, label, kind]) rows: a label makes it something to examine."""
    out = []
    for it in items:
        name, model, x, y = it[:4]
        p = {"id": f"{gid}_{name}", "cell": [x, y], "kind": "decor", "model": model}
        if len(it) > 4:
            p["kind"] = "examine"; p["label"] = it[4]
        out.append(p)
    return out


# --- The grounds -------------------------------------------------------------------------------------------------------------

def oakwood(out):
    g = {"id": "road_oakwood", "name": "The Oak Road", "region": "wickermoor",
         "summary": "A cart road winding through old oaks between the wreck and Wickermoor, with a fallen trunk across one rut. A road fight in Wickermoor Hollow's woods may play out here.",
         "text": "The road bends under old oaks gone the colour of rust. Leaves lie ankle deep in the ruts, and somewhere above you a branch creaks with nothing on it.",
         "spawns": {"default": [12, 12]},
         "exits": road_exits((0, 13), (33, 10)),
         "foe_spots": [[20, 9], [22, 13], [18, 15], [25, 10], [27, 14], [16, 7], [8, 8], [6, 15], [10, 17], [24, 17], [29, 8], [14, 16], [21, 6], [4, 11]]}
    c = Canvas(g["id"], 90)
    c.edge(3, 3)
    c.band([(0, 13), (6, 13), (12, 12), (18, 11), (24, 11), (30, 10), (33, 10)], 3, OPEN, 100)       # the road, worn a little lower
    c.scatter(10, WOODS, (1.0, 1.8), keep=[(12, 12, 4), (18, 11, 3), (24, 11, 3), (6, 13, 3), (30, 10, 3)], box=(2, 5, 31, 19))
    c.blob(16, 7, 3.5, 2, height=150)                     # a knoll north of the road
    c.blob(24, 17, 3, 1.6, height=60)                     # a leafy hollow south of it
    c.blob(24, 17, 2.2, 1.0, BRAMBLE)
    for x in range(19, 23): c.cell(x, 12, FENCE)           # the fallen oak across the south rut
    c.finish(g, out)
    g["props"] = decor("oak", [
        ("fallen_oak", "fallen_beam", 20, 12, "A fallen oak across the rut"), ("milestone", "milestone", 3, 12, "A milestone, its number chiselled off"),
        ("lantern", "lantern_post", 13, 10, "A road lantern with a carved gourd for a hood"), ("crows", "crow", 21, 11),
        ("leaves_1", "leaves", 10, 13), ("leaves_2", "leaves", 17, 10), ("leaves_3", "leaves", 26, 12), ("leaves_4", "leaves", 6, 12),
        ("stump", "stump", 15, 14), ("boulder", "boulder", 28, 13), ("tree_1", "dead_tree_a", 9, 6), ("tree_2", "dead_tree_b", 26, 7),
        ("tree_3", "tree_marked", 11, 16, "An oak with a face cut into its bark"), ("tree_4", "dead_tree_a", 30, 15), ("tree_5", "dead_tree_b", 4, 7),
        ("bones", "bone_scatter", 24, 16), ("cart", "cart_broken", 7, 16, "A cart with one wheel, left where it broke"), ("puddle", "puddle", 18, 12)])
    return g


def moor(out):
    g = {"id": "road_moor_bonfire", "name": "The Bonfire Crossing", "region": "wickermoor",
         "summary": "Open moor where two tracks cross by a burnt-out bonfire of old bones, a scarecrow and a ring of grey stones on the rise above. A road fight on Wickermoor Hollow's open ground may play out here.",
         "text": "Heather and dead bracken roll away under a low sky. Where the tracks cross, a ring of blackened bones still smokes, and a scarecrow watches the four ways at once.",
         "spawns": {"default": [13, 12]},
         "exits": road_exits((0, 12), (33, 12)),
         "foe_spots": [[21, 12], [19, 8], [23, 16], [26, 10], [17, 4], [17, 19], [28, 14], [7, 6], [6, 17], [10, 4], [24, 5], [29, 19], [3, 9], [15, 16]]}
    c = Canvas(g["id"], 100)
    c.edge(2, 2, ROCK)
    c.band([(0, 12), (8, 12), (17, 12), (25, 12), (33, 12)], 2, OPEN, None)
    c.band([(17, 0), (17, 6), (17, 12), (18, 18), (17, 23)], 2, OPEN, None)
    c.blob(25, 6, 4.5, 3.0, height=190)                   # the rise with the stones
    c.blob(8, 18, 3.5, 2.2, BRAMBLE, height=55)           # a boggy hollow
    c.blob(7, 18.5, 1.6, 1.1, WATER, height=40)           # its pool
    for x in range(3, 10): c.cell(x, 8, FENCE)             # a tumbled drystone wall
    for y in range(15, 20): c.cell(26, y, FENCE)
    c.scatter(5, ROCK, (0.6, 1.0), keep=[(13, 12, 4), (17, 12, 4), (25, 6, 5)], box=(2, 3, 31, 20))
    c.finish(g, out)
    g["props"] = decor("moor", [
        ("bonfire", "ash_heap", 18, 11, "A burnt-out bonfire of bones"), ("bonfire_bones", "bone_scatter", 19, 12), ("bonfire_scorch", "scorch", 18, 12),
        ("scarecrow", "scarecrow_stitched", 16, 10, "A scarecrow facing all four ways at once"), ("signpost", "signpost_broken", 15, 13, "A signpost with every arm snapped off"),
        ("stones", "standing_stones", 25, 6, "A ring of grey stones on the rise"), ("cairn", "cairn", 22, 7), ("crow_1", "crow", 25, 5), ("crow_2", "crow", 16, 9),
        ("reeds", "reeds", 9, 17), ("reeds_2", "reeds", 6, 19), ("rocks_1", "rocks", 29, 9), ("rocks_2", "rocks", 11, 4), ("bones", "bones", 21, 16),
        ("dead_tree", "dead_tree_b", 30, 17), ("gibbet", "cage", 4, 14, "An empty gibbet cage hung on a post")])
    return g


def ford(out):
    g = {"id": "road_creek_ford", "name": "The Creek Ford", "region": "wickermoor",
         "summary": "A brown creek running across the road through willows and reeds, crossed at a stony ford. A road fight by Wickermoor Hollow's streams may play out here.",
         "text": "The road runs down into a brown creek and climbs out the far side. Willows trail their hair in the water, and the ford stones are slick with green.",
         "spawns": {"default": [9, 12]},
         "exits": road_exits((0, 12), (33, 11)),
         "foe_spots": [[22, 11], [24, 7], [25, 15], [28, 9], [21, 18], [29, 16], [13, 6], [12, 18], [5, 7], [6, 17], [27, 4], [19, 5], [3, 14], [30, 12]]}
    c = Canvas(g["id"], 110)
    c.edge(3, 3)
    c.band([(15, 0), (16, 6), (17, 12), (16, 18), (17, 23)], 4, None, 30)       # the creek bed, cut down
    c.band([(15, 0), (16, 6), (17, 12), (16, 18), (17, 23)], 2.4, WATER, 20)
    c.band([(0, 12), (8, 12), (14, 12), (20, 11), (26, 11), (33, 11)], 3, OPEN, None)
    c.band([(14.5, 12), (19.5, 11.5)], 2.2, BRAMBLE, 50)                        # the ford: slick stones, knee deep
    for (cx, cy) in [(13, 4), (20, 5), (12, 19), (21, 19), (14, 15), (20, 8)]: c.blob(cx, cy, 1.4, 1.1, WOODS)    # willows
    c.scatter(4, WOODS, (0.9, 1.4), keep=[(9, 12, 4), (17, 12, 6), (26, 11, 4)], box=(3, 4, 30, 19))
    c.finish(g, out)
    g["props"] = decor("ford", [
        ("stones", "rocks", 17, 12, "Ford stones, slick with weed"), ("reeds_1", "reeds", 15, 9), ("reeds_2", "reeds", 18, 15), ("reeds_3", "reeds", 16, 4),
        ("reeds_4", "reeds", 18, 19), ("post", "lantern_post", 12, 11, "A ford post hung with a dead lantern"), ("boulder", "boulder_a", 23, 13),
        ("stump", "stump", 7, 14), ("leaves", "leaves", 25, 10), ("bones", "bone_scatter", 20, 14), ("tree_1", "dead_tree_a", 5, 5),
        ("tree_2", "dead_tree_b", 28, 18), ("cairn", "cairn", 26, 8, "A cairn of creek stones with a doll's shoe on top"), ("puddle", "puddle", 10, 13)])
    return g


def cornfield(out):
    g = {"id": "road_cornfield_lane", "name": "The Cornfield Lane", "region": "foxwillow",
         "summary": "A fenced lane between tall dead corn on the way east to Foxwillow, past a hay wagon and a field of scarecrows. A road fight in Foxwillow's farmland may play out here.",
         "text": "Dead corn stands higher than your heads on both sides of the lane, rattling though there's no wind. Out in the rows, scarecrows lean on their poles.",
         "spawns": {"default": [11, 12]},
         "exits": road_exits((0, 12), (33, 12)),
         "foe_spots": [[20, 12], [23, 10], [25, 14], [18, 9], [28, 12], [8, 9], [7, 15], [15, 16], [21, 17], [26, 6], [13, 7], [30, 15], [4, 13], [17, 14]]}
    c = Canvas(g["id"], 90)
    for y in range(0, 9):                                  # the corn: rows of stalks, gaps between plots
        for x in range(W):
            if not (12 <= x <= 14 or 24 <= x <= 25) and c.r.random() > 0.08: c.cell(x, y, WOODS)
    for y in range(16, H):
        for x in range(W):
            if not (5 <= x <= 7 or 19 <= x <= 21) and c.r.random() > 0.08: c.cell(x, y, WOODS)
    c.blob(25, 12, 6, 3.5, OPEN, 0.1)                      # a trodden clearing where the wagon turned
    c.blob(25, 12, 5, 3, height=120)
    for x in list(range(1, 11)) + list(range(15, 20)) + list(range(29, 33)): c.cell(x, 10, FENCE)    # split-rail fences, gaps for gates
    for x in list(range(1, 6)) + list(range(9, 18)) + list(range(30, 33)): c.cell(x, 15, FENCE)
    c.finish(g, out)
    g["props"] = decor("corn", [
        ("wagon", "cart", 23, 11, "A hay wagon with no horse"), ("hay_1", "hay_bale", 21, 13), ("hay_2", "hay_bale", 27, 14),
        ("scarecrow_1", "scarecrow", 13, 5, "A scarecrow with a crow's skull for a face"), ("scarecrow_2", "scarecrow", 20, 18), ("scarecrow_3", "scarecrow_stitched", 6, 19),
        ("scarecrow_4", "scarecrow", 25, 4), ("crow_1", "crow", 18, 11), ("crow_2", "crow", 28, 10), ("crow_3", "crow", 9, 13),
        ("signpost", "signpost", 3, 11, "A signpost: Foxwillow, east"), ("pumpkins", "garden_bed", 16, 13), ("leaves", "leaves", 8, 12),
        ("bones", "bone_scatter", 30, 13), ("barrel", "barrel", 24, 9)])
    return g


def bayou(out):
    g = {"id": "road_bayou_causeway", "name": "The Swamp Causeway", "region": "drowned_crossroads",
         "summary": "A raised track of packed mud and old planks across black water and cypress knees, south toward the Drowned Crossroads. A road fight in the swamp may play out here.",
         "text": "The track rides a hump of packed mud across black water. Moss hangs off dead cypress in long grey beards, and the water moves where nothing should be moving it.",
         "spawns": {"default": [9, 12]},
         "exits": road_exits((0, 12), (33, 12)),
         "foe_spots": [[19, 12], [22, 10], [24, 14], [16, 8], [27, 12], [20, 16], [13, 15], [6, 9], [7, 15], [29, 9], [25, 6], [12, 6], [30, 15], [3, 12]]}
    c = Canvas(g["id"], 60, 30)
    c.L.rectangle((0, 0, W * S, H * S), fill=WATER); c.H.rectangle((0, 0, W * S, H * S), fill=30)
    c.band([(0, 12), (6, 12), (12, 11), (18, 12), (24, 12), (30, 12), (33, 12)], 3.2, OPEN, 110)     # the causeway
    for (cx, cy, rx, ry) in [(14, 6, 4, 2.2), (24, 16, 4.5, 2.4), (6, 16, 3, 1.8), (27, 7, 3, 1.8), (19, 18, 2.2, 1.4)]:     # hummocks
        c.blob(cx, cy, rx, ry, OPEN, height=95)
        c.blob(cx, cy, rx * 0.5, ry * 0.5, WOODS)
    c.band([(19, 12), (20, 15), (22, 16)], 1.6, OPEN, 100)  # a spit out to a hummock
    c.band([(13, 11), (14, 8)], 1.6, OPEN, 100)
    c.scatter(6, BRAMBLE, (0.8, 1.3), keep=[(9, 12, 3), (18, 12, 3)], box=(2, 4, 31, 19))
    c.finish(g, out)
    g["props"] = decor("bayou", [
        ("planks", "broken_boards", 16, 12, "Rotten planks laid over a soft stretch"), ("reeds_1", "reeds", 11, 14), ("reeds_2", "reeds", 22, 9), ("reeds_3", "reeds", 28, 14),
        ("reeds_4", "reeds", 5, 10), ("tree_1", "dead_tree_a", 14, 5), ("tree_2", "dead_tree_b", 24, 17), ("tree_3", "dead_tree_a", 27, 6),
        ("vines", "vines", 15, 7), ("boat", "rowboat", 20, 18, "A flat-bottomed boat, sunk to its rails"), ("lantern", "lantern_post", 8, 11, "A swamp lantern on a crooked pole"),
        ("bones", "bone_scatter", 21, 15), ("puddle", "puddle", 25, 12), ("crow", "crow", 7, 16)])
    return g


def foothills(out):
    g = {"id": "road_foothill_pass", "name": "The Foothill Road", "region": "dawns_gate",
         "summary": "A stony road climbing between scree and boulders below the Howlers, past a roadside shrine. A road fight in the foothills may play out here.",
         "text": "The road climbs between grey boulders and slides of loose stone. A small shrine leans by the wayside, its candle long out and its offerings picked clean.",
         "spawns": {"default": [9, 13]},
         "exits": road_exits((0, 14), (33, 9)),
         "foe_spots": [[19, 11], [22, 8], [23, 13], [17, 6], [27, 10], [20, 16], [13, 17], [5, 9], [6, 18], [28, 5], [25, 17], [12, 7], [30, 12], [15, 12]]}
    c = Canvas(g["id"], 60, 30)
    for x in range(W):                                     # the land tilts up to the east
        c.H.rectangle((x * S, 0, (x + 1) * S, H * S), fill=int(50 + 140 * x / W))
    c.edge(3, 3, ROCK)
    c.band([(0, 14), (7, 13), (14, 12), (21, 11), (27, 10), (33, 9)], 3, OPEN, None)
    for (cx, cy, rx, ry) in [(10, 5, 3, 1.6), (25, 18, 3.5, 1.6), (20, 5, 2, 1.2), (5, 19, 2.5, 1.2)]: c.blob(cx, cy, rx, ry, BRAMBLE)   # scree
    c.blob(17, 4, 3, 1.8, height=230); c.blob(17, 4, 1.6, 1.0, ROCK)              # a crag north of the road
    c.scatter(7, ROCK, (0.6, 1.1), keep=[(9, 13, 4), (21, 11, 3), (27, 10, 3), (14, 12, 3)], box=(2, 4, 31, 19))
    c.finish(g, out)
    g["props"] = decor("hill", [
        ("shrine", "shrine_small", 15, 10, "A wayside shrine, its offerings picked clean"), ("candles", "candle_cluster", 15, 11), ("cairn", "cairn", 24, 8, "A cairn with a bell tied to the top stone"),
        ("boulder_1", "boulder", 19, 14), ("boulder_2", "boulder_b", 11, 15), ("boulder_3", "boulder_a", 26, 12), ("rocks_1", "rocks", 22, 6), ("rocks_2", "rocks", 7, 10),
        ("tree_1", "pine_b", 4, 6), ("tree_2", "pine_a", 29, 15), ("tree_3", "dead_tree_b", 13, 18), ("bones", "bone_scatter", 21, 13),
        ("milestone", "milestone", 30, 9, "A milestone: Dawn's Gate, up the hill"), ("crow", "crow", 16, 9)])
    return g


GROUNDS = [oakwood, moor, ford, cornfield, bayou, foothills]
TOP = {"road_oakwood": 20, "road_moor_bonfire": 25, "road_creek_ford": 20, "road_cornfield_lane": 15, "road_bayou_causeway": 10, "road_foothill_pass": 30}


def write(out):
    for make in GROUNDS:
        g = make(out)
        g["areas"] = [{"id": g["id"], "name": g["name"], "cells": [[0, 0], [W - 1, H - 1]]}]
        g["rest"] = "risky"
        path = ROOT / "data/locations" / f"{g['id']}.json"
        old = json.loads(path.read_text()) if path.exists() else {}
        if "map" in old:
            m = {"rows": old["map"]["rows"], "elevation": old["map"]["elevation"], "outdoors": True}
            reach = _reach(m["rows"], tuple(g["spawns"]["default"]))
            g["foe_spots"] = [c for c in g["foe_spots"] if tuple(c) in reach]   # a spot the land closed off is dropped
            g = {"map": m, **g}
        path.write_text(json.dumps(g, indent=2) + "\n")
        print(f"make sketch HEIGHT={out}/{g['id']}/height.png LAYOUT={out}/{g['id']}/layout.png SIZE={W}x{H} TOP={TOP[g['id']]} LOC=data/locations/{g['id']}.json")


OPEN_FLOOR = ".~"


def _reach(rows, start):
    """Open squares reachable from `start` in 8 directions, as `make validate` walks them."""
    seen, todo = {start}, [start]
    while todo:
        x, z = todo.pop()
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                n = (x + dx, z + dz)
                if n not in seen and 0 <= n[1] < len(rows) and 0 <= n[0] < len(rows[n[1]]) and rows[n[1]][n[0]] in OPEN_FLOOR:
                    seen.add(n); todo.append(n)
    return seen


def check():
    bad = 0
    for path in sorted((ROOT / "data/locations").glob("road_*.json")):
        g = json.loads(path.read_text()); rows = g["map"]["rows"]
        def walk(c): return rows[c[1]][c[0]] in ".~"
        for name, cells in [("spawn", g["spawns"].values()), ("exit", [e["cell"] for e in g["exits"]]), ("foe spot", g["foe_spots"])]:
            for c in cells:
                if not walk(c): print(f"{path.name}: {name} {c} is on '{rows[c[1]][c[0]]}'"); bad += 1
    print("check:", "ok" if bad == 0 else f"{bad} closed")
    return bad


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(1 if check() else 0)
    write(Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plans/road_grounds"))
