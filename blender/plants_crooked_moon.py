"""The Crooked Moon's own plants (docs/art/plants.md, branch look-plants-v2): real 3D plants for what the 2D leaf cards could only stand in
for, built with the framework of blender/plants_3d.py (tubes for trunks and canes, bent cards for leaves, a normal, a light and a wind value
per vertex) and written to art/plants/<id>.glb and art/plants/manifest.json beside the others.

  blender -b --python blender/plants_crooked_moon.py -- [--only corn_a wytch_a ...] [--no-export]
  (a batch for the GPU scheduler: ~/.crooked-moon/blender_queue/NN_region_plants.py, tools/gpu/blender_batch.sh)

What is built, and what each region plants of it (art/plants/flora.json):
  corn_a, corn_b, corn_c   a clump of three to five corn plants: thick jointed stalks, ten long arching leaves each, ears in their husks
                           (two on some) and a tassel on top; Foxwillow's fields and maze
  wytch_a, wytch_b         a stout, hunched oak with a heavy dark crown hung with long thin hag-hair; the Wytchwood
  fungal_a, fungal_b       a rotting stump with a flared root foot, a broken jagged top and bark, layered shelf fungi up its sides;
                           Hartsblight
  briar_a                  a tangle of long curving thorny canes with branchlets and bramble leaves; the Wytchwood, the Crooked House
  cypress_a                a bald cypress: a fluted, buttressed trunk with knees round its foot, limbs hung with feathery fronds and
                           long Spanish moss; Murkwater Bend and the bayou
Each tree has a `_far` copy. The leaves are the Crooked Moon's own second atlas (art/plants/cards2.png, cards2.json, a plant's `leaf2`
material, engine Flora.CARDS2_PATH) of photoreal cut-outs (tools/art/plant_cards2.py): corn blades, ears and tassels, moss and hair strands,
cypress fronds, bramble sprigs and shelf fungi; the wytch trees' crowns still use the first atlas's oak leaves. Repainting a card repaints
every model that uses it.
"""
import json
import math
import sys
import traceback
from pathlib import Path

import bpy  # noqa: F401  (Blender's own module: this script only runs inside Blender)
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plants_3d as P  # noqa: E402

plant = P.plant
UP = Vector((0, 0, 1))

_C2 = json.loads((P.OUT_DIR / "cards2.json").read_text())
C2 = _C2["cells"]
_AW, _AH = _C2["width"], _C2["height"]


def aspect(cell):
    """A second-atlas card's painted width over its height."""
    u0, v0, u1, v1 = C2[cell]
    return ((u1 - u0) * _AW) / max((v1 - v0) * _AH, 1.0)


def card2(p, cell, grid, normal_fn, shade_fn, phase, flutter=(0.0, 1.0), along_u=True, floor=None):
    """P.Plant.card for a card of the second atlas (the `leaf2` material). `grid` is rows of points: grid[i][j] with i along the card's
    length from its root and j across; the painting's length runs along u (a blade, root at its left) or up v (root at its bottom).
    `floor`: the lowest height a point may have."""
    u0, v0, u1, v1 = C2[cell]
    n_i, n_j = len(grid), len(grid[0])
    rows = []
    for i in range(n_i):
        row = []
        for j in range(n_j):
            q = Vector(grid[i][j])
            if floor is not None and q.z < floor:
                q = Vector((q.x, q.y, floor))      # a leaf lies on the ground rather than sinking into it
            row.append((p._vert(q, normal_fn(q)), q))
        rows.append(row)
    for i in range(n_i - 1):
        for j in range(n_j - 1):
            quad = [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
            uvs, winds, shades = [], [], []
            for (ii, jj) in ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)):
                t = ii / (n_i - 1)
                s = jj / (n_j - 1)
                if along_u:
                    u = u0 + (u1 - u0) * t
                    v = v0 + (v1 - v0) * s
                else:
                    u = u0 + (u1 - u0) * s
                    v = v1 - (v1 - v0) * t
                uvs.append((u, 1.0 - v))
                winds.append((flutter[0] + (flutter[1] - flutter[0]) * t, phase))
                shades.append(shade_fn(rows[ii][jj][1]))
            p._face([q[0] for q in quad], "leaf2", uvs, winds, shades)


