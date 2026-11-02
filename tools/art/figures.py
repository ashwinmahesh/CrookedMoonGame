#!/usr/bin/env python3
"""3D creature figures for the game (the engine's FigureModels, art/figures/manifest.json): each figure whose manifest
entry names a `source` (a rigged GLB under the asset root, e.g. tripo/models/rook_final_..._6clips.glb from Tripo
Studio) is copied to its `file` in the repo, made fit to ship:

- every texture the materials use is scaled down to at most --max px on its long side (Tripo exports 4K or 8K; a
  figure fills a few hundred pixels of the screen) with macOS's sips, still a JPEG;
- images no material uses (Tripo's spare normal map) are left out;
- the images are named for what they are (albedo, normal), so the textures Godot extracts beside the file are
  <figure>_albedo.jpg and <figure>_normal.png;
- animation names lose Tripo's ".001" and "preset:...:" decorations ("idle.001" -> "idle", "preset:quadruped:walk"
  -> "walk"), so the manifest and the engine name clips plainly.

The meshes, skins and animations are copied byte for byte. The source files are never changed.

Parts a figure wears (the manifest's "parts": a head made apart from its body, say) are copied the same way when they
name a `source`. A figure or part with a `close_up` gets its source's base-colour picture at full size (up to 4096 px)
at the `close_up`'s `albedo` path: the look a conversation's close-up swaps in (the engine's ModelFigure.set_close_up).

Entries that need no model of their own are handled too:
- an entry with a `base` (another figure's art id: the six haint dressings share the haint body) and no `source` gets no
  GLB; if it has an `albedo_source` (the Tripo retexture export of the base body, a GLB, or a .png/.jpg picture) its
  base-colour texture is taken out, scaled to at most --max px and written to its `albedo` path as a JPEG, which the
  engine lays over the base figure's own;
- a figure whose source is not on the asset root yet (Tripo has not delivered it) is skipped with a one-line note, so
  the game keeps showing its `sprite` and everything else is still copied.

  python3 tools/art/figures.py             copies every figure whose file is missing or older than its source (and the dressings' paint)
  python3 tools/art/figures.py --force     copies them all again
  python3 tools/art/figures.py rook_coldwake adela_druskenvald    only these
"""
import json, os, re, struct, subprocess, sys, tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / 'tools'))
from asset_root import asset_root  # noqa: E402
sys.path.insert(0, str(REPO / 'tools/art'))
import rig_facing  # noqa: E402

MANIFEST = REPO / 'art/figures/manifest.json'
GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


def read_glb(path: Path):
    data = path.read_bytes()
    magic, version, _length = struct.unpack_from('<III', data, 0)
    if magic != GLB_MAGIC or version != 2:
        raise ValueError(f'{path} is not a glTF 2 binary')
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


def write_glb(path: Path, doc: dict, binary: bytes) -> None:
    js = json.dumps(doc, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    binary += b'\0' * (-len(binary) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    out = struct.pack('<III', GLB_MAGIC, 2, total) + struct.pack('<II', len(js), CHUNK_JSON) + js
    out += struct.pack('<II', len(binary), CHUNK_BIN) + binary
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)


def view_bytes(doc: dict, binary: bytes, index: int) -> bytes:
    v = doc['bufferViews'][index]
    start = v.get('byteOffset', 0)
    return binary[start:start + v['byteLength']]


def shrink(image: bytes, mime: str, max_px: int) -> bytes:
    """The image at most max_px on its long side (sips keeps JPEG as JPEG, PNG as PNG)."""
    ext = '.png' if mime == 'image/png' else '.jpg'
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = Path(tmp) / ('in' + ext), Path(tmp) / ('out' + ext)
        src.write_bytes(image)
        size = subprocess.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(src)], capture_output=True, text=True,
                              check=True).stdout
        dims = [int(n) for n in re.findall(r'pixel(?:Width|Height): (\d+)', size)]
        if max(dims) <= max_px:
            return image
        args = ['sips', '-Z', str(max_px), str(src), '--out', str(dst)]
        if ext == '.jpg':
            args[1:1] = ['-s', 'formatOptions', '92']
        subprocess.run(args, capture_output=True, check=True)
        return dst.read_bytes()


