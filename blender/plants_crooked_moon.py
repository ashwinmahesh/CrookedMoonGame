"""The Crooked Moon's own plants (docs/art/plants.md, branch look-plants-photoreal): real 3D plants for what the 2D leaf cards could only
stand in for, built with the same builders as blender/plants_3d.py (cards from the atlas art/plants/cards.png, tubes for trunks, a
normal, a light and a wind value per vertex) and written to art/plants/<id>.glb and art/plants/manifest.json beside the others.

  blender -b --python blender/plants_crooked_moon.py -- [--only corn_a wytch_a ...] [--no-export]
  (a batch for the GPU scheduler: ~/.crooked-moon/blender_queue/NN_region_plants.py, tools/gpu/blender_batch.sh)

What is built, and what each region plants of it (art/plants/flora.json):
  corn_a, corn_b, corn_c   a tall corn stalk: a thin stalk, tiers of arching leaves, an ear in its husk and a tassel; Foxwillow's fields
  wytch_a, wytch_b         a stout, hunched oak with a heavy dark crown and long hag-hair strands hanging from its rim; the Wytchwood
  fungal_a, fungal_b       a rotting stump with stacked bracket fungi up its sides and a ring of glowing fans at its foot; Hartsblight
  briar_a                  a thick arching bramble hedge of thorny canes with dark leaves; the Wytchwood, the Crooked House's grounds
  cypress_a                a buttressed bald cypress hung with long moss; Murkwater Bend and the bayou
Each tree has a `_far` copy. The leaves are the atlas's painted cards (corn is the `sedge` card, brackets and glowing fans the
`fern_brown` card, hag-hair and moss the `willow_strand` card, briar leaves the `vine_leaves` card), so repainting the cards (photoreal,
tools/art/plant_cards.py) repaints every model.
"""
import math
import sys
from pathlib import Path

import bpy  # noqa: F401  (Blender's own module: this script only runs inside Blender)
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plants_3d as P  # noqa: E402

plant = P.plant
BOX = P.BOX


def corn_stalk(p, H, ears=1, leaves=7, far=False, bend=0.12):
    """A corn plant: a thin stalk (slightly bowed), a tier of long arching leaves up it, an ear in its husk at about two thirds of the
    height and a feathery tassel on top. Leaves and ears are crossed cards of the `sedge` painting (ripe corn)."""
    rng = p.rng
    bow = Vector((bend, 0, 0))

    def axis(z):
        return Vector((bend * H * (z / H) ** 2 * 0.4, 0, z))

    def wind_of(q):
        return min(1.0, max(0.0, q.z / H * 1.1))

    def shade(q):
        return min(1.0, 0.45 + 0.55 * q.z / H)

    n = 3 if far else 6
    path = [axis(H * 0.92 * i / n) for i in range(n + 1)]
    radii = [0.018 * (1.5 if i == 0 else 1.0) * (1.0 - 0.45 * i / n) for i in range(n + 1)]
    p.tube(path, radii, 4 if far else 5, "bark_dead", shade, wind_of, cap=True)

    def normal(q):
        return (Vector((q.x, q.y, 0)) * 1.0 + Vector((0, 0, 0.7))).normalized()

    offset = rng.uniform(0, math.tau)
    count = max(4, leaves - (2 if far else 0))
    for k in range(count):
        f = (k + 0.5) / count
        z = H * (0.18 + 0.66 * f)
        az = offset + k * 2.4 + rng.uniform(-0.25, 0.25)   # a leaf on alternate sides, as corn does
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        L = H * rng.uniform(0.38, 0.5) * (1.1 - 0.35 * f)
        u0, v0, u1, v1 = BOX["sedge"]
        W = L * 0.22
        root = axis(z)
        grid = []
        segs = 2 if far else 3
        for i in range(segs + 1):
            s = i / segs
            # Up and out, then arching over and drooping at the tip.
            c = root + out * (L * s * 0.95) + Vector((0, 0, L * (0.55 * s - 0.65 * s * s)))
            grid.append([c + side * (j - 1) * W * 0.5 * (1.0 - 0.55 * s) for j in range(3)])
        p.card("sedge", grid, normal, shade, rng.random(), flutter=(0.1, 0.9), along_u=False)
    # The ear: two crossed cards along the stalk, husk-coloured, at about two thirds of the height.
    for e in range(ears):
        z = H * (0.58 + 0.05 * e)
        az = offset + 1.1 + e * 2.6
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        base = axis(z) + out * 0.03
        tip = base + out * H * 0.07 + Vector((0, 0, H * 0.16))
        W = H * 0.07
        for k in range(1 if far else 2):
            sd = Matrix.Rotation(k * math.pi / 2, 3, (tip - base).normalized()) @ side
            grid = [[base + (tip - base) * (i / 2) + sd * (j - 1) * W * 0.5 * (1.0 - 0.3 * i / 2) for j in range(3)]
                    for i in range(3)]
            p.card("sedge", grid, normal, shade, rng.random(), flutter=(0.0, 0.4), along_u=False)
    # The tassel: a small spray of feathery cards standing up at the top.
    top = axis(H * 0.92)
    for k in range(1 if far else 2):
        az = offset + k * math.pi / 2
        side = Vector((math.cos(az), math.sin(az), 0))
        W = H * 0.16
        grid = [[top + Vector((0, 0, H * 0.14 * i / 2)) + side * (j - 1) * W * 0.5 * (1.0 - 0.5 * i / 2)
                 for j in range(3)] for i in range(3)]
        p.card("sedge", grid, normal, shade, rng.random(), flutter=(0.4, 1.0), along_u=False)


