#!/usr/bin/env python3
"""Free CC0 models into the figure pipeline (art/figures/manifest.json, tools/art/figures.py).

The packs sit untouched on the asset SSD (<asset root>/sourced/<pack>/pack/ ...) and, for the files the game uses, in
art/sourced/<pack>/. This script makes the figures' source files from them under <asset root>/free_models/, which
`python3 tools/art/figures.py` then ships (textures cut to 2K, clip names tidied) to the manifest entries' `file`s:

- villager_gray.glb: Quaternius's Universal Base Characters Superhero_Male (the body alone: its hair and eye meshes are
  left out, because a manifest `albedo` paints every textured surface) with Universal Animation Library 1 and 2 clips
  added (both rigs share their bones), the hands named RightHand and LeftHand as the manifest's parts expect (the pack
  calls them hand_r and hand_l). Its base-colour picture is clay grey; villager_brown_albedo.png and
  villager_red_albedo.png are two outfits painted on the same UVs, from the skin weights (tunic, sleeves, trousers,
  boots, hair), for manifest entries that lay them over the body (`base` + `albedo_source`).
- weapons/<id>.glb: the held weapons, from Quaternius's Modular Weapons Pack (OBJ) and KayKit's Adventurers (glTF).
- hair/<id>.glb: two of the pack's hairstyles (skinned to the head bone, in the body's own space), worn as skinned layers.
- warhorse.glb: Quaternius's Horse with its clips listed once (the pack's GLB repeats each with an armature prefix).

  /Users/.../venv/bin/python tools/art/free_figures.py [villager|weapons|hair|warhorse] ...   (Pillow and numpy for the outfits)
"""
import copy, json, math, struct, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / 'tools'))
from asset_root import asset_root  # noqa: E402

ROOT = asset_root()
SRC = ROOT / 'sourced'
OUT = ROOT / 'free_models'

UBC = SRC / 'quaternius_universal_base_characters/pack/Universal Base Characters[Standard]/Base Characters'
UAL1 = SRC / 'quaternius_universal_animation_library/pack/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb'
UAL2 = SRC / 'quaternius_universal_animation_library_2/pack/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb'
WEAPONS = SRC / 'quaternius_modular_weapons_pack/pack/Medieval Weapons Pack - Sept 2018/OBJ'
KAYKIT = SRC / 'kaykit_adventurers/pack/KayKit_Adventurers_2.0_FREE/Assets/gltf'
HORSE = SRC / 'quaternius_ultimate_animated_animal_pack/glb/Horse.glb'
HAIR_DIR = UBC.parent / 'Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)'
HAIR = {'hair_parted': 'Hair_SimpleParted', 'hair_buzzed': 'Hair_Buzzed'}

# The clips the villager keeps from the two Universal Animation Libraries (each library's 43 would be 11 MB of tracks).
CLIPS_1 = ['Idle_Loop', 'Walk_Loop', 'Jog_Fwd_Loop', 'Sprint_Loop', 'Sword_Attack', 'Sword_Idle', 'Spell_Simple_Shoot',
           'Spell_Simple_Idle_Loop', 'Hit_Chest', 'Hit_Head', 'Death01', 'Idle_Talking_Loop', 'Interact', 'Idle_Torch_Loop',
           'Punch_Cross', 'Roll', 'Crouch_Idle_Loop', 'Crouch_Fwd_Loop']
CLIPS_2 = ['Yes', 'Sword_Regular_A', 'Melee_Hook', 'Hit_Knockback', 'Idle_Lantern_Loop', 'Idle_FoldArms_Loop', 'Sword_Block',
           'Walk_Carry_Loop', 'OverhandThrow']
RENAMES = {'hand_r': 'RightHand', 'hand_l': 'LeftHand'}

GLB_MAGIC, CHUNK_JSON, CHUNK_BIN = 0x46546C67, 0x4E4F534A, 0x004E4942
SIZES = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
COUNTS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT2': 4, 'MAT3': 9, 'MAT4': 16}


# --- glTF in and out -----------------------------------------------------------------------------------------------------