def perp(d, roll=0.0):
    """A unit vector at right angles to `d`, horizontal where it can be, turned `roll` about `d`."""
    d = Vector(d).normalized()
    s = d.cross(UP)
    s = s.normalized() if s.length > 1e-3 else Vector((1, 0, 0))
    return Vector(Matrix.Rotation(roll, 3, d) @ s) if roll else s


def arc(rng, start, direction, length, steps, drop=0.0, wobble=0.0):
    """A path from `start` heading `direction`, bending down as it goes (`drop`: how much of its heading it loses to gravity by its end),
    wandering a little (`wobble`)."""
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    seg = length / steps
    for _ in range(steps):
        d = (d + Vector((0, 0, -drop / steps)) +
             Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * wobble).normalized()
        pts.append(pts[-1] + d * seg)
    return pts


# --- Corn -----------------------------------------------------------------------------------------------------------

def corn_stalk(p, base, H, leaves, ears, lean, centre, far=False):
    """One corn plant at `base`: a thick, jointed stalk leaning a little (`lean`, a horizontal offset of its top), a spiral of long
    arching leaves (the lower ones longest and the most drooped), an ear or two in their husks at about the middle and a tassel on top."""
    rng = p.rng
    base = Vector(base)
    lean = Vector(lean)

    def axis(z):
        f = (z / H) ** 2
        return base + Vector((lean.x * f, lean.y * f, z))

    def wind_of(q):
        return min(1.0, max(0.0, q.z / H * 1.1))

    def shade(q):
        # Plants in the middle of a clump are shaded by the others.
        inner = min(1.0, Vector((q.x - centre.x, q.y - centre.y, 0)).length / 0.35)
        return min(1.0, (0.55 + 0.45 * inner) * (0.5 + 0.5 * min(1.0, max(0.0, q.z) / H)))

    def normal(q):
        return Vector((q.x - centre.x, q.y - centre.y, 0)) + Vector((0, 0, 0.9))

    n = 5 if far else 9
    path = [axis(H * 0.94 * i / n) for i in range(n + 1)]
    radii = []
    for i in range(n + 1):
        r = 0.036 * (1.0 - 0.5 * i / n)
        if i == 0:
            r *= 1.4      # the foot flares into its roots
        elif i % 2 == 0:
            r *= 1.16     # a joint
        radii.append(r)
    p.tube(path, radii, 5 if far else 6, "bark_pine", shade, wind_of)
    # The leaves: a spiral up the stalk, each growing out and up and arching over to hang its tip.
    count = max(5, leaves - (3 if far else 0))
    offset = rng.uniform(0, math.tau)
    steps = 3 if far else 6
    for k in range(count):
        f = (k + 0.5) / count
        z = H * (0.12 + 0.7 * f)
        az = offset + k * 2.4 + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        L = rng.uniform(0.5, 0.68) * (1.0 - 0.3 * f) * (H / 1.5)
        W = L / 6.5
        pitch = math.radians(28 + 34 * f + rng.uniform(-6, 6))
        drop = rng.uniform(1.0, 1.5) * (1.1 - 0.55 * f)
        root = axis(z) + out * 0.014
        pts = arc(rng, root, out * math.cos(pitch) + UP * math.sin(pitch), L, steps, drop=drop, wobble=0.03)
        roll = math.radians(rng.uniform(-14, 14))
        phase = rng.random()
        grid = []
        for i, c in enumerate(pts):
            t = i / steps
            tang = pts[min(i + 1, steps)] - pts[max(i - 1, 0)]
            side = perp(tang, roll=roll)
            lift = 0.16 * W if i > 0 else 0.0     # the blade is a shallow trough
            ripple = 0.14 * W * math.sin(t * 13 + phase * 6.0)
            grid.append([c - side * W * 0.5 + UP * (lift + ripple), c + UP * (ripple * 0.3),
                         c + side * W * 0.5 + UP * (lift - ripple)])
        card2(p, "corn_blade_a" if rng.random() < 0.5 else "corn_blade_b", grid, normal, shade, phase, flutter=(0.15, 1.0), floor=0.01)
    # The ears: in their husks, standing up and a little out from the stalk, two crossed cards each.
    for e in range(ears):
        az = offset + 1.1 + e * 2.9 + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        z = H * (0.5 + 0.13 * e + rng.uniform(-0.03, 0.03))
        root = axis(z) + out * 0.022
        d = (out * 0.42 + UP).normalized()
        L = 0.27 * (H / 1.5)
        W = L * aspect("corn_ear") * 1.05
        for ang in (0.0, math.pi / 2):
            side = perp(d, roll=ang)
            grid = [[root + d * L * (i / 2.0) + out * 0.05 * (i / 2.0) ** 2 + side * (j - 1) * W * 0.5 for j in range(3)]
                    for i in range(3)]
            card2(p, "corn_ear", grid, normal, shade, rng.random(), flutter=(0.0, 0.25), along_u=False)
    # The tassel: three crossed cards arching over the top.
    top = axis(H * 0.94)
    L = 0.3 * (H / 1.5)
    W = L * aspect("corn_tassel")
    arch = lean.normalized() * 0.1 if lean.length > 1e-3 else Vector((0.1, 0, 0))
    for a in (0.0, math.pi / 3, 2 * math.pi / 3):
        side = Vector((math.cos(a), math.sin(a), 0))
        grid = [[top + UP * L * (i / 2.0) + arch * (i / 2.0) ** 2 + side * (j - 1) * W * 0.5 for j in range(3)] for i in range(3)]
        card2(p, "corn_tassel", grid, normal, shade, rng.random(), flutter=(0.2, 1.0), along_u=False)


