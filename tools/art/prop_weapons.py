#!/usr/bin/env python3
"""Held weapons from Ashwin's Fantasy Props MegaKit (Quaternius, CC0, Source tier) for the figure pipeline.

Each weapon is the kit's glTF (Exports/glTF (Godot)/) folded into one GLB: the collision mesh is left out, and so are
the normal and ORM pictures (the figure shader paints with the base colour), and the trim sheet each material uses is
cut to --max px as a JPEG. The source GLBs go to <asset root>/free_models/weapons/<id>.glb, which
`python3 tools/art/figures.py` ships to the manifest parts' `file`s; --ship writes the shipped copy in
art/figures/weapons/ directly as well (for a machine without macOS's sips, which figures.py uses).

  python3 tools/art/prop_weapons.py [--kit <folder with the kit's glTF (Godot) exports>] [--ship] [--max 1024] [id ...]
"""
import argparse, copy, io, sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / 'tools'))
sys.path.insert(0, str(REPO / 'tools/art'))
from asset_root import asset_root  # noqa: E402
import free_figures as FF  # noqa: E402

KIT = asset_root() / 'sourced/quaternius_fantasy_props_megakit_source/pack/Exports/glTF (Godot)'
OUT = asset_root() / 'free_models/weapons'
SHIP = REPO / 'art/figures/weapons'

# Part id -> the kit's file (one sword serves the long, short and great sword at different sizes in the manifest).
WEAPONS = {'sword': 'Sword_Steel', 'shield_wooden': 'Shield_Wooden', 'shield_metal': 'Shield_Metal'}


def fold(src: Path, max_px: int):
    doc, binary = FF.read_gltf(src)
    # Only the visible meshes: nodes whose names mark them as collision shapes lose their meshes and leave the scene.
    keep = [i for i, n in enumerate(doc['nodes']) if 'colonly' not in n.get('name', '')]
    remap = {old: new for new, old in enumerate(keep)}
    nodes = []
    for i in keep:
        n = copy.deepcopy(doc['nodes'][i])
        if 'children' in n:
            n['children'] = [remap[c] for c in n['children'] if c in remap]
            if not n['children']:
                del n['children']
        nodes.append(n)
    doc['nodes'] = nodes
    for s in doc['scenes']:
        s['nodes'] = [remap[c] for c in s['nodes'] if c in remap]
    used_meshes = sorted({n['mesh'] for n in nodes if 'mesh' in n})
    mesh_map = {old: new for new, old in enumerate(used_meshes)}
    doc['meshes'] = [doc['meshes'][m] for m in used_meshes]
    for n in nodes:
        if 'mesh' in n:
            n['mesh'] = mesh_map[n['mesh']]
    # Base colour only.
    for m in doc.get('materials', []):
        m.pop('normalTexture', None)
        m.pop('occlusionTexture', None)
        (m.get('pbrMetallicRoughness') or {}).pop('metallicRoughnessTexture', None)
    w = FF.Writer()
    used_tex = sorted({m['pbrMetallicRoughness']['baseColorTexture']['index'] for m in doc.get('materials', [])
                       if 'baseColorTexture' in m.get('pbrMetallicRoughness', {})})
    tex_map = {old: new for new, old in enumerate(used_tex)}
    images, textures = [], []
    for t in used_tex:
        img_doc = doc['images'][doc['textures'][t]['source']]
        v = doc['bufferViews'][img_doc['bufferView']]
        raw = binary[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        im = Image.open(io.BytesIO(raw)).convert('RGB')
        im.thumbnail((max_px, max_px), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, 'JPEG', quality=90)
        images.append({'bufferView': w.view(buf.getvalue()), 'mimeType': 'image/jpeg',
                       'name': Path(img_doc.get('name', f'tex{t}')).stem})
        textures.append({'source': len(images) - 1})
    for m in doc.get('materials', []):
        pbr = m.get('pbrMetallicRoughness', {})
        if 'baseColorTexture' in pbr:
            pbr['baseColorTexture'] = {'index': tex_map[pbr['baseColorTexture']['index']]}
    # The meshes' accessors copied through the writer.
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            p['attributes'] = {k: w.accessor(doc, binary, a, 34962) for k, a in p['attributes'].items()}
            if 'indices' in p:
                p['indices'] = w.accessor(doc, binary, p['indices'], 34963)
    out = {'asset': {'version': '2.0', 'generator': 'tools/art/prop_weapons.py'}, 'scene': 0, 'scenes': doc['scenes'],
           'nodes': doc['nodes'], 'meshes': doc['meshes'], 'materials': doc.get('materials', []),
           'textures': textures, 'images': images, 'samplers': [{}], 'bufferViews': w.views, 'accessors': w.accessors}
    for t in textures:
        t['sampler'] = 0
    return out, bytes(w.binary)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('ids', nargs='*')
    ap.add_argument('--kit', default=str(KIT))
    ap.add_argument('--ship', action='store_true')
    ap.add_argument('--max', type=int, default=1024)
    a = ap.parse_args(argv)
    for wid in a.ids or list(WEAPONS):
        doc, binary = fold(Path(a.kit) / f'{WEAPONS[wid]}.gltf', a.max)
        targets = [OUT / f'{wid}.glb'] + ([SHIP / f'{wid}.glb'] if a.ship else [])
        for t in targets:
            FF.write_glb(t, copy.deepcopy(doc), binary)
            print(f'{t}: {FF.triangles(doc)} triangles, {t.stat().st_size / 1e3:.0f} KB')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