def read_gltf(path: Path):
    """(doc, binary) of a .glb, or of a .gltf with its external buffer and images folded in as bufferViews."""
    data = path.read_bytes()
    if path.suffix.lower() == '.glb':
        doc, binary, off = None, b'', 12
        while off < len(data):
            size, kind = struct.unpack_from('<II', data, off)
            chunk = data[off + 8:off + 8 + size]
            if kind == CHUNK_JSON:
                doc = json.loads(chunk)
            elif kind == CHUNK_BIN:
                binary = chunk
            off += 8 + size
        return doc, binary
    doc = json.loads(data)
    binary = bytearray()
    for buf in doc.get('buffers', []):
        binary += (path.parent / buf['uri']).read_bytes()
        binary += b'\0' * (-len(binary) % 4)
        break   # one buffer, as the exporters here write
    for img in doc.get('images', []):
        if 'uri' in img:
            if not (path.parent / img['uri']).exists():
                continue   # the Universal Base Characters' hair normal map is named for a file the pack lacks; the body doesn't use it
            bytes_ = (path.parent / img['uri']).read_bytes()
            binary += b'\0' * (-len(binary) % 4)
            doc.setdefault('bufferViews', []).append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(bytes_)})
            img['bufferView'] = len(doc['bufferViews']) - 1
            img['mimeType'] = 'image/png' if str(img['uri']).lower().endswith('.png') else 'image/jpeg'
            del img['uri']
            binary += bytes_
    return doc, bytes(binary)


