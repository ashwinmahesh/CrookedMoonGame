#!/usr/bin/env python3
"""ONE-SHOT (R21, Fool's Day). Writes the festival that takes over Wickermoor: the warped town (`fd_festival`), the Silent Church (`fd_silent_church`),
the Ring of Fools (`fd_ring_of_fools`), the festival's people, quests, flags, items, monsters, fights, cutscene definitions, and the small additive
hooks in the existing hub (data/locations/wickermoor_village.json, wickermoor_green_queen_inn.json): the inn hand's letter, the takeover and
the way back into the festival. The hub edits are idempotent (our entries are removed and put back ahead of the others); the new files are ours.
    python3 tools/content/build_fools_day.py"""
import copy, json, sys
from collections import deque
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G
from fools_day_cast import COSTUMES, REVELERS, BOOTHS, HOST_NAMES
from heirlooms_kept import kept

ROOT = Path(__file__).resolve().parents[2]
REGION = "wickermoor"
FD = "fools_day/"
W, H = 80, 60


def write(rel, obj):
    if kept(rel):
        return
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def prop(pid, cell, label=None, kind="examine", model=None, **kw):
    d = {"id": pid, "cell": list(cell), "kind": kind}
    if label:
        d["label"] = label
    if model:
        d["model"] = model
    d.update(kw)
    return d


def npc(nid, cell, dialogue=None, **kw):
    d = {"npc": nid, "cell": list(cell)}
    if dialogue:
        d["dialogue"] = FD + dialogue
    d.update(kw)
    return d


def area(aid, name, a, b, **kw):
    d = {"id": aid, "name": name, "cells": [list(a), list(b)]}
    d.update(kw)
    return d


def exit_(eid, cell, to, spawn, label, **kw):
    d = {"id": eid, "cell": list(cell), "to": to, "spawn": spawn, "label": label}
    d.update(kw)
    return d


def monster(mid, cell, name=None, **kw):
    d = {"monster": mid, "cell": list(cell)}
    if name:
        d["name"] = name
    d.update(kw)
    return d


def slot_when(nid):
    """Who stands in a costume's slot (the digest's swap rule: a hero's Connection who is listed but not picked takes the default's place)."""
    return {
        "wendel_somerton": "not flag.connection_ascendancy and not flag.connection_immortality",
        "alda_farnum": "flag.connection_ascendancy",
        "jean_myriel": "flag.connection_immortality and not flag.connection_ascendancy",
        "holly_aster": "not (flag.connection_evolution and not flag.connection_liberation)",
        "thomasin_ardor": "flag.connection_evolution and not flag.connection_liberation",
    }.get(nid, "")


def holds(*parts):
    return " and ".join(p for p in parts if p)


# ---- the festival town ------------------------------------------------------------------------------------------------------------
SQUARE = (28, 20, 52, 40)           # x0, y0, x1, y1, the Festival Square (C2), the Founder's Round gone square
PLAZA = (32, 42, 48, 49)            # the Prize Counter's lot (C3)
CHURCH_LOT = (58, 3, 68, 11)        # the Silent Church (C5) stands here
AVENUE = (2, 27, 27, 33)            # the way in from the west


def inside(r, x, y, pad=0):
    return r[0] - pad <= x <= r[2] + pad and r[1] - pad <= y <= r[3] + pad


def festival_rows():
    g = G(W, H)
    g.fill(1, 1, W - 2, H - 2, ".")                        # the town is open ground; blocks of packed buildings stand in it
    g.wall(0, 0, W - 1, 1).wall(0, H - 2, W - 1, H - 1).wall(0, 0, 1, H - 1).wall(W - 2, 0, W - 1, H - 1)
    blocks = []
    for y0 in range(4, H - 10, 6):
        for x0 in range(4, W - 12, 7):
            if any(inside(R, x, y, 3) for R in (SQUARE, PLAZA, CHURCH_LOT, AVENUE) for (x, y) in ((x0, y0), (x0 + 7, y0), (x0, y0 + 5), (x0 + 7, y0 + 5), (x0 + 3, y0 + 2))):
                continue
            if all(g.c[yy][xx] == "." for yy in range(max(2, y0 - 3), min(H - 2, y0 + 9)) for xx in range(max(2, x0 - 3), min(W - 2, x0 + 11))):
                blocks.append((x0, y0))
                g.wall(x0, y0, x0 + 7, y0 + 5)
    # chicanes: small walls in the long streets so no sightline runs past about 60 feet
    for i, yc in enumerate((10, 22, 34, 46)):
        for j, x in enumerate(range(9, 72, 11)):
            y = yc + (0 if (i + j) % 2 else 3)
            if any(inside(R, xx, yy, 2) for R in (SQUARE, PLAZA, CHURCH_LOT, AVENUE) for (xx, yy) in ((x, y), (x + 2, y), (x, y + 2), (x + 2, y + 2))):
                continue
            if all(g.c[yy][xx] == "." for yy in range(y, y + 3) for xx in range(x, x + 3)):
                g.wall(x, y, x + 2, y + 2)
    # the church: a small block with its door on the south face (open floor), tarps and new timber
    g.wall(60, 4, 66, 8)
    g.put([(63, 8)], ".")
    # the square: a bonfire ring round the maypole is a low obstacle; the booths are low counters
    g.put([(39, 30), (41, 30), (40, 29), (40, 31)], "=")
    for key, (_, _, _, (x0, y, n, vert), _, _) in BOOTHS.items():
        for i in range(n):
            g.put([(x0, y + i) if vert else (x0 + i, y)], "=")
    g.fill(37, 44, 43, 44, "=")                             # the Prize Counter
    # the roads out: a gap in the border on each side, with a band of difficult going in front of it
    for (cells, band) in (([(1, 30), (0, 30)], [(2, 29), (2, 30), (2, 31), (3, 29), (3, 30), (3, 31)]),
                          ([(W - 2, 30), (W - 1, 30)], [(W - 3, 29), (W - 3, 30), (W - 3, 31), (W - 4, 29), (W - 4, 30), (W - 4, 31)]),
                          ([(40, 1), (40, 0)], [(39, 2), (40, 2), (41, 2), (39, 3), (40, 3), (41, 3)]),
                          ([(40, H - 2), (40, H - 1)], [(39, H - 3), (40, H - 3), (41, H - 3), (39, H - 4), (40, H - 4), (41, H - 4)])):
        g.put(cells, ".")
        g.put(band, "~")
    return g.rows(), blocks