def corn_clump(p, stalks, H0, leaves=10, spread=0.26, far=False):
    """Three to five corn plants growing together, which is how the field is planted."""
    rng = p.rng
    centre = Vector((0, 0, 0))
    base_angle = rng.uniform(0, math.tau)
    for k in range(stalks):
        ang = base_angle + math.tau * k / stalks + rng.uniform(-0.4, 0.4)
        r = spread * rng.uniform(0.5, 1.0)
        base = Vector((math.cos(ang) * r, math.sin(ang) * r, 0))
        H = H0 * rng.uniform(0.86, 1.12)
        lean = Vector((math.cos(ang), math.sin(ang), 0)) * H * rng.uniform(0.04, 0.15)
        corn_stalk(p, base, H, leaves, 2 if rng.random() < 0.3 else 1, lean, centre, far)


@plant("corn_a", "bush")
def corn_a(p):
    corn_clump(p, 4, 1.55)


@plant("corn_b", "bush")
def corn_b(p):
    corn_clump(p, 3, 1.75, leaves=9, spread=0.24)


@plant("corn_c", "bush")
def corn_c(p):
    corn_clump(p, 5, 1.35, leaves=9, spread=0.3)


# --- Hag-hair and moss: long hanging strands ---------------------------------------------------------------------------

