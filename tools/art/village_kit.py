"""The building kit's "village" style from Quaternius's Medieval Village MegaKit (CC0): cuts, scales and re-materials the
pack's walls, corners, doors, windows and roofs into the modules TownBuilder builds houses from (the engine's
docs/reference/art/building_kit.md), writes them to art/models/kit/village/ and lists them in the game's
art/models/kit/manifest.json (merged over the engine's). The pack itself stays untouched on the asset root.

    python3 tools/art/village_kit.py            # every module, then the manifest
    python3 tools/art/village_kit.py --list     # what it would make, from which pieces

The pack builds a storey 3.12 m high from walls 2 m wide; the kit's storey is H = 2.2 world units over a square 1 unit wide,
so a wall is squeezed to 0.53 of its width (the faces overlap a little, as the kit's own do) and 0.705 of its height. Its
surfaces are the pack's own textures (tools/art/pack_textures.py), drawn on the pieces' UVs by world/look/pack_materials.gd.
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gltf_mesh as G  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = "art/models/kit/village"
MANIFEST = "art/models/kit/manifest.json"
PACK_REL = "sourced/quaternius_medieval_village_megakit_source/pack/glTF"

# The kit's numbers (the engine's art/models/kit/manifest.json "constants").
H = 2.2
LOW_TOP = 1.09
FOOT = 0.343
DOOR_TOP = 2.04

STOREY = 3.12          # the pack's wall height
SX = 0.53              # a 2 m wall to a little over one square
SY = H / STOREY        # 0.705
SZ = 0.25              # the pack's 0.4 m walls to 0.1
BACK = -0.31           # the pack wall's inner face (its outer face is +z)
SINK = 0.01            # how far a face's back sits inside the house's core

# The pack's materials as the game's texture sets (tools/art/pack_textures.py: its own albedo, normal and roughness,
# drawn on the model's UVs by world/look/pack_materials.gd).
MATERIALS = {
    "MI_Plaster": "tex_vkit__plaster",
    "MI_WoodTrim": "tex_vkit__woodtrim",
    "MI_WoodTrim_Wear": "tex_vkit__woodtrim",
    "MI_Brick": "tex_vkit__brick",
    "MI_UnevenBrick": "tex_vkit__unevenbrick",
    "MI_RedBrick": "tex_vkit__redbrick",
    "MI_RockTrim": "tex_vkit__rocktrim",
    "MI_RoundTiles": "tex_vkit__roundtiles",
    "MI_FlatTiles": "tex_vkit__flattiles",
    "MI_WindowGlass": "tex_vkit__glass",
    "MI_MetalOrnaments": "tex_vkit__metal",
}
DEFAULT = "pal_slate"

# The styles cut from the pack: each its walls (a lower band from `lows`, an upper band from `ups`, picked per face by the
# kit), window wall, door wall, footing, corner post (its material), roof (the pack's modular roofs, 4, 6 and 8 m across)
# and the gable fronts that close it. village: plaster over a brick plinth, timbered above, round tiles (Wickermoor's,
# Foxwillow's, every village-theme town's); vstone: uneven brick and flat tiles (the cemetery's, the roads', the
# riverside's); vwood: weathered boards and flat tiles (the woods' cabins and communes).
STYLES = {
    "village": {"lows": {"low_a": "Wall_Plaster_Straight_Base"},
                "ups": {"up_a": "Wall_Plaster_WoodGrid", "up_b": "Wall_Plaster_Straight"},
                "window_wall": "Wall_Plaster_Window_Wide_Flat", "door_wall": "Wall_Plaster_Door_Flat",
                "foot_wall": "Wall_UnevenBrick_Straight", "corner": "MI_WoodTrim",
                "roof": "Roof_Modular_RoundTiles_%d_Mid", "roof_top": {4: 3.71, 6: 4.89, 8: 6.1}, "gable": "Roof_Front_Wood%d"},
    "vstone": {"lows": {"low_a": "Wall_UnevenBrick_Straight"},
               "ups": {"up_a": "Wall_UnevenBrick_Straight"},
               "window_wall": "Wall_UnevenBrick_Window_Wide_Flat", "door_wall": "Wall_UnevenBrick_Door_Flat",
               "foot_wall": "Wall_UnevenBrick_Straight", "corner": "MI_RockTrim",
               "roof": "Roof_Modular_FlatTiles_%d_Mid", "roof_top": {4: 3.58, 6: 4.89, 8: 6.1}, "gable": "Roof_Front_Brick%d"},
    "vwood": {"lows": {"low_a": "Wall_WoodWear_Straight"},
              "ups": {"up_a": "Wall_WoodWear_Straight", "up_b": "Wall_WoodBrick_Straight"},
              "window_wall": "Wall_WoodWear_Window_Wide_Flat", "door_wall": "Wall_WoodWear_Door_Flat",
              "foot_wall": "Wall_UnevenBrick_Straight", "corner": "MI_WoodTrim",
              "roof": "Roof_Modular_FlatTiles_%d_Mid", "roof_top": {4: 3.58, 6: 4.89, 8: 6.1}, "gable": "Roof_Front_Wood%d"},
}
WINDOW = "Window_Wide_Flat1"
SHUTTERS = "WindowShutters_Wide_Flat_Closed"
WINDOW_FROM = 0.94     # where the pack's wide windows start: a window face's upper band is the wall from here up
CORNER = "Corner_Exterior_Wood"
# Yard walls (waist high, free standing): the uneven brick wall's outer face, doubled back to back and capped with the
# pack's stone border; a pier where it turns or ends is the brick chimney stack's foot. YARD_H is the kit's arm height.
YARD_WALL = "Wall_UnevenBrick_Straight"
YARD_CAP = "Prop_ExteriorBorder_Straight1"
PIER = "Prop_Chimney"
YARD_H = 1.08
PIER_H = 1.28
PILLAR_H = 2.36
SPANS = range(1, 13)
# Inside: a timbered wall face over each whole side of a room wall, the pack's door frame round each doorway, a wood
# strip along the walls' tops.
FACE = "Wall_Plaster_WoodGrid"
ROOM_H = 2.4           # InteriorWalls' height for a style it has no entry for
DOORFRAME = "DoorFrame_Flat_WoodDark"
LINTEL = 2.14          # where the frame's lintel starts
DOORWAY_H = 1.15       # the kit's doorway (its jambs' top, the head's foot)
COPING = "Wall_BottomCover"
VERGE = 0.3            # how far a roof's end runs out past its gable


def pack_dir():
    root = subprocess.run([sys.executable, os.path.join(ROOT, "tools/asset_root.py")], capture_output=True, text=True,
                          check=True, cwd=ROOT).stdout.strip()
    return os.path.join(root, PACK_REL)


def piece(name):
    return G.load(os.path.join(pack_dir(), name + ".gltf"))


def wall_band(name, lo, hi, to_lo, scale_y):
    """The pack wall `name` between heights lo and hi (m), its foot at to_lo, `scale_y` units a metre."""
    m = G.clip(piece(name), 1, lo, hi)
    return G.mapped(m, lambda p: (p[0] * SX, to_lo + (p[1] - lo) * scale_y, (p[2] - BACK) * SZ - SINK),
                    lambda p, n: (n[0] / SX, n[1] / scale_y, n[2] / SZ))


def window_band(name):
    """A window face's upper band and what fills it: the pack from WINDOW_FROM up, squeezed into LOW_TOP..H."""
    s = (H - LOW_TOP) / (STOREY - WINDOW_FROM)
    return wall_band(name, WINDOW_FROM, None, LOW_TOP, s)


