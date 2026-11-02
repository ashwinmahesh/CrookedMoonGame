"""Reads and writes the plain triangle meshes of a glTF file, without Blender or numpy: what tools/art/village_kit.py needs to
cut, scale and re-material the Medieval Village MegaKit's pieces into building kit modules."""
import base64
import json
import os
import struct

_COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


class Vertex:
    __slots__ = ("p", "n", "uv", "c")

    def __init__(self, p, n, uv, c=(1.0, 1.0, 1.0)):
        self.p = p
        self.n = n
        self.uv = uv
        self.c = c


def _open(path):
    """A .gltf's JSON and buffers, or a .glb's."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] == b"glTF":
        n = struct.unpack_from("<I", data, 12)[0]
        g = json.loads(data[20:20 + n])
        bin_at = 20 + n
        return g, [data[bin_at + 8:bin_at + 8 + struct.unpack_from("<I", data, bin_at)[0]]]
    g = json.loads(data)
    return g, _buffers(g, os.path.dirname(path))


def materials(path):
    """Each material's base colour factor and base colour image (a path, or None)."""
    g, _ = _open(path)
    out = {}
    for m in g.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        img = None
        if "baseColorTexture" in pbr:
            src = g["textures"][pbr["baseColorTexture"]["index"]]["source"]
            uri = g["images"][src].get("uri")
            img = os.path.join(os.path.dirname(path), uri) if uri else None
        out[m["name"]] = (pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0]), img)
    return out


def _buffers(g, folder):
    out = []
    for b in g["buffers"]:
        uri = b["uri"]
        if uri.startswith("data:"):
            out.append(base64.b64decode(uri.split(",", 1)[1]))
        else:
            with open(os.path.join(folder, uri), "rb") as f:
                out.append(f.read())
    return out


def _read(g, bufs, idx):
    a = g["accessors"][idx]
    v = g["bufferViews"][a["bufferView"]]
    fmt, size = _COMP[a["componentType"]]
    n = _COUNT[a["type"]]
    stride = v.get("byteStride", size * n)
    data = bufs[v["buffer"]]
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    out = []
    for i in range(a["count"]):
        vals = struct.unpack_from("<" + fmt * n, data, start + i * stride)
        out.append(vals if n > 1 else vals[0])
    return out


def _trs(node):
    """A node's transform as a 3x4 matrix (rows), from its matrix or its translation, rotation and scale."""
    if "matrix" in node:
        m = node["matrix"]   # column-major 4x4
        return [[m[0], m[4], m[8], m[12]], [m[1], m[5], m[9], m[13]], [m[2], m[6], m[10], m[14]]]
    tx, ty, tz = node.get("translation", [0.0, 0.0, 0.0])
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    sx, sy, sz = node.get("scale", [1.0, 1.0, 1.0])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[0][0] * sx, r[0][1] * sy, r[0][2] * sz, tx], [r[1][0] * sx, r[1][1] * sy, r[1][2] * sz, ty],
            [r[2][0] * sx, r[2][1] * sy, r[2][2] * sz, tz]]


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) + (a[i][3] if j == 3 else 0.0) for j in range(4)] for i in range(3)]


def _apply(m, p):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3))


def _apply_normal(m, n):
    # Rotations and scales: the inverse transpose of the 3x3, through its cofactors.
    a = [row[:3] for row in m]
    cof = [[a[(i + 1) % 3][(j + 1) % 3] * a[(i + 2) % 3][(j + 2) % 3] - a[(i + 1) % 3][(j + 2) % 3] * a[(i + 2) % 3][(j + 1) % 3]
            for j in range(3)] for i in range(3)]
    return tuple(cof[i][0] * n[0] + cof[i][1] * n[1] + cof[i][2] * n[2] for i in range(3))


def load(path):
    """{material name: [triangles]}, each triangle three Vertex, in the scene's own units (node transforms applied).
    Collision copies (the "glTF (Godot)" folders' -col nodes) are left out."""
    g, bufs = _open(path)
    out = {}
    ident = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0]]
    scene = g["scenes"][g.get("scene", 0)]["nodes"] if "scenes" in g else range(len(g["nodes"]))

    def visit(i, parent):
        node = g["nodes"][i]
        if "col" in node.get("name", "").lower():
            return
        m = _mul(parent, _trs(node))
        for c in node.get("children", []):
            visit(c, m)
        if "mesh" not in node:
            return
        for prim in g["meshes"][node["mesh"]]["primitives"]:
            att = prim["attributes"]
            pos = _read(g, bufs, att["POSITION"])
            nrm = _read(g, bufs, att["NORMAL"]) if "NORMAL" in att else [(0.0, 1.0, 0.0)] * len(pos)
            uvs = _read(g, bufs, att["TEXCOORD_0"]) if "TEXCOORD_0" in att else [(0.0, 0.0)] * len(pos)
            ix = _read(g, bufs, prim["indices"]) if "indices" in prim else list(range(len(pos)))
            mat = g["materials"][prim["material"]]["name"] if "material" in prim else ""
            cols = [(1.0, 1.0, 1.0)] * len(pos)
            if "COLOR_0" in att:
                a = g["accessors"][att["COLOR_0"]]
                scale = {5126: 1.0, 5121: 255.0, 5123: 65535.0}[a["componentType"]]
                cols = [tuple(x / scale for x in c[:3]) for c in _read(g, bufs, att["COLOR_0"])]
            verts = []
            for p, n, uv, col in zip(pos, nrm, uvs, cols):
                nn = _apply_normal(m, n)
                ln = sum(c * c for c in nn) ** 0.5 or 1.0
                verts.append(Vertex(_apply(m, p), tuple(c / ln for c in nn), uv, col))
            tris = out.setdefault(mat, [])
            for k in range(0, len(ix) - 2, 3):
                tris.append([verts[ix[k]], verts[ix[k + 1]], verts[ix[k + 2]]])

    for i in scene:
        visit(i, ident)
    return out


