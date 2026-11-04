#!/usr/bin/env python3
"""Lays the fun pass's finds (data/treasure/fun_finds.json) into their places in data/locations: containers where they would
really stand, hidden things a Search turns up, and traps (Ashwin, 2026-11-03, fun pass fix 3: exploring pays).

Each place lists `containers`, `finds` (search props) and `traps`. A thing without a `cell` gets one the first time, and the cell
is written back into fun_finds.json so later runs (after a chapter's build script rewrote its places) put it in the same spot:

- a container or find: plain floor ('.' or '_') against a wall, inside its `area` if it names one (an area id, or several), as
  close as it can be to the prop, container or NPC named by `near`, else in a corner as far from the spawn as the area allows;
- a trap: a walkable square in a quiet corner (`area`/`near` as above), or, for a container with a `trap`, every open square
  round that container, so reaching it springs the trap unless a Search found it first.

Nothing goes on or beside the squares the party walks between the place's spawns, exits, stairs, people and props (every
shortest route between any two of them), nor next to a door, exit, spawn, person, prop or light, so the story bots, which are
path-sensitive, never meet a new trap and no walkable square, spawn or exit moves. A container or find stands on a floor square
without filling it. Places can also be given a `treasure_level` (Treasure.level_for). Safe to run again; `--check` says whether
the places are current.

    python3 tools/content/place_fun_finds.py [--check] [PLACE ...]"""
import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FINDS = ROOT / "data" / "treasure" / "fun_finds.json"
LOCS = ROOT / "data" / "locations"
WALK = set(".~_1234=")
FLOOR = set("._")
DIRS8 = [(dx, dz) for dx in (-1, 0, 1) for dz in (-1, 0, 1) if (dx, dz) != (0, 0)]
FACES = [(1, 0), (-1, 0), (0, 1), (0, -1)]
FAILED = []   # things no cell could be found for: reported, and left out of the place
# What the tool writes for each kind of thing, beyond the fields the config copies over as they are.
CONTAINER_KEYS = ("label", "model", "lock_dc", "gold", "items", "owner", "no_random_loot", "when", "flag", "text")
FIND_KEYS = ("label", "model", "search_dc", "skill", "item", "text", "clue", "when", "flag", "say")
TRAP_KEYS = ("label", "model", "detect_dc", "disarm_dc", "save", "damage", "damage_type", "condition", "text", "when", "flag")


def at(rows, x, z):
    if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
        return " "
    return rows[z][x]


def cell_of(v):
    if isinstance(v, list) and len(v) >= 2 and isinstance(v[0], int):
        return (int(v[0]), int(v[1]))
    return None


