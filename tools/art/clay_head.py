#!/usr/bin/env python3
"""A neutral clay head for the figures whose Tripo body models were made without one (art/figures/heads/clay_head.glb): an egg with a
small nose, so it shows which way it faces, and two ears, in a muted skin-toned clay. A head
made apart from the body is a rigid piece the engine fits to any body's neck (`"fit": "head"`), so one head serves every body until each
has a head model of its own. Pure Python, no packages; the output is deterministic.
  python3 tools/art/clay_head.py"""
import json, math, struct
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / 'art/figures/heads/clay_head.glb'
def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4


# glTF base colours are linear; this deep skin-toned clay (104, 74, 56) is sRGB. Anything paler (the stand-in bodies' clay is (184, 168, 148)) glowed
# like a bulb on a head in a dark room.
CLAY = (linear(104 / 255), linear(74 / 255), linear(56 / 255), 1.0)


def ellipsoid(centre, radii, lat=14, lon=22):
    cx, cy, cz = centre
    rx, ry, rz = radii
    pos, nrm, idx = [], [], []
    for i in range(lat + 1):
        th = math.pi * i / lat
        for j in range(lon + 1):
            ph = 2 * math.pi * j / lon
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


def build():
    pos, nrm, idx = [], [], []
    for centre, radii in [((0, 0.52, 0), (0.40, 0.52, 0.44)),          # the head
                          ((0, 0.43, 0.43), (0.07, 0.09, 0.11)),         # the nose, front (+z)
                          ((-0.405, 0.5, 0.0), (0.05, 0.1, 0.07)),       # the ears
                          ((0.405, 0.5, 0.0), (0.05, 0.1, 0.07))]:
        p, n, i = ellipsoid(centre, radii)
        base = len(pos)
        pos += p
        nrm += n
        idx += [k + base for k in i]
    pbytes = b''.join(struct.pack('<fff', *p) for p in pos)
    nbytes = b''.join(struct.pack('<fff', *n) for n in nrm)
    ibytes = b''.join(struct.pack('<H', k) for k in idx)
    ibytes += b'\0' * (-len(ibytes) % 4)
    blob = pbytes + nbytes + ibytes
    xs, ys, zs = zip(*pos)
    doc = {
        'asset': {'version': '2.0', 'generator': 'tools/art/clay_head.py'},
        'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': 'ClayHead'}],
        'meshes': [{'name': 'ClayHead', 'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2, 'material': 0}]}],
        'materials': [{'name': 'clay', 'pbrMetallicRoughness': {'baseColorFactor': list(CLAY), 'metallicFactor': 0.0, 'roughnessFactor': 0.9}}],
        'buffers': [{'byteLength': len(blob)}],
        'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': len(pbytes), 'target': 34962},
                        {'buffer': 0, 'byteOffset': len(pbytes), 'byteLength': len(nbytes), 'target': 34962},
                        {'buffer': 0, 'byteOffset': len(pbytes) + len(nbytes), 'byteLength': len(idx) * 2, 'target': 34963}],
        'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': [min(xs), min(ys), min(zs)], 'max': [max(xs), max(ys), max(zs)]},
                      {'bufferView': 1, 'componentType': 5126, 'count': len(nrm), 'type': 'VEC3'},
                      {'bufferView': 2, 'componentType': 5123, 'count': len(idx), 'type': 'SCALAR'}],
    }
    js = json.dumps(doc, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    blob += b'\0' * (-len(blob) % 4)
    glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)) + struct.pack('<II', len(js), 0x4E4F534A) + js
    glb += struct.pack('<II', len(blob), 0x004E4942) + blob
    OUT.write_bytes(glb)
    print(OUT, len(glb), 'bytes,', len(idx) // 3, 'triangles')


if __name__ == '__main__':
    build()