@plant("corn_a", "grass", far=None)
def corn_a(p):
    corn_stalk(p, 1.55, ears=1, leaves=7)


@plant("corn_b", "grass")
def corn_b(p):
    corn_stalk(p, 1.8, ears=2, leaves=8, bend=-0.15)


@plant("corn_c", "grass")
def corn_c(p):
    corn_stalk(p, 1.3, ears=1, leaves=6, bend=0.2)


@plant("wytch_a", "broadleaf", ["pine"], far="wytch_a_far")
def wytch_a(p):
    P.crown_tree(p, 3.9, (1.65, 1.0), 2.35, ["oak_leaves"], "bark_oak", 60, limbs=7, droop=0.3, girth=2.1, lean=0.55,
                 hang=(["willow_strand"], 30, 1.5))


@plant("wytch_b", "broadleaf", ["pine"], far="wytch_b_far")
def wytch_b(p):
    P.crown_tree(p, 3.4, (1.45, 0.95), 2.05, ["oak_leaves", "leaves_b"], "bark_oak", 52, limbs=6, droop=0.35, girth=2.4,
                 lean=-0.6, hang=(["willow_strand"], 26, 1.35))


@plant("wytch_a_far", "broadleaf", far_of="wytch_a")
def wytch_a_far(p):
    P.crown_tree(p, 3.9, (1.65, 1.0), 2.35, ["oak_leaves"], "bark_oak", 18, droop=0.3, girth=2.1, lean=0.55, far=True,
                 hang=(["willow_strand"], 9, 1.5))


@plant("wytch_b_far", "broadleaf", far_of="wytch_b")
def wytch_b_far(p):
    P.crown_tree(p, 3.4, (1.45, 0.95), 2.05, ["oak_leaves"], "bark_oak", 16, droop=0.35, girth=2.4, lean=-0.6, far=True,
                 hang=(["willow_strand"], 8, 1.35))