def albedo_of(src: Path, dst: Path, max_px: int) -> str:
    """The base-colour picture of `src` (a GLB's first material that has one, or an image file) as a JPEG of at most
    max_px at `dst`."""
    if src.suffix.lower() in ('.png', '.jpg', '.jpeg'):
        image, mime = src.read_bytes(), 'image/png' if src.suffix.lower() == '.png' else 'image/jpeg'
    else:
        doc, binary = read_glb(src)
        image = None
        for m in doc.get('materials', []):
            ref = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
            if ref and 'source' in doc['textures'][ref['index']]:
                img = doc['images'][doc['textures'][ref['index']]['source']]
                if 'bufferView' in img:
                    image, mime = view_bytes(doc, binary, img['bufferView']), img.get('mimeType', '')
                    break
        if image is None:
            raise ValueError(f'{src} has no base-colour texture')
    image = shrink(image, mime, max_px)
    if mime == 'image/png':
        with tempfile.TemporaryDirectory() as tmp:
            png, jpg = Path(tmp) / 'in.png', Path(tmp) / 'out.jpg'
            png.write_bytes(image)
            subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '92', str(png), '--out', str(jpg)],
                           capture_output=True, check=True)
            image = jpg.read_bytes()
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(image)
    paint_import(dst)
    return f'{dst.relative_to(REPO)}: {len(image) / 1e6:.1f} MB from {src.name}'


# A picture on its own imports as a flat 2D texture; a dressing's paint is drawn on a model, so it imports as the
# textures Godot takes out of a GLB do: compressed for the GPU, with mipmaps (the figure shader filters with them).
PAINT_IMPORT = {'compress/mode': '2', 'mipmaps/generate': 'true', 'detect_3d/compress_to': '0'}


def paint_import(dst: Path) -> None:
    imp = dst.with_name(dst.name + '.import')
    if not imp.exists():
        imp.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                       + ''.join(f'{k}={v}\n' for k, v in PAINT_IMPORT.items()))
        return
    lines = imp.read_text().split('\n')
    for i, line in enumerate(lines):
        key = line.split('=', 1)[0]
        if key in PAINT_IMPORT:
            lines[i] = f'{key}={PAINT_IMPORT[key]}'
    imp.write_text('\n'.join(lines))


def plain_clip_name(name: str) -> str:
    return re.sub(r'\.\d+$', '', name.split(':')[-1])


def convert(src: Path, dst: Path, max_px: int) -> str:
    doc, binary = read_glb(src)
    used_images = sorted({t['source'] for t in doc.get('textures', []) if 'source' in t})
    # What each image is for (Godot names the texture it extracts <file>_<image name>).
    role = {}
    for m in doc.get('materials', []):
        for kind, ref in (('albedo', m.get('pbrMetallicRoughness', {}).get('baseColorTexture')), ('normal', m.get('normalTexture')),
                          ('orm', m.get('pbrMetallicRoughness', {}).get('metallicRoughnessTexture')),
                          ('emission', m.get('emissiveTexture')), ('occlusion', m.get('occlusionTexture'))):
            if ref and 'index' in ref:
                role.setdefault(doc['textures'][ref['index']]['source'], kind)
    keep_views = set()
    for a in doc.get('accessors', []):
        if 'bufferView' in a:
            keep_views.add(a['bufferView'])
        for part in ('indices', 'values'):
            if part in a.get('sparse', {}):
                keep_views.add(a['sparse'][part]['bufferView'])
    new_bytes = {}
    image_remap, images = {}, []
    for i in used_images:
        img = dict(doc['images'][i])
        if 'bufferView' in img:
            keep_views.add(img['bufferView'])
            new_bytes[img['bufferView']] = shrink(view_bytes(doc, binary, img['bufferView']), img.get('mimeType', ''), max_px)
        name = role.get(i, 'image')
        img['name'] = name if name not in [im['name'] for im in images] else f'{name}_{len(images)}'
        image_remap[i] = len(images)
        images.append(img)
    # The binary again: the views kept, in their order, each 4-byte aligned, images replaced by their smaller copies.
    view_remap, views, out = {}, [], bytearray()
    for i, v in enumerate(doc.get('bufferViews', [])):
        if i not in keep_views:
            continue
        chunk = new_bytes.get(i, view_bytes(doc, binary, i))
        out += b'\0' * (-len(out) % 4)
        nv = dict(v)
        nv['buffer'] = 0
        nv['byteOffset'] = len(out)
        nv['byteLength'] = len(chunk)
        out += chunk
        view_remap[i] = len(views)
        views.append(nv)
    doc['bufferViews'] = views
    for a in doc.get('accessors', []):
        if 'bufferView' in a:
            a['bufferView'] = view_remap[a['bufferView']]
        for part in ('indices', 'values'):
            if part in a.get('sparse', {}):
                a['sparse'][part]['bufferView'] = view_remap[a['sparse'][part]['bufferView']]
    for img in images:
        if 'bufferView' in img:
            img['bufferView'] = view_remap[img['bufferView']]
    doc['images'] = images
    for t in doc.get('textures', []):
        if 'source' in t:
            t['source'] = image_remap[t['source']]
    names = [plain_clip_name(a.get('name', '')) for a in doc.get('animations', [])]
    for a, plain in zip(doc.get('animations', []), names):
        if plain and names.count(plain) == 1:
            a['name'] = plain
    doc['buffers'] = [{'byteLength': len(out)}]
    write_glb(dst, doc, bytes(out))
    return f'{dst.relative_to(REPO)}: {src.stat().st_size / 1e6:.1f} MB -> {dst.stat().st_size / 1e6:.1f} MB, ' \
           f'clips {", ".join(a.get("name", "") for a in doc.get("animations", []))}'