def corner(material, thick=1.0):
    """The pack's wood corner post, in `material` (a stone style's is a dressed stone quoin of the same shape)."""
    m = G.renamed(piece(CORNER), {}, material)
    top = G.bounds(m)[1][1]
    s = H / top
    return G.mapped(m, lambda p: (p[0] * thick, p[1] * s, p[2] * thick), lambda p, n: (n[0] / thick, n[1] / s, n[2] / thick))


def roof_size(style, span):
    """The pack roof a span is cut from, how far across a metre of it goes, and the rise."""
    w = 4 if span <= 2 else (6 if span == 3 else 8)
    across = span / float(w)
    rise = min(max(span * 0.7, 0.8), 3.2)
    return w, across, rise, rise / STYLES[style]["roof_top"][w]


def roof_slice(style, span, end=False):
    """One square of roof along the ridge (the kit's x), `span` squares across (its z): the pack piece turned a quarter."""
    w, across, rise, sy = roof_size(style, span)
    m = piece(STYLES[style]["roof"] % w)
    if end:
        # The verge: the outer part of a slice, run out past the gable (the kit turns an end so its +x points out).
        start = 1.05 - VERGE / 0.5
        m = G.clip(m, 2, start, None)
        return G.mapped(m, lambda p: ((p[2] - start) * 0.5, p[1] * sy, p[0] * across),
                        lambda p, n: (n[2] / 0.5, n[1] / sy, n[0] / across))
    return G.mapped(m, lambda p: (p[2] * 0.5, p[1] * sy, p[0] * across),
                    lambda p, n: (n[2] / 0.5, n[1] / sy, n[0] / across))