def fungal_stump(p, H, brackets, fans, far=False):
    """A rotting stump H high, thick and flaring at the foot, with shelf fungi stacked up its sides (flat, nearly horizontal fans of the
    `fern_brown` painting) and a ring of upright glowing fans round its foot."""
    rng = p.rng

    def wind_of(q):
        return 0.0

    def shade(q):
        return min(1.0, 0.5 + 0.5 * q.z / H)

    path = [Vector((0.02 * math.sin(i), 0.02 * math.cos(i * 1.7), H * i / 4)) for i in range(5)]
    radii = [0.2, 0.15, 0.145, 0.135, 0.1]
    p.tube(path, radii, 5 if far else 8, "bark_dead", shade, wind_of, cap=True)

    def normal(q):
        return (Vector((q.x, q.y, 0)) + Vector((0, 0, 0.9))).normalized()

    u0, v0, u1, v1 = BOX["fern_brown"]
    for k in range(brackets):
        az = rng.uniform(0, math.tau)
        z = H * rng.uniform(0.12, 0.9)
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        L = rng.uniform(0.16, 0.3)
        W = L * 1.6
        root = Vector((0, 0, z)) + out * 0.13
        tilt = rng.uniform(0.05, 0.3)
        grid = []
        for i in range(2 if far else 3):
            s = i / (1 if far else 2)
            c = root + out * L * s + Vector((0, 0, -tilt * L * s))
            grid.append([c + side * (j - 1) * W * 0.5 * (0.6 + 0.4 * s) for j in range(3)])
        p.card("fern_brown", grid, normal, shade, rng.random(), flutter=(0.0, 0.15), along_u=False)
    for k in range(fans):
        az = math.tau * k / fans + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        L = rng.uniform(0.32, 0.55)
        W = L * 0.55
        root = out * 0.19 + Vector((0, 0, 0.01))
        grid = []
        for i in range(3):
            s = i / 2
            c = root + out * L * 0.35 * s + Vector((0, 0, L * s))
            grid.append([c + side * (j - 1) * W * 0.5 * (0.5 + 0.5 * s) for j in range(3)])
        p.card("fern_brown", grid, normal, lambda q: min(1.0, 0.6 + 0.4 * q.z / 0.5), rng.random(),
               flutter=(0.0, 0.4), along_u=False)


@plant("fungal_a", "bush")
def fungal_a(p):
    fungal_stump(p, 0.7, 9, 6)


@plant("fungal_b", "bush")
def fungal_b(p):
    fungal_stump(p, 1.05, 12, 7)


def briar(p, spread, canes, far=False):
    """A thorny bramble hedge: canes that rise from a few roots and arch over in tall loops, thorned with dark leaf sprays (the
    `vine_leaves` painting, which carries the thorns and berries), a low dense mound round a few high arches."""
    rng = p.rng

    def wind_of(q):
        return min(1.0, q.z * 0.9)

    def shade(q):
        return min(1.0, 0.35 + 0.65 * min(1.0, q.z / 0.9))

    def normal(q):
        return (Vector((q.x, q.y, 0)) * 0.7 + Vector((0, 0, 1))).normalized()

    u0, v0, u1, v1 = BOX["vine_leaves"]
    for k in range(canes):
        az = rng.uniform(0, math.tau)
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        root = out * rng.uniform(0.0, spread * 0.35)
        H = rng.uniform(0.55, 1.1)
        L = rng.uniform(0.7, 1.2) * spread
        pts = []
        for i in range(5):
            s = i / 4
            pts.append(root + out * L * s + Vector((0, 0, H * math.sin(s * math.pi * 0.85) + 0.02)))
        p.tube(pts, [0.03 * (1.0 - 0.7 * i / 4) for i in range(5)], 4 if far else 5, "bark_dead", shade, wind_of,
               phase=rng.random(), cap=True)
        for i in range(1, 5):
            for e in range(1 if far else 2):
                sd = Vector(Matrix.Rotation(rng.uniform(0, math.tau), 3, (pts[i] - pts[i - 1]).normalized()) @ side)
                Lc = rng.uniform(0.22, 0.38)
                Wc = Lc * (v1 - v0) / max(u1 - u0, 1e-3)
                dirn = (sd + Vector((0, 0, 0.3))).normalized()
                base = pts[i]
                grid = [[base + dirn * Lc * (a / 2) + side * (j - 1) * Wc * 0.5 - Vector((0, 0, 0.05 * (a / 2) ** 2))
                         for j in range(3)] for a in range(3)]
                p.card("vine_leaves", grid, normal, shade, rng.random(), flutter=(0.2, 0.9))


@plant("briar_a", "bush")
def briar_a(p):
    briar(p, 1.1, 9)


