#!/usr/bin/env python3
"""Whether a held weapon cuts through its figure's body: the figure's skinned mesh posed through its clips, the part held
as the engine holds it (ModelFigure._hold_at with `follow` "turn": the hand's place and turn, the part's `turn`, `offset`,
`grip` and `size` from art/figures/manifest.json), and every sampled point along the blade tested against the body (inside
it by the nearest surface's normal, or nearer than --margin of the figure's height). The hand and forearm holding it and
the head (a part of its own) don't count.

  python3 tools/art/weapon_clearance.py rook_coldwake sword_great            each clip's poses that cut through
  python3 tools/art/weapon_clearance.py rook_coldwake sword_great --search   the best turns with the handle across the palm

--search keeps the handle across the palm (the blade out of the thumb side, swung toward the back of the hand or the palm
by up to 45 degrees, tilted toward the fingers or the wrist by up to 60) and prints the turns that clear the most poses.
"""
import argparse, itertools, json, math, sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / 'tools'))
sys.path.insert(0, str(REPO / 'tools/art'))
import free_figures as FF  # noqa: E402
import retarget_clips as R  # noqa: E402

MANIFEST = REPO / 'art/figures/manifest.json'
ROLES = ['idle', 'walk', 'run', 'attack', 'hurt', 'talk', 'greet', 'cast']
# The pack's spell clips, sampled too where the model has them (the cast role may sit in the manifest's defaults later).
EXTRA = ['Spell_Simple_Enter', 'Spell_Simple_Shoot', 'Spell_Simple_Exit']
SAMPLES = 12


