#!/usr/bin/env python3
"""The Quaternius pack people for the figure pipeline (art/figures/manifest.json, tools/art/figures.py): one male and one female
body, a head, an outfit and a hairstyle each, from Ashwin's Source packs (CC0; art/sourced/quaternius_*_source/ keeps the files
this reads, the whole packs sit on the asset root under sourced/).

Every file here is on Quaternius's one 65-joint skeleton (root, pelvis, spine_01..03, neck_01, Head, clavicle_l ... ball_r): the
joint names and rest pose of the bodies, the outfits, the hairstyles and the Universal Animation Library are the same, so
nothing is retargeted. This script makes the figures' source files under <asset root>/free_models/pack/, which
`python3 tools/art/figures.py` then ships (textures cut to 2K, images named) to the manifest entries' `file`s:

- pack_male.glb, pack_female.glb: the Regular body (FullBody: the skeleton, and the body mesh with no picture, since a head and
  an outfit are laid over it and hide it; it still gives the figure its height) with the clips the game uses, copied from the
  Universal Animation Library's Source glb (UAL1) and the Standard UAL2 for the few it has and UAL1 lacks (Yes, Idle_No_Loop,
  Sword_Block...). The clips keep the pack's names; the manifest's rigs.quaternius.clips names the roles they play (idle, walk,
  run, attack, hurt, die, talk, greet, ...).
- pack_<sex>_head.glb: the OnlyHead body (head, eyes, eyebrows) with the light skin, the brown eye and the hair picture.
- pack_<sex>_peasant.glb, pack_<sex>_noble.glb: the Peasant and the Noble outfit (arms, body, legs, feet) with the colour
  picture the pack gives it and the same light skin on its hands. The Noble's crown and pauldrons are left out (a village
  gentleman, not a knight); `peasant2`, `peasant3`, `noble2` and `noble3` are the pack's other colourings of the same
  models (olive and blue-and-cream peasants, blue and green nobles beside the red).
- pack_<sex>_hair_<style>.glb: a hairstyle rigged to the head bone, its picture coloured (HAIRS: browns and blacks, the
  greys and white of the elders, a beard for the men).
Normal and roughness maps are left out (the figure shader paints with the base-colour picture), so each file is small.

  /usr/bin/python3 tools/art/pack_figures.py [bodies] [parts] [outfits] [hairs]       (the default: all four; `parts` is the head,
  the first peasant and the first hair, `outfits` the other colourings and the nobles, `hairs` the rest of HAIRS)
"""
import copy, io, json, struct, sys
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / 'tools'))
sys.path.insert(0, str(REPO / 'tools/art'))
from asset_root import asset_root  # noqa: E402
import free_figures as FF  # noqa: E402  (its glTF reader and writer)

ROOT = asset_root()
SRC = ROOT / 'sourced'
OUT = ROOT / 'free_models' / 'pack'
UBC = SRC / 'quaternius_universal_base_characters_source/pack'
BODIES = UBC / 'Base Characters/Exports/Godot - UE'
SKIN_TEX = UBC / 'Base Characters/Textures'
HAIR = UBC / 'Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)'
OUTFITS = SRC / 'quaternius_modular_character_outfits_fantasy_source/pack/Modular Character Outfits - Fantasy[Source]'
UAL1 = SRC / 'quaternius_universal_animation_library_source/pack/Unreal-Godot/UAL1.glb'
UAL2 = SRC / 'quaternius_universal_animation_library_2/pack/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb'

SEXES = {
    'male': {'body': 'Regular_Male', 'skin': 'T_Regular_Male_Light_BaseColor.png', 'hair_colour': (0.30, 0.19, 0.11)},
    'female': {'body': 'Regular_Female', 'skin': 'T_Regular_Female_Light_BaseColor.png', 'hair_colour': (0.50, 0.27, 0.12)},
}