def gable(style, span):
    w, across, rise, sy = roof_size(style, span)
    m = piece(STYLES[style]["gable"] % w)
    return G.mapped(m, lambda p: (p[0] * across, p[1] * sy, p[2] * SZ),
                    lambda p, n: (n[0] / across, n[1] / sy, n[2] / SZ))


def yard_arm():
    """Half a square of free-standing wall, from the square's middle out along +x: the brick face twice, back to back."""
    front = G.clip(G.clip(piece(YARD_WALL), 0, 0.0, 1.0), 2, -0.11, None)
    front = G.clip(front, 1, None, YARD_H / SY)
    back = G.mapped(front, lambda p: (p[0], p[1], -0.22 - p[2]), lambda p, n: (n[0], n[1], -n[2]))
    wall = G.mapped(G.join(front, back), lambda p: (p[0] * 0.5, p[1] * SY, (p[2] + 0.11) * 1.2),
                    lambda p, n: (n[0] / 0.5, n[1] / SY, n[2] / 1.2))
    cap = G.mapped(G.clip(piece(YARD_CAP), 0, 0.0, 1.0), lambda p: (p[0] * 0.5, YARD_H - 0.02 + p[1] * 0.6, (p[2] - 0.35) * 0.8),
                   lambda p, n: (n[0] / 0.5, n[1] / 0.6, n[2] / 0.8))
    return G.join(wall, cap)


def stack(height, width):
    """The pack's brick chimney stack from its foot, `width` across and `height` high (a yard wall's pier, a lone pillar)."""
    m = piece(PIER)
    lo, hi = G.bounds(m)
    sx = width / (hi[0] - lo[0])
    sy = height / (hi[1] - lo[1])
    return G.mapped(m, lambda p: (p[0] * sx, (p[1] - lo[1]) * sy, p[2] * sx), lambda p, n: (n[0] / sx, n[1] / sy, n[2] / sx))


def modules():
    """id -> (part, mesh, extra manifest fields)."""
    ids = {}
    for style in STYLES:
        for k, v in style_modules(style).items():
            ids["kit_%s_%s" % (style, k)] = v
        for span in SPANS:
            rise = roof_size(style, span)[2]
            ids["kit_%s_slate_w%d" % (style, span)] = ("roof", roof_slice(style, span), {"span": span, "rise": round(rise, 3)})
            ids["kit_%s_slate_w%d_end" % (style, span)] = ("roof_end", roof_slice(style, span, True),
                                                           {"span": span, "rise": round(rise, 3)})
            ids["kit_%s_gable_w%d" % (style, span)] = ("gable", gable(style, span), {"span": span})
        ids["kit_pillar_%s" % style] = ("pillar", stack(PILLAR_H, 0.62), {})
    for k, v in inside().items():
        ids["kit_village_%s" % k] = v
    return ids