def write_glb(path: Path, doc: dict, binary: bytes) -> None:
    doc['buffers'] = [{'byteLength': len(binary)}]
    js = json.dumps(doc, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    binary += b'\0' * (-len(binary) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack('<III', GLB_MAGIC, 2, total) + struct.pack('<II', len(js), CHUNK_JSON) + js
                     + struct.pack('<II', len(binary), CHUNK_BIN) + binary)


def accessor_bytes(doc: dict, binary: bytes, index: int) -> bytes:
    """An accessor's elements tightly packed (a strided view repacked)."""
    a = doc['accessors'][index]
    assert 'sparse' not in a, 'sparse accessors are not handled'
    elem = SIZES[a['componentType']] * COUNTS[a['type']]
    v = doc['bufferViews'][a['bufferView']]
    start, stride = v.get('byteOffset', 0) + a.get('byteOffset', 0), v.get('byteStride', 0) or elem
    if stride == elem:
        return binary[start:start + elem * a['count']]
    return b''.join(binary[start + i * stride:start + i * stride + elem] for i in range(a['count']))


class Writer:
    """A new glTF's binary and views, accessors copied in from other files (each once)."""

    def __init__(self) -> None:
        self.binary = bytearray()
        self.views: list = []
        self.accessors: list = []
        self._seen: dict = {}

    def view(self, chunk: bytes, target: int = 0) -> int:
        self.binary += b'\0' * (-len(self.binary) % 4)
        v = {'buffer': 0, 'byteOffset': len(self.binary), 'byteLength': len(chunk)}
        if target:
            v['target'] = target
        self.binary += chunk
        self.views.append(v)
        return len(self.views) - 1

    def accessor(self, src_doc: dict, src_bin: bytes, index: int, target: int = 0) -> int:
        key = (id(src_doc), index, target)
        if key not in self._seen:
            a = dict(src_doc['accessors'][index])
            a['bufferView'] = self.view(accessor_bytes(src_doc, src_bin, index), target)
            a.pop('byteOffset', None)
            self.accessors.append(a)
            self._seen[key] = len(self.accessors) - 1
        return self._seen[key]


def triangles(doc: dict) -> int:
    t = 0
    for m in doc.get('meshes', []):
        for p in m['primitives']:
            t += (doc['accessors'][p['indices']]['count'] if 'indices' in p else doc['accessors'][p['attributes']['POSITION']]['count']) // 3
    return t


# --- The villager ----------------------------------------------------------------------------------------------------------

ZONES = ['head', 'torso', 'upper_arm', 'forearm', 'hand', 'thigh', 'calf', 'foot']


def zone_of(joint: str) -> str:
    j = joint.lower()
    if j in ('head', 'neck_01'):
        return 'head'
    if j.startswith('upperarm') or j.startswith('clavicle'):
        return 'upper_arm' if j.startswith('upperarm') else 'torso'
    if j.startswith('lowerarm'):
        return 'forearm'
    if j.startswith(('hand', 'righthand', 'lefthand', 'index', 'middle', 'pinky', 'ring', 'thumb')):
        return 'hand'
    if j.startswith('thigh'):
        return 'thigh'
    if j.startswith('calf'):
        return 'calf'
    if j.startswith(('foot', 'ball')):
        return 'foot'
    return 'torso'   # root, pelvis, spines


# Outfits: a colour per zone (None keeps the skin), a hair colour and a belt.
OUTFITS = {
    'gray': {'torso': (0.62,) * 3, 'upper_arm': (0.62,) * 3, 'forearm': (0.62,) * 3, 'hand': (0.62,) * 3, 'head': (0.62,) * 3,
             'thigh': (0.55,) * 3, 'calf': (0.55,) * 3, 'foot': (0.45,) * 3, 'hair': (0.5,) * 3, 'belt': (0.4,) * 3, 'flat': True},
    'brown': {'torso': (0.47, 0.31, 0.17), 'upper_arm': (0.47, 0.31, 0.17), 'forearm': None, 'hand': None, 'head': None,
              'thigh': (0.26, 0.21, 0.15), 'calf': (0.26, 0.21, 0.15), 'foot': (0.13, 0.09, 0.06), 'hair': (0.2, 0.12, 0.07),
              'belt': (0.09, 0.06, 0.04)},
    'red': {'torso': (0.58, 0.13, 0.11), 'upper_arm': (0.58, 0.13, 0.11), 'forearm': (0.58, 0.13, 0.11), 'hand': None, 'head': None,
            'thigh': (0.2, 0.21, 0.25), 'calf': (0.2, 0.21, 0.25), 'foot': (0.2, 0.14, 0.08), 'hair': (0.62, 0.5, 0.22),
            'belt': (0.45, 0.35, 0.1)},
}


def build_villager() -> None:
    body_doc, body_bin = read_gltf(UBC / 'Godot - UE/Superhero_Male_FullBody.gltf')
    w = Writer()
    nodes = copy.deepcopy(body_doc['nodes'])
    mesh_node = next(i for i, n in enumerate(nodes) if n.get('name') == 'SuperHero_Male')
    skin = body_doc['skins'][0]
    # Only the body's skinned mesh stays: the eyebrows' and eyes' nodes lose their meshes and leave their parents.
    drop = {i for i, n in enumerate(nodes) if 'mesh' in n and i != mesh_node}
    for i in drop:
        nodes[i].pop('mesh', None)
        nodes[i].pop('skin', None)
    for n in nodes:
        if 'children' in n:
            n['children'] = [c for c in n['children'] if c not in drop]
            if not n['children']:
                del n['children']
    for n in nodes:
        n['name'] = RENAMES.get(n.get('name', ''), n.get('name', ''))
    prim = body_doc['meshes'][nodes[mesh_node]['mesh']]['primitives'][0]
    attrs = {k: w.accessor(body_doc, body_bin, prim['attributes'][k], 34962)
             for k in ('POSITION', 'NORMAL', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0')}
    mesh = {'name': 'Villager', 'primitives': [{'attributes': attrs, 'indices': w.accessor(body_doc, body_bin, prim['indices'], 34963),
                                                'material': 0}]}
    nodes[mesh_node]['mesh'] = 0
    doc = {'asset': {'version': '2.0', 'generator': 'tools/art/free_figures.py'}, 'scene': 0, 'scenes': body_doc['scenes'],
           'nodes': nodes, 'meshes': [mesh],
           'skins': [{'name': skin.get('name', 'Armature'), 'joints': skin['joints'],
                      'inverseBindMatrices': w.accessor(body_doc, body_bin, skin['inverseBindMatrices'])}],
           'materials': [{'name': 'villager', 'doubleSided': False,
                          'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0, 'roughnessFactor': 0.85}}],
           'textures': [{'source': 0}], 'images': [{'bufferView': -1, 'mimeType': 'image/png'}], 'animations': []}
    name_to_node = {n['name']: i for i, n in enumerate(nodes)}
    # The clips: each channel finds its bone by name, each sampler's tracks are copied once.
    for lib_path, wanted in ((UAL1, CLIPS_1), (UAL2, CLIPS_2)):
        ual, ual_bin = read_gltf(lib_path)
        ual_names = [RENAMES.get(n.get('name', ''), n.get('name', '')) for n in ual['nodes']]
        for clip in ual['animations']:
            if clip['name'] not in wanted:
                continue
            samplers, remap, channels = [], {}, []
            for ch in clip['channels']:
                target = name_to_node.get(ual_names[ch['target']['node']])
                if target is None:
                    continue
                s = ch['sampler']
                if s not in remap:
                    src = clip['samplers'][s]
                    samplers.append({'input': w.accessor(ual, ual_bin, src['input']), 'output': w.accessor(ual, ual_bin, src['output']),
                                     'interpolation': src.get('interpolation', 'LINEAR')})
                    remap[s] = len(samplers) - 1
                channels.append({'sampler': remap[s], 'target': {'node': target, 'path': ch['target']['path']}})
            doc['animations'].append({'name': clip['name'], 'samplers': samplers, 'channels': channels})
    # The pictures: clay grey on the glb, the outfits beside it.
    tex = UBC / 'Textures/T_Superhero_Male_Ligh.png'
    pngs = paint_outfits(body_doc, body_bin, prim, skin, tex)
    doc['images'][0]['bufferView'] = w.view(pngs['gray'])
    doc['bufferViews'] = w.views
    doc['accessors'] = w.accessors
    out = OUT / 'villager_gray.glb'
    write_glb(out, doc, bytes(w.binary))
    for k in ('brown', 'red'):
        (OUT / f'villager_{k}_albedo.png').write_bytes(pngs[k])
    missing = [c for c in CLIPS_1 + CLIPS_2 if c not in [a['name'] for a in doc['animations']]]
    print(f'{out}: {triangles(doc)} triangles, {len(doc["animations"])} clips, {out.stat().st_size / 1e6:.1f} MB'
          + (f', clips not found: {missing}' if missing else ''))


def paint_outfits(body_doc: dict, body_bin: bytes, prim: dict, skin: dict, tex_path: Path) -> dict:
    """PNG bytes of the clay and the two outfits, painted over the skin texture where the body's skin weights say which
    part of the body each texel belongs to."""
    import io
    import numpy as np
    from PIL import Image, ImageFilter
    f32 = lambda i: np.frombuffer(accessor_bytes(body_doc, body_bin, i), dtype='<f4')   # noqa: E731
    pos = f32(prim['attributes']['POSITION']).reshape(-1, 3)
    uv = f32(prim['attributes']['TEXCOORD_0']).reshape(-1, 2)
    ja = body_doc['accessors'][prim['attributes']['JOINTS_0']]
    joints = np.frombuffer(accessor_bytes(body_doc, body_bin, prim['attributes']['JOINTS_0']),
                           dtype='<u1' if ja['componentType'] == 5121 else '<u2').reshape(-1, 4)
    wa = body_doc['accessors'][prim['attributes']['WEIGHTS_0']]
    weights = np.frombuffer(accessor_bytes(body_doc, body_bin, prim['attributes']['WEIGHTS_0']), dtype='<f4').reshape(-1, 4) \
        if wa['componentType'] == 5126 else np.frombuffer(accessor_bytes(body_doc, body_bin, prim['attributes']['WEIGHTS_0']),
                                                          dtype='<u2' if wa['componentType'] == 5123 else '<u1').reshape(-1, 4) / (
            65535.0 if wa['componentType'] == 5123 else 255.0)
    ia = body_doc['accessors'][prim['indices']]
    idx = np.frombuffer(accessor_bytes(body_doc, body_bin, prim['indices']),
                        dtype={5125: '<u4', 5123: '<u2', 5121: '<u1'}[ia['componentType']]).astype(np.int64).reshape(-1, 3)
    joint_names = [body_doc['nodes'][j]['name'] for j in skin['joints']]
    zone_ix = {z: i for i, z in enumerate(ZONES)}
    joint_zone = np.array([zone_ix[zone_of(n)] for n in joint_names])
    vz = np.zeros((len(pos), len(ZONES)), dtype=np.float32)
    for k in range(4):
        np.add.at(vz, (np.arange(len(pos)), joint_zone[joints[:, k]]), weights[:, k])
    # Hair and belt are extra zones cut from the head and torso by height.
    ymin, ymax = float(pos[:, 1].min()), float(pos[:, 1].max())
    head_ix = zone_ix['head']
    head_y = pos[vz.argmax(1) == head_ix][:, 1]
    hair_line = ymax - 0.07   # the forehead's top: the head is about a quarter of a metre tall, the eyes 0.12 below its top
    belt_y = float(pos[vz.argmax(1) == zone_ix['thigh']][:, 1].max())   # where the thighs start
    extra = np.zeros((len(pos), 2), dtype=np.float32)   # hair, belt
    top = pos[:, 1] > hair_line
    extra[(vz.argmax(1) == head_ix) & top, 0] = 1.0
    back = (pos[:, 2] < float(np.median(pos[vz.argmax(1) == head_ix][:, 2])) - 0.02) & (vz.argmax(1) == head_ix) & (pos[:, 1] > ymax - 0.16)
    extra[back, 0] = 1.0
    extra[(vz.argmax(1) == zone_ix['torso']) & (np.abs(pos[:, 1] - belt_y) < 0.035), 1] = 1.0
    feat = np.concatenate([vz, extra], axis=1)
    size = 2048
    skin_img = Image.open(tex_path).convert('RGB')
    if skin_img.size != (size, size):
        skin_img = skin_img.resize((size, size), Image.LANCZOS)
    acc = np.zeros((size, size, feat.shape[1]), dtype=np.float32)
    covered = np.zeros((size, size), dtype=bool)
    px = uv * size
    for a, b, c in idx:
        p0, p1, p2 = px[a], px[b], px[c]
        x0, x1 = int(max(0, math.floor(min(p0[0], p1[0], p2[0])))), int(min(size - 1, math.ceil(max(p0[0], p1[0], p2[0]))))
        y0, y1 = int(max(0, math.floor(min(p0[1], p1[1], p2[1])))), int(min(size - 1, math.ceil(max(p0[1], p1[1], p2[1]))))
        if x1 < x0 or y1 < y0:
            continue
        den = (p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1])
        if abs(den) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        l0 = ((p1[1] - p2[1]) * (gx - p2[0]) + (p2[0] - p1[0]) * (gy - p2[1])) / den
        l1 = ((p2[1] - p0[1]) * (gx - p2[0]) + (p0[0] - p2[0]) * (gy - p2[1])) / den
        l2 = 1.0 - l0 - l1
        inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        val = l0[..., None] * feat[a] + l1[..., None] * feat[b] + l2[..., None] * feat[c]
        sub = acc[y0:y1 + 1, x0:x1 + 1]
        sub[inside] = val[inside]
        covered[y0:y1 + 1, x0:x1 + 1] |= inside
    # A few pixels of bleed past the island edges, so mip levels and filtering find paint, not skin.
    for _ in range(6):
        grown = covered.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(np.roll(covered, dy, 0), dx, 1)
            take = shifted & ~grown
            src = np.roll(np.roll(acc, dy, 0), dx, 1)
            acc[take] = src[take]
            grown |= shifted
        covered = grown
    zone_map = acc[..., :len(ZONES)].argmax(-1)
    hair_map = acc[..., len(ZONES)] > 0.5
    belt_map = acc[..., len(ZONES) + 1] > 0.5
    skin_arr = np.asarray(skin_img).astype(np.float32) / 255.0
    lum = skin_arr @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    detail = (lum / max(float(lum[covered].mean()), 1e-3)).clip(0.5, 1.5)
    out = {}
    for name, outfit in OUTFITS.items():
        img = skin_arr.copy()
        flat = bool(outfit.get('flat'))
        for z, i in zone_ix.items():
            colour = outfit.get(z)
            if colour is None:
                continue
            m = (zone_map == i) & covered
            shade = (0.84 + 0.16 * detail) if not flat else (0.9 + 0.1 * detail)
            img[m] = (np.array(colour, dtype=np.float32) * shade[m, None]).clip(0, 1)
        for mask, key in ((hair_map, 'hair'), (belt_map, 'belt')):
            m = mask & covered & (zone_map == (head_ix if key == 'hair' else zone_ix['torso']))
            if outfit.get(key) is not None:
                img[m] = (np.array(outfit[key], dtype=np.float32) * (0.88 + 0.12 * detail[m, None])).clip(0, 1)
        im = Image.fromarray((img * 255).astype(np.uint8), 'RGB').filter(ImageFilter.GaussianBlur(0.6))
        buf = io.BytesIO()
        im.save(buf, 'PNG', optimize=True)
        out[name] = buf.getvalue()
    return out


# --- Weapons ---------------------------------------------------------------------------------------------------------------

# id: source file. Quaternius OBJs are exported Y up with the blade (or shaft) along Y.
OBJ_WEAPONS = {'dagger': 'Dagger', 'spear': 'Spear', 'bow': 'Bow_Wooden'}
KAYKIT_WEAPONS = {'staff': 'staff', 'greataxe': 'axe_2handed'}


def read_mtl(path: Path) -> dict:
    mats, cur = {}, None
    if not path.exists():
        return mats
    for line in path.read_text().splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == 'newmtl':
            cur = parts[1]
            mats[cur] = [0.8, 0.8, 0.8]
        elif parts[0] == 'Kd' and cur:
            mats[cur] = [float(v) for v in parts[1:4]]
    return mats


def obj_to_glb(src: Path, dst: Path) -> None:
    """A Wavefront OBJ (with its MTL) as a GLB: one primitive per material, flat colours, faces triangulated."""
    mats = read_mtl(src.with_suffix('.mtl'))
    v, vt, vn = [], [], []
    groups: dict = {}
    cur = None
    for line in src.read_text().splitlines():
        p = line.split()
        if not p:
            continue
        if p[0] == 'v':
            v.append([float(x) for x in p[1:4]])
        elif p[0] == 'vt':
            vt.append([float(p[1]), 1.0 - float(p[2])])
        elif p[0] == 'vn':
            vn.append([float(x) for x in p[1:4]])
        elif p[0] == 'usemtl':
            cur = p[1]
        elif p[0] == 'f':
            corners = []
            for c in p[1:]:
                s = c.split('/')
                corners.append((int(s[0]) - 1, int(s[1]) - 1 if len(s) > 1 and s[1] else -1, int(s[2]) - 1 if len(s) > 2 and s[2] else -1))
            for k in range(1, len(corners) - 1):
                groups.setdefault(cur, []).extend([corners[0], corners[k], corners[k + 1]])
    w = Writer()
    prims, materials = [], []
    lo, hi = [1e9] * 3, [-1e9] * 3
    for mi, (name, corners) in enumerate(groups.items()):
        pos = b''.join(struct.pack('<3f', *v[c[0]]) for c in corners)
        nor = b''.join(struct.pack('<3f', *(vn[c[2]] if c[2] >= 0 else [0, 1, 0])) for c in corners)
        for c in corners:
            for a in range(3):
                lo[a], hi[a] = min(lo[a], v[c[0]][a]), max(hi[a], v[c[0]][a])
        mn = [min(v[c[0]][a] for c in corners) for a in range(3)]
        mx = [max(v[c[0]][a] for c in corners) for a in range(3)]
        w.accessors.append({'bufferView': w.view(pos, 34962), 'componentType': 5126, 'count': len(corners), 'type': 'VEC3', 'min': mn, 'max': mx})
        w.accessors.append({'bufferView': w.view(nor, 34962), 'componentType': 5126, 'count': len(corners), 'type': 'VEC3'})
        prims.append({'attributes': {'POSITION': len(w.accessors) - 2, 'NORMAL': len(w.accessors) - 1}, 'material': mi})
        kd = mats.get(name, [0.8, 0.8, 0.8])
        materials.append({'name': str(name), 'pbrMetallicRoughness': {'baseColorFactor': [*kd, 1.0], 'metallicFactor': 0.0, 'roughnessFactor': 0.8}})
    doc = {'asset': {'version': '2.0', 'generator': 'tools/art/free_figures.py'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
           'nodes': [{'name': dst.stem, 'mesh': 0}], 'meshes': [{'name': dst.stem, 'primitives': prims}], 'materials': materials,
           'bufferViews': w.views, 'accessors': w.accessors}
    write_glb(dst, doc, bytes(w.binary))
    print(f'{dst}: {triangles(doc)} triangles, size {[round(hi[a] - lo[a], 3) for a in range(3)]}, min {[round(x, 3) for x in lo]}')


def build_weapons() -> None:
    for wid, stem in OBJ_WEAPONS.items():
        obj_to_glb(WEAPONS / f'{stem}.obj', OUT / 'weapons' / f'{wid}.glb')
    for wid, stem in KAYKIT_WEAPONS.items():
        doc, binary = read_gltf(KAYKIT / f'{stem}.gltf')
        dst = OUT / 'weapons' / f'{wid}.glb'
        doc.pop('buffers', None)
        write_glb(dst, doc, binary)
        box = [(doc['accessors'][p['attributes']['POSITION']]['min'], doc['accessors'][p['attributes']['POSITION']]['max'])
               for m in doc['meshes'] for p in m['primitives']]
        lo = [min(b[0][a] for b in box) for a in range(3)]
        hi = [max(b[1][a] for b in box) for a in range(3)]
        print(f'{dst}: {triangles(doc)} triangles, size {[round(hi[a] - lo[a], 3) for a in range(3)]}, min {[round(x, 3) for x in lo]}')


# --- Hair -------------------------------------------------------------------------------------------------------------------

def build_hair() -> None:
    """The hairstyles as GLBs with their base-colour picture folded in; the normal map is dropped (the figure shader does
    not use it, and tools/art/figures.py leaves unused pictures out anyway)."""
    for pid, stem in HAIR.items():
        doc, binary = read_gltf(HAIR_DIR / f'{stem}.gltf')
        for n in doc['nodes']:   # the hands are RightHand and LeftHand on the villager, so the hair's skin binds to those names
            n['name'] = RENAMES.get(n.get('name', ''), n.get('name', ''))
        mat = doc['materials'][0]
        mat.pop('normalTexture', None)
        tex = doc['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]
        image = doc['images'][tex['source']]
        doc['images'], doc['textures'] = [image], [{'source': 0, **({'sampler': tex['sampler']} if 'sampler' in tex else {})}]
        mat['pbrMetallicRoughness']['baseColorTexture']['index'] = 0
        out = OUT / 'hair' / f'{pid}.glb'
        doc.pop('buffers', None)
        write_glb(out, doc, binary)
        print(f'{out}: {triangles(doc)} triangles')


# --- The warhorse ----------------------------------------------------------------------------------------------------------

def build_warhorse() -> None:
    """The Horse with each clip once: the pack's GLB lists every clip twice, plain and as AnimalArmature|name."""
    doc, binary = read_gltf(HORSE)
    doc['animations'] = [a for a in doc['animations'] if '|' not in a.get('name', '')]
    # Unused accessors and views go with the repeats: rebuild the binary from what is still referenced.
    w = Writer()
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            for k, i in list(p['attributes'].items()):
                p['attributes'][k] = w.accessor(doc, binary, i, 34962)
            if 'indices' in p:
                p['indices'] = w.accessor(doc, binary, p['indices'], 34963)
    for s in doc['skins']:
        s['inverseBindMatrices'] = w.accessor(doc, binary, s['inverseBindMatrices'])
    for a in doc['animations']:
        for s in a['samplers']:
            s['input'] = w.accessor(doc, binary, s['input'])
            s['output'] = w.accessor(doc, binary, s['output'])
    doc['accessors'], doc['bufferViews'] = w.accessors, w.views
    out = OUT / 'warhorse.glb'
    write_glb(out, doc, bytes(w.binary))
    print(f'{out}: {triangles(doc)} triangles, clips {[a["name"] for a in doc["animations"]]}')


def main(argv: list) -> int:
    which = argv or ['villager', 'weapons', 'hair', 'warhorse']
    OUT.mkdir(parents=True, exist_ok=True)
    if 'villager' in which:
        build_villager()
    if 'weapons' in which:
        build_weapons()
    if 'hair' in which:
        build_hair()
    if 'warhorse' in which:
        build_warhorse()
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
