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
- pack_<sex>_peasant.glb: the Peasant outfit (arms, body, legs, feet) with its colour picture (--outfit 1..3, three colourings)
  and the same light skin on its hands.
- pack_<sex>_hair_<style>.glb: a hairstyle rigged to the head bone.
Normal and roughness maps are left out (the figure shader paints with the base-colour picture), so each file is small.

  /usr/bin/python3 tools/art/pack_figures.py [bodies] [parts] [outfits]       (the default: bodies and parts; outfits adds the peasants' other two colourings)
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
    'male': {'body': 'Regular_Male', 'skin': 'T_Regular_Male_Light_BaseColor.png', 'outfit': 'Male_Peasant', 'hair': 'Male/Hair_SimpleParted',
             'hair_id': 'parted', 'hair_colour': (0.30, 0.19, 0.11)},
    'female': {'body': 'Regular_Female', 'skin': 'T_Regular_Female_Light_BaseColor.png', 'outfit': 'Female_Peasant', 'hair': 'Female/Hair_Buns',
               'hair_id': 'buns', 'hair_colour': (0.50, 0.27, 0.12)},
}

# The clips the game uses, by the pack's names (rigs.quaternius.clips in art/figures/manifest.json says which role plays which).
CLIPS_1 = ['Idle_Loop', 'Walk_Loop', 'Jog_Fwd_Loop', 'Sprint_Loop', 'Sword_Attack', 'Sword_Idle', 'Spell_Simple_Enter', 'Spell_Simple_Shoot',
           'Spell_Simple_Idle_Loop', 'Spell_Simple_Exit', 'Hit_Chest', 'Hit_Head', 'Hit_Stomach', 'Death01', 'Death02', 'Idle_Talking_Loop', 'Interact',
           'Idle_Torch_Loop', 'Idle_LookAround_Loop', 'Crying', 'Celebration', 'Counter_Angry', 'Sitting_Enter', 'Sitting_Idle_Loop',
           'Sitting_Exit', 'Roll']
CLIPS_2 = ['Yes', 'Idle_No_Loop', 'Sword_Block', 'Walk_Carry_Loop', 'Idle_FoldArms_Loop', 'Idle_Lantern_Loop']


def slim(doc: dict, binary: bytes, images: dict = None, tints: dict = None):
    """A copy of a glTF with only what its meshes, skin and (when asked) clips reach: the base-colour pictures of the materials
    (the file's, or a replacement path from `images`: image index -> file), none of the normal, roughness or occlusion maps."""
    images = images or {}
    tints = tints or {}
    w = FF.Writer()
    out = {'asset': {'version': '2.0', 'generator': 'tools/art/pack_figures.py'}, 'scene': doc.get('scene', 0), 'scenes': doc['scenes'],
           'nodes': copy.deepcopy(doc['nodes']), 'meshes': [], 'skins': [], 'materials': [], 'textures': [], 'images': []}
    for mesh in doc['meshes']:
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
                    im = Image.merge('RGB', (r.point(lambda v: int(v * c[0])), g.point(lambda v: int(v * c[1])), b.point(lambda v: int(v * c[2]))))
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


def hair_tint(doc: dict, sex: str) -> dict:
    """image index -> the sex's hair colour, for the image the hair and eyebrow materials use."""
    return {doc['textures'][m['pbrMetallicRoughness']['baseColorTexture']['index']]['source']: SEXES[sex]['hair_colour']
            for m in doc['materials'] if m['name'].startswith('MI_Hair')}


def build_head(sex: str) -> None:
    info = SEXES[sex]
    doc, binary = FF.read_gltf(BODIES / f"{info['body']}_OnlyHead.gltf")
    out, w = slim(doc, binary, skin_swap(doc, sex), hair_tint(doc, sex))
    dst = OUT / f'pack_{sex}_head.glb'
    finish(out, w, dst)
    print(f'{dst.name}: {FF.triangles(out)} triangles, {dst.stat().st_size / 1e6:.1f} MB')


def build_outfit(sex: str, colouring: int = 1) -> None:
    info = SEXES[sex]
    doc, binary = FF.read_gltf(OUTFITS / 'Exports/glTF (Godot-Unreal)/Outfits' / f"{info['outfit']}.gltf")
    swap = skin_swap(doc, sex)
    if colouring > 1:
        for mat in doc['materials']:
            if mat['name'] == 'MI_Peasant':
                swap[doc['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']] = (
                    OUTFITS / f'Textures/Peasant/T_Peasant_{colouring}_BaseColor.png')
    out, w = slim(doc, binary, swap)
    dst = OUT / (f'pack_{sex}_peasant.glb' if colouring == 1 else f'pack_{sex}_peasant{colouring}.glb')
    finish(out, w, dst)
    print(f'{dst.name}: {FF.triangles(out)} triangles, {dst.stat().st_size / 1e6:.1f} MB')


def build_hair(sex: str) -> None:
    info = SEXES[sex]
    doc, binary = FF.read_gltf(HAIR / f"{info['hair']}.gltf")
    out, w = slim(doc, binary, None, hair_tint(doc, sex))
    dst = OUT / f"pack_{sex}_hair_{info['hair_id']}.glb"
    finish(out, w, dst)
    print(f'{dst.name}: {FF.triangles(out)} triangles, {dst.stat().st_size / 1e6:.1f} MB')


def main(argv: list) -> int:
    which = argv or ['bodies', 'parts']
    OUT.mkdir(parents=True, exist_ok=True)
    for sex in SEXES:
        if 'bodies' in which:
            build_body(sex)
        if 'parts' in which:
            build_head(sex)
            for c in ((1, 2, 3) if 'outfits' in which else (1,)):   # `outfits`: the other two colourings too
                build_outfit(sex, c)
            build_hair(sex)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
