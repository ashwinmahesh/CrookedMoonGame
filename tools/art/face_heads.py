#!/usr/bin/env /usr/bin/python3
"""Heads with a painted face for the figures that have no head model (art/figures/heads/<part>.glb), from look-P head sheets (PIL only).

A head turnaround sheet (a front view, a side view and a back view of one head on white, left to right: the Tripo head sheets
under <asset root>/turnarounds/tpose/<id>-head-sheet.png, or the generic ones tools/art/specs/face_sheets.json makes) is cut into
its front and back views and painted onto the neutral clay head's shape (the same egg, nose and ears as tools/art/clay_head.py): the
front view is projected onto the front half from straight ahead, the back view onto the back half from behind, into one atlas
(front on the left, back on the right, each with a few pixels of padding so the filter never bleeds across). The head is a rigid
piece the engine fits to any body's neck (`"fit": "head"`), so a face goes on any body that has a `layers` entry for it.

  /usr/bin/python3 tools/art/face_heads.py             builds every head in tools/art/face_heads.json that has its sheet
  /usr/bin/python3 tools/art/face_heads.py face_m1     only these

tools/art/face_heads.json: {"<part id>": {"sheet": "<path under the asset root>", "chin": 0.85, "front": [x0, y0, x1, y1]?, "back": [...]?}}.
`chin` is where the chin is in the front crop, as a fraction of its height from the top (the part below it, the neck, is left out);
the boxes are found by themselves (the white around each view) when not given.
"""
from __future__ import annotations
import io, json, math, struct, sys
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path('/Volumes/ASH-SSD/CrookedMoon/assets')
SPEC = ROOT / 'tools/art/face_heads.json'
OUT = ROOT / 'art/figures/heads'
ATLAS = 1024                     # the atlas is ATLAS wide and ATLAS / 2 high: front on the left, back on the right
PAD = 4
TILE = ATLAS // 2                # one view's square in the atlas
HEAD_H = 1.04                    # the egg is this tall (y from 0 to HEAD_H) and 0.8 wide, 0.88 deep (as clay_head.py)


def content_box(sheet: Image.Image, x0: int, x1: int) -> tuple[int, int, int, int]:
    sub = sheet.crop((x0, 0, x1, sheet.height)).convert('RGB')
    r, g, b = sub.split()
    mask = ImageChops.darker(ImageChops.darker(r, g), b).point(lambda v: 255 if v < 236 else 0)
    bb = mask.getbbox()
    if bb is None:
        raise SystemExit('no head found in the sheet')
    return bb[0] + x0, bb[1], bb[2] + x0, bb[3]


def bleed(tile: Image.Image) -> Image.Image:
    """The white of the sheet either side of the head in each row replaced by that row's first and last painted pixel, so
    the ears and the egg's edge-on sides take the hair or skin colour, not white (and the same above the head, which is the
    crown the game's camera sees from above)."""
    r, g, b = tile.split()
    ink = ImageChops.darker(ImageChops.darker(r, g), b).point(lambda v: 255 if v < 236 else 0)
    out = tile.copy()
    for x in range(tile.width):                  # above the head (between hair tufts, a hat's crown): the colour just inside it
        bb = ink.crop((x, 0, x + 1, tile.height)).getbbox()
        if bb is not None and bb[1] > 0:
            out.paste(tile.getpixel((x, min(bb[1] + 6, tile.height - 1))), (x, 0, x + 1, bb[1]))
    tile = out.copy()
    last = None
    rows = []
    for y in range(tile.height):
        bb = ink.crop((0, y, tile.width, y + 1)).getbbox()
        rows.append(bb)
    for y, bb in enumerate(rows):
        if bb is None:
            bb = next((rows[k] for k in range(y, tile.height) if rows[k]), None) or last
            if bb is None:
                continue
        last = bb
        x0, x1 = bb[0], bb[2] - 1
        sy = y if rows[y] else min(max(y, 0), tile.height - 1)
        if x0 > 0:
            out.paste(tile.getpixel((x0 + 1, sy)), (0, y, x0, y + 1))
        if x1 < tile.width - 1:
            out.paste(tile.getpixel((x1 - 1, sy)), (x1 + 1, y, tile.width, y + 1))
    return out