def reachable(rows, start):
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= ny < len(rows) and 0 <= nx < len(rows[0]) and (nx, ny) not in seen and rows[ny][nx] in ".~_":
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def build_festival():
    rows, blocks = festival_rows()
    spawn = (6, 30)
    assert rows[30][6] == ".", "spawn"
    seen = reachable(rows, spawn)
    # every placement must stand on open ground the spawn can reach
    placements = {}
    for nid, (_, _, cell, _) in REVELERS.items():
        placements[nid] = cell
    for key, v in BOOTHS.items():
        placements["host_" + key] = v[4]
    placements.update({"chuckles": (40, 43), "quill": (36, 27), "understudy": (24, 37), "man_door": (63, 9), "welcome": (40, 27), "roads_w": (2, 30), "roads_e": (W - 3, 30),
                       "roads_n": (40, 2), "roads_s": (40, H - 3), "streets": (12, 30), "heralds_a": (38, 33), "heralds_b": (42, 33)})
    for k, c in placements.items():
        assert tuple(c) in seen, f"{k} at {c} is not reachable ({rows[c[1]][c[0]]!r})"
    town = {
        "id": "fd_festival", "name": "The Festival of Fools", "region": REGION,
        "summary": "Wickermoor Village swollen to three times its size, strung with ribbon and ringing with carnival music, with no way out that stays out.",
        "text": "The village is the wrong size. The streets twist back on themselves between buildings stuffed to the rafters with hand pies, ribbons run roof to roof in green, red and gold, and in the middle of a square that used to be round a maypole carries a grinning balloon up into the smoke of the bonfires.",
        "map": {"rows": rows, "theme": "village", "light": "bright", "outdoors": True},
        "areas": [
            area("fd_streets", "The Absurd Streets", (2, 2), (W - 3, H - 3)),
            area("fd_square", "Festival Square", SQUARE[:2], SQUARE[2:]),
            area("fd_prize_lot", "The Prize Counter", PLAZA[:2], PLAZA[2:]),
            area("fd_church_lot", "A shuttered door", (58, 9), (68, 11)),
        ],
        "spawns": {"default": list(spawn), "from_hub": list(spawn), "from_church": [63, 10], "from_ring": [40, 36], "from_roads": [40, 36]},
        "exits": [
            exit_("to_church", (63, 8), "fd_silent_church", "from_festival", "A door with no sound behind it", when="flag.fd_church_found"),
        ],
        "props": [], "npcs": [], "encounters": [], "lights": [], "doors": [],
        "rest": "no", "rest_text": "Nobody can sleep in the festival, however tired they are: not by drink, not by spell. The only place that lets you is a quiet church.",
    }
    P = town["props"]
    # set pieces
    P += [
        prop("fd_maypole", (40, 28), "The maypole, and its grinning balloon", model="lantern_post", scale=3.5, tint="#d94a3d", call=FD + "welcome:welcome", approach=9,
             call_when="flag.absurd_streets_seen and not flag.fd_welcomed"),
        prop("fd_balloon", (40, 27), "A clown balloon the size of a cart", kind="decor", model="statue_head", scale=3, tint="#e8c23a"),
        prop("fd_streamers", (38, 28), "Ribbons, roof to roof", kind="decor", model="bunting"),
        prop("fd_streamers_b", (42, 28), "Ribbons, roof to roof", kind="decor", model="bunting"),
        prop("fd_bonfire_w", (31, 30), "A bonfire", kind="decor", model="hearth"),
        prop("fd_bonfire_e", (49, 30), "A bonfire", kind="decor", model="hearth"),
        prop("fd_calliope", (34, 33), "A calliope wagon", model="cart", call=FD + "crowd:calliope", approach=3, call_when="flag.connection_apocalypse and not flag.apocalypse_calliope"),
        prop("fd_joker_card", (46, 33), "A gleaming joker card pinned to a stall", model="papers", call=FD + "crowd:joker", approach=3, call_when="flag.connection_liberation and not flag.liberation_wild_joker"),
        prop("fd_streets_herd", (12, 30), "The crowd, closing in", kind="decor", call=FD + "welcome:streets", approach=8, call_when="not flag.absurd_streets_seen"),
        prop("fd_crowd_search", (34, 25), "The crowd of dancers", kind="decor", model="scarecrow", dialogue=FD + "crowd:search"),
        prop("fd_crowd_shove", (28, 25), "Dancers shoving to the music", kind="decor", model="scarecrow", dialogue=FD + "crowd:shove"),
        prop("fd_parade_ground", (40, 35), "The parade forms up", kind="decor", call=FD + "parade:begin", approach=12,
             call_when="(flag.revelers_freed >= 12 or flag.told_chuckles_hate or flag.parade_offer_taken) and not flag.parade_begun"),
        prop("fd_unmask", (40, 32), "Two masks, cracked down the middle", kind="decor", call=FD + "parade:unmask", approach=12,
             call_when="flag.parade_heralds_done and not flag.druskenvalds_unmasked"),
        prop("fd_hold_door", (63, 9), "The shuttered door", kind="decor", call=FD + "church:hold_door", approach=6,
             call_when="flag.parade_begun and flag.church_quest_asked and not flag.church_door_done"),
    ]
    P += [prop(f"fd_pie_shop_{i}", c, "A building packed to the rafters with scotch eggs and hand pies", kind="decor", model="crate_stack")
          for i, c in enumerate([(16, 3), (30, 15), (58, 16), (66, 28), (10, 40), (24, 52), (58, 52), (44, 15)])]
    for i, (x, y) in enumerate([(14, 26), (20, 34), (26, 22), (54, 22), (60, 34), (50, 44), (22, 44), (56, 38), (46, 18), (34, 18)]):
        P.append(prop(f"fd_dancer_{i}", (x, y), "A costumed dancer, not stopping", kind="decor", model="scarecrow"))
    P += [prop("fd_road_w", (2, 30), "The road out, west", kind="decor", call=FD + "roads:attempt", approach=2),
          prop("fd_road_e", (W - 3, 30), "The road out, east", kind="decor", call=FD + "roads:attempt", approach=2),
          prop("fd_road_n", (40, 2), "The road out, north", kind="decor", call=FD + "roads:attempt", approach=2),
          prop("fd_road_s", (40, H - 3), "The road out, south", kind="decor", call=FD + "roads:attempt", approach=2),
          prop("fd_church_door", (63, 9), "A shuttered door with no sound behind it", kind="decor", model="door_house", when="not flag.fd_church_found")]
    for key, (name, host, block, (x0, y, n, vert), hostcell, theme) in BOOTHS.items():
        P.append(prop(f"fd_booth_{key}", (x0, y), f"{name}", kind="decor", model="bar", span=[1, n] if vert else [n, 1]))
        town["npcs"].append(npc(host, hostcell, f"{'booths' if key in 'abcd' else 'booths_two'}:{key}_start"))
        town["encounters"].append({"id": f"booth_{key}", "trigger": "dialogue", "flag": f"booth_{key}_beaten",
                                   "monsters": [monster(block, (hostcell[0], hostcell[1] + (3 if key in "abc" else -3 if key in "fg" else 0)), HOST_NAMES[host][0])]})
    # the crowd search (Quill's program, the understudy, Chuckles)
    town["npcs"] += [
        npc("ambrose_quill", (36, 27), "quill:festival", when="flag.fd_welcomed"),
        npc("fd_understudy", (24, 37), "understudy:start", when="flag.fd_welcomed"),
        npc("chuckles", (40, 43), "prize:counter", when="flag.fd_welcomed"),
    ]
    for nid, (name, costume, cell, _) in REVELERS.items():
        sw = slot_when(nid)
        found = f"flag.found_{costume}"
        town["npcs"].append(npc(nid, cell, f"reveler_{costume}:{nid}_start",
                                when=holds(found, sw, f"not flag.reveler_{nid}_freed", f"not flag.reveler_{nid}_beaten"), steps_aside=True))
        town["npcs"].append(npc(nid, cell, f"reveler_{costume}:{nid}_beaten", when=holds(sw, f"flag.reveler_{nid}_beaten", f"not flag.reveler_{nid}_freed"), steps_aside=True))
        block = COSTUMES[costume][1]
        town["encounters"].append({"id": f"reveler_{nid}", "trigger": "dialogue", "flag": f"reveler_{nid}_beaten",
                                   "monsters": [monster(block, (cell[0], cell[1] + 2), f"{name}, in costume", facing="north")]})
    # the brawl when the party will not follow the crowd
    town["encounters"].append({"id": "follow_follow_brawl", "trigger": "dialogue", "flag": "fd_brawl_done",
        "monsters": [monster("reveler_of_stories_great_beast", (14, 30), "A dancer in a bear's head", facing="west")],
        "round_events": [
            {"id": f"brawl_{i}", "name": "Another dancer joins", "summary": "The crowd sends another costume to herd you.", "kind": "summon", "affects": "enemies",
             "monster": mon, "count": 1, "side": "enemies", "cells": [[12, 28], [12, 32]], "at": 20, "every": 1, "from_round": r, "times": 1, "say": "fd_brawl_join"}
            for i, (r, mon) in enumerate([(2, "reveler_of_song_drone"), (3, "reveler_of_stories_hero"), (4, "reveler_of_song_drum"), (5, "reveler_of_stories_witch"),
                                          (6, "reveler_of_song_bell"), (7, "herald_of_fools")])]})
    town["encounters"].append({"id": "parade_heralds", "trigger": "dialogue", "flag": "parade_heralds_done", "quest": {"id": "fools_day", "stage": "heralds_unmasked"},
        "monsters": [monster("herald_of_fools", (38, 33), "Phillip, Herald of Fools, masked", facing="south"),
                     monster("herald_of_fools", (42, 33), "Adela, Herald of Fools, masked", facing="south")]})
    # lights: the festival is lit brighter than the village has ever been
    for c in ((31, 30), (49, 30), (40, 24), (40, 36), (40, 44), (20, 30), (60, 30), (40, 10), (40, 52)):
        town["lights"].append({"cell": list(c), "kind": "fire", "bright_ft": 40, "dim_ft": 80, "color": "ember"})
    write("data/locations/fd_festival.json", town)
    return town