def face_forward(fid: str, info: dict, dst: Path) -> None:
    """A figure rigged facing any way but +z walks sideways or backwards (the engine turns the model to the way it
    walks, assuming +z is its front: tools/art/rig_facing.py). A figure without a `turn` of its own gets the one its
    skeleton needs, written into the manifest; one whose `turn` disagrees is reported."""
    front = rig_facing.facing(dst)
    if front is None:
        return
    need = rig_facing.turn_needed(front)
    if 'turn' in info:
        if rig_facing.turned(front, float(info['turn']))[1] < 0.7:
            print(f'{fid}: its manifest turn {info["turn"]} leaves it facing the wrong way; its skeleton needs {need:g}',
                  file=sys.stderr)
        return
    if need == 0:
        return
    text = MANIFEST.read_text()
    key = f'"{fid}": {{'
    if text.count(key) != 1:
        print(f'{fid}: faces the wrong way and needs "turn": {need:g} in the manifest (add it by hand)', file=sys.stderr)
        return
    MANIFEST.write_text(text.replace(key, f'{key}"turn": {need:g}, ', 1))
    info['turn'] = need
    print(f'{fid}: rigged facing away from +z, so the manifest now turns it {need:g} degrees')


def main(argv):
    force = '--force' in argv
    max_px = 2048
    for a in argv:
        if a.startswith('--max='):
            max_px = int(a.split('=', 1)[1])
    only = [a for a in argv if not a.startswith('--')]
    manifest = json.loads(MANIFEST.read_text())
    figures = dict(manifest['figures'])
    # Parts with a `source` (a familiar's own model, a piece of gear made for the game) are copied the same way.
    figures.update({pid: p for pid, p in manifest.get('parts', {}).items() if 'source' in p})
    root = asset_root()
    for fid, info in figures.items():
        if only and fid not in only:
            continue
        if 'source' in info:
            src, dst = root / info['source'], REPO / info['file']
            if not src.exists():
                print(f'{fid}: model {info["source"]} is not on the asset root yet, keeping its sprite', file=sys.stderr)
            elif force or not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
                print(convert(src, dst, max_px))
                face_forward(fid, info, dst)
        if 'source' in info and isinstance(info.get('close_up'), dict) and 'albedo' in info['close_up']:
            src, dst = root / info['source'], REPO / info['close_up']['albedo']
            if src.exists() and (force or not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime):
                print(albedo_of(src, dst, 4096))
        if 'albedo_source' in info and 'albedo' in info:
            src, dst = root / info['albedo_source'], REPO / info['albedo']
            if not src.exists():
                print(f'{fid}: paint {info["albedo_source"]} is not on the asset root yet', file=sys.stderr)
            elif force or not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
                print(albedo_of(src, dst, max_px))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