# The outfits: style -> the pack's model for each sex, its material (whose picture the colourings replace), the parts left out
# (nodes whose names hold one of these words), and how many colourings the pack's Textures/<Folder>/ has.
OUTFIT_STYLES = {
    'peasant': {'male': 'Male_Peasant', 'female': 'Female_Peasant', 'material': 'MI_Peasant', 'folder': 'Peasant', 'leave_out': (), 'colourings': 3},
    'noble': {'male': 'Male_Noble', 'female': 'Female_Noble', 'material': 'MI_Noble', 'folder': 'Noble', 'leave_out': ('Head_Crown', 'Pauldron'),
              'colourings': 3},
}

# The hairstyles, by the id a part is named for (pack_<sex>_hair_<id>): the pack's model and the colour its picture is painted
# (the pack's own is a mid grey that the game's materials would colour: here it is painted into the file). The first of a sex's is
# the one `parts` makes. Colours: brown, black, auburn, blond, the greys and white of the old.
BROWN, BLACK, AUBURN, BLOND, GREY, WHITE = (0.30, 0.19, 0.11), (0.09, 0.08, 0.07), (0.45, 0.2, 0.1), (0.62, 0.44, 0.2), (0.95, 0.95, 0.97), (1.6, 1.6, 1.65)
HAIRS = {
    'male': {
        'parted': ('Male/Hair_SimpleParted', BROWN), 'slick': ('Male/Hair_SlickBack', BLACK), 'ponytail': ('Male/Hair_Ponytail', AUBURN),
        'buzzed': ('Male/Hair_Buzzed', BLOND), 'parted_grey': ('Male/Hair_SimpleParted', GREY), 'balding_grey': ('Male/Hair_Balding', GREY),
        'balding_white': ('Male/Hair_Balding', WHITE), 'beard': ('Male/Hair_Beard', BROWN), 'beard_grey': ('Male/Hair_Beard', GREY),
        'beard_white': ('Male/Hair_Beard', WHITE), 'moustache': ('Male/Hair_Moustache', BLACK),
    },
    'female': {
        'buns': ('Female/Hair_Buns', (0.50, 0.27, 0.12)), 'bob': ('Female/Hair_Bob', BLACK), 'long': ('Female/Hair_Long', BLOND),
        'ponytail': ('Female/Hair_Ponytail_2', BROWN), 'buns_white': ('Female/Hair_Buns', WHITE), 'bob_grey': ('Female/Hair_Bob', GREY),
        'long_auburn': ('Female/Hair_Long', AUBURN),
    },
}

# The clips the game uses, by the pack's names (rigs.quaternius.clips in art/figures/manifest.json says which role plays which).
CLIPS_1 = ['Idle_Loop', 'Walk_Loop', 'Jog_Fwd_Loop', 'Sprint_Loop', 'Sword_Attack', 'Sword_Idle', 'Spell_Simple_Shoot',
           'Spell_Simple_Idle_Loop', 'Hit_Chest', 'Hit_Head', 'Hit_Stomach', 'Death01', 'Death02', 'Idle_Talking_Loop', 'Interact',
           'Idle_Torch_Loop', 'Idle_LookAround_Loop', 'Crying', 'Celebration', 'Counter_Angry', 'Sitting_Enter', 'Sitting_Idle_Loop',
           'Sitting_Exit', 'Roll']
CLIPS_2 = ['Yes', 'Idle_No_Loop', 'Sword_Block', 'Walk_Carry_Loop', 'Idle_FoldArms_Loop', 'Idle_Lantern_Loop']