def build_church():
    g = G(14, 20).room(1, 1, 12, 18)
    g.fill(4, 1, 9, 2, "_")                                 # the altar's step
    g.put([(3, 6), (4, 6), (9, 6), (10, 6), (3, 9), (4, 9), (9, 9), (10, 9), (3, 12), (4, 12), (9, 12), (10, 12)], "=")   # pews
    g.put([(7, 19)], ".")
    loc = {
        "id": "fd_silent_church", "name": "The Silent Church", "region": REGION,
        "summary": "The half-rebuilt Brightsinger chapel, the one place the festival cannot reach.",
        "text": "The carnival music stops at the door as if cut with a knife. Tarps hang where the windows will go, new timber smells of resin, and a knight in marble twice a man's height stands before the altar with a sneer on his stone face.",
        "map": {"rows": g.rows(), "theme": "manor", "light": "dim", "outdoors": False},
        "areas": [area("church", "The Silent Church", (1, 1), (12, 18))],
        "spawns": {"default": [7, 17], "from_festival": [7, 17]},
        "exits": [exit_("door", (7, 19), "fd_festival", "from_church", "Out into the festival")],
        "props": [
            prop("fd_altar", (6, 1), "The altar, half rebuilt", model="dais", kind="decor"),
            prop("fd_marble_arrival", (7, 13), "The stone knight watches the door", kind="decor", call=FD + "church:arrive", approach=12, call_when="not flag.man_in_marble_met"),
            prop("fd_church_tarps", (2, 4), "Tarps where the windows will go", model="rags"),
            prop("fd_church_timber", (11, 4), "New timber, still sweet with resin", model="crate_stack"),
        ],
        "npcs": [npc("man_in_marble", (7, 3), "church:talk", when="flag.man_in_marble_met", steps_aside=True)],
        "encounters": [], "lights": [{"cell": [7, 4], "kind": "candle", "bright_ft": 20, "dim_ft": 40, "color": "candle"}],
        "rest": "safe", "rest_text": "The festival's sound stops at the door, and nothing outside moves while you sleep.",
    }
    # the freed stand about the nave; the order is fixed so nobody stands on a pew
    spots = [(2, 8), (11, 8), (2, 11), (11, 11), (2, 14), (11, 14), (5, 8), (8, 8), (5, 11), (8, 11), (5, 14), (8, 14), (5, 16), (8, 16), (3, 16)]
    for i, (nid, (name, costume, cell, _)) in enumerate(REVELERS.items()):
        loc["npcs"].append(npc(nid, spots[i], f"reveler_{costume}:{nid}_sheltered", when=holds(slot_when(nid), f"flag.reveler_{nid}_freed", "not flag.shows_over")))
    write("data/locations/fd_silent_church.json", loc)
    return loc