def _lerp(a, b, t):
    return Vertex(tuple(x + (y - x) * t for x, y in zip(a.p, b.p)), tuple(x + (y - x) * t for x, y in zip(a.n, b.n)),
                  tuple(x + (y - x) * t for x, y in zip(a.uv, b.uv)), tuple(x + (y - x) * t for x, y in zip(a.c, b.c)))


def _clip_poly(poly, axis, value, keep_above):
    out = []
    for i, cur in enumerate(poly):
        prev = poly[i - 1]
        cin = (cur.p[axis] >= value) if keep_above else (cur.p[axis] <= value)
        pin = (prev.p[axis] >= value) if keep_above else (prev.p[axis] <= value)
        if cin != pin:
            d = cur.p[axis] - prev.p[axis]
            out.append(_lerp(prev, cur, (value - prev.p[axis]) / d if d != 0 else 0.0))
        if cin:
            out.append(cur)
    return out


def clip(mesh, axis, lo=None, hi=None):
    """The part of `mesh` with axis (0 x, 1 y, 2 z) between lo and hi, triangles cut where they cross."""
    out = {}
    for mat, tris in mesh.items():
        kept = []
        for tri in tris:
            poly = list(tri)
            if lo is not None:
                poly = _clip_poly(poly, axis, lo, True)
            if hi is not None and len(poly) >= 3:
                poly = _clip_poly(poly, axis, hi, False)
            for k in range(1, len(poly) - 1):
                kept.append([poly[0], poly[k], poly[k + 1]])
        if kept:
            out[mat] = kept
    return out


def mapped(mesh, fn, normal_fn):
    """Every point through fn((x, y, z)) and normal through normal_fn((point), (normal)), each vertex once."""
    out = {}
    done = {}
    for mat, tris in mesh.items():
        out[mat] = []
        for tri in tris:
            new = []
            for v in tri:
                if id(v) not in done:
                    n = normal_fn(v.p, v.n)
                    ln = sum(c * c for c in n) ** 0.5 or 1.0
                    done[id(v)] = Vertex(fn(v.p), tuple(c / ln for c in n), v.uv, v.c)
                new.append(done[id(v)])
            out[mat].append(new)
    return out


def join(*meshes):
    out = {}
    for m in meshes:
        for mat, tris in m.items():
            out.setdefault(mat, []).extend(tris)
    return out


def renamed(mesh, names, default):
    """Materials renamed by `names` (unlisted ones to `default`, or kept when it is None); surfaces that end up with the same
    name are joined."""
    out = {}
    for mat, tris in mesh.items():
        out.setdefault(names.get(mat, mat if default is None else default), []).extend(tris)
    return out


def bounds(mesh):
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for tris in mesh.values():
        for tri in tris:
            for v in tri:
                for i in range(3):
                    lo[i] = min(lo[i], v.p[i])
                    hi[i] = max(hi[i], v.p[i])
    return lo, hi


def triangles(mesh):
    return sum(len(t) for t in mesh.values())


def write_glb(mesh, path, name):
    """One mesh node, one primitive per material (materials named only, no textures: the game draws its own)."""
    blob = bytearray()
    views = []
    accessors = []
    prims = []
    mats = []

    def add(data, target, comp, kind, count, lo=None, hi=None):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        acc = {"bufferView": len(views) - 1, "componentType": comp, "count": count, "type": kind}
        if lo is not None:
            acc["min"] = lo
            acc["max"] = hi
        accessors.append(acc)
        return len(accessors) - 1

    for mat in sorted(mesh):
        tris = mesh[mat]
        index = {}
        verts = []
        ix = []
        for tri in tris:
            for v in tri:
                key = (tuple(round(c, 5) for c in v.p), tuple(round(c, 4) for c in v.n), tuple(round(c, 5) for c in v.uv),
                       tuple(round(c, 3) for c in v.c))
                if key not in index:
                    index[key] = len(verts)
                    verts.append(key)
                ix.append(index[key])
        lo = [min(v[0][i] for v in verts) for i in range(3)]
        hi = [max(v[0][i] for v in verts) for i in range(3)]
        p = add(b"".join(struct.pack("<3f", *v[0]) for v in verts), 34962, 5126, "VEC3", len(verts), lo, hi)
        n = add(b"".join(struct.pack("<3f", *v[1]) for v in verts), 34962, 5126, "VEC3", len(verts))
        t = add(b"".join(struct.pack("<2f", *v[2]) for v in verts), 34962, 5126, "VEC2", len(verts))
        attributes = {"POSITION": p, "NORMAL": n, "TEXCOORD_0": t}
        if any(v[3] != (1.0, 1.0, 1.0) for v in verts):
            attributes["COLOR_0"] = add(b"".join(struct.pack("<3f", *v[3]) for v in verts), 34962, 5126, "VEC3", len(verts))
        i = add(b"".join(struct.pack("<I", k) for k in ix), 34963, 5125, "SCALAR", len(ix))
        mats.append({"name": mat, "pbrMetallicRoughness": {"baseColorFactor": [0.8, 0.8, 0.8, 1.0], "metallicFactor": 0.0}})
        prims.append({"attributes": attributes, "indices": i, "material": len(mats) - 1})
    while len(blob) % 4:
        blob.append(0)
    g = {"asset": {"version": "2.0", "generator": "tools/art/village_kit.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": name, "mesh": 0}], "meshes": [{"name": name, "primitives": prims}], "materials": mats,
         "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(blob)}]}
    js = json.dumps(g, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)
