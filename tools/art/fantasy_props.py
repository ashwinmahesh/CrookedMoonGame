"""Set dressing from Quaternius's Fantasy Props MegaKit (CC0): each pack prop listed in PROPS stands in for the engine's own
model of the same thing, in every place that dresses with it (the props catalog's models3d "art", repointed by
`--catalog`). The pack itself stays untouched on the asset root; this writes art/models/props_pack/<id>.glb and lists them
in the game's art/models/manifest.json (merged over the engine's).

    python3 tools/art/fantasy_props.py              # the models and their manifest entries
    python3 tools/art/fantasy_props.py --catalog    # and point the catalog's art ids at them
    python3 tools/art/fantasy_props.py --list       # what it would make

A prop keeps the engine model's place: its footprint is fitted inside the old one's (turned a quarter when the pack's
long side runs the other way, scaled 0.75 to 1.2 of its real size, 1 unit = 5 ft), centred as a free piece,
its back on the wall line for one that stands or hangs against a wall; one still wider than the old piece (the pack's
beds and tables are life-size, the game's furniture keeps to its square) is narrowed to it, keeping its height, and never
shorter than life. Its surfaces are the pack's own trim sheets and vertex colours (tools/art/pack_textures.py).
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gltf_mesh as G  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = "art/models/props_pack"
MANIFEST = "art/models/manifest.json"
CORE_MANIFEST = "addons/dnd_core/art/models/manifest.json"
CATALOG = "art/sprites/props/catalog.json"
PACK_REL = "sourced/quaternius_fantasy_props_megakit_source/pack/Exports/glTF"
SOURCE = "quaternius_fantasy_props_megakit_source"
REAL = 1.0 / 1.524           # metres to squares
SCALE_RANGE = (0.75 * REAL, 1.2 * REAL)
FOOTPRINT_SLACK = 1.1        # how much wider than the old piece a prop may stand

# The engine model each pack prop replaces -> the pack piece.
PROPS = {
    "barrel": "Barrel",
    "crate": "Crate_Wooden",
    "chest": "Chest_Wood",
    "trunk": "Chest_Wood",
    "table": "Table_Large",
    "chair_high": "Chair_1",
    "bench": "Bench",
    "bed": "Bed_Double",
    "bed_small": "Bed_Twin1",
    "bookcase": "Bookcase_1",
    "desk": "Desk",
    "cauldron": "Cauldron",
    "wagon": "Wagon",
    "stall": "Stall_Empty",
    "workbench": "Workbench",
    "sack": "Bag",
    "footstool": "Stool",
    "cabinet_small": "Nightstand_Drawer",
    # Batch 2 (2026-11-02): shelving, kitchen and shop pieces, racks, and the market's stalls.
    "shelves": "Bookcase_2",
    "shelves_wall": "Shelf_Simple",
    "shelf_goods": "Shelf_Small_Bottles",
    "cookpot": "Pot_1",
    "stewpot": "Cauldron",
    "weapon_rack": "WeaponStand",
    "market_stall": "Stall_Vegetables_Full",
    "bucket_brush": "Bucket_Wooden_1",
    "tool_rack": "Peg_Rack",
    "footlocker": "Chest_Wood",
    "sideboard": "Dresser_1",
    "dressing_table": "Dresser_1",
    "lectern": "BookStand",
    "book_stack": "Book_Stack_2",
    "barrel_spigot": "Barrel_Holder",
    "cage_hanging": "Cage_Small",
    "sack_pile": "Bag_2",
    "reading_table": "Table_Large",
}

# The pack's materials as the game's texture sets (tools/art/pack_textures.py), drawn on the props' own UVs and vertex
# colours by world/look/pack_materials.gd.
MATERIALS = {
    "MI_Trim_Furniture": "tex_vpro__furniture",
    "MI_Trim_Metal": "tex_vpro__metal",
    "MI_Trim_Metal_Vertex": "tex_vpro__metal_v",
    "MI_Trim_Props": "tex_vpro__props",
    "MI_Trim_Props_Vertex": "tex_vpro__props_v",
    "MI_Trim_Cloth": "tex_vpro__cloth",
}
DEFAULT = "tex_vpro__props"


def asset_root():
    return subprocess.run([sys.executable, os.path.join(ROOT, "tools/asset_root.py")], capture_output=True, text=True,
                          check=True, cwd=ROOT).stdout.strip()


def fitted(mesh, core, core_lo=None):
    """The prop in the engine model's place: turned to run the same way, scaled into its footprint, seated the same."""
    lo, hi = G.bounds(mesh)
    cw, ch, cd = core["size"]
    pw, pd = hi[0] - lo[0], hi[2] - lo[2]
    turn = (pw > pd) != (cw > cd) and abs(pw - pd) > 0.15 * max(pw, pd) and abs(cw - cd) > 0.15 * max(cw, cd)
    if turn:
        mesh = G.mapped(mesh, lambda p: (-p[2], p[1], p[0]), lambda p, n: (-n[2], n[1], n[0]))
        lo, hi = G.bounds(mesh)
        pw, pd = hi[0] - lo[0], hi[2] - lo[2]
    s = min(max(min(cw / pw, cd / pd), SCALE_RANGE[0]), SCALE_RANGE[1])
    # Still wider than the old piece (the pack's beds and tables are life-size; the game's furniture keeps to a square):
    # narrowed to it, keeping its height.
    sx = min(s, cw * FOOTPRINT_SLACK / pw)
    sz = min(s, cd * FOOTPRINT_SLACK / pd)
    sy = max(s, REAL)   # never shorter than life: a table stays table-high beside the figures
    cx = (lo[0] + hi[0]) / 2.0
    back = core.get("mount") in ("against_wall", "wall")
    cz = lo[2] if back else (lo[2] + hi[2]) / 2.0
    # A piece hung on a wall keeps the old one's height on it (its model is drawn at that height).
    lift = core_lo[1] if core.get("mount") == "wall" and core_lo is not None else 0.0
    return G.mapped(mesh, lambda p: ((p[0] - cx) * sx, (p[1] - lo[1]) * sy + lift, (p[2] - cz) * sz),
                    lambda p, n: (n[0] / sx, n[1] / sy, n[2] / sz)), s, turn


