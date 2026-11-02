#!/usr/bin/env python3
"""Runs blender/plants_crooked_moon.py's builders outside Blender, against a small stand-in for Blender's vectors and mesh editor, to
catch a typo or a bad grid before a once-an-hour Blender turn is spent on it, and to count each plant's triangles and measure its size.

  python3 tools/art/plants_dry_run.py [corn_a wytch_a ...]

The stand-in keeps only what plants_3d.Plant uses (vertices, faces, per-loop layers); it checks nothing about how the real mesh looks.
Triangles are counted the way the manifest counts them (a quad is two). Prints a line per plant, and the tallest and widest it reaches.
"""
import math
import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Vector:
    __slots__ = ("x", "y", "z")

    def __init__(self, v=(0.0, 0.0, 0.0)):
        self.x, self.y, self.z = (float(v[0]), float(v[1]), float(v[2]))

    def __getitem__(self, i):
        return (self.x, self.y, self.z)[i]

    def __len__(self):
        return 3

    def __iter__(self):
        return iter((self.x, self.y, self.z))

    def __add__(self, o):
        return Vector((self.x + o[0], self.y + o[1], self.z + o[2]))

    __radd__ = __add__

    def __sub__(self, o):
        return Vector((self.x - o[0], self.y - o[1], self.z - o[2]))

    def __rsub__(self, o):
        return Vector((o[0] - self.x, o[1] - self.y, o[2] - self.z))

    def __neg__(self):
        return Vector((-self.x, -self.y, -self.z))

    def __mul__(self, k):
        if isinstance(k, (int, float)):
            return Vector((self.x * k, self.y * k, self.z * k))
        raise TypeError("Vector * non-scalar")

    __rmul__ = __mul__

    def __truediv__(self, k):
        return Vector((self.x / k, self.y / k, self.z / k))

    @property
    def length(self):
        return math.sqrt(self.x ** 2 + self.y ** 2 + self.z ** 2)

    def normalized(self):
        n = self.length
        return Vector((self.x / n, self.y / n, self.z / n)) if n > 1e-12 else Vector((0, 0, 0))

    def dot(self, o):
        return self.x * o[0] + self.y * o[1] + self.z * o[2]

    def cross(self, o):
        return Vector((self.y * o[2] - self.z * o[1], self.z * o[0] - self.x * o[2], self.x * o[1] - self.y * o[0]))

    def lerp(self, o, t):
        return self * (1 - t) + Vector(o) * t

    def orthogonal(self):
        return self.cross((0, 0, 1)) if abs(self.z) < 0.9 else self.cross((1, 0, 0))


class Matrix:
    def __init__(self, rows):
        self.rows = rows

    @staticmethod
    def Rotation(angle, size, axis):
        a = Vector(axis).normalized()
        c, s = math.cos(angle), math.sin(angle)
        x, y, z = a.x, a.y, a.z
        return Matrix([[c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
                       [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
                       [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)]])

    def __matmul__(self, v):
        r = self.rows
        return Vector((sum(r[0][i] * v[i] for i in range(3)), sum(r[1][i] * v[i] for i in range(3)), sum(r[2][i] * v[i] for i in range(3))))


class _Layer:
    def __init__(self):
        self.n = 0

    def new(self, name=""):
        self.n += 1
        return (name, self.n)


class _Layers:
    def __init__(self):
        self.uv = _Layer()
        self.float_color = _Layer()


class _Loop:
    def __init__(self):
        self.d = {}

    def __getitem__(self, k):
        return types.SimpleNamespace(uv=None) if k[0] in ("UVMap", "Wind") else self.d.get(k)

    def __setitem__(self, k, v):
        self.d[k] = v


class _Face:
    def __init__(self, verts):
        self.verts = verts
        self.material_index = 0
        self.smooth = False
        self.loops = [_Loop() for _ in verts]


class _Verts(list):
    def new(self, co):
        v = types.SimpleNamespace(co=Vector(co))
        self.append(v)
        return v


class _Faces(list):
    def new(self, verts):
        assert len(set(id(v) for v in verts)) == len(verts), "a face repeats a vertex"
        f = _Face(verts)
        self.append(f)
        return f


class _BM:
    def __init__(self):
        self.loops = types.SimpleNamespace(layers=_Layers())
        self.verts = _Verts()
        self.faces = _Faces()


def install():
    bpy = types.ModuleType("bpy")
    bpy.data = types.SimpleNamespace(objects=[])
    bmesh = types.ModuleType("bmesh")
    bmesh.new = _BM
    mathutils = types.ModuleType("mathutils")
    mathutils.Vector = Vector
    mathutils.Matrix = Matrix
    sys.modules.update({"bpy": bpy, "bmesh": bmesh, "mathutils": mathutils})


def main(argv):
    install()
    sys.path.insert(0, str(ROOT / "blender"))
    import plants_3d as P
    import plants_crooked_moon as M
    ids = argv or M.MINE
    bad = 0
    for id_ in ids:
        p = P.Plant(id_, seed=sum(ord(c) * (i + 1) for i, c in enumerate(id_)))
        try:
            P.PLANTS[id_]["build"](p)
        except Exception as e:   # noqa: BLE001
            import traceback
            traceback.print_exc()
            print("FAILED", id_, e)
            bad += 1
            continue
        tris = sum(len(f.verts) - 2 for f in p.bm.faces)
        xs = [v.co.x for v in p.bm.verts]
        ys = [v.co.y for v in p.bm.verts]
        zs = [v.co.z for v in p.bm.verts]
        mats = {}
        for f in p.bm.faces:
            mats[p.mats[f.material_index]] = mats.get(p.mats[f.material_index], 0) + len(f.verts) - 2
        print("%-16s %5d triangles  size %.2f x %.2f x %.2f  z %.2f..%.2f  %s" % (
            id_, tris, max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs), min(zs), max(zs), mats))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