def strands(p, cell, anchors, length, normal, shade, far=False, hang_out=0.12, flutter=(1.0, 0.15)):
    """Long thin strands hanging from each of `anchors` (points on branches): two crossed cards of `cell` (a tall thin painting, thick at
    its top) each, so they read from every side. The painting is thick at its root, so it is laid root up: the grid runs from the tip
    (bottom) to the root (top), and the wind moves the tip most."""
    rng = p.rng
    for top in anchors:
        L = length * rng.uniform(0.7, 1.15)
        W = L * aspect(cell)
        az = rng.uniform(0, math.tau)
        out = Vector((math.cos(az), math.sin(az), 0)) * hang_out * rng.uniform(0.3, 1.2)
        segs = 2 if far else 3
        sway = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * 0.06 * L
        for ang in ((0.0,) if far else (0.0, math.pi / 2)):
            side = Vector((math.cos(az + ang), math.sin(az + ang), 0))
            grid = []
            for i in range(segs, -1, -1):          # from the tip up to the root
                t = i / segs
                c = top + out * t + sway * t * t - UP * L * t
                grid.append([c - side * W * 0.5 * (1.0 - 0.35 * t), c + side * W * 0.5 * (1.0 - 0.35 * t)])
            card2(p, cell, grid, normal, shade, rng.random(), flutter=flutter, along_u=False)


def wytch(p, H, crown, centre_z, cells, sprays, limbs, droop, girth, lean, hairs, hair_len, far=False):
    """A hunched oak (the framework's crown tree on the first atlas's oak leaves) hung with long thin hag-hair from its crown's rim."""
    P.crown_tree(p, H, crown, centre_z, cells, "bark_oak", sprays, limbs=limbs, droop=droop, girth=girth, lean=lean, far=far)
    rng = p.rng
    rx, rz = crown
    C = Vector((lean * H * 0.1, 0, centre_z))

    def normal(q):
        d = q - C
        return Vector((d.x / rx, d.y / rx, d.z / rz)).normalized() + Vector((0, 0, 0.35))

    def shade(q):
        return min(1.0, 0.5 + 0.5 * max(0.0, (q.z - 0.3) / (H * 0.8)))

    anchors = []
    for _ in range(hairs):
        az = rng.uniform(0, math.tau)
        ring = rng.uniform(0.55, 1.0)
        anchors.append(C + Vector((math.cos(az) * rx * ring, math.sin(az) * rx * ring, rz * rng.uniform(-0.35, 0.35))))
    strands(p, "hair_strand", anchors, hair_len, normal, shade, far=far, hang_out=0.16)


@plant("wytch_a", "broadleaf", ["pine"], far="wytch_a_far")
def wytch_a(p):
    wytch(p, 3.9, (1.65, 1.0), 2.35, ["oak_leaves"], 56, 7, 0.3, 2.1, 0.55, 30, 1.7)


@plant("wytch_b", "broadleaf", ["pine"], far="wytch_b_far")
def wytch_b(p):
    wytch(p, 3.4, (1.45, 0.95), 2.05, ["oak_leaves", "leaves_b"], 48, 6, 0.35, 2.4, -0.6, 26, 1.5)


@plant("wytch_a_far", "broadleaf", far_of="wytch_a")
def wytch_a_far(p):
    wytch(p, 3.9, (1.65, 1.0), 2.35, ["oak_leaves"], 18, 0, 0.3, 2.1, 0.55, 9, 1.7, far=True)


@plant("wytch_b_far", "broadleaf", far_of="wytch_b")
def wytch_b_far(p):
    wytch(p, 3.4, (1.45, 0.95), 2.05, ["oak_leaves"], 16, 0, 0.35, 2.4, -0.6, 8, 1.5, far=True)


# --- Fungal stumps ------------------------------------------------------------------------------------------------------