def main():
    listing = "--list" in sys.argv
    core = json.load(open(os.path.join(ROOT, CORE_MANIFEST)))["models"]
    path = os.path.join(ROOT, MANIFEST)
    manifest = json.load(open(path))
    models = manifest["models"]
    src = os.path.join(asset_root(), PACK_REL)
    os.makedirs(os.path.join(ROOT, OUT), exist_ok=True)
    made = {}
    for engine_id, piece in sorted(PROPS.items()):
        old = core[engine_id]
        gpath = os.path.join(src, piece + ".gltf")
        mesh = G.renamed(G.load(gpath), MATERIALS, DEFAULT)
        mesh, s, turn = fitted(mesh, old, G.bounds(G.load(os.path.join(ROOT, "addons/dnd_core", old["file"])))[0])
        lo, hi = G.bounds(mesh)
        mid = "pp_" + engine_id
        size = [round(hi[i] - lo[i], 3) for i in range(3)]
        if listing:
            print(mid, piece, "scale %.2f of real" % (s / REAL), "turned" if turn else "", size, "was", old["size"],
                  G.triangles(mesh), sorted(mesh))
            continue
        rel = "%s/%s.glb" % (OUT, mid)
        G.write_glb(mesh, os.path.join(ROOT, rel), mid)
        entry = {k: v for k, v in old.items() if k in ("mount", "stands_for", "turns", "sockets", "see_through")}
        entry.update({"file": rel, "size": size, "materials": sorted(mesh), "triangles": G.triangles(mesh),
                      "sourced": [SOURCE], "replaces": engine_id})
        models[mid] = entry
        made[engine_id] = mid
    if listing:
        return
    with open(path, "w") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    print("wrote %d props to %s" % (len(made), OUT))
    if "--catalog" in sys.argv:
        repoint(made)


def repoint(made):
    """Every art id the catalog draws with a replaced engine model now draws with the pack's."""
    path = os.path.join(ROOT, CATALOG)
    text = open(path).read()
    cat = json.loads(text)
    art = cat["models3d"]["art"]
    n = 0
    for k, v in art.items():
        if isinstance(v, str) and v in made:
            art[k] = made[v]
            n += 1
        elif isinstance(v, dict):
            for t, m in v.items():
                if m in made:
                    v[t] = made[m]
                    n += 1
        elif isinstance(v, list):
            for i, m in enumerate(v):
                if m in made:
                    v[i] = made[m]
                    n += 1
    with open(path, "w") as f:
        json.dump(cat, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("repointed %d catalog art ids" % n)


if __name__ == "__main__":
    main()
