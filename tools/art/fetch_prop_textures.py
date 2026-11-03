#!/usr/bin/env python3
"""Fetches the CC0 PBR texture sets for the Ghostlight Express's cars, its track, the statues, the scarecrow and Barrow Hill's
standing stones (Ashwin, 2026-11-03 01:20Z: "find different ones online", his yes to download them), each into its own folder
under art/sourced/ as delivered, with SOURCE.md and LICENSE.txt, and prints the art/textures/manifest.json entries for them.

Poly Haven (polyhaven.com): the 2k diffuse (or a set's first colourway), OpenGL normal and AO/roughness/metal (arm) JPEGs. ambientCG (ambientcg.com): the
2K-JPG zip's colour, OpenGL normal and roughness JPEGs (the zip itself is not kept).
  python3 tools/art/fetch_prop_textures.py            # fetch what is missing
"""
import io
import json
import os
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UA = {"User-Agent": "CrookedMoonBuild/1.0"}
DATE = "2026-11-03"
YES = "with Ashwin's yes (his own message in the project thread, 2026-11-03 01:20Z: find different textures online)"

# name in the game's "props" texture theme: (site, asset id, tile size in units, what it is for)
SETS = {
    "passenger_panel": ("ph", "stained_pine", 1.6, "the Passenger Car's wall panelling"),
    "passenger_carpet": ("acg", "Carpet012", 1.2, "the Passenger Car's carpet"),
    "passenger_leather": ("ph", "leather_red_03", 0.8, "the Passenger Car's red leather seats"),
    "sleeper_panel": ("ph", "oak_veneer_01", 1.6, "the Sleeper Car's cabin walls"),
    "sleeper_carpet": ("ph", "dirty_carpet", 1.2, "the Sleeper Car's cabin carpet"),
    "sleeper_corridor": ("ph", "rectangular_parquet", 1.4, "the Sleeper Car's corridor floor"),
    "lounge_panel": ("ph", "walnut_veneer", 1.6, "the Lounge Car's walnut panelling"),
    "lounge_floor": ("ph", "herringbone_parquet", 1.4, "the Lounge Car's herringbone floor"),
    "lounge_velvet": ("ph", "velour_velvet", 0.8, "the Lounge Car's velvet banquettes"),
    "dining_panel": ("ph", "mocha_oak_veneer", 1.6, "the Dining Car's oak panelling"),
    "dining_floor": ("ph", "floor_tiles_06", 1.6, "the Dining Car's tiled floor"),
    "mail_wall": ("ph", "raw_plank_wall", 2.0, "the Mail Car's pine plank walls"),
    "mail_floor": ("ph", "worn_planks", 1.6, "the Mail Car's worn floorboards"),
    "baggage_wall": ("ph", "dark_wooden_planks", 2.0, "the Baggage Car's plank walls"),
    "baggage_floor": ("ph", "old_wood_floor", 1.6, "the Baggage Car's old floorboards"),
    "circus_wall": ("ph", "blue_painted_planks", 2.0, "the Circus Car's painted plank walls"),
    "circus_floor": ("ph", "wood_floor_worn", 1.6, "the Circus Car's worn floor"),
    "circus_iron": ("ph", "rusty_metal_02", 1.0, "the Circus Car's iron cages"),
    "track_ballast": ("ph", "rocky_gravel", 1.6, "the Ghostlight Express's ballast"),
    "track_sleeper": ("ph", "weathered_planks", 1.4, "the Ghostlight Express's sleepers and trestle"),
    "track_rail": ("ph", "rusty_metal", 1.0, "the Ghostlight Express's rails"),
    "stone_marble": ("acg", "Marble012", 1.2, "the saint statue's marble"),
    "stone_marble_cream": ("acg", "Marble014", 1.2, "the headless statue's marble"),
    "stone_granite": ("acg", "Granite002B", 1.2, "the knight statue's granite"),
    "stone_mossy": ("ph", "mossy_rock", 1.6, "Mother Night's mossy stone"),
    "stone_lichen": ("ph", "lichen_rock", 1.8, "Barrow Hill's standing stones"),
    "scarecrow_timber": ("ph", "rough_wood", 1.0, "the scarecrows' posts"),
    "scarecrow_straw": ("acg", "ThatchedRoof001A", 0.6, "the scarecrows' straw"),
}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return r.read()


