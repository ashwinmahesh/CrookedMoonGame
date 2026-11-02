"""The Quaternius packs' own surfaces for the game's realistic look (Ashwin, 2026-11-02: fully 3D, realistic lighting and
textures, no toon): each texture set the village kit and the pack props draw with, copied from the pack's "glTF (Godot)"
folder (its normal maps are Godot's way up) at 1024 px to art/textures/<theme>/, and listed in the game's
art/textures/manifest.json under the themes "vkit" (Medieval Village MegaKit) and "vpro" (Fantasy Props MegaKit).

A module surface named tex_vkit__plaster is that set: the engine draws it with its world-mapped cel texture, and
world/look/pack_materials.gd swaps in a plain lit material on the model's own UVs (the trim sheets need them), with the
set's albedo, normal map and roughness (from an ORM map's green, or a roughness map), and its vertex colours where
`vertex` is set (the props' tinted trims). Used by tools/art/village_kit.py and tools/art/fantasy_props.py.

    python3 tools/art/pack_textures.py
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = "art/textures/manifest.json"
SIZE = 1024
VILLAGE = "sourced/quaternius_medieval_village_megakit_source/pack/glTF (Godot)"
PROPS = "sourced/quaternius_fantasy_props_megakit_source/pack/Exports/glTF (Godot)"

# theme -> set -> (pack folder, albedo, normal, roughness map, "orm" or "rough", extra)
SETS = {
    "vkit": {
        "plaster": (VILLAGE, "T_Plaster_BaseColor", "T_Plaster_Normal", "T_Plaster_ORM", "orm", {}),
        # (a house's core and gable ends, which the engine builds without the pack's UVs: mapped by world position)
        "plaster_core": (VILLAGE, "T_Plaster_BaseColor", "T_Plaster_Normal", "T_Plaster_ORM", "orm", {"triplanar": True}),
        "woodtrim": (VILLAGE, "T_WoodTrim_BaseColor", "T_WoodTrim_Normal", "T_WoodTrim_Roughness", "rough", {}),
        "brick": (VILLAGE, "T_Brick_BaseColor", "T_Brick_Normal", "T_Brick_Roughness", "rough", {}),
        "unevenbrick": (VILLAGE, "T_UnevenBrick_BaseColor", "T_UnevenBrick_Normal", "T_UnevenBrick_Roughness", "rough", {}),
        "redbrick": (VILLAGE, "T_RedBrick_BaseColor", "T_Brick_Normal", "T_Brick_Roughness", "rough", {}),
        "rocktrim": (VILLAGE, "T_RockTrim_BaseColor", "T_RockTrim_Normal", "T_RockTrim_ORM", "orm", {}),
        "roundtiles": (VILLAGE, "T_RoundTiles_BaseColor", "T_RoundTiles_Normal", "T_RoundTiles_Roughness", "rough", {}),
        "flattiles": (VILLAGE, "T_FlatTiles_BaseColor", "T_FlatTiles_Normal", "T_FlatTiles_Roughness", "rough", {}),
        "metal": (VILLAGE, "T_MetalOrnaments_BaseColor", None, "T_MetalOrnaments_Roughness", "rough", {"metallic": 0.8}),
        # (the pack's glass is a flat dark pane)
        "glass": (None, None, None, None, None, {"colour": [0.05, 0.06, 0.09], "roughness": 0.1}),
    },
    "vpro": {
        "furniture": (PROPS, "T_Trim_Furniture_BaseColor", "T_Trim_Furniture_Normal", "T_Trim_Furniture_ORM", "orm", {}),
        "metal": (PROPS, "T_Trim_Metal_BaseColor", "T_Trim_Metal_Normal", "T_Trim_Metal_ORM", "orm", {"metallic": 0.7}),
        "metal_v": (PROPS, "T_Trim_Metal_BaseColor", "T_Trim_Metal_Normal", "T_Trim_Metal_ORM", "orm", {"metallic": 0.7, "vertex": True}),
        "props": (PROPS, "T_Trim_Props_BaseColor", "T_Trim_Props_Normal", "T_Trim_Props_ORM", "orm", {}),
        "props_v": (PROPS, "T_Trim_Props_BaseColor", "T_Trim_Props_Normal", "T_Trim_Props_ORM", "orm", {"vertex": True}),
        "cloth": (PROPS, "T_Trim_Cloth_BaseColor", "T_Trim_Cloth_Normal", "T_Trim_Cloth_ORM", "orm", {}),
    },
}


def asset_root():
    return subprocess.run([sys.executable, os.path.join(ROOT, "tools/asset_root.py")], capture_output=True, text=True,
                          check=True, cwd=ROOT).stdout.strip()


def _copy(src, dst):
    """The pack image at SIZE px (sips, the Mac's own), unless it is already there."""
    if os.path.exists(dst):
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    subprocess.run(["sips", "-Z", str(SIZE), src, "--out", dst], check=True, capture_output=True)


def main():
    root = asset_root()
    path = os.path.join(ROOT, MANIFEST)
    manifest = json.load(open(path))
    themes = manifest.setdefault("themes", {})
    for theme, sets in SETS.items():
        out = themes.setdefault(theme, {})
        for name, (folder, albedo, normal, rough, kind, extra) in sets.items():
            entry = {"wrap": "xy", "tile_world_units": 2.0, "pack": True}
            entry.update(extra)
            for key, img in (("file", albedo), ("normal_file", normal), ("rough_file" if kind == "rough" else "orm_file", rough)):
                if img is None:
                    continue
                rel = "art/textures/%s/%s.png" % (theme, img[2:].lower())
                _copy(os.path.join(root, folder, img + ".png"), os.path.join(ROOT, rel))
                entry[key] = rel
            if "file" not in entry:
                # A plain colour: the engine still needs a picture for its fallback; the albedo's colour carries it.
                entry["file"] = "art/textures/%s/plaster_basecolor.png" % theme
            out[name] = entry
    with open(path, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("texture sets:", ", ".join("%s/%s" % (t, n) for t, s in SETS.items() for n in s))


if __name__ == "__main__":
    main()