def style_modules(style):
    """A style's wall modules."""
    st = STYLES[style]
    out = {}
    low_cut = LOW_TOP / SY
    for k, name in st["lows"].items():
        out[k] = ("low", wall_band(name, 0.0, low_cut, 0.0, SY), {})
    for k, name in st["ups"].items():
        out[k] = ("up", wall_band(name, low_cut, None, LOW_TOP, SY), {})
    out["up_win"] = ("up", window_band(st["window_wall"]), {})
    glass = {"glass": [0, round((LOW_TOP + (H - LOW_TOP) * (1.73 - WINDOW_FROM) / (STOREY - WINDOW_FROM)), 3), 0.03]}
    win = window_band(WINDOW)
    out["window"] = ("window", win, {"sockets": glass})
    out["window_lit"] = ("window", G.renamed(win, {"MI_WindowGlass": "glow_candle"}, None), {"sockets": glass})
    out["window_shut"] = ("window", G.join(window_band(SHUTTERS), win), {"sockets": glass})
    door_cut = DOOR_TOP / SY
    out["door"] = ("door", wall_band(st["door_wall"], 0.0, door_cut, 0.0, SY), {})
    out["door_top"] = ("door_top", wall_band(st["door_wall"], door_cut, None, DOOR_TOP, SY), {})
    out["foot"] = ("foot", wall_band(st["foot_wall"], 0.0, FOOT / SY, 0.0, SY), {})
    out["corner"] = ("corner", corner(st["corner"], 1.0 if st["corner"] == "MI_WoodTrim" else 1.4), {})
    out["yard_arm"] = ("yard_arm", yard_arm(), {"height": YARD_H})
    out["yard_pier"] = ("yard_pier", stack(PIER_H, 0.66), {})
    return out


def inside():
    """The village style's interior parts (docs/reference/art/building_kit.md "Interiors"), for every room it dresses."""
    out = {}
    sy = ROOM_H / STOREY
    # A square's width of the pack's wall at one even scale (the room's height over the pack's storey), never squeezed:
    # the middle of the 2 m piece, cut to the share of it a square holds.
    half = 0.5 / sy
    face = G.mapped(G.clip(piece(FACE), 0, -half, half), lambda p: (p[0] * sy, p[1] * sy, (p[2] - BACK) * 0.2),
                    lambda p, n: (n[0] / sy, n[1] / sy, n[2] / 0.2))
    out["face"] = ("face", face, {})
    frame = piece(DOORFRAME)
    fx = 1.18 / 1.58
    jy = DOORWAY_H / LINTEL
    hy = 0.15 / (2.3 - LINTEL)
    out["doorway"] = ("doorway", G.mapped(G.clip(frame, 1, None, LINTEL),
                                          lambda p: (p[0] * fx, p[1] * jy, (p[2] + 0.24) * 0.25 - 0.01),
                                          lambda p, n: (n[0] / fx, n[1] / jy, n[2] / 0.25)), {})
    out["doorway_head"] = ("doorway_head", G.mapped(G.clip(frame, 1, LINTEL, None),
                                                    lambda p: (p[0] * fx, DOORWAY_H + (p[1] - LINTEL) * hy, (p[2] + 0.24) * 0.3 - 0.01),
                                                    lambda p, n: (n[0] / fx, n[1] / hy, n[2] / 0.3)), {})
    out["coping"] = ("coping", G.mapped(piece(COPING), lambda p: (p[0] * 0.5, 1.09 + (p[1] + 0.12) * 0.25, (p[2] + 0.31) * 0.19 - 0.01),
                                        lambda p, n: (n[0] / 0.5, n[1] / 0.25, n[2] / 0.19)), {})
    return out


# --- Natural size (Ashwin, 2026-11-02: "we are not building for the 5 foot grid. We are building a world that looks natural
# and then putting the grid on top of it afterwards") ------------------------------------------------------------------
# The pack's pieces at their own size, 1 unit = 5 ft = 1.524 m (the figures' scale), for world/look/natural_houses.gd, which
# lays them along each wall's real length instead of one per square. A wall piece is centred on x, its foot at y 0, its
# inner face at z 0 and its outer face out along +z; a roof piece's ridge runs along x.
REAL = 1.0 / 1.524
NATURAL = {
    "village": {"low": "Wall_Plaster_Straight_Base", "up": "Wall_Plaster_WoodGrid", "low_win": "Wall_Plaster_Window_Wide_Flat",
                "up_win": "Wall_Plaster_Window_Wide_Flat", "door": "Wall_Plaster_Door_Flat",
                "roof": "Roof_Modular_RoundTiles_%d_Mid", "gable": "Roof_Front_Wood%d", "corner": "MI_WoodTrim"},
    "vstone": {"low": "Wall_UnevenBrick_Straight", "up": "Wall_UnevenBrick_Straight", "low_win": "Wall_UnevenBrick_Window_Wide_Flat",
               "up_win": "Wall_UnevenBrick_Window_Wide_Flat", "door": "Wall_UnevenBrick_Door_Flat",
               "roof": "Roof_Modular_FlatTiles_%d_Mid", "gable": "Roof_Front_Brick%d", "corner": "MI_RockTrim"},
    "vwood": {"low": "Wall_WoodWear_Straight", "up": "Wall_WoodBrick_Straight", "low_win": "Wall_WoodWear_Window_Wide_Flat",
              "up_win": "Wall_WoodBrick_Window_Wide_Flat", "door": "Wall_WoodWear_Door_Flat",
              "roof": "Roof_Modular_FlatTiles_%d_Mid", "gable": "Roof_Front_Wood%d", "corner": "MI_WoodTrim"},
}