def build_ring():
    w, h = 30, 36
    g = G(w, h).room(1, 1, w - 2, h - 2)
    g.fill(10, 2, 19, 4, "=")                                # the calliope wagon on the north edge
    g.put([(3, 8), (4, 8), (3, 9), (26, 8), (25, 8), (26, 9), (3, 26), (4, 26), (3, 25), (26, 26), (25, 26), (26, 25), (6, 31), (7, 31), (22, 31), (23, 31)], "=")   # stalls, wagons, barrels
    loc = {
        "id": "fd_ring_of_fools", "name": "The Ring of Fools", "region": REGION,
        "summary": "The cleared square where the parade ends: a maypole at the middle, six white streamers running out from it, and a ring of people who cannot stop dancing.",
        "text": "The crowd has drawn back into a ring. The ribbons of the maypole lie in six chalk-white trails across the packed earth, the calliope wagon waits on the north edge, and the clown balloon is straining at the top of its pole.",
        "map": {"rows": g.rows(), "theme": "village", "light": "bright", "outdoors": True},
        "areas": [area("ring", "The Ring of Fools", (1, 1), (w - 2, h - 2))],
        "spawns": {"default": [15, 32], "from_parade": [15, 32]},
        "exits": [], "doors": [],
        "props": [
            prop("fd_ring_pole", (15, 18), "The maypole", model="lantern_post", scale=3.5, tint="#d94a3d", kind="decor"),
            prop("fd_ring_balloon", (15, 16), "A leering clown balloon", model="statue_head", scale=3, tint="#e8c23a", kind="decor"),
            prop("fd_ring_calliope", (14, 3), "The calliope wagon", model="cart", kind="decor"),
            prop("fd_ring_taunt", (15, 28), "The ring waits", kind="decor", call=FD + "ring:taunt", approach=12, call_when="not flag.ring_started"),
            prop("fd_ring_after", (15, 24), "The firework fades", kind="decor", call=FD + "ring:shows_over", approach=12, call_when="flag.ring_of_fools_done and not flag.shows_over"),
        ],
        "npcs": [], "lights": [{"cell": [x, y], "kind": "fire", "bright_ft": 30, "dim_ft": 60, "color": "ember"} for (x, y) in ((6, 6), (23, 6), (6, 28), (23, 28))],
        "rest": "no", "rest_text": "Nobody can sleep in the festival.",
    }
    ring = [(15, 7), (19, 8), (22, 11), (24, 15), (24, 20), (22, 24), (19, 27), (11, 27), (8, 24), (6, 20), (6, 15), (8, 11)]
    dancers = [monster("reveler_of_stories_great_beast", c, "A forced reveler, screaming for help", side="neutral", facing="north") for c in ring]
    boss = monster("lord_of_fools", (15, 12), "Chuckles, the Lord of Fools", boss=True, facing="south")
    heralds = [monster("dancing_herald", c, "A dancing Herald", facing="south") for c in ((9, 16), (21, 16), (15, 22))]
    bands = [(0, 2, 8), (3, 5, 6), (6, 8, 4), (9, 11, 2), (12, 12, 0)]
    events = [{"id": "festival_influence", "name": "Festival Influence", "summary": "The crowd's mood turns on the party.", "kind": "text", "at": 20, "every": 1, "pick": "random",
               "table": [
                   {"id": "join_the_dance", "name": "Join the dance", "summary": "Another Herald dances in from the crowd if fewer than three remain.", "kind": "summon", "affects": "enemies", "monster": "dancing_herald",
                    "count": 1, "side": "enemies", "cells": [[9, 20], [21, 20]], "say": "fd_join_dance"},
                   {"id": "ribbon_bind", "name": "Ribbon bind", "summary": "Ribbons snap round the party's feet.", "kind": "save", "affects": "party", "save": {"ability": "str", "dc": 15},
                    "condition": "restrained", "until": "target_turn_end", "area": {"rect": [1, 1, 28, 34]}, "say": "fd_ribbon_bind"},
                   {"id": "snack_pelting", "name": "Snack pelting", "summary": "Hand pies and sticky buns rain on the heroes.", "kind": "save", "affects": "party", "save": {"ability": "dex", "dc": 13},
                    "damage": {"dice": "1d4", "type": "bludgeoning"}, "half": True, "area": {"rect": [1, 1, 28, 34]}, "say": "fd_snack_pelting"}]}]
    loc["encounters"] = []
    for (lo, hi, n) in bands:
        when = f"flag.revelers_freed >= {lo} and flag.revelers_freed <= {hi}"
        loc["encounters"].append({"id": "ring_of_fools", "trigger": "dialogue", "flag": "ring_of_fools_done", "when": when, "quest": {"id": "fools_day", "stage": "shows_over"},
                                  "monsters": [boss] + heralds + dancers[:n], "round_events": copy.deepcopy(events)})
    write("data/locations/fd_ring_of_fools.json", loc)
    return loc


