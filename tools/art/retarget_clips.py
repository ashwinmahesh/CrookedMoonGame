#!/usr/bin/env python3
"""Clips from the Universal Animation Library (Quaternius's skeleton) baked onto a Tripo figure (Mixamo-named skeleton).

A figure's shipped glb (art/figures/<id>.glb) gets a copy with the library's clips added under their pack names
(art/figures/<id>_ual.glb by default); the manifest entry for that file names which role plays which clip. Nothing else
in the file changes, so the figure keeps its mesh, its skin and its own Tripo clips.

How a pose moves across: each mapped bone is aimed the way the pack's bone points. For every bone the two rest poses
are lined up once (the bone's direction to its child, and a second direction across it: hip to hip, shoulder to
shoulder, index knuckle to little-finger knuckle), so an A-pose rest and a T-pose rest don't skew the arms. Then, frame
by frame, the target bone takes the pack bone's turn away from its own rest: Tw(t) = Sw(t) * Sw0^-1 * A * Tw0 (world
rotations; A lines the target's rest frame up with the pack's). The hips also move, scaled by the two hip heights.
Bones with no partner (finger tips, toe ends, the head top) keep their rest pose under their parent.

Works for any figure on the Mixamo names (every Tripo rig): the bone map is rigs.quaternius.bones in
art/figures/manifest.json read backwards, plus the fingers. A figure moved onto the pack names its Tripo-only entry in
`retarget_from` (rook_coldwake: "retarget_from": "rook_coldwake_tripo", whose file tools/art/figures.py keeps current), and
its own `file` is the bake; run this again whenever the Tripo file changes. Godot's import drops a clip name's "_Loop"
(Idle_Loop plays as Idle), so the manifest names the loops without it.

  python3 tools/art/retarget_clips.py <figure id> [--clips A,B,...] [--out <glb>] [--fps 30]
"""
import argparse, json, math, struct, sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / 'tools'))
sys.path.insert(0, str(REPO / 'tools/art'))
import free_figures as FF  # noqa: E402  (its glTF reader and writer)

UAL1 = REPO / 'art/sourced/quaternius_universal_animation_library_source/UAL1.glb'
MANIFEST = REPO / 'art/figures/manifest.json'

# The clips a fighter and a caster use, by the pack's names.
DEFAULT_CLIPS = ['Idle_Loop', 'Walk_Loop', 'Jog_Fwd_Loop', 'Sword_Idle', 'Sword_Attack', 'Sword_Attack_Standing',
                 'Spell_Simple_Enter', 'Spell_Simple_Idle_Loop', 'Spell_Simple_Shoot', 'Spell_Simple_Exit', 'Spell_Double_Shoot_Loop',
                 'Hit_Chest', 'Death01', 'Idle_Talking_Loop', 'Interact', 'Punch_Jab', 'Punch_Cross']

FINGERS = {'Index': 'index', 'Middle': 'middle', 'Ring': 'ring', 'Pinky': 'pinky', 'Thumb': 'thumb'}

# The bone each bone points at (Mixamo names), and the second direction that fixes its twist (a pair of bones, from
# the first to the second). A bone with neither on one side keeps its parent's lining up.
AIM = {'Hips': 'Spine', 'Spine': 'Spine1', 'Spine1': 'Spine2', 'Spine2': 'Neck', 'Neck': 'Head',
       'LeftShoulder': 'LeftArm', 'LeftArm': 'LeftForeArm', 'LeftForeArm': 'LeftHand', 'LeftHand': 'LeftHandMiddle1',
       'RightShoulder': 'RightArm', 'RightArm': 'RightForeArm', 'RightForeArm': 'RightHand', 'RightHand': 'RightHandMiddle1',
       'LeftUpLeg': 'LeftLeg', 'LeftLeg': 'LeftFoot', 'LeftFoot': 'LeftToeBase',
       'RightUpLeg': 'RightLeg', 'RightLeg': 'RightFoot', 'RightFoot': 'RightToeBase'}
ACROSS_BODY = ('RightUpLeg', 'LeftUpLeg')
ACROSS = {'Hips': ACROSS_BODY, 'Spine': ('RightShoulder', 'LeftShoulder'), 'Spine1': ('RightShoulder', 'LeftShoulder'),
          'Spine2': ('RightShoulder', 'LeftShoulder'), 'Neck': ('RightShoulder', 'LeftShoulder'),
          'LeftUpLeg': ACROSS_BODY, 'LeftLeg': ACROSS_BODY, 'LeftFoot': ACROSS_BODY,
          'RightUpLeg': ACROSS_BODY, 'RightLeg': ACROSS_BODY, 'RightFoot': ACROSS_BODY}