class Place:
    def __init__(self, loc, managed):
        self.loc = loc
        self.rows = loc["map"]["rows"]
        self.managed = managed   # ids this tool writes: they don't count as what was already there
        self.links = {}
        for s in loc["map"].get("stairs", []) or []:
            a, b = cell_of(s.get("from")), cell_of(s.get("to"))
            if a and b:
                self.links.setdefault(a, []).append(b)
                self.links.setdefault(b, []).append(a)
        self.dressing = set()   # set dressing and lights: kept clear of, but nobody walks to them
        self.points = self._points()
        self.taken = set(self.points) | self.dressing
        self.reach = self._reachable()
        self._route = None

    def walkable(self, c):
        return at(self.rows, *c) in WALK

    def _points(self):
        pts = set()
        loc = self.loc
        for key in ("props", "containers", "npcs", "lights", "doors", "exits", "traps", "foe_spots"):
            for t in loc.get(key, []) or []:
                if str(t.get("id", "")) in self.managed:
                    continue
                if key == "lights" or (key == "props" and t.get("kind") == "decor"):
                    self.dressing.add(cell_of(t.get("cell")))
                    continue
                c = cell_of(t.get("cell"))
                if c:
                    pts.add(c)
                for cc in t.get("cells", []) or []:
                    c = cell_of(cc)
                    if c:
                        pts.add(c)
        for v in (loc.get("spawns") or {}).values():
            c = cell_of(v)
            if c:
                pts.add(c)
        for a in self.links:
            pts.add(a)
        for e in loc.get("encounters", []) or []:
            for m in e.get("monsters", []) or []:
                c = cell_of(m.get("cell"))
                if c:
                    pts.add(c)
        return pts

    def _bfs(self, start):
        dist = {start: 0}
        q = deque([start])
        while q:
            c = q.popleft()
            nxt = [(c[0] + dx, c[1] + dz) for dx, dz in DIRS8] + self.links.get(c, [])
            for n in nxt:
                if n not in dist and self.walkable(n):
                    dist[n] = dist[c] + 1
                    q.append(n)
        return dist

    def _reachable(self):
        seen = set()
        for v in (self.loc.get("spawns") or {}).values():
            c = cell_of(v)
            if c and c not in seen:
                seen |= set(self._bfs(c))
        return seen

    def route(self):
        """Every square on some shortest walk between two of the place's points, and the squares beside them."""
        if self._route is None:
            pts = [p for p in self.points if p in self.reach]
            dists = {p: self._bfs(p) for p in pts}
            on = set()
            for i, a in enumerate(pts):
                da = dists[a]
                for b in pts[i + 1:]:
                    if b not in da:
                        continue
                    db = dists[b]
                    total = da[b]
                    for c, d in da.items():
                        if d <= total and db.get(c, 1 << 30) + d == total:
                            on.add(c)
            wide = set()
            for (x, z) in on:
                for dx in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        wide.add((x + dx, z + dz))
            self._route = wide
        return self._route

    def near_taken(self, c, r=1):
        return any((c[0] + dx, c[1] + dz) in self.taken for dx in range(-r, r + 1) for dz in range(-r, r + 1))

    def in_area(self, c, areas):
        if not areas:
            return True
        for a in self.loc.get("areas", []) or []:
            if a["id"] not in areas:
                continue
            cells = a.get("cells", [])
            if len(cells) == 2 and all(isinstance(v, list) for v in cells):
                (x0, z0), (x1, z1) = cells
                if min(x0, x1) <= c[0] <= max(x0, x1) and min(z0, z1) <= c[1] <= max(z0, z1):
                    return True
            elif [c[0], c[1]] in cells:
                return True
        return False

    def anchor(self, ref):
        for key in ("props", "containers", "npcs", "traps"):
            for t in self.loc.get(key, []) or []:
                if str(t.get("id", t.get("npc", ""))) == ref or str(t.get("npc", "")) == ref:
                    c = cell_of(t.get("cell"))
                    if c:
                        return c
        return None

    def walls(self, c):
        return sum(1 for dx, dz in FACES if at(self.rows, c[0] + dx, c[1] + dz) == "#")

    def pick(self, spec, trap=False, ring=False):
        areas = spec.get("area")
        areas = [areas] if isinstance(areas, str) else (areas or [])
        near = self.anchor(spec["near"]) if spec.get("near") else None
        if spec.get("near") and near is None:
            raise SystemExit("%s: %s is near %s, which isn't in the place" % (self.loc["id"], spec["id"], spec["near"]))
        start = cell_of((self.loc.get("spawns") or {}).get("default")) or next(iter(self.reach), (0, 0))
        dist = self._bfs(start)
        route = self.route() if ring else set()
        best = None
        for c in self.reach:
            if not self.in_area(c, areas) or self.near_taken(c, 1):
                continue
            if trap and not ring:
                if not self.walkable(c) or at(self.rows, *c) == "=" or not self.aside(c) or self.near_points(c, 2):
                    continue
            elif at(self.rows, *c) not in FLOOR or self.walls(c) == 0:
                continue
            if ring:
                if any(n in route or (n in self.taken) for n in self.ring_of(c)) or not self.ring_of(c) or self.near_points(c, 2):
                    continue
            closeness = -max(abs(c[0] - near[0]), abs(c[1] - near[1])) if near else 0
            key = (closeness, min(self.walls(c), 2), dist.get(c, 0), -c[1], -c[0])
            if best is None or key > best[0]:
                best = (key, c)
        if best is None:
            FAILED.append("%s: no quiet floor for %s" % (self.loc["id"], spec["id"]))
            return None
        return best[1]

    def aside(self, c):
        """Whether `c` is off every shortest walk: its walkable neighbours all touch each other, so a walk through it is
        always one step longer than a walk round it (a room's corner, the end of a nook)."""
        ns = [(c[0] + dx, c[1] + dz) for dx, dz in DIRS8 if self.walkable((c[0] + dx, c[1] + dz))] + self.links.get(c, [])
        if c in self.links:
            return False
        for i, a in enumerate(ns):
            for b in ns[i + 1:]:
                if max(abs(a[0] - b[0]), abs(a[1] - b[1])) > 1:
                    return False
        return True

    def near_points(self, c, r):
        return any(max(abs(c[0] - p[0]), abs(c[1] - p[1])) <= r for p in self.points)

    def ring_of(self, c):
        """The open squares round a container at `c`: where whoever opens it stands."""
        out = []
        for dx, dz in DIRS8:
            n = (c[0] + dx, c[1] + dz)
            if n in self.reach and at(self.rows, *n) in FLOOR:
                out.append(n)
        return out

    def claim(self, c):
        self.taken.add(c)


