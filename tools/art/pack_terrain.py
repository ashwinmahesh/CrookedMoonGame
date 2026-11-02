#!/usr/bin/env python3
"""Packs the overworld's ground textures the way Terrain3D reads them (world/overworld/overworld_terrain.gd).

Terrain3D takes two pictures a ground: albedo in RGB with height in alpha, and an OpenGL normal map in RGB with roughness
in alpha. Poly Haven ships the colour, the OpenGL normal and an AO/roughness/metal map apart (art/sourced/, kept untouched),
so this writes the packed pairs to art/overworld/ground/<name>_albedo_height.png and <name>_normal_rough.png at 1024 px.
Height is the colour's brightness stretched to the full range (Poly Haven's displacement maps weren't downloaded).

    /usr/bin/python3 tools/art/pack_terrain.py
"""
import os
import sys

from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIZE = 1024
# The overworld's grounds in Terrain3D's texture order (OverworldTerrain.GROUNDS keeps the same order).
GROUNDS = [
    ("meadow", "art/sourced/polyhaven_overworld/textures/leafy_grass/leafy_grass"),
    ("moor", "art/sourced/polyhaven_overworld/textures/withered_grass/withered_grass"),
    ("rock", "art/sourced/polyhaven_overworld/textures/rocky_terrain_02/rocky_terrain_02"),
    ("road", "art/sourced/polyhaven_overworld/textures/stony_dirt_path/stony_dirt_path"),
    ("woods", "art/sourced/polyhaven_forest/textures/forest_leaves_02/forest_leaves_02"),
    ("hill", "art/sourced/polyhaven_overworld/textures/aerial_grass_rock/aerial_grass_rock"),
]


def pack(name: str, stem: str) -> None:
    src = os.path.join(ROOT, stem)
    albedo = Image.open(src + "_diff_2k.jpg").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    height = ImageOps.autocontrast(albedo.convert("L"), cutoff=1)
    normal = Image.open(src + "_nor_gl_2k.jpg").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    rough = Image.open(src + "_arm_2k.jpg").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).split()[1]
    out = os.path.join(ROOT, "art/overworld/ground")
    os.makedirs(out, exist_ok=True)
    Image.merge("RGBA", (*albedo.split(), height)).save(os.path.join(out, name + "_albedo_height.png"))
    Image.merge("RGBA", (*normal.split(), rough)).save(os.path.join(out, name + "_normal_rough.png"))
    print("packed", name)


def main() -> int:
    for name, stem in GROUNDS:
        pack(name, stem)
    return 0


if __name__ == "__main__":
    sys.exit(main())