# ---- the people -------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude, extra
    ("chuckles", "Chuckles", "The Lord of Fools", "A squeaking clown puppet on a ball of ribbons, who talks in doubled baby-talk and wants, more than anything, to be hated enough to be killed.", "friendly", {}),
    ("man_in_marble", "The Man in Marble", "A stone knight", "A knight in white marble twice a man's height with a sneer cut into his face; he speaks into minds and guards a church he cannot leave.", "indifferent", {}),
    ("bess_crumley", "Bess Crumley", "An inn hand", "A cheerful, overworked hand at the Green Queen Inn who knows everyone's order and none of their secrets.", "friendly", {"region": REGION}),
    ("fd_understudy", "Barnaby Tuppence", "A second jester", "A travelling jester who is entirely certain that he, and not the balloon, is the Lord of Fools.", "friendly", {}),
] + [(hid, nm, "A festival booth worker", desc, "indifferent", {"monster": mon}) for hid, ((nm, desc), mon) in
     ((h, (HOST_NAMES[h], next(v[2] for v in BOOTHS.values() if v[1] == h))) for h in HOST_NAMES)]


def build_people():
    for (nid, name, title, summary, att, extra) in PEOPLE:
        d = {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION}
        d.update(extra)
        write(f"data/npcs/{nid}.json", d)