for side in ('Left', 'Right'):
    palm = (f'{side}HandPinky1', f'{side}HandIndex1')
    for b in ('Shoulder', 'Arm', 'ForeArm', 'Hand'):
        ACROSS[side + b] = palm
    for f in FINGERS:
        for i in (1, 2, 3):
            AIM[f'{side}Hand{f}{i}'] = f'{side}Hand{f}{i + 1}'
            ACROSS[f'{side}Hand{f}{i}'] = palm


# --- Quaternions (x, y, z, w) -----------------------------------------------------------------------------------------

def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz])


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]]) / max(np.dot(q, q), 1e-12)


def qrot(q, v):
    return qmul(qmul(q, np.array([v[0], v[1], v[2], 0.0])), qinv(q))[:3]


def qnorm(q):
    return q / max(np.linalg.norm(q), 1e-12)


def qslerp(a, b, t):
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        return qnorm(a + (b - a) * t)
    th = math.acos(d)
    return (math.sin((1 - t) * th) * a + math.sin(t * th) * b) / math.sin(th)


def qfrom_matrix(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        return qnorm(np.array([(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]))
    i = int(np.argmax([m[0, 0], m[1, 1], m[2, 2]]))
    if i == 0:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        return qnorm(np.array([0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]))
    if i == 1:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        return qnorm(np.array([(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]))
    s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
    return qnorm(np.array([(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]))


def qfrom_to(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    c = np.cross(a, b)
    d = float(np.dot(a, b))
    if d < -0.99999:
        axis = np.cross(a, [1, 0, 0]) if abs(a[0]) < 0.9 else np.cross(a, [0, 1, 0])
        return qnorm(np.array([*axis, 0.0]))
    return qnorm(np.array([c[0], c[1], c[2], 1.0 + d]))


def frame(primary, secondary):
    """An orthonormal basis (columns) from a direction and a second one across it."""
    x = primary / np.linalg.norm(primary)
    y = secondary - x * np.dot(secondary, x)
    y = y / np.linalg.norm(y)
    return np.stack([x, y, np.cross(x, y)], axis=1)


def trs_matrix(t, r, s):
    m = np.eye(4)
    x, y, z, w = r
    rot = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                    [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                    [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m[:3, :3] = rot * np.array(s)[None, :]
    m[:3, 3] = t
    return m


# --- Reading a skeleton -----------------------------------------------------------------------------------------------

def accessor(doc, binary, index):
    a = doc['accessors'][index]
    raw = FF.accessor_bytes(doc, binary, index)
    assert a['componentType'] == 5126, 'float accessors only'
    return np.frombuffer(raw, dtype='<f4').reshape(a['count'], FF.COUNTS[a['type']]).astype(np.float64)


class Skeleton:
    def __init__(self, doc, binary, strip_prefix=False):
        self.doc, self.bin = doc, binary
        self.nodes = doc['nodes']
        self.parent = {}
        for i, n in enumerate(self.nodes):
            for c in n.get('children', []):
                self.parent[c] = i
        self.joints = list(doc['skins'][0]['joints'])
        self.name = {}
        for i in self.joints:
            n = self.nodes[i].get('name', '')
            if strip_prefix and ':' in n:
                n = n.split(':', 1)[1]
            self.name[n] = i
        self.rest = {i: (np.array(n.get('translation', [0, 0, 0]), float), qnorm(np.array(n.get('rotation', [0, 0, 0, 1]), float)),
                         np.array(n.get('scale', [1, 1, 1]), float)) for i, n in enumerate(self.nodes)}
        # Joints parents first.
        order, seen = [], set()

        def visit(i):
            if i in seen:
                return
            p = self.parent.get(i)
            if p is not None and p in self.joints:
                visit(p)
            seen.add(i)
            order.append(i)
        for j in self.joints:
            visit(j)
        self.order = order

    def outer_world(self, i):
        """The world matrix of node i's parent chain above the joints (armature nodes), as a matrix."""
        m = np.eye(4)
        p = self.parent.get(i)
        chain = []
        while p is not None:
            chain.append(p)
            p = self.parent.get(p)
        for p in reversed(chain):
            if p in self.joints:
                break
            t, r, s = self.rest[p]
            m = m @ trs_matrix(t, r, s)
        return m

    def pose_world(self, local):
        """World (matrix) of every joint, from local {joint: (t, r, s)} (rest where missing)."""
        out = {}
        for j in self.order:
            t, r, s = local.get(j, self.rest[j])
            p = self.parent.get(j)
            base = out[p] if p in out else self.outer_world(j)
            out[j] = base @ trs_matrix(t, r, s)
        return out


def world_rot(m):
    r = m[:3, :3] / np.linalg.norm(m[:3, :3], axis=0)[None, :]
    return qfrom_matrix(r)


def sample(times, values, t, interp, is_quat):
    if t <= times[0]:
        return values[0]
    if t >= times[-1]:
        return values[-1]
    k = int(np.searchsorted(times, t) - 1)
    if interp == 'STEP':
        return values[k]
    u = (t - times[k]) / max(times[k + 1] - times[k], 1e-9)
    if is_quat:
        return qslerp(values[k], values[k + 1], u)
    return values[k] + (values[k + 1] - values[k]) * u


# --- The bake ---------------------------------------------------------------------------------------------------------

def bone_map():
    rig = json.loads(MANIFEST.read_text())['rigs']['quaternius']['bones']
    out = {mix: q for mix, q in rig.items() if q}
    out.setdefault('Head', 'Head')   # the rig map leaves out names the two skeletons share
    for side, s in (('Left', 'l'), ('Right', 'r')):
        for f, q in FINGERS.items():
            for i in (1, 2, 3, 4):
                out[f'{side}Hand{f}{i}'] = f'{q}_0{i}_{s}' if i < 4 else f'{q}_04_leaf_{s}'
    return out


def bake(figure: Path, out: Path, clips: list, fps: float) -> None:
    tdoc, tbin = FF.read_gltf(figure)
    sdoc, sbin = FF.read_gltf(UAL1)
    T = Skeleton(tdoc, tbin, strip_prefix=True)
    S = Skeleton(sdoc, sbin)
    mapping = {m: q for m, q in bone_map().items() if m in T.name and q in S.name}
    Tw0 = T.pose_world({})
    Sw0 = S.pose_world({})
    tpos = lambda b: Tw0[T.name[b]][:3, 3]
    spos = lambda b: Sw0[S.name[mapping[b]]][:3, 3]

    # The two models face the same way (glTF +Z) when their toes point alike; else the pack turns about Y to match.
    def forward(pos):
        v = (pos('LeftToeBase') + pos('RightToeBase')) / 2 - (pos('LeftFoot') + pos('RightFoot')) / 2
        v[1] = 0
        return v
    G = qfrom_to(forward(spos), forward(tpos))
    gp = lambda v: qrot(G, v)

    # Lining up each mapped bone's rest frame (target -> pack, in the target's world).
    align = {}
    for mix in [T.nodes[j].get('name', '').split(':')[-1] for j in T.order]:
        if mix not in mapping:
            continue
        aim, across = AIM.get(mix), ACROSS.get(mix)
        if aim in mapping and across and all(b in mapping for b in across):
            ft = frame(tpos(aim) - tpos(mix), tpos(across[1]) - tpos(across[0]))
            fs = frame(gp(spos(aim) - spos(mix)), gp(spos(across[1]) - spos(across[0])))
            align[mix] = qfrom_matrix(fs @ ft.T)
        elif aim in mapping:
            align[mix] = qfrom_to(tpos(aim) - tpos(mix), gp(spos(aim) - spos(mix)))
        else:
            p = T.parent.get(T.name[mix])
            pname = T.nodes[p].get('name', '').split(':')[-1] if p is not None else ''
            align[mix] = align.get(pname, np.array([0, 0, 0, 1.0]))

    hips_t, hips_s = T.name['Hips'], S.name[mapping['Hips']]
    t_floor = min(tpos('LeftToeBase')[1], tpos('RightToeBase')[1])
    s_floor = min(spos('LeftToeBase')[1], spos('RightToeBase')[1])
    hip_scale = (tpos('Hips')[1] - t_floor) / max(spos('Hips')[1] - s_floor, 1e-6)

    w = FF.Writer()
    # Copy the figure's own buffers through the writer: its views as they are (accessors keep their indices).
    for v in tdoc.get('bufferViews', []):
        chunk = tbin[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        nv = w.view(chunk, v.get('target', 0))
        if 'byteStride' in v:
            w.views[nv]['byteStride'] = v['byteStride']
    new_acc = list(tdoc.get('accessors', []))

    def add(arr, kind):
        data = np.ascontiguousarray(arr, dtype='<f4')
        view = w.view(data.tobytes())
        a = {'bufferView': view, 'componentType': 5126, 'count': int(data.shape[0]), 'type': kind}
        if kind == 'SCALAR':
            a['min'] = [float(data.min())]
            a['max'] = [float(data.max())]
        new_acc.append(a)
        return len(new_acc) - 1

    by_name = {a['name']: a for a in sdoc['animations']}
    anims = list(tdoc.get('animations', []))
    have = {a['name'] for a in anims}
    for clip_name in clips:
        if clip_name not in by_name:
            print(f'  no clip {clip_name} in the pack', file=sys.stderr)
            continue
        if clip_name in have:
            continue
        clip = by_name[clip_name]
        tracks = {}
        end = 0.0
        for ch in clip['channels']:
            smp = clip['samplers'][ch['sampler']]
            times = accessor(sdoc, sbin, smp['input'])[:, 0]
            vals = accessor(sdoc, sbin, smp['output'])
            end = max(end, float(times[-1]))
            tracks[(ch['target']['node'], ch['target']['path'])] = (times, vals, smp.get('interpolation', 'LINEAR'))
        frames = max(2, int(round(end * fps)) + 1)
        times = np.linspace(0.0, end, frames)
        rot_out = {j: np.zeros((frames, 4)) for j in T.joints}
        hips_out = np.zeros((frames, 3))
        for f, t in enumerate(times):
            local = {}
            for j in S.joints:
                rt, rr, rs = S.rest[j]
                tr = tracks.get((j, 'translation'))
                rq = tracks.get((j, 'rotation'))
                local[j] = (sample(*tr[:2], t, tr[2], False) if tr else rt,
                            qnorm(sample(*rq[:2], t, rq[2], True)) if rq else rr, rs)
            Sw = S.pose_world(local)
            # The target's world rotations, parents first.
            tw = {}
            for j in T.order:
                mix = T.nodes[j].get('name', '').split(':')[-1]
                p = T.parent.get(j)
                parent_w = tw[p] if p in tw else world_rot(T.outer_world(j))
                if mix in mapping:
                    sj = S.name[mapping[mix]]
                    turn = qmul(world_rot(Sw[sj]), qinv(world_rot(Sw0[sj])))
                    turn = qmul(qmul(G, turn), qinv(G))
                    tw[j] = qnorm(qmul(qmul(turn, align[mix]), world_rot(Tw0[j])))
                else:
                    tw[j] = qnorm(qmul(parent_w, T.rest[j][1]))
                local_r = qnorm(qmul(qinv(parent_w), tw[j]))
                prev = rot_out[j][f - 1] if f else None
                if prev is not None and np.dot(prev, local_r) < 0:
                    local_r = -local_r
                rot_out[j][f] = local_r
            # The hips: the pack's move from its rest, turned to face the same way and scaled to the figure.
            moved = gp(Sw[hips_s][:3, 3] - Sw0[hips_s][:3, 3]) * hip_scale
            want = Tw0[hips_t][:3, 3] + moved
            parent_m = T.outer_world(hips_t)
            p = T.parent.get(hips_t)
            if p in T.joints:
                parent_m = Tw0[p]
            hips_out[f] = (np.linalg.inv(parent_m) @ np.array([*want, 1.0]))[:3]
        tin = add(times[:, None], 'SCALAR')
        tone = add(np.array([[0.0]]), 'SCALAR')
        samplers, channels = [], []
        for j in T.joints:
            samplers.append({'input': tin, 'output': add(rot_out[j], 'VEC4'), 'interpolation': 'LINEAR'})
            channels.append({'sampler': len(samplers) - 1, 'target': {'node': j, 'path': 'rotation'}})
            if j == hips_t:
                samplers.append({'input': tin, 'output': add(hips_out, 'VEC3'), 'interpolation': 'LINEAR'})
            else:
                samplers.append({'input': tone, 'output': add(np.array([T.rest[j][0]]), 'VEC3'), 'interpolation': 'STEP'})
            channels.append({'sampler': len(samplers) - 1, 'target': {'node': j, 'path': 'translation'}})
            samplers.append({'input': tone, 'output': add(np.array([T.rest[j][2]]), 'VEC3'), 'interpolation': 'STEP'})
            channels.append({'sampler': len(samplers) - 1, 'target': {'node': j, 'path': 'scale'}})
        anims.append({'name': clip_name, 'samplers': samplers, 'channels': channels})
        print(f'  {clip_name}: {frames} frames, {end:.2f} s')
    tdoc['bufferViews'] = w.views
    tdoc['accessors'] = new_acc
    tdoc['animations'] = anims
    for img in tdoc.get('images', []):
        img.pop('uri', None)
    FF.write_glb(out, tdoc, bytes(w.binary))
    print(f'{out}: {len(anims)} clips, {out.stat().st_size / 1e6:.1f} MB')


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('figure', help="a manifest figure id: one with `retarget_from` is baked from that entry's file into its own")
    ap.add_argument('--clips', default=','.join(DEFAULT_CLIPS))
    ap.add_argument('--out', default='')
    ap.add_argument('--fps', type=float, default=30.0)
    a = ap.parse_args(argv)
    figures = json.loads(MANIFEST.read_text())['figures']
    entry = figures.get(a.figure, {})
    if entry.get('retarget_from'):
        src = REPO / figures[entry['retarget_from']]['file']
        out = Path(a.out) if a.out else REPO / entry['file']
    else:
        src = REPO / 'art/figures' / f'{a.figure}.glb'
        out = Path(a.out) if a.out else REPO / 'art/figures' / f'{a.figure}_ual.glb'
    bake(src, out, [c for c in a.clips.split(',') if c], a.fps)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