def fungal_stump(p, H, r0, tiers, per_tier, lean=0.0, far=False):
    """A rotting stump H high and r0 wide at its waist: a root foot flaring into five or six roots, a fluted, bark-furrowed trunk, a
    broken, jagged top, and shelf fungi in tiers up its side (flat fans, lowered at the rim) with side-on stacks between them."""
    rng = p.rng
    wob = rng.uniform(0, math.tau)
    s = r0 / 0.2

    def rad(z):
        return r0 * (1.0 - 0.2 * (z / H)) * (1.0 + 0.85 * math.exp(-z / (0.16 * H + 0.03)))

    def centre(z):
        return Vector((lean * (z / H) ** 2 + 0.02 * math.sin(wob + z * 5), 0.02 * math.cos(wob + z * 4), z))

    def shade(q):
        return min(1.0, 0.5 + 0.5 * max(0.0, q.z) / H)

    def wind_of(q):
        return 0.0

    n = 5 if far else 9
    zs = [H * i / n for i in range(n + 1)] + [H + 0.018, H + 0.034]
    path = [centre(z) for z in zs]
    radii = [rad(z) for z in zs[:-2]] + [rad(H) * 0.78, rad(H) * 0.4]
    p.tube(path, radii, 6 if far else 11, "bark_dead", shade, wind_of, cap=True)
    # Flutes: ridges of bark standing proud of the trunk, from the foot up.
    for k in range(0 if far else 4):
        az = rng.uniform(0, math.tau)
        d = Vector((math.cos(az), math.sin(az), 0))
        top = rng.uniform(0.5, 0.85)
        pts = [centre(H * top * i / 5) + d * rad(H * top * i / 5) * 0.96 for i in range(6)]
        p.tube(pts, [0.05 * s * (1.0 - 0.45 * i / 5) for i in range(6)], 5, "bark_dead", shade, wind_of, cap=True)
    # Roots: out from the foot and down into the ground.
    nr = 4 if far else 6
    for k in range(nr):
        az = math.tau * k / nr + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(az), math.sin(az), 0))
        z0 = 0.22 * H
        pts = [centre(z0) + d * rad(z0) * 0.8, d * r0 * 1.3 + Vector((0, 0, 0.09)), d * r0 * 1.8 + Vector((0, 0, 0.035)),
               d * r0 * 2.4 + Vector((0, 0, -0.012))]
        p.tube(pts, [0.085 * s, 0.062 * s, 0.038 * s, 0.014 * s], 4 if far else 5, "bark_dead", shade, wind_of, cap=True)
    # The broken top: splinters standing round the rim.
    nsp = 3 if far else 6
    for k in range(nsp):
        az = math.tau * k / nsp + rng.uniform(-0.4, 0.4)
        d = Vector((math.cos(az), math.sin(az), 0))
        h = rng.uniform(0.06, 0.2) * (H / 0.6)
        b = centre(H) + d * rad(H) * 0.76
        pts = [b - UP * 0.025, b + UP * h * 0.5 - d * 0.01, b + UP * h - d * 0.03]
        p.tube(pts, [0.048 * s, 0.032 * s, 0.006], 4, "bark_dead", shade, wind_of, cap=True)

    def normal(q):
        return Vector((q.x, q.y, 0)) + Vector((0, 0, 0.9))

    # Shelf fungi in tiers, round the trunk: flat fans lowered at the rim.
    for t in range(tiers):
        z0 = H * (0.13 + 0.8 * t / max(1, tiers))
        count = max(1, per_tier - (1 if far else 0))
        az0 = rng.uniform(0, math.tau)
        for k in range(count):
            az = az0 + math.tau * k / count + rng.uniform(-0.4, 0.4)
            d = Vector((math.cos(az), math.sin(az), 0))
            z = z0 + rng.uniform(-0.04, 0.04) * H
            L = rng.uniform(0.11, 0.2) * s ** 0.5
            W = L * aspect("shelf_top") * 1.1
            side = Vector((-d.y, d.x, 0))
            root = centre(z) + d * rad(z) * 0.95
            tilt = rng.uniform(0.04, 0.22)
            grid = []
            for i in range(3):
                f = i / 2.0
                c = root + d * L * f - UP * tilt * L * f
                grid.append([c - side * W * 0.5 * (0.6 + 0.4 * f) - UP * 0.1 * W * f, c,
                             c + side * W * 0.5 * (0.6 + 0.4 * f) - UP * 0.1 * W * f])
            card2(p, "shelf_top", grid, normal, lambda q: 0.9, rng.random(), flutter=(0.0, 0.08), along_u=False)
    # Side-on stacks of brackets on the lower trunk and the roots' shoulders.
    for k in range(2 if far else 4):
        az = rng.uniform(0, math.tau)
        d = Vector((math.cos(az), math.sin(az), 0))
        z = rng.uniform(0.04, 0.45) * H
        h = rng.uniform(0.14, 0.24) * s ** 0.5
        w = h * aspect("shelf_side")
        side = Vector((-d.y, d.x, 0))
        root = centre(z) + d * (rad(z) + 0.015)
        grid = [[root + (d * 0.05 + UP) * h * (i / 2.0) + side * (j - 1) * w * 0.5 for j in range(3)] for i in range(3)]
        card2(p, "shelf_side", grid, normal, lambda q: 0.9, rng.random(), flutter=(0.0, 0.05), along_u=False)