class Body:
    """A figure's skinned mesh and skeleton, posed by its clips."""

    def __init__(self, path: Path):
        d, b = FF.read_gltf(path)
        self.d, self.b = d, b
        self.T = R.Skeleton(d, b, strip_prefix=True)
        prim = d['meshes'][0]['primitives'][0]
        pos = R.accessor(d, b, prim['attributes']['POSITION'])
        self.P = np.c_[pos, np.ones(len(pos))]
        self.N = R.accessor(d, b, prim['attributes']['NORMAL'])
        ja = d['accessors'][prim['attributes']['JOINTS_0']]
        self.J = np.frombuffer(FF.accessor_bytes(d, b, prim['attributes']['JOINTS_0']),
                               dtype={5121: np.uint8, 5123: '<u2'}[ja['componentType']]).reshape(-1, 4).astype(int)
        self.W = R.accessor(d, b, prim['attributes']['WEIGHTS_0'])
        skin = d['skins'][0]
        self.IBM = R.accessor(d, b, skin['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
        self.joints = skin['joints']
        names = [self.T.nodes[j]['name'].split(':')[-1] for j in self.joints]
        holding = {i for i, n in enumerate(names) if n.startswith('RightHand') or n in ('RightForeArm', 'Head', 'HeadTop_End', 'Neck')}
        self.keep = np.array([k not in holding for k in self.J[np.arange(len(self.J)), self.W.argmax(1)]])
        self.anims = {a['name']: a for a in d['animations']}
        rest = self.skinned(self.T.pose_world({}))
        self.height = float(rest[:, 1].max() - rest[:, 1].min())

    def clip(self, name: str):
        for key in (name, name + '_Loop'):
            if key in self.anims:
                return key
        return ''

    def length(self, clip: str) -> float:
        return max(R.accessor(self.d, self.b, s['input'])[-1, 0] for s in self.anims[clip]['samplers'])

    def pose(self, clip: str, t: float) -> dict:
        a, loc = self.anims[clip], {}
        for ch in a['channels']:
            sm = a['samplers'][ch['sampler']]
            times = R.accessor(self.d, self.b, sm['input'])[:, 0]
            vals = R.accessor(self.d, self.b, sm['output'])
            j, path = ch['target']['node'], ch['target']['path']
            tt, rr, ss = loc.get(j, self.T.rest[j])
            v = R.sample(times, vals, t, sm.get('interpolation', 'LINEAR'), path == 'rotation')
            if path == 'rotation':
                rr = R.qnorm(v)
            elif path == 'translation':
                tt = v
            else:
                ss = v
            loc[j] = (tt, rr, ss)
        return self.T.pose_world(loc)

    def skinned(self, world: dict) -> np.ndarray:
        """Positions and normals (n x 6) of the posed mesh."""
        M = np.stack([world[j] @ self.IBM[i] for i, j in enumerate(self.joints)])
        pos, nrm = np.zeros((len(self.P), 3)), np.zeros((len(self.P), 3))
        for k in range(4):
            Mk = M[self.J[:, k]]
            pos += self.W[:, k:k + 1] * np.einsum('nij,nj->ni', Mk, self.P)[:, :3]
            nrm += self.W[:, k:k + 1] * np.einsum('nij,nj->ni', Mk[:, :3, :3], self.N)
        nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
        return np.c_[pos, nrm]


def euler(v) -> np.ndarray:
    """Godot's Basis.from_euler (YXZ) of degrees."""
    x, y, z = (math.radians(float(a)) for a in v)
    rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    rz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
    return ry @ rx @ rz


def to_euler(m: np.ndarray) -> list:
    x = math.asin(-max(-1.0, min(1.0, m[1, 2])))
    if abs(math.cos(x)) < 1e-5:
        y, z = math.atan2(-m[2, 0], m[0, 0]), 0.0
    else:
        y, z = math.atan2(m[0, 2], m[2, 2]), math.atan2(m[1, 0], m[1, 1])
    return [round(math.degrees(a), 1) for a in (x, y, z)]


def poses(body: Body, entry: dict) -> list:
    """(clip, time, body points, hand place, hand turn) through every clip the entry's roles name (the attack's window)."""
    out = []
    wanted = [(role, entry.get('clips', {}).get(role)) for role in ROLES] + [('extra', c) for c in EXTRA]
    for role, specs in wanted:
        for spec in (specs if isinstance(specs, list) else [specs] if specs else []):
            name = spec.get('clip') if isinstance(spec, dict) else spec
            clip = body.clip(str(name))
            if not clip:
                continue
            end = body.length(clip)
            lo = float(spec.get('from', 0.0)) if isinstance(spec, dict) else 0.0
            hi = min(float(spec.get('to', end)), end) if isinstance(spec, dict) else end
            for t in np.linspace(lo, hi, SAMPLES):
                world = body.pose(clip, t)
                hand = world[body.T.name['RightHand']]
                out.append((clip, t, body.skinned(world)[body.keep], hand[:3, 3], hand[:3, :3] / np.linalg.norm(hand[:3, :3], axis=0)))
    return out


def blade(part: dict, height: float, longest: float, lo: float, hi: float, turn=None) -> np.ndarray:
    """Points along the part's long (y) axis in the hand's frame, as ModelFigure._hold_at places them."""
    s = float(part.get('size', 0.0)) * height / longest
    basis = euler(turn if turn is not None else part.get('turn', [0, 0, 0])) * s
    gy = float(part.get('grip', [0, 0, 0])[1])
    ys = np.linspace(gy + 0.1 * (hi - gy), hi, 16)   # the blade beyond the fist (the pommel below the grip is in the hand)
    pts = np.stack([np.zeros_like(ys), ys, np.zeros_like(ys)], 1) - np.array(part.get('grip', [0, 0, 0]), float)
    return (basis @ pts.T).T + np.array(part.get('offset', [0, 0, 0]), float) * height


def cuts(frames: list, local: np.ndarray, height: float, margin: float) -> dict:
    out = {}
    for clip, _t, body, place, turn in frames:
        w = place + (turn @ local.T).T
        diff = w[:, None, :] - body[None, :, :3]
        dist = np.sqrt((diff ** 2).sum(-1))
        k = dist.argmin(1)
        near = dist[np.arange(len(w)), k]
        inside = np.einsum('ij,ij->i', diff[np.arange(len(w)), k], body[k, 3:]) < 0
        hit = bool(((near < margin * height) | (inside & (near < 0.15 * height))).any())
        out.setdefault(clip, [0, 0])
        out[clip][0] += int(hit)
        out[clip][1] += 1
    return out


def across_palm(theta: float, phi: float) -> np.ndarray:
    """The part's turn with its blade out of the thumb side (the hand's +z on a Mixamo rig; its fingers run along +y),
    swung `theta` degrees toward the back of the hand and tilted `phi` toward the fingers."""
    t, p = math.radians(theta), math.radians(phi)
    d = math.cos(p) * np.array([math.sin(t), 0, math.cos(t)]) + math.sin(p) * np.array([0, 1.0, 0])
    x = np.array([1.0, 0, 0]) - d * d[0]
    x /= np.linalg.norm(x)
    return np.stack([x, d, np.cross(x, d)], 1)


def main(argv) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('figure')
    ap.add_argument('part')
    ap.add_argument('--margin', type=float, default=0.01, help='share of the figure height counted as touching')
    ap.add_argument('--search', action='store_true')
    a = ap.parse_args(argv)
    manifest = json.loads(MANIFEST.read_text())
    entry = dict(manifest.get('defaults', {}))
    entry.update(manifest['figures'][a.figure])
    clips = dict(manifest.get('defaults', {}).get('clips', {}))
    clips.update(manifest['figures'][a.figure].get('clips', {}))
    entry['clips'] = clips
    part = manifest['parts'][a.part]
    body = Body(REPO / entry['file'])
    pd, pb = FF.read_gltf(REPO / part['file'])
    lo = min(pd['accessors'][p['attributes']['POSITION']]['min'][1] for m in pd['meshes'] for p in m['primitives'])
    hi = max(pd['accessors'][p['attributes']['POSITION']]['max'][1] for m in pd['meshes'] for p in m['primitives'])
    size = [max(pd['accessors'][p['attributes']['POSITION']]['max'][i] for m in pd['meshes'] for p in m['primitives'])
            - min(pd['accessors'][p['attributes']['POSITION']]['min'][i] for m in pd['meshes'] for p in m['primitives']) for i in range(3)]
    longest = max(size)
    frames = poses(body, entry)
    now = cuts(frames, blade(part, body.height, longest, lo, hi), body.height, a.margin)
    total = sum(v[0] for v in now.values())
    print(f'{a.figure} holding {a.part} at turn {part.get("turn")}: cuts through in {total} of {len(frames)} poses',
          {k: v[0] for k, v in now.items() if v[0]})
    if a.search:
        best = []
        for theta, phi in itertools.product(range(-45, 46, 15), range(-60, 61, 15)):
            turn = to_euler(across_palm(theta, phi))
            c = cuts(frames, blade(part, body.height, longest, lo, hi, turn), body.height, a.margin)
            best.append((sum(v[0] for v in c.values()), abs(phi) + abs(theta), turn, theta, phi))
        best.sort()
        for n, _, turn, theta, phi in best[:8]:
            print(f'  turn {turn}: {n} poses cut (swung {theta}, tilted {phi})')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
