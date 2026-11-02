#!/usr/bin/env python3
"""Which way a rigged figure's GLB faces at rest, from its skeleton: the joints on its left side against those on its
right. The engine turns a figure to the way it walks by turning the model so its front looks along the heading, which
only works when the model's front is +z at a manifest `turn` of 0 (the engine's FigureModels: "the degrees it is
turned about its up axis so it faces +z"). A rig made facing -z walks backwards (the Corrupted Passenger and the Phantom,
Ashwin 2026-11-02), so tools/art/figures.py gives such a figure `"turn": 180` as it copies it, and
tests/tools/test_figure_facing.py checks every figure in the manifest. Stdlib only.

  python3 tools/art/rig_facing.py                 every figure in the manifest: its facing and whether it needs a turn
  python3 tools/art/rig_facing.py --check         the same, quiet unless a figure faces the wrong way; exits 1 if one does
  python3 tools/art/rig_facing.py path/to/x.glb   one file
"""
import json, math, re, struct, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
MANIFEST = REPO / 'art/figures/manifest.json'

# A joint on the figure's left or right side, by the names the rigs we use give them: Mixamo and Tripo (LeftUpLeg,
# tripo::0_Left_Limb_1), Quaternius (thigh_l, ball_leaf_l) and Blender's own (FrontUpperLeg.L).
LEFT = re.compile(r'left|(_|\.)l$|_l_', re.I)
RIGHT = re.compile(r'right|(_|\.)r$|_r_', re.I)


def _doc(path: Path):
    data = path.read_bytes()
    if data[:4] != b'glTF':
        return None   # a Git LFS pointer (the model isn't pulled) or not a GLB
    size = struct.unpack_from('<I', data, 12)[0]
    return json.loads(data[20:20 + size])


def _mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def _local(node: dict):
    if 'matrix' in node:
        m = node['matrix']
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    sx, sy, sz = node.get('scale', [1, 1, 1])
    tx, ty, tz = node.get('translation', [0, 0, 0])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    s = (sx, sy, sz)
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], (tx, ty, tz)[i]] for i in range(3)] + [[0, 0, 0, 1]]


def facing(path: Path):
    """The figure's front at rest as (x, z), unit length, or None when the file isn't a pulled GLB or has no skeleton
    with named left and right joints."""
    doc = _doc(path)
    if doc is None or not doc.get('skins'):
        return None
    nodes = doc['nodes']
    parent = {c: i for i, n in enumerate(nodes) for c in n.get('children', [])}

    def world(i):
        m = _local(nodes[i])
        while i in parent:
            i = parent[i]
            m = _mat_mul(_local(nodes[i]), m)
        return (m[0][3], m[1][3], m[2][3])

    sides = {'l': [], 'r': []}
    for j in doc['skins'][0]['joints']:
        name = str(nodes[j].get('name', '')).split(':')[-1]
        is_l, is_r = bool(LEFT.search(name)), bool(RIGHT.search(name))
        if is_l != is_r:
            sides['l' if is_l else 'r'].append(world(j))
    if not sides['l'] or not sides['r']:
        return None
    avg = {k: [sum(p[a] for p in v) / len(v) for a in range(3)] for k, v in sides.items()}
    lx, lz = avg['l'][0] - avg['r'][0], avg['l'][2] - avg['r'][2]
    # Facing f with up +y has its left at up x f... so f = left x up: (lx, 0, lz) x (0, 1, 0) = (-lz, 0, lx).
    fx, fz = -lz, lx
    length = math.hypot(fx, fz)
    return None if length < 1e-6 else (fx / length, fz / length)


def turned(front, turn_deg: float):
    """`front` (x, z) after the engine's turn of `turn_deg` about the up axis (Node3D.rotation.y)."""
    a = math.radians(turn_deg)
    x, z = front
    return (x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a))


def turn_needed(front) -> float:
    """The turn, in whole quarter turns, that brings `front` closest to +z."""
    return min((0.0, 90.0, 180.0, 270.0), key=lambda t: -turned(front, t)[1]) % 360


def figure_files(manifest: dict):
    """art id -> (its GLB path, its turn) for every figure with a model file of its own."""
    out = {}
    for fid, info in manifest.get('figures', {}).items():
        if 'file' in info:
            out[fid] = (REPO / info['file'], float(info.get('turn', 0.0)))
    return out


def main(argv):
    check = '--check' in argv
    files = [a for a in argv if not a.startswith('--')]
    if files:
        for p in files:
            front = facing(Path(p))
            print(f'{p}: ' + ('no skeleton read' if front is None else f'front ({front[0]:.2f}, {front[1]:.2f}), turn {turn_needed(front):g}'))
        return 0
    wrong = 0
    for fid, (path, turn) in figure_files(json.loads(MANIFEST.read_text())).items():
        front = facing(path) if path.exists() else None
        if front is None:
            if not check:
                print(f'{fid}: not checked (no pulled GLB or no left and right joints)')
            continue
        ok = turned(front, turn)[1] > 0.7
        wrong += 0 if ok else 1
        if not ok or not check:
            print(f'{fid}: turn {turn:g}, needs {turn_needed(front):g}' + ('' if ok else '  <-- faces the wrong way: set its "turn" in art/figures/manifest.json'))
    return 1 if check and wrong else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