@plant("fungal_a", "dead")
def fungal_a(p):
    fungal_stump(p, 0.72, 0.2, 4, 4, lean=0.05)


@plant("fungal_b", "dead")
def fungal_b(p):
    fungal_stump(p, 0.46, 0.27, 3, 5, lean=-0.04)


# --- Briar ----------------------------------------------------------------------------------------------------------

def briar(p, spread, canes, far=False):
    """A briar: long canes springing from a knot, arching up and over to the ground under their own weight, branching, set with hooked
    thorns and hung with bramble sprigs; softer and more tangled than stiff sticks."""
    rng = p.rng

    def wind_of(q):
        return min(1.0, max(0.0, q.z * 0.8))

    def shade(q):
        return min(1.0, 0.45 + 0.55 * min(1.0, max(0.0, q.z) / 0.9))

    centre = Vector((0, 0, 0.2))

    def normal(q):
        return (q - centre).normalized() * 0.7 + Vector((0, 0, 0.5))

    leaf_w = 0.3

    def cane(start, direction, length, thick, steps, thorny):
        pts = arc(rng, start, direction, length, steps, drop=rng.uniform(1.8, 2.6), wobble=0.12)
        pts = [Vector((q.x, q.y, max(q.z, 0.012))) for q in pts]
        p.tube(pts, [thick * (1.0 - 0.7 * i / steps) + 0.004 for i in range(steps + 1)], 4 if far else 5, "bark_dead", shade, wind_of,
               phase=rng.random(), cap=True)
        # Thorns, alternating up the cane, hooked back toward its root.
        if thorny and not far:
            for i in range(1, steps):
                for _ in (1, -1):
                    if rng.random() < 0.5:
                        tang = (pts[i + 1] - pts[i - 1]).normalized()
                        o = perp(tang, roll=rng.uniform(0, math.tau))
                        tip = pts[i] + (o * 0.9 - tang * 0.45).normalized() * rng.uniform(0.028, 0.05)
                        p.tube([pts[i] - o * 0.003, Vector((tip.x, tip.y, max(tip.z, 0.01)))], [0.0085, 0.0015], 3, "bark_dead", shade, wind_of, phase=rng.random())
        # Bramble sprigs along the cane, hanging outward.
        for i in range(2, steps + 1, 2):
            for _ in range(1 if far else 2):
                tang = (pts[min(i + 1, steps)] - pts[i - 1]).normalized()
                o = perp(tang, roll=rng.uniform(0, math.tau))
                d = (o + Vector((0, 0, -0.25)) + tang * 0.2).normalized()
                S = leaf_w * rng.uniform(0.8, 1.25)
                side = perp(d, roll=rng.uniform(-0.5, 0.5))
                grid = [[pts[i] + d * S * (a / 2.0) - UP * 0.06 * (a / 2.0) ** 2 + side * (j - 1) * S * 0.5 for j in range(3)]
                        for a in range(3)]
                card2(p, "briar_leaf", grid, normal, shade, rng.random(), flutter=(0.15, 1.0), along_u=False, floor=0.012)
        return pts

    for k in range(canes):
        az = math.tau * k / canes + rng.uniform(-0.4, 0.4)
        out = Vector((math.cos(az), math.sin(az), 0))
        start = Vector((out.x * 0.04, out.y * 0.04, 0.03))
        d = out * rng.uniform(0.3, 0.8) + UP * rng.uniform(0.7, 1.1)
        L = spread * rng.uniform(0.95, 1.5)
        main = cane(start, d, L, 0.018, 7 if far else 10, True)
        if not far:
            for _ in range(rng.choice((1, 2))):
                i = int(len(main) * rng.uniform(0.35, 0.65))
                tang = (main[i + 1] - main[i - 1]).normalized()
                o = perp(tang, roll=rng.uniform(0, math.tau))
                cane(main[i], (tang + o * 0.9 + UP * 0.2).normalized(), L * rng.uniform(0.3, 0.5), 0.009, 6, True)


