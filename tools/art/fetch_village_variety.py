#!/usr/bin/env python3
"""Fetches the 30 CC0 texture sets that give the village houses (and, later, the roads) their variety, from Poly Haven
(https://polyhaven.com, CC0 1.0): each set's 2k diffuse, normal (OpenGL) and ARM (ao, roughness, metal) JPEGs, untouched, into
art/sourced/polyhaven_variety/<set>/ with a SOURCE.md and a LICENSE.txt beside them. About 230 MB; every file's md5 is checked
against Poly Haven's. Downloaded with Ashwin's yes (2026-11-03, the decision card "Download about 30 CC0 texture sets").
  python3 tools/art/fetch_village_variety.py            # fetch what is missing
  python3 tools/art/fetch_village_variety.py --list     # the sets, their kind, real-world size and author
The sets are wired by art/textures/manifest.json (themes.vkit, the `variants` lists) and credited in art/credits.json.
"""
import hashlib
import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "sourced" / "polyhaven_variety"
API = "https://api.polyhaven.com"

# kind -> sets. A kind is what the set is for (the manifest lists wall plaster, masonry, roofs and wood as variants;
# `ground` sets are only fetched, for later).
SETS = {
    "plaster": ["worn_plaster_wall", "worn_cracked_plaster", "worn_mossy_plasterwall", "grey_plaster_02", "red_plaster_weathered",
                "damaged_plaster", "rough_plaster_03", "plaster_stone_wall_01"],
    "masonry": ["castle_brick_01", "medieval_red_brick", "castle_brick_07", "rough_block_wall", "stone_brick_wall_001", "mossy_brick"],
    "roof": ["roof_slates_02", "roof_slates_03", "grey_roof_tiles_02", "clay_roof_tiles_03", "thatch_roof_angled"],
    "wood": ["weathered_planks", "weathered_brown_planks", "dark_planks", "old_planks_02", "wood_peeling_paint_weathered",
             "wood_planks_dirt"],
    "ground": ["cobblestone_floor_01", "cobblestone_floor_03", "mossy_cobblestone", "stone_pathway_02", "rock_embedded_floor"],
}
MAPS = {"Diffuse": "diff", "nor_gl": "nor_gl", "arm": "arm"}
LICENCE = "Creative Commons Zero (CC0 1.0), https://creativecommons.org/publicdomain/zero/1.0/"


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "CrookedMoonGame-asset-fetch/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def md5(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def authors(info: dict) -> str:
    return ", ".join(sorted(info["authors"]))


def main() -> None:
    listing = "--list" in sys.argv
    for kind, names in SETS.items():
        for name in names:
            info = get_json(f"{API}/info/{name}")
            size_m = info["dimensions"][0] / 1000.0
            if listing:
                print(f"{kind:8} {name:30} {size_m:5.2f} m  {authors(info)}")
                continue
            files = get_json(f"{API}/files/{name}")
            folder = OUT / name
            folder.mkdir(parents=True, exist_ok=True)
            got: list[str] = []
            for key, tag in MAPS.items():
                entry = files[key]["2k"]["jpg"]
                dest = folder / f"{name}_{tag}_2k.jpg"
                if not (dest.exists() and md5(dest) == entry["md5"]):
                    subprocess.run(["curl", "-fsSL", "--retry", "3", "-o", str(dest), entry["url"]], check=True)
                    if md5(dest) != entry["md5"]:
                        sys.exit(f"md5 mismatch: {dest}")
                    time.sleep(0.5)
                got.append(dest.name)
            (folder / "LICENSE.txt").write_text(
                f"{info['name']} by {authors(info)} (Poly Haven)\nhttps://polyhaven.com/a/{name}\n\nLicence: {LICENCE}\n"
                "The page states the work is in the public domain (CC0); no credit is required, but it is credited in art/credits.json.\n")
            (folder / "SOURCE.md").write_text(
                f"# {info['name']}\n\n- Source: https://polyhaven.com/a/{name}\n- Author: {authors(info)} (Poly Haven)\n- Licence: {LICENCE}\n"
                f"- Real-world size of one tile: {size_m:g} m\n"
                "- Downloaded: 2026-11-03, with Ashwin's yes (the decision card \"Download about 30 CC0 texture sets from Poly Haven and "
                "ambientCG?\"), by tools/art/fetch_village_variety.py\n"
                f"- What is here: the 2k diffuse ({got[0]}), normal ({got[1]}, OpenGL, green up) and ARM ({got[2]}: ambient occlusion in red, "
                "roughness in green, metal in blue) JPEGs, as delivered.\n"
                f"- For: per-house variety in the villages ({kind}): art/textures/manifest.json, themes.vkit, the `variants` lists "
                "(world/look/pack_materials.gd). Tileable sets, mapped by world position.\n\n"
                "Kept untouched (CLAUDE.md, Art): changes for the game are made on copies elsewhere, never in this folder.\n")
            print(f"ok   {kind:8} {name}")


if __name__ == "__main__":
    main()