def polyhaven(asset, folder):
    info = json.loads(get("https://api.polyhaven.com/info/" + asset))
    files = json.loads(get("https://api.polyhaven.com/files/" + asset))
    out = {}
    for key, kind in (("Diffuse", "file"), ("nor_gl", "normal_file"), ("arm", "orm_file")):
        if key not in files:
            key = "coll1"   # (a set made in colourways, a leather: its first)
        url = files[key]["2k"]["jpg"]["url"]
        name = url.rsplit("/", 1)[1]
        path = os.path.join(folder, name)
        if not os.path.exists(path):
            open(path, "wb").write(get(url))
        out[kind] = name
    authors = ", ".join(info.get("authors", {}).keys()) or "Poly Haven"
    return out, info.get("name", asset), authors, "https://polyhaven.com/a/" + asset


def ambientcg(asset, folder):
    out = {}
    wanted = {"_Color.jpg": "file", "_NormalGL.jpg": "normal_file", "_Roughness.jpg": "rough_file"}
    if not all(os.path.exists(os.path.join(folder, asset + "_2K-JPG" + s)) for s in wanted):
        z = zipfile.ZipFile(io.BytesIO(get("https://ambientcg.com/get?file=%s_2K-JPG.zip" % asset)))
        for n in z.namelist():
            for s in wanted:
                if n.endswith(s):
                    open(os.path.join(folder, os.path.basename(n)), "wb").write(z.read(n))
    for s, kind in wanted.items():
        out[kind] = asset + "_2K-JPG" + s
    return out, asset, "ambientCG (Lennart Demes)", "https://ambientcg.com/view?id=" + asset


def main():
    entries = {}
    for name, (site, asset, tile, use) in SETS.items():
        folder = os.path.join(ROOT, "art", "sourced", ("polyhaven_" if site == "ph" else "ambientcg_") + asset.lower())
        os.makedirs(folder, exist_ok=True)
        files, title, authors, page = (polyhaven if site == "ph" else ambientcg)(asset, folder)
        rel = os.path.relpath(folder, ROOT)
        what = ", ".join("%s (%s)" % (f, k.replace("_file", "").replace("file", "colour")) for k, f in files.items())
        open(os.path.join(folder, "SOURCE.md"), "w").write(
            "# %s\n\n- Source: %s\n- Author: %s\n- Licence: Creative Commons Zero (CC0 1.0), https://creativecommons.org/publicdomain/zero/1.0/\n"
            "- Downloaded: %s, %s, by tools/art/fetch_prop_textures.py\n- What is here: the 2K JPEGs as delivered: %s.\n- For: %s "
            "(art/textures/manifest.json, theme props, set %s).\n\nKept untouched (CLAUDE.md, Art): changes for the game are made on copies "
            "elsewhere, never in this folder.\n" % (title, page, authors, DATE, YES, what, use, name))
        open(os.path.join(folder, "LICENSE.txt"), "w").write(
            "%s by %s\n%s\n\nLicence: Creative Commons Zero (CC0 1.0), https://creativecommons.org/publicdomain/zero/1.0/\n"
            "The page states the work is in the public domain (CC0); no credit is required, but it is credited in art/credits.json.\n"
            % (title, authors, page))
        e = {k: rel + "/" + f for k, f in files.items()}
        e.update({"wrap": "xy", "tile_world_units": tile})
        entries[name] = e
        print("fetched", name, asset, file=sys.stderr)
    print(json.dumps(entries, indent=2))


if __name__ == "__main__":
    main()