def upsert(entries, eid, values):
    e = next((t for t in entries if str(t.get("id")) == eid), None)
    if e is None:
        e = {"id": eid}
        entries.append(e)
    e.update(values)
    return e


def copy(spec, keys):
    return {k: spec[k] for k in keys if k in spec}


def lay(loc_id, cfg):
    path = LOCS / ("%s.json" % loc_id)
    before = path.read_text()
    loc = json.loads(before)
    managed = set()
    for c in cfg.get("containers", []):
        managed.add(c["id"])
        if "trap" in c:
            managed.add(c["id"] + "_trap")
    for key in ("finds", "traps"):
        for t in cfg.get(key, []):
            managed.add(t["id"])
    place = Place(loc, managed)
    changed = False
    if "treasure_level" in cfg:
        loc["treasure_level"] = int(cfg["treasure_level"])
    conts = loc.setdefault("containers", [])
    props = loc.setdefault("props", [])
    traps = loc.setdefault("traps", [])
    # Things with cells first, so new ones keep clear of them.
    for spec in cfg.get("containers", []) + cfg.get("finds", []) + cfg.get("traps", []):
        if "cell" in spec:
            place.claim(tuple(spec["cell"]))
            for n in spec.get("trap_cells", []):
                place.claim(tuple(n))
    for spec in cfg.get("containers", []):
        if "cell" not in spec:
            c = place.pick(spec, ring="trap" in spec)
            if c is None:
                continue
            spec["cell"] = list(c)
            changed = True
            place.claim(c)
        values = copy(spec, CONTAINER_KEYS)
        values["cell"] = spec["cell"]
        values.setdefault("gold", 0)
        values.setdefault("lock_dc", 0)
        values["items"] = [i if isinstance(i, dict) else {"id": i, "qty": 1} for i in spec.get("items", [])]
        upsert(conts, spec["id"], values)
        if "trap" in spec:
            if "trap_cells" not in spec:
                spec["trap_cells"] = [list(n) for n in place.ring_of(tuple(spec["cell"]))]
                changed = True
            for n in spec["trap_cells"]:
                place.claim(tuple(n))
            t = dict(spec["trap"])
            tv = copy(t, TRAP_KEYS)
            tv["cells"] = spec["trap_cells"]
            upsert(traps, spec["id"] + "_trap", tv)
    for spec in cfg.get("finds", []):
        if "cell" not in spec:
            c = place.pick(spec)
            if c is None:
                continue
            spec["cell"] = list(c)
            changed = True
            place.claim(c)
        values = copy(spec, FIND_KEYS)
        values["kind"] = "search"
        values["cell"] = spec["cell"]
        upsert(props, spec["id"], values)
    for spec in cfg.get("traps", []):
        if "cell" not in spec:
            c = place.pick(spec, trap=True)
            if c is None:
                continue
            spec["cell"] = list(c)
            changed = True
            place.claim(c)
        values = copy(spec, TRAP_KEYS)
        values["cells"] = [spec["cell"]]
        upsert(traps, spec["id"], values)
    for key in ("containers", "traps"):
        if not loc[key]:
            del loc[key]
    after = json.dumps(loc, indent=2, ensure_ascii=False) + "\n"
    return path, before, after, changed


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    cfg = json.loads(FINDS.read_text())
    places = cfg["places"]
    stale = []
    cfg_changed = False
    counts = [0, 0, 0]
    for loc_id, spec in places.items():
        if loc_id.startswith("_") or (args and loc_id not in args):
            continue
        counts[0] += len(spec.get("containers", []))
        counts[1] += len(spec.get("finds", []))
        counts[2] += len(spec.get("traps", [])) + sum(1 for c in spec.get("containers", []) if "trap" in c)
        path, before, after, changed = lay(loc_id, spec)
        cfg_changed = cfg_changed or changed
        if after != before:
            stale.append(loc_id)
            if not check:
                path.write_text(after)
    for f in FAILED:
        print(f)
    if cfg_changed and not check:
        FINDS.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
    print("%d containers, %d hidden finds, %d traps in %d places%s" % (counts[0], counts[1], counts[2], len([p for p in places if not p.startswith("_")]),
        (": stale " + ", ".join(stale)) if check and stale else ""))
    if FAILED or (check and (stale or cfg_changed)):
        sys.exit(1)


if __name__ == "__main__":
    main()