def slim(doc: dict, binary: bytes, images: dict = None, tints: dict = None, leave_out: tuple = ()):
    """A copy of a glTF with only what its meshes, skin and (when asked) clips reach: the base-colour pictures of the materials
    (the file's, or a replacement path from `images`: image index -> file), none of the normal, roughness or occlusion maps.
    The nodes whose names hold a word of `leave_out` lose their meshes (a crown, a pauldron), and the meshes nothing uses go."""
    images = images or {}
    tints = tints or {}
    w = FF.Writer()
    nodes = copy.deepcopy(doc['nodes'])
    left = {i for i, n in enumerate(nodes) if 'mesh' in n and any(word in n.get('name', '') for word in leave_out)}
    for i in left:
        nodes[i].pop('mesh')
        nodes[i].pop('skin', None)
    for n in nodes:
        if 'children' in n:
            n['children'] = [c for c in n['children'] if c not in left]
    used = sorted({n['mesh'] for n in nodes if 'mesh' in n})
    mesh_index = {old: new for new, old in enumerate(used)}
    for n in nodes:
        if 'mesh' in n:
            n['mesh'] = mesh_index[n['mesh']]
    out = {'asset': {'version': '2.0', 'generator': 'tools/art/pack_figures.py'}, 'scene': doc.get('scene', 0), 'scenes': doc['scenes'],
           'nodes': nodes, 'meshes': [], 'skins': [], 'materials': [], 'textures': [], 'images': []}
    for mesh in (doc['meshes'][i] for i in used):
        m = copy.deepcopy(mesh)
        for p in m['primitives']:
            for k, i in list(p['attributes'].items()):
                p['attributes'][k] = w.accessor(doc, binary, i, 34962)
            if 'indices' in p:
                p['indices'] = w.accessor(doc, binary, p['indices'], 34963)
        out['meshes'].append(m)
    for s in doc.get('skins', []):
        s2 = copy.deepcopy(s)
        s2['inverseBindMatrices'] = w.accessor(doc, binary, s['inverseBindMatrices'])
        out['skins'].append(s2)
    image_of = {}
    for mat in doc.get('materials', []):
        m = copy.deepcopy(mat)
        pbr = m.get('pbrMetallicRoughness', {})
        ref = pbr.get('baseColorTexture')
        for key in ('normalTexture', 'occlusionTexture', 'emissiveTexture'):
            m.pop(key, None)
        pbr.pop('metallicRoughnessTexture', None)
        if ref is not None:
            tex = doc['textures'][ref['index']]
            src = tex['source']
            if src not in image_of:
                img = doc['images'][src]
                if src in images:
                    data, mime = Path(images[src]).read_bytes(), 'image/png' if str(images[src]).endswith('.png') else 'image/jpeg'
                else:
                    v = doc['bufferViews'][img['bufferView']]
                    data = binary[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
                    mime = img.get('mimeType', 'image/png')
                if src in tints:   # a picture painted in a colour: the hair's is nearly white and the game's materials colour it
                    im = Image.open(io.BytesIO(data)).convert('RGB')
                    r, g, b = im.split()
                    c = tints[src]
                    im = Image.merge('RGB', (r.point(lambda v: min(255, int(v * c[0]))), g.point(lambda v: min(255, int(v * c[1]))), b.point(lambda v: min(255, int(v * c[2])))))
                    buf = io.BytesIO()
                    im.save(buf, 'PNG')
                    data, mime = buf.getvalue(), 'image/png'
                out['images'].append({'bufferView': w.view(data), 'mimeType': mime, 'name': img.get('name', 'albedo')})
                out['textures'].append({'source': len(out['images']) - 1, **({'sampler': tex['sampler']} if 'sampler' in tex else {})})
                image_of[src] = len(out['textures']) - 1
            pbr['baseColorTexture'] = {**ref, 'index': image_of[src]}
        pbr['metallicFactor'] = 0.0
        out['materials'].append(m)
    if doc.get('samplers'):
        out['samplers'] = doc['samplers']
    if not out['images']:
        for k in ('images', 'textures'):
            out.pop(k)
    return out, w


def add_clips(out: dict, w, lib_path: Path, wanted: list) -> list:
    """The clips `wanted` of a library copied onto `out`'s skeleton: each channel finds its bone by name."""
    ual, ual_bin = FF.read_gltf(lib_path)
    name_to_node = {n['name']: i for i, n in enumerate(out['nodes']) if 'name' in n}
    ual_names = [n.get('name', '') for n in ual['nodes']]
    got = []
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
        out.setdefault('animations', []).append({'name': clip['name'], 'samplers': samplers, 'channels': channels})
        got.append(clip['name'])
    return got


def finish(out: dict, w, dst: Path) -> None:
    out['bufferViews'] = w.views
    out['accessors'] = w.accessors
    FF.write_glb(dst, out, bytes(w.binary))


def build_body(sex: str) -> None:
    info = SEXES[sex]
    doc, binary = FF.read_gltf(BODIES / f"{info['body']}_FullBody.gltf")
    out, w = slim(doc, binary)
    got = add_clips(out, w, UAL1, CLIPS_1) + add_clips(out, w, UAL2, CLIPS_2)
    missing = [c for c in CLIPS_1 + CLIPS_2 if c not in got]
    dst = OUT / f'pack_{sex}.glb'
    finish(out, w, dst)
    print(f'{dst.name}: {FF.triangles(out)} triangles, {len(got)} clips, {dst.stat().st_size / 1e6:.1f} MB'
          + (f', clips not found: {missing}' if missing else ''))


def skin_swap(doc: dict, sex: str) -> dict:
    """image index -> the light skin picture, for the image the body's skin material uses (the pack's glTFs name the dark one)."""
    swap = {}
    for mat in doc['materials']:
        if mat['name'].startswith('MI_Regular_'):
            swap[doc['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']] = SKIN_TEX / SEXES[sex]['skin']
    return swap


def hair_tint(doc: dict, colour: tuple) -> dict:
    """image index -> the hair colour, for the image the hair and eyebrow materials use."""
    return {doc['textures'][m['pbrMetallicRoughness']['baseColorTexture']['index']]['source']: colour
            for m in doc['materials'] if m['name'].startswith('MI_Hair')}


def build_head(sex: str) -> None:
    info = SEXES[sex]
    doc, binary = FF.read_gltf(BODIES / f"{info['body']}_OnlyHead.gltf")
    out, w = slim(doc, binary, skin_swap(doc, sex), hair_tint(doc, info['hair_colour']))
    dst = OUT / f'pack_{sex}_head.glb'
    finish(out, w, dst)
    print(f'{dst.name}: {FF.triangles(out)} triangles, {dst.stat().st_size / 1e6:.1f} MB')


def build_outfit(sex: str, style: str = 'peasant', colouring: int = 1) -> None:
    """The outfit `style` in the pack's colouring 1 to 3, as pack_<sex>_<style>[2|3].glb."""
    kind = OUTFIT_STYLES[style]
    doc, binary = FF.read_gltf(OUTFITS / 'Exports/glTF (Godot-Unreal)/Outfits' / f"{kind[sex]}.gltf")
    swap = skin_swap(doc, sex)
    if colouring > 1:
        for mat in doc['materials']:
            if mat['name'] == kind['material']:
                swap[doc['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']] = (
                    OUTFITS / f"Textures/{kind['folder']}/T_{kind['folder']}_{colouring}_BaseColor.png")
    out, w = slim(doc, binary, swap, None, kind['leave_out'])
    dst = OUT / (f'pack_{sex}_{style}.glb' if colouring == 1 else f'pack_{sex}_{style}{colouring}.glb')
    finish(out, w, dst)
    print(f'{dst.name}: {FF.triangles(out)} triangles, {dst.stat().st_size / 1e6:.1f} MB')


def build_hair(sex: str, hair_id: str) -> None:
    stem, colour = HAIRS[sex][hair_id]
    doc, binary = FF.read_gltf(HAIR / f'{stem}.gltf')
    out, w = slim(doc, binary, None, hair_tint(doc, colour))
    dst = OUT / f'pack_{sex}_hair_{hair_id}.glb'
    finish(out, w, dst)
    print(f'{dst.name}: {FF.triangles(out)} triangles, {dst.stat().st_size / 1e6:.1f} MB')


def main(argv: list) -> int:
    which = argv or ['bodies', 'parts', 'outfits', 'hairs']
    OUT.mkdir(parents=True, exist_ok=True)
    for sex in SEXES:
        if 'bodies' in which:
            build_body(sex)
        if 'parts' in which:
            build_head(sex)
            build_outfit(sex, 'peasant')
            build_hair(sex, next(iter(HAIRS[sex])))
        if 'outfits' in which:
            for style, kind in OUTFIT_STYLES.items():
                for c in range(1 if style != 'peasant' else 2, kind['colourings'] + 1):
                    build_outfit(sex, style, c)
        if 'hairs' in which:
            for hair_id in list(HAIRS[sex])[1:]:
                build_hair(sex, hair_id)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