def cypress(p, H, far=False):
    """A bald cypress: a buttressed trunk (fluted foot of five roots), a few drooping limbs and a thin crown, hung all round with long moss
    (the `willow_strand` painting, silver-grey)."""
    rng = p.rng

    def wind_of(q):
        return min(1.0, max(0.0, (q.z / H - 0.25) * 1.3))

    def shade(q):
        return 0.5 + 0.5 * min(1.0, q.z / H)

    path = [Vector((0.03 * math.sin(i * 1.3), 0.03 * math.cos(i * 0.9), H * 0.78 * i / 6)) for i in range(7)]
    radii = [0.2 * (1.0 - 0.7 * i / 6) + 0.03 for i in range(7)]
    p.tube(path, radii, 5 if far else 8, "bark_dead", shade, wind_of, cap=True)
    for k in range(4 if far else 6):   # the buttress: roots flaring from the foot
        az = math.tau * k / (4 if far else 6) + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        pts = [Vector((0, 0, 0.5)) * 0.5, out * 0.2 + Vector((0, 0, 0.18)), out * 0.4 + Vector((0, 0, 0.03)), out * 0.55 + Vector((0, 0, -0.02))]
        p.tube(pts, [0.09, 0.075, 0.05, 0.025], 4, "bark_dead", shade, wind_of, cap=True)
    tops = []
    for k in range(3 if far else 5):
        az = math.tau * k / 5 + rng.uniform(-0.4, 0.4)
        out = Vector((math.cos(az), math.sin(az), 0))
        base = path[min(6, 4 + k % 3)]
        pts = [base, base + out * 0.35 + Vector((0, 0, 0.3)), base + out * 0.8 + Vector((0, 0, 0.35)), base + out * 1.15 + Vector((0, 0, 0.1))]
        p.tube(pts, [0.06, 0.045, 0.03, 0.015], 4, "bark_dead", shade, wind_of, phase=rng.random(), cap=True)
        tops.append(pts)

    def normal(q):
        return (Vector((q.x, q.y, 0)) * 0.5 + Vector((0, 0, 0.6))).normalized()

    cell = "willow_strand"
    u0, v0, u1, v1 = BOX[cell]
    n = (10 if far else 26)
    for k in range(n):
        pts = tops[k % len(tops)]
        t = rng.uniform(0.35, 1.0)
        top = pts[min(3, int(t * 3))]
        L = rng.uniform(1.0, 1.7)
        W = L * (u1 - u0) / max(v1 - v0, 1e-3)
        az = rng.uniform(0, math.tau)
        side = Vector((-math.sin(az), math.cos(az), 0))
        grid = [[top + Vector((0, 0, -1)) * L * (i / 2) + side * (j - 1) * W * 0.5 for j in range(3)] for i in range(3)]
        p.card(cell, grid, normal, lambda q: min(1.0, 0.45 + 0.55 * (q.z / H)), rng.random(), flutter=(0.2, 1.0), along_u=False)
    # A thin crown of leafy twigs on the limbs' ends.
    for pts in tops:
        base = pts[-1]
        for k in range(1 if far else 2):
            sd = Matrix.Rotation(k * math.pi / 2 + rng.uniform(-0.3, 0.3), 3, Vector((0, 0, 1))) @ Vector((1, 0, 0))
            Lc = rng.uniform(0.35, 0.55)
            Wc = Lc * 0.9
            grid = [[base + Vector((0, 0, 0.1 + Lc * i / 2)) + sd * (j - 1) * Wc * 0.5 for j in range(3)] for i in range(3)]
            p.card("twigs", grid, normal, lambda q: 0.9, rng.random(), flutter=(0.3, 1.0))


@plant("cypress_a", "broadleaf", ["pine"], far="cypress_a_far")
def cypress_a(p):
    cypress(p, 4.4)


@plant("cypress_a_far", "broadleaf", far_of="cypress_a")
def cypress_a_far(p):
    cypress(p, 4.4, far=True)


def main():
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--no-export", action="store_true")
    a = ap.parse_args(argv)
    mine = ["corn_a", "corn_b", "corn_c", "wytch_a", "wytch_b", "wytch_a_far", "wytch_b_far", "fungal_a", "fungal_b", "briar_a",
            "cypress_a", "cypress_a_far"]
    ids = a.only or mine
    built = P.build(ids)
    if not a.no_export:
        P.export(built)


if __name__ == "__main__":
    main()