def real_size(name, z_from=None):
    """Pack piece `name` at its own size; with `z_from`, moved so that depth is z 0 (a wall's inner face)."""
    m = piece(name)
    dz = -z_from if z_from is not None else 0.0
    return G.mapped(m, lambda p: (p[0] * REAL, p[1] * REAL, (p[2] + dz) * REAL), lambda p, n: n)


def natural():
    out = {}
    for style, st in NATURAL.items():
        for part in ["low", "up", "low_win", "up_win", "door"]:
            out["kit_nat_%s_%s" % (style, part)] = ("nat_wall", real_size(st[part], BACK), {})
        out["kit_nat_%s_corner" % style] = ("nat_corner", G.renamed(real_size(CORNER), {}, st["corner"]), {})
        for w in (4, 6, 8):
            roof = piece(st["roof"] % w)
            out["kit_nat_%s_roof%d" % (style, w)] = ("nat_roof", G.mapped(roof, lambda p: (p[2] * REAL, p[1] * REAL, p[0] * REAL),
                                                                             lambda p, n: (n[2], n[1], n[0])), {"wall_m": w})
            out["kit_nat_%s_gable%d" % (style, w)] = ("nat_gable", real_size(st["gable"] % w), {"wall_m": w})
    win = real_size(WINDOW, BACK)
    out["kit_nat_window"] = ("nat_window", win, {})
    out["kit_nat_window_lit"] = ("nat_window", G.renamed(win, {"MI_WindowGlass": "glow_candle"}, None), {})
    out["kit_nat_window_shut"] = ("nat_window", G.join(real_size(SHUTTERS, BACK), win), {})
    out["kit_nat_chimney"] = ("nat_chimney", real_size("Prop_Chimney"), {})
    return out


def main():
    listing = "--list" in sys.argv
    os.makedirs(os.path.join(ROOT, OUT), exist_ok=True)
    path = os.path.join(ROOT, MANIFEST)
    manifest = json.load(open(path)) if os.path.exists(path) else {}
    manifest["about"] = ("The game's building kit modules, merged over the engine's art/models/kit/manifest.json (ArtPaths.json): "
                         "the village, vstone and vwood styles, cut from Quaternius's Medieval Village MegaKit by tools/art/village_kit.py.")
    models = manifest.setdefault("models", {})
    for mid, (part, mesh, extra) in sorted(dict(modules(), **natural()).items()):
        mesh = G.renamed(mesh, dict(MATERIALS, glow_candle="glow_candle"), DEFAULT)
        lo, hi = G.bounds(mesh)
        rel = "%s/%s.glb" % (OUT, mid)
        if listing:
            print(mid, part, [round(hi[i] - lo[i], 3) for i in range(3)], G.triangles(mesh), sorted(mesh))
            continue
        G.write_glb(mesh, os.path.join(ROOT, rel), mid)
        entry = {"file": rel, "mount": "kit", "stands_for": [], "size": [round(hi[i] - lo[i], 3) for i in range(3)],
                 "materials": sorted(mesh), "triangles": G.triangles(mesh), "part": part,
                 "sourced": ["quaternius_medieval_village_megakit_source"]}
        entry.update(extra)
        models[mid] = entry
    if not listing:
        with open(path, "w") as f:
            json.dump(manifest, f, indent=1, sort_keys=True)
            f.write("\n")
        print("wrote %d modules to %s" % (len(models), OUT))


if __name__ == "__main__":
    main()