@plant("briar_a", "bush")
def briar_a(p):
    briar(p, 0.72, 8)


# --- Cypress --------------------------------------------------------------------------------------------------------

def cypress(p, H, far=False):
    """A bald cypress: a fluted trunk on a buttressed foot (ridges and flared roots), knees standing round it, a few limbs that spread and
    droop, flat feathery fronds along them and a crown of upright ones, and long Spanish moss hung from the limbs."""
    rng = p.rng
    wob = rng.uniform(0, math.tau)

    def rad(z):
        return (0.1 + 0.2 * math.exp(-z / 0.45)) * (1.0 - 0.45 * min(1.0, z / (H * 0.7)))

    def centre(z):
        return Vector((0.03 * math.sin(wob + z * 1.3), 0.03 * math.cos(wob + z * 0.9), z))

    def wind_of(q):
        return min(1.0, max(0.0, (q.z / H - 0.3) * 1.3))

    def shade(q):
        return 0.5 + 0.5 * min(1.0, max(0.0, q.z) / H)

    def normal(q):
        return Vector((q.x, q.y, 0)) * 0.5 + Vector((0, 0, 0.6))

    n = 6 if far else 12
    top = H * 0.72
    zs = [top * i / n for i in range(n + 1)]
    p.tube([centre(z) for z in zs], [rad(z) for z in zs], 6 if far else 10, "bark_oak", shade, wind_of, cap=True)
    # The buttress: ridges climbing the trunk, and roots flaring out of its foot.
    nb = 3 if far else 6
    for k in range(nb):
        az = math.tau * k / nb + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(az), math.sin(az), 0))
        h = rng.uniform(0.6, 1.1)
        pts = [centre(h * i / 5) + d * (rad(h * i / 5) * 0.95 + 0.02) for i in range(6)]
        p.tube(pts, [0.075 * (1.0 - 0.6 * i / 5) + 0.01 for i in range(6)], 4, "bark_oak", shade, wind_of, cap=True)
        roots = [centre(0.4) + d * 0.1, d * 0.28 + Vector((0, 0, 0.14)), d * 0.55 + Vector((0, 0, 0.04)), d * 0.85 + Vector((0, 0, -0.015))]
        p.tube(roots, [0.1, 0.07, 0.04, 0.015], 4 if far else 5, "bark_oak", shade, wind_of, cap=True)
    # Knees: woody cones standing out of the mud round the tree.
    for k in range(3 if far else 8):
        az = rng.uniform(0, math.tau)
        r = rng.uniform(0.45, 1.25)
        h = rng.uniform(0.12, 0.46)
        b = Vector((math.cos(az) * r, math.sin(az) * r, -0.02))
        bend = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * 0.04
        p.tube([b, b + UP * h * 0.5 + bend, b + UP * h + bend * 2.0], [0.065, 0.04, 0.012], 4 if far else 6, "bark_oak", shade, wind_of,
               cap=True)
    # Limbs, spreading from the upper trunk and drooping at the ends.
    limb_paths = []
    nl = 4 if far else 6
    for k in range(nl):
        az = math.tau * k / nl + rng.uniform(-0.4, 0.4)
        d = Vector((math.cos(az), math.sin(az), 0))
        base = centre(top * rng.uniform(0.62, 0.98))
        pts = arc(rng, base, d + UP * rng.uniform(0.35, 0.7), rng.uniform(0.9, 1.4), 5, drop=0.8, wobble=0.1)
        p.tube(pts, [0.058 * (1.0 - 0.75 * i / 5) + 0.008 for i in range(6)], 4 if far else 5, "bark_oak", shade, wind_of,
               phase=rng.random(), cap=True)
        limb_paths.append(pts)
    # Fronds: flat feathery sprays out along each limb, and a crown of upright ones at the top.
    for pts in limb_paths:
        for i in range(2, 6):
            for sgn in ((1,) if far else (1, -1)):
                tang = (pts[min(i + 1, 5)] - pts[i - 1]).normalized()
                side = perp(tang)
                dirn = (tang * 0.35 + side * sgn * 0.95 + UP * 0.12).normalized()
                L = rng.uniform(0.42, 0.62)
                W = L / aspect("cypress_frond_a")
                cell = "cypress_frond_a" if rng.random() < 0.55 else "cypress_frond_b"
                fs = perp(dirn, roll=rng.uniform(-0.25, 0.25))
                grid = [[pts[i] + dirn * L * (a / 2.0) - UP * 0.1 * L * (a / 2.0) ** 2 + fs * (j - 1) * W * 0.5 for j in range(3)]
                        for a in range(3)]
                card2(p, cell, grid, normal, shade, rng.random(), flutter=(0.15, 1.0))
    c = centre(top)
    for k in range(3 if far else 7):
        az = math.tau * k / 7 + rng.uniform(-0.3, 0.3)
        dirn = Vector((math.cos(az) * 0.8, math.sin(az) * 0.8, 0.9)).normalized()
        L = rng.uniform(0.45, 0.65)
        W = L / aspect("cypress_frond_a")
        fs = perp(dirn, roll=rng.uniform(-0.4, 0.4))
        grid = [[c + dirn * L * (a / 2.0) - UP * 0.08 * L * (a / 2.0) ** 2 + fs * (j - 1) * W * 0.5 for j in range(3)] for a in range(3)]
        card2(p, "cypress_frond_b", grid, normal, shade, rng.random(), flutter=(0.2, 1.0))
    # Spanish moss: long grey strands hung all along the limbs.
    anchors = []
    for pts in limb_paths:
        for _ in range(2 if far else 4):
            t = rng.uniform(0.3, 1.0)
            anchors.append(pts[min(5, int(t * 5))])
    strands(p, "moss_strand", anchors, 1.05, normal, lambda q: min(1.0, 0.5 + 0.5 * max(0.0, q.z) / H), far=far, hang_out=0.1)


@plant("cypress_a", "broadleaf", ["pine"], far="cypress_a_far")
def cypress_a(p):
    cypress(p, 3.9)


@plant("cypress_a_far", "broadleaf", far_of="cypress_a")
def cypress_a_far(p):
    cypress(p, 3.9, far=True)


MINE = ["corn_a", "corn_b", "corn_c", "wytch_a", "wytch_b", "wytch_a_far", "wytch_b_far", "fungal_a", "fungal_b", "briar_a",
        "cypress_a", "cypress_a_far"]


def main():
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--no-export", action="store_true")
    a = ap.parse_args(argv)
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    built = {}
    for id_ in (a.only or MINE):
        try:
            pl = P.Plant(id_, seed=sum(ord(c) * (i + 1) for i, c in enumerate(id_)))
            P.PLANTS[id_]["build"](pl)
            built[id_] = pl.finish()
        except Exception:   # one plant failing must not lose the others in a once-an-hour Blender turn
            print("PLANT FAILED", id_)
            traceback.print_exc()
    if not a.no_export and built:
        P.export(built)


if __name__ == "__main__":
    main()
