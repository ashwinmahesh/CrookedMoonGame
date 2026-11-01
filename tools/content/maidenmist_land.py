"""Painting helpers for the Maidenmist Cemetery maps (R19): a Land is a grid of map characters plus an elevation grid, painted with
rectangles, blobs and scatter, then written out as the location's `map.rows` and `map.elevation`. The same job make sketch does from a
PNG, done in code so the whole chapter regenerates from one script (the sketch tool needs a Godot run per place).
Legend (docs/contracts/locations.md): '.' floor, '#' wall/tree/fence, '=' low cover (headstones), '~' difficult ground (fog-mud), 'w' water."""
import math
import random
from collections import deque

ELEV = "0123456789abcdefghijklmnopqrstuvwxyz"


class Land:
    def __init__(self, w, h, seed, base=".", height=2):
        self.w, self.h, self.rng = w, h, random.Random(seed)
        self.c = [[base] * w for _ in range(h)]
        self.e = [[height] * w for _ in range(h)]
        self.reserved = set()

    # painting ---------------------------------------------------------------------------------------------------------------------
    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.c[y][x] = ch

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ch)
        return self

    def border(self, ch="#"):
        self.rect(0, 0, self.w - 1, 0, ch).rect(0, self.h - 1, self.w - 1, self.h - 1, ch)
        self.rect(0, 0, 0, self.h - 1, ch).rect(self.w - 1, 0, self.w - 1, self.h - 1, ch)
        return self

    def blob(self, cx, cy, rx, ry, ch, wob=0.25, only=None):
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x - cx) / max(rx, 0.1), (y - cy) / max(ry, 0.1)
                k = 1 + self.rng.uniform(-wob, wob)
                if dx * dx + dy * dy <= k * k and (only is None or self.c[y][x] in only):
                    self.c[y][x] = ch
        return self

    def hline(self, x0, x1, y, ch):
        return self.rect(min(x0, x1), y, max(x0, x1), y, ch)

    def vline(self, x, y0, y1, ch):
        return self.rect(x, min(y0, y1), x, max(y0, y1), ch)

    def scatter(self, region, ch, n, only=".", gap=1):
        """n squares of `ch` inside region (x0, y0, x1, y1), on squares that are `only`, not reserved, apart from each other by `gap`."""
        x0, y0, x1, y1 = region
        placed, tries = [], 0
        while len(placed) < n and tries < n * 40:
            tries += 1
            x, y = self.rng.randint(x0, x1), self.rng.randint(y0, y1)
            if (x, y) in self.reserved or self.c[y][x] not in only:
                continue
            if any(abs(x - px) <= gap and abs(y - py) <= gap for px, py in placed):
                continue
            self.c[y][x] = ch
            placed.append((x, y))
        return placed

    def hold(self, *cells, r=1):
        """Reserve squares (and r squares round them) from scatter, so ways in and key props stay clear."""
        for (x, y) in cells:
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if not (0 <= x + dx < self.w and 0 <= y + dy < self.h):
                        continue
                    self.reserved.add((x + dx, y + dy))
                    if self.c[y + dy][x + dx] in "=#~" and (dx, dy) == (0, 0):
                        self.c[y + dy][x + dx] = "."
        return self

    def clear(self, *cells):
        for (x, y) in cells:
            self.c[y][x] = "."
        return self

    # height -----------------------------------------------------------------------------------------------------------------------
    def hill(self, cx, cy, r, steps):
        """A smooth rise of `steps` x 5 ft with about one step in every r/steps squares of slope."""
        for y in range(self.h):
            for x in range(self.w):
                d = math.hypot(x - cx, y - cy)
                if d < r:
                    self.e[y][x] = max(self.e[y][x], int(round(self.e[y][x] + steps * (1 - d / r))))
        return self

    def hollow(self, cx, cy, r, steps):
        for y in range(self.h):
            for x in range(self.w):
                d = math.hypot(x - cx, y - cy)
                if d < r:
                    self.e[y][x] = max(0, int(round(self.e[y][x] - steps * (1 - d / r))))
        return self

    def level(self, x0, y0, x1, y1, v):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.e[y][x] = v
        return self

    def smooth(self, passes=2):
        """Keep neighbouring squares within one step (a walkable slope)."""
        for _ in range(passes * 4):
            moved = False
            for y in range(self.h):
                for x in range(self.w):
                    for dx, dy in ((1, 0), (0, 1)):
                        nx, ny = x + dx, y + dy
                        if nx < self.w and ny < self.h and abs(self.e[y][x] - self.e[ny][nx]) > 1:
                            if self.e[y][x] > self.e[ny][nx]:
                                self.e[y][x] -= 1
                            else:
                                self.e[ny][nx] -= 1
                            moved = True
            if not moved:
                break
        return self

    # output -----------------------------------------------------------------------------------------------------------------------
    def rows(self):
        return ["".join(r) for r in self.c]

    def elevation(self):
        return ["".join(ELEV[max(0, min(35, v))] for v in r) for r in self.e]

    def open_cells(self, region=None):
        x0, y0, x1, y1 = region or (0, 0, self.w - 1, self.h - 1)
        return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if self.c[y][x] in ".~"]

    def reachable(self, start):
        seen, q = {start}, deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < self.w and 0 <= ny < self.h and (nx, ny) not in seen and self.c[ny][nx] in ".~123456789":
                    seen.add((nx, ny))
                    q.append((nx, ny))
        return seen

    def is_open(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.c[y][x] in ".~123456789"