# ---- quests -----------------------------------------------------------------------------------------------------------------------
def stage(sid, journal, hint=None, objectives=None, ends=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    return d


def quest(qid, name, kind, giver, summary, stages):
    write(f"data/quests/{qid}.json", {"id": qid, "name": name, "kind": kind, "region": REGION, "giver": giver, "summary": summary, "stages": stages})


def build_quests():
    quest("fools_day", "Fool's Day", "main", "bess_crumley",
          "A dying bell-jingler hands us a rhyming letter: the Lord of Fools has taken Wickermoor, and every friend we have is dancing in his costumes.", [
        stage("invitation", "A reveler in a coat of bells fell dead at our feet with a wax-sealed letter in rhyme. Under the costume was Bess Crumley, from the Green Queen. The letter says all our friends will be at a party.",
              "Go back into Wickermoor, where the music is coming from.", ["Reach the festival"]),
        stage("absurd_streets", "The village has swollen to three times its size, and a crowd of costumed dancers is shoving us toward the middle of it.",
              "Follow the crowd to the Festival Square, or fight your way out of it.", ["Reach Festival Square"]),
        stage("welcome", "In the square a puppet jester fell out of the sky into a net and explained the rules: win tickets at the booths, spend them on our friends, or find them ourselves.",
              "Find the costumed friends and free them: tickets, a fight, a spell, or a quiet church.", ["Free the twelve forced revelers"]),
        stage("revelry", "Twelve of our friends are forced revelers in the old troupe's costumes. Every one we free makes the next dearer at the Prize Counter.",
              "Free the rest of the revelers, or tell Chuckles to his face how much you hate him.", ["Free the revelers (see the counter)"]),
        stage("parade", "The parade has begun. Two masked Heralds lead it, and anyone we have not freed is dancing in it.",
              "Face the Heralds in the Festival Square.", ["Beat the two Heralds"]),
        stage("heralds_unmasked", "The Heralds' masks cracked. Under them were Phillip and Adela Druskenvald, smiling through paint like blood. Chuckles turned them to streamers.",
              "Go to the Ring of Fools.", ["Reach the Ring of Fools"]),
        stage("ring_of_fools", "In the Ring of Fools the jester was only a picture. The real Lord of Fools is the balloon on the pole.",
              "End the Lord of Fools.", ["Defeat Chuckles"]),
        stage("shows_over", "Chuckles went up in a firework of his own grinning face. The town shrank back to its size and the rescued gathered to piece together what they had been.",
              None, None, "success"),
    ])
    quest("twelve_costumes", "Twelve Costumes", "side", "ambrose_quill",
          "Ambrose Quill has found the old troupe's program, scrambled, and wants every costume matched to its player before the parade turns it into a souvenir.", [
        stage("asked", "Quill, in the festival, has a torn program of Chuckles's old troupe with its six players and costumes crossed out and mixed. He swears the right matching is a verse waiting to happen.",
              "Match the six players to their costumes: look around the booths, or ask the crowd.", ["Match all six troupe members"]),
        stage("matched", "The program is right at last, and Quill has a rhyme about every one.", "Bring Quill the result.", ["Report to Quill"]),
        stage("done", "Quill read out his verses. Only two of them scanned, and one of those by accident.", ends="success"),
        stage("lost", "The parade began and Quill's program went into the bonfire with the rest of the paper. He wrote the rhyme anyway.", ends="failure"),
    ])
    quest("the_silent_church", "The Silent Church", "side", "man_in_marble",
          "The Man in Marble will shelter anyone brought to him, and asked us to bring some before the parade.", [
        stage("asked", "The Man in Marble can shelter villagers from the festival's compulsion, but only those brought through his door, and he cannot leave the church to fetch them.",
              "Bring at least three freed or compelled villagers to the Silent Church.", ["Bring three villagers to the church"]),
        stage("sheltered", "Three villagers sit in the pews, quiet, while the carnival rages outside. The parade will press on the door.", "Be at the church door when the parade begins.", ["Hold the church door"]),
        stage("done", "The door held. The Man in Marble watched the crowd break on it and said nothing, which from him was thanks.", ends="success"),
        stage("barred", "We let the Man in Marble bar the door. Those we had not brought in are with the parade now.", ends="failure"),
    ])
    quest("chuckles_understudy", "Chuckles's Understudy", "side", "fd_understudy",
          "A travelling jester is entirely sure he is the real Lord of Fools and has asked for a duel of jokes.", [
        stage("asked", "Barnaby Tuppence, in a hat of belled points, is certain he is the Lord of Fools and that the balloon is his understudy. He wants a witness to the contest.",
              "Humour him, expose him, or find out who he really is.", ["Settle Barnaby's claim"]),
        stage("done", "Barnaby's claim is settled, one way or another. The crowd laughed in the right places for once.", ends="success"),
        stage("slighted", "We told Barnaby what he is. He took it badly and walked into the parade as a heckler.", ends="failure"),
    ])
    quest("the_storks_letter", "The Stork's Letter", "side", "bess_crumley",
          "Bess Crumley had a second letter in her pocket, a private one, for the groundskeeper in the stork costume.", [
        stage("asked", "In Bess's pocket was a second letter, in her own round hand, addressed to Old Rusty at the Founder's Round. She had meant to deliver it herself.",
              "Put Bess's letter in Old Rusty's hands.", ["Deliver Bess's letter to Old Rusty"]),
        stage("done", "Old Rusty has Bess's letter.", ends="success"),
        stage("unsent", "The festival ended with the letter still in our pocket. It was a short letter.", ends="failure"),
    ])
    quest("free_the_bell", "Free the Bell", "side", "doris_squire",
          "Doris Squire and Weston Murdoch, in the Bell costume, sing half a tune they cannot finish.", [
        stage("asked", "The two bell revelers hum the same unfinished tune, and each time they reach the last bar the bells stop. Someone put a song in their heads and took the end out.",
              "Find the rest of the tune: hymnals, a good ear, or Jericho's banjo.", ["Finish the Bell's tune"]),
        stage("done", "We finished the tune. The bells rang true for a moment, and it was enough to loosen a charm.", ends="success"),
        stage("silenced", "We could not finish it, and the song went on without an ending.", ends="failure"),
    ])


# ---- flags ------------------------------------------------------------------------------------------------------------------------
def flags():
    out = [
        ("fools_letter_given", "bool", "The dying bell reveler has handed over Chuckles's letter."),
        ("bess_dead", "bool", "Bess Crumley is dead in a coat of bells."),
        ("festival_active", "bool", "The Festival of Fools has taken over Wickermoor."), ("fd_away", "int", "1 while the party has fled the festival and the hub is ordinary for now, 0 when they step back in."),
        ("absurd_streets_seen", "bool", "The party has been herded out of the Absurd Streets."), ("fd_brawl_done", "bool", "The follow-the-crowd brawl is over."),
        ("fd_resisted", "bool", "The party resisted the crowd."),
        ("fd_welcomed", "bool", "Chuckles has welcomed the party and laid out the game."), ("parade_offer_taken", "bool", "The party said yes to Chuckles's offer to skip to the parade."),
        ("parade_begun", "bool", "The Parade of Fools has begun."), ("parade_heralds_done", "bool", "The two Heralds are beaten."),
        ("druskenvalds_unmasked", "bool", "Phillip and Adela's masks cracked."), ("ring_started", "bool", "The Ring of Fools fight has begun."),
        ("ring_of_fools_done", "bool", "The Lord of Fools is dead."), ("chuckles_dead", "bool", "Chuckles is dead; the Magician card pays out."),
        ("marotte_found", "bool", "The Marotte of the Lord of Fools was taken from the dead marionette."), ("shows_over", "bool", "The festival is over, the town shrunk back."),
        ("fool_tickets", "int", "Carnival tickets the party holds."), ("revelers_bought", "int", "Release slips bought at the Prize Counter; each makes the next dearer."),
        ("release_slips", "int", "Release slips in hand, each good for one reveler."), ("revelers_freed", "int", "Forced revelers freed, 0 to 12."),
        ("church_guests", "int", "Revelers or villagers brought to the Silent Church."),
        ("told_chuckles_hate", "bool", "The party told Chuckles to his face that they hate him; the parade begins now."), ("refused_to_hate", "bool", "The party pitied Chuckles aloud and would not hate him."),
        ("left_festival", "bool", "The party escaped the festival by the roads out."), ("roads_failures", "int", "Failed attempts on the roads out."),
        ("fd_church_found", "bool", "The first road out landed the party at the Silent Church."),
        ("man_in_marble_met", "bool", "The Man in Marble has asked who the party is."), ("church_rest_taken", "bool", "The party rested in the Silent Church."),
        ("church_quest_asked", "bool", "The Man in Marble asked for villagers."), ("church_door_done", "bool", "The church door's moment has passed."),
        ("apocalypse_calliope", "bool", "The party pressed the calliope's moon button (Apocalypse)."), ("liberation_wild_joker", "bool", "The party's shadow took the joker card (Liberation)."),
        ("ascendancy_fool_reborn", "bool", "The party's spectral fool took the marionette (Ascendancy)."),
        ("fd_searched", "int", "How many hours the party has searched the crowd."),
        ("fd_chuckles_amused", "bool", "A failed attempt at the revelers made Chuckles laugh."),
        ("bell_tune_known", "bool", "The party knows how the Bell's tune ends."), ("bell_tune_banjo", "bool", "The Bell's tune was finished on Jericho's banjo."),
        ("understudy_outcome", "string", "How Barnaby Tuppence's claim ended."), ("stork_letter_outcome", "string", "How Bess's letter reached Old Rusty."),
        ("quill_costume_matches", "int", "Troupe members Quill's program has right."), ("twelve_costumes_done", "bool", "Quill's program is matched."),
        ("fd_darts_hits", "int", "Darts that landed this round."), ("fd_beats_ok", "int", "Drum beats answered."), ("fd_beats_bad", "int", "Drum beats missed."),
        ("fd_drinks", "int", "Cups drunk at the Wretched Drink booth."), ("fd_riddle_bet", "int", "Which riddle bet is on the table."),
        ("fd_bess_letter_taken", "bool", "The party took Bess's second letter from her pocket."),
        ("fd_unmasked_told", "bool", "The unmasking has been narrated."), ("phillip_adela_taken", "bool", "Chuckles turned Phillip and Adela to streamers."),
        ("twelve_costumes_asked", "bool", "Quill has told the party about the torn program."), ("free_bell_asked", "bool", "The Bell's unfinished tune was asked about."),
        ("bell_tune_lost", "bool", "The party gave up on the Bell's tune."), ("fd_ring_phase2", "bool", "The balloon tore the maypole out (the Lord of Fools' second phase)."),
        ("keg_dead_note", "bool", "Reserved: a reveler the Powder Keg killed is replaced by the next candidate (set by the hysteria chapter)."),
    ]
    for key in BOOTHS:
        out += [(f"booth_{key}_plays", "int", f"Times booth {key.upper()} was played; allowed while this is no more than the revelers freed (one play per wave)."), (f"booth_{key}_beaten", "bool", f"Booth {key.upper()}'s worker was beaten.")]
    for costume in COSTUMES:
        out.append((f"found_{costume}", "bool", f"The party has found the {costume} costume's players."))
    for nid, (name, costume, cell, _) in REVELERS.items():
        out += [(f"reveler_{nid}", "string", f"How {name} was freed (tickets, beaten, uncharmed, church, finale)."), (f"reveler_{nid}_freed", "bool", f"{name} is free of the costume."),
                (f"reveler_{nid}_beaten", "bool", f"{name} was knocked out of the costume.")]
    for prize in ("crow", "sword", "shoes", "doll", "glue", "shovel", "card", "potion", "bag", "suit", "paranormal", "curio", "scroll"):
        out.append((f"prize_{prize}_taken", "bool", f"The {prize} prize was taken from the counter (one of each)."))
    for ev in ("fd_fallen_harvest", "fd_fallen_vessla"):
        out.append((ev, "bool", f"Puppet theatre: the show of {ev[10:]} has been seen."))
    return out


def build_flags():
    # golub_dead belongs to the Roving Rookery lane (data/flags/rookery.json there). Until that lane is merged it is registered here so this branch validates on its
    # own; when both are merged, delete data/flags/fools_day_borrowed.json (a flag is registered once).
    write("data/flags/fools_day_borrowed.json", {"flags": [{"id": "golub_dead", "type": "bool", "summary": "Golub Graygullet is dead (set by the Roving Rookery chapter); Chuckles's letter waits on it.", "set_by": "engine"}]})
    write("data/flags/fools_day.json", {"flags": [{"id": i, "type": t, "summary": s, "read_later": True} for (i, t, s) in flags()]})


# ---- items and monsters -----------------------------------------------------------------------------------------------------------
TRINKETS = [("plush_angry_crow", "A plush angry crow", "Stuffed, stitched and furious."),
            ("bloody_toy_sword", "A bloody-painted wooden sword", "The paint is red, the grain is not."),
            ("crocodile_shoes", "Crocodile-skin shoes", "Two sizes too large and pinching anyway."),
            ("lace_porcelain_doll", "A porcelain doll in black lace", "Its eyes are painted open, and its mouth is painted shut."),
            ("jar_of_clown_glue", "A jar of glue", "Dries in ten minutes. Strength DC 10 breaks it."),
            ("child_shovel_pail", "A child's shovel and pail", "Brand new, and sized for someone who will not be back for it.")]
MAGIC = {
    "revelry_suit": ("The Revelry Suit", "wondrous", "rare", "robe", [{"stat": "ac", "value": 2}],
                     "A suit of motley hide in the troupe's colours: +2 to Armor Class. Dancing Dodge (once a dusk, a failed Dex save becomes a success), Wild Steps (move as a bonus action without opportunity attacks) and the Dancing Curse (a Wisdom save at the start of a fight or lose the first turn to a folk dance) wait on the engine's heirloom hooks."),
    "marotte_of_the_lord_of_fools": ("The Marotte of the Lord of Fools", "rod", "very_rare", None, [{"stat": "spell_attack", "value": "tier"}, {"stat": "spell_dc", "value": "tier"}],
                     "A jester's rod from the dead marionette's hands, a spellcasting focus that adds its tier to spell attacks and spell save DCs. Its Coulrophobia, Fortune's Fool and Fool's Motley powers wait on the engine's heirloom hooks."),
    "deck_of_illusions_card": ("A card from a Deck of Illusions", "wondrous", "uncommon", None, [], "A single painted card, one of a deck of illusions; turning it over wears an illusion of the picture. The rest of the deck is not for sale."),
    "rust_bag_of_tricks": ("The Rust Bag of Tricks", "wondrous", "uncommon", None, [], "A rust-coloured bag that, shaken, only ever produces goats. Chuckles finds this very funny."),
    "scroll_of_resurrection": ("Spell Scroll of Resurrection", "wondrous", "rare", None, [], "A spell scroll of Resurrection, rolled tight and tied with a ribbon. One of a kind at the counter."),
    "cursed_curio_prize": ("A cursed curio", "wondrous", "uncommon", None, [], "A small, ugly keepsake from the Prize Counter. It is cursed, and Chuckles will not say how."),
    "wild_joker_card": ("The Wild Joker", "wondrous", "legendary", None, [], "A gleaming joker priced at infinity tickets, boasting of luck and demanding a wager of a realm of death."),
}


def build_items():
    for (iid, name, summary) in TRINKETS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": "treasure", "weight_lb": 1, "cost_gp": 0, "summary": summary})
    write("data/items/chuckles_letter.json", {"id": "chuckles_letter", "name": "Chuckles's letter", "source": {"book": "CrookedMoon"}, "category": "quest", "weight_lb": 0, "cost_gp": 0,
                                                "summary": "A wax-sealed invitation in rhyme, from Chuckles the Clown, to a party where all our friends will be."})
    write("data/items/bess_second_letter.json", {"id": "bess_second_letter", "name": "Bess's letter", "source": {"book": "CrookedMoon"}, "category": "quest", "weight_lb": 0, "cost_gp": 0,
                                                   "summary": "A short letter in a round hand, for the groundskeeper of the Founder's Round."})
    for iid, (name, cat, rarity, worn, mods, summary) in MAGIC.items():
        d = {"id": iid, "name": name, "source": {"book": "CrookedMoon", "note": "Fool's Day prize or heirloom; the book's numbers, our words."}, "category": cat, "weight_lb": 2, "cost_gp": 0,
             "magic": {"rarity": rarity, "attunement": iid in ("revelry_suit", "marotte_of_the_lord_of_fools")}, "theme": "implements",
             "modifiers": mods, "summary": summary}
        if worn:
            d["worn"] = worn
        if cat == "rod":
            d["category"] = "wondrous"
            d["held"] = True
            d["focus"] = "arcane"
        write(f"data/magic_items/{iid}.json", d)


def build_monsters():
    base = read("data/monsters/herald_of_fools.json")
    m = copy.deepcopy(base)
    m.update({"id": "dancing_herald", "name": "Dancing Herald", "hp": {"average": 30, "dice": "4d8+12"}, "cr": 2, "xp": 450,
              "summary": "One of Chuckles's dancing Heralds in the finale: a Herald of Fools with 30 Hit Points and no Multiattack."})
    m.pop("multiattack", None)
    write("data/monsters/dancing_herald.json", m)
    lord = read("data/monsters/lord_of_fools.json")
    lord["phases"] = [{"id": "carnival_of_chaos", "name": "Carnival of Chaos", "when": {"bloodied": True},
                       "summary": "The balloon swells, rips the maypole out of the ground and floats free; Chuckles speaks in his own voice, and bounds a full Speed at the start of each of his turns.",
                       "say": "fd_phase_two", "flag": "fd_ring_phase2", "cutscene": "fd_balloon_rises"}]
    write("data/monsters/lord_of_fools.json", lord)


# ---- the hub ----------------------------------------------------------------------------------------------------------------------
HUB_MINE = ("fools_day/hook:takeover", "fools_day/hook:return_gate", "fools_day/hook:messenger")


def build_hub():
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    town["props"] = [p for p in town["props"] if str(p.get("call", "")) not in HUB_MINE and not str(p.get("id")).startswith(("wm_fd_takeover", "wm_fd_return"))]
    town["npcs"] = [n for n in town["npcs"] if str(n.get("dialogue", "")) not in HUB_MINE]
    spots = [("a", (7, 21)), ("b", (30, 3)), ("c", (30, 44)), ("d", (14, 12)), ("e", (46, 22)), ("f", (22, 36))]
    town["props"][0:0] = [prop("wm_fd_takeover_" + k, c, "The village, swelling", kind="decor", call=FD + "hook:takeover", approach=12,
                               call_when="flag.festival_active and not flag.shows_over and not flag.fd_away") for k, c in spots] + [
        prop("wm_fd_return", (31, 26), "Carnival music, just past the last house", kind="decor", call=FD + "hook:return_gate", approach=4,
             call_when="flag.festival_active and not flag.shows_over and flag.fd_away")]
    town["npcs"][0:0] = [npc("bess_crumley", (31, 14), "hook:messenger", when="flag.golub_dead and not flag.fools_letter_given", approach=12)]
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")
    # Bess works the Green Queen until the letter comes
    ipath = ROOT / "data/locations/wickermoor_green_queen_inn.json"
    if not kept("data/locations/wickermoor_green_queen_inn.json"):   # (the inn is one place with its floors now: its squares moved)
        inn = json.loads(ipath.read_text())
        inn["npcs"] = [n for n in inn["npcs"] if str(n.get("dialogue", "")) != FD + "hook:inn_chat"]
        inn["npcs"].append(npc("bess_crumley", (12, 12), "hook:inn_chat", when="not flag.golub_dead"))
        ipath.write_text(json.dumps(inn, indent=2, ensure_ascii=False) + "\n")


# ---- cutscenes --------------------------------------------------------------------------------------------------------------------
PICTURES = {
    "fd_messenger": "A figure in a costume covered with tiny bells stumbling along a road at night toward a campfire, ribbons trailing behind in the dark",
    "fd_messenger_2": "A wax-sealed letter lying on dark grass beside a still hand in a jingling glove, popcorn and confetti scattered around it",
    "fd_unfolds": "A wide shot of a small village swollen to twice its size, every roof strung with green, red and gold ribbon, bonfires in the lanes, an orange moon behind",
    "fd_unfolds_2": "A square town green turned square, a tall maypole at its centre topped by a leering clown balloon, a small wooden jester backflipping on its peak",
    "fd_dream": "A manor on a hill in impossible daylight under a sun with a painted clown's face, the sky a bright wrong blue",
    "fd_dream_2": "The clown sun laughing until blood runs from its nose, then falling in a wall of fire onto a quiet valley",
    "fd_unmasking": "Two porcelain harlequin masks cracking down the middle in a crowd of costumed dancers, confetti in the air",
    "fd_unmasking_2": "A thin lord and a young woman smiling through paint like blood, their harlequin masks in pieces at their feet",
    "fd_unmasking_3": "Two figures bursting into long streamers that scatter on the wind over a festival square",
    "fd_balloon_rises": "A maypole tearing out of packed earth as a vast clown balloon lifts, ribbons whipping, the crowd below staring up",
    "fd_balloon_rises_2": "A painted balloon mouth opening and moving as if to speak, lit gold by bonfires",
    "fd_shows_over": "A small wooden jester marionette with its head popped off lying on packed earth, a rod in its wooden hands",
    "fd_shows_over_2": "A clown balloon shrinking into the night sky and bursting into a firework in the shape of a leering face",
    "fd_shows_over_3": "Morning on empty streets of ordinary size, confetti in the gutters, villagers waving at an empty road as if a troupe were leaving",
}


def build_cutscenes():
    write("tools/content/fools_day_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("fd_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


if __name__ == "__main__":
    build_festival()
    build_church()
    build_ring()
    build_people()
    build_quests()
    build_flags()
    build_items()
    build_monsters()
    build_cutscenes()
    build_hub()
    print("ok")