def view(sheet: Image.Image, box, chin: float, height: int) -> Image.Image:
    """The head of one view, cut `chin` of `height` down from the top of its box, stretched to a square tile with the edge
    pixels repeated into the padding."""
    x0, y0, x1, y1 = box
    y1 = min(y1, y0 + int(height * chin))
    tile = sheet.crop((x0, y0, x1, y1)).convert('RGB')
    size = ATLAS // 2 - 2 * PAD
    tile = bleed(tile.resize((size, size), Image.LANCZOS))
    padded = Image.new('RGB', (ATLAS // 2, ATLAS // 2))
    padded.paste(tile, (PAD, PAD))
    for k in range(PAD):                                   # replicate the edge into the padding
        padded.paste(tile.crop((0, 0, 1, size)).resize((1, size)), (k, PAD))
        padded.paste(tile.crop((size - 1, 0, size, size)), (PAD + size + k, PAD))
    for k in range(PAD):
        row_top = padded.crop((0, PAD, ATLAS // 2, PAD + 1))
        row_bot = padded.crop((0, PAD + size - 1, ATLAS // 2, PAD + size))
        padded.paste(row_top, (0, k))
        padded.paste(row_bot, (0, PAD + size + k))
    return padded


def atlas_for(sheet_path: Path, chin: float, front=None, back=None) -> Image.Image:
    sheet = Image.open(sheet_path).convert('RGB')
    w = sheet.width
    front = front or content_box(sheet, 0, w // 3)
    back = back or content_box(sheet, 2 * w // 3, w)
    atlas = Image.new('RGB', (ATLAS, ATLAS // 2))
    fh = front[3] - front[1]
    # the back's box can reach well below the head (a ponytail, a bun, a hat's brim): take the head's height from the front's
    bh = min(back[3] - back[1], round(fh * (back[2] - back[0]) / (front[2] - front[0])))
    atlas.paste(view(sheet, front, chin, fh), (0, 0))
    atlas.paste(view(sheet, back, chin, bh), (ATLAS // 2, 0))
    return atlas


# --- The mesh ------------------------------------------------------------------------------------------------------------------

def grid(centre, radii, phi0, phi1, lat=14, lon=12):
    cx, cy, cz = centre
    rx, ry, rz = radii
    pos, nrm, idx = [], [], []
    for i in range(lat + 1):
        th = math.pi * i / lat
        for j in range(lon + 1):
            ph = phi0 + (phi1 - phi0) * j / lon
            x, y, z = math.sin(th) * math.sin(ph), math.cos(th), math.sin(th) * math.cos(ph)
            pos.append((cx + x * rx, cy + y * ry, cz + z * rz))
            n = (x / rx, y / ry, z / rz)
            ln = math.sqrt(sum(c * c for c in n)) or 1.0
            nrm.append(tuple(c / ln for c in n))
    for i in range(lat):
        for j in range(lon):
            a, b = i * (lon + 1) + j, i * (lon + 1) + j + 1
            c, d = (i + 1) * (lon + 1) + j, (i + 1) * (lon + 1) + j + 1
            idx += [a, c, b, b, c, d]
    return pos, nrm, idx


def _v(p) -> float:
    return PAD / TILE + (1.0 - p[1] / HEAD_H) * (TILE - 2 * PAD) / TILE


def uv_front(p):
    """Seen from the front the head's left (-x) is the picture's left."""
    return (PAD / ATLAS + ((p[0] + 0.40) / 0.80) * (TILE - 2 * PAD) / ATLAS, _v(p))


def uv_back(p):
    """Seen from behind the head's -x is the picture's right."""
    return (TILE / ATLAS + PAD / ATLAS + ((0.40 - p[0]) / 0.80) * (TILE - 2 * PAD) / ATLAS, _v(p))


def build_mesh():
    pos, nrm, uvs, idx = [], [], [], []

    def add(p, n, i, uvf):
        base = len(pos)
        pos.extend(p)
        nrm.extend(n)
        uvs.extend(uvf(q) for q in p)
        idx.extend(k + base for k in i)

    head = ((0, 0.52, 0), (0.40, 0.52, 0.44))
    for phi0, phi1, uvf in ((-math.pi / 2, math.pi / 2, uv_front), (math.pi / 2, 3 * math.pi / 2, uv_back)):
        p, n, i = grid(head[0], head[1], phi0, phi1)
        add(p, n, i, uvf)
    for centre, radii in (((0, 0.43, 0.43), (0.07, 0.09, 0.11)), ((-0.405, 0.5, 0.0), (0.05, 0.1, 0.07)), ((0.405, 0.5, 0.0), (0.05, 0.1, 0.07))):
        p, n, i = grid(centre, radii, 0.0, 2 * math.pi, 10, 14)
        add(p, n, i, uv_front)
    return pos, nrm, uvs, idx


def glb(pos, nrm, uvs, idx, jpeg: bytes, name: str) -> bytes:
    pb = b''.join(struct.pack('<fff', *p) for p in pos)
    nb = b''.join(struct.pack('<fff', *n) for n in nrm)
    ub = b''.join(struct.pack('<ff', *t) for t in uvs)
    ib = b''.join(struct.pack('<H', k) for k in idx)
    ib += b'\0' * (-len(ib) % 4)
    blob = pb + nb + ub + ib
    img_at = len(blob)
    blob += jpeg + b'\0' * (-len(jpeg) % 4)
    xs, ys, zs = zip(*pos)
    doc = {
        'asset': {'version': '2.0', 'generator': 'tools/art/face_heads.py'},
        'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': name}],
        'meshes': [{'name': name, 'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0}]}],
        'materials': [{'name': 'face', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0, 'roughnessFactor': 1.0}}],
        'textures': [{'sampler': 0, 'source': 0}],
        'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 33071, 'wrapT': 33071}],
        'images': [{'bufferView': 4, 'mimeType': 'image/jpeg', 'name': 'albedo'}],
        'buffers': [{'byteLength': len(blob)}],
        'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': len(pb), 'target': 34962},
                        {'buffer': 0, 'byteOffset': len(pb), 'byteLength': len(nb), 'target': 34962},
                        {'buffer': 0, 'byteOffset': len(pb) + len(nb), 'byteLength': len(ub), 'target': 34962},
                        {'buffer': 0, 'byteOffset': len(pb) + len(nb) + len(ub), 'byteLength': len(idx) * 2, 'target': 34963},
                        {'buffer': 0, 'byteOffset': img_at, 'byteLength': len(jpeg)}],
        'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': [min(xs), min(ys), min(zs)], 'max': [max(xs), max(ys), max(zs)]},
                      {'bufferView': 1, 'componentType': 5126, 'count': len(nrm), 'type': 'VEC3'},
                      {'bufferView': 2, 'componentType': 5126, 'count': len(uvs), 'type': 'VEC2'},
                      {'bufferView': 3, 'componentType': 5123, 'count': len(idx), 'type': 'SCALAR'}],
    }
    js = json.dumps(doc, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)) + struct.pack('<II', len(js), 0x4E4F534A) + js
    return out + struct.pack('<II', len(blob), 0x004E4942) + blob


def build(part: str, spec: dict) -> Path | None:
    sheet = ASSETS / spec['sheet']
    if not sheet.exists():
        print(f'{part}: sheet {spec["sheet"]} is not there yet', file=sys.stderr)
        return None
    chin = float(spec.get('chin', 0.85))
    atlas = atlas_for(sheet, chin, spec.get('front'), spec.get('back'))
    buf = io.BytesIO()
    atlas.save(buf, 'JPEG', quality=88)
    pos, nrm, uvs, idx = build_mesh()
    out = OUT / f'{part}.glb'
    OUT.mkdir(parents=True, exist_ok=True)
    out.write_bytes(glb(pos, nrm, uvs, idx, buf.getvalue(), part))
    print(out.name, out.stat().st_size // 1024, 'KB')
    return out


def main(argv: list[str]) -> None:
    spec = json.loads(SPEC.read_text())
    for part, s in spec.items():
        if argv and part not in argv:
            continue
        build(part, s)


if __name__ == '__main__':
    main(sys.argv[1:])
