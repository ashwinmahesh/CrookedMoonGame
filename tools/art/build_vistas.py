#!/usr/bin/env /usr/bin/python3
"""Cuts the painted backdrops seen past a map's edge (the engine's Vista, docs/art/atmosphere.md "Vistas") out of their plain white
ground: <asset root>/vistas/<id>_<take>.png -> art/vistas/<id>.png with a soft alpha, so the mist at a landmark's foot thins out
rather than stopping at a hard edge. Retargeted from Curse of Strahd's tool (read only) to the local image service.

  /usr/bin/python3 tools/art/build_vistas.py [--generate] [--only id ...] [--places]

--generate queues the paintings that don't exist yet (one per landmark, look P, art/prompts/vista_preamble.txt) on the image queue and
waits for them. --places writes art/vistas/vistas.json: every location's place on the travel art (`places`, from data/travel and the
locations' regions) and each landmark's entry (`landmarks`) from tools/art/vista_recipes.json. Needs PIL (macOS /usr/bin/python3); the queue
client is tools/art/generate_local.py.
"""
from __future__ import annotations
import argparse, glob, json, math, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RECIPES = ROOT / "tools/art/vista_recipes.json"
ASSETS = Path("/Volumes/ASH-SSD/CrookedMoon/assets/vistas")
# A region's own place on the travel art, when no travel place names the location itself.
REGION_PLACE = {"wickermoor": "wickermoor_village", "crooked_house": "druskenvald_estate", "ghostlight_express": "ghostlight_wreckage",
                "foxwillow": "foxwillow", "fields_of_the_crow": "foxwillow", "dawns_gate": "dawns_gate", "crimson_monastery": "dawns_gate",
                "drowned_crossroads": "dc_murkwater", "skitterdeep_mine": "sk_camp", "memorys_rest": "memorys_rest",
                "hartsblight_forest": "hartsblight_forest", "maidenmist_cemetery": "maidenmist_gate", "crooked_nightmare": "nm_estate",
                "wickers_vigil": "wv_square", "the_wytchwood": "ct_wytchwood", "crooked_tree": "ct_wytchwood", "moonfall": "mf_round"}


def cut(src: Path, height: int) -> Image.Image:
    im = Image.open(src).convert("RGB")
    im = im.resize((round(im.width * height / im.height), height), Image.LANCZOS)
    w, h = im.size
    px = im.load()
    out = Image.new("RGBA", (w, h))
    po = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            # How far from the white ground: near-white is clear, a little off it is mist, the rest is solid.
            d = math.sqrt(((255 - r) ** 2 + (255 - g) ** 2 + (255 - b) ** 2) / 3.0) / 255.0
            t = min(1.0, max(0.0, (d - 0.035) / 0.2))
            a = t * t * (3 - 2 * t)
            if 0.0 < a < 1.0:   # take the white out of the colour that's left, so thin mist doesn't go pale at its edges
                r = max(0, min(255, int(255 - (255 - r) / a)))
                g = max(0, min(255, int(255 - (255 - g) / a)))
                b = max(0, min(255, int(255 - (255 - b) / a)))
            po[x, y] = (r, g, b, int(a * 255))
    return out


def generate(landmarks: dict) -> None:
    import generate_local as g
    jobs = {}
    ASSETS.mkdir(parents=True, exist_ok=True)
    for k, r in landmarks.items():
        if (ASSETS / f"{k}_{r['take']}.png").exists():
            continue
        text = r["prompt"] + " " + (ROOT / "art/prompts/vista_preamble.txt").read_text().strip()
        jobs[k] = (g.submit("vistas", k, text, r["size"], 7500 + len(jobs), use_preamble=False), r["take"])
        print("queued", k, flush=True)
    for k, (jid, take) in jobs.items():
        job = g.wait(jid)
        if job["status"] == "succeeded":
            src = g.fetch(job, "vistas", k)
            src.rename(ASSETS / f"{k}_{take}.png")
            print("painted", k, flush=True)
        else:
            print(job["status"], k, str(job.get("error"))[:120], flush=True)


def places_json(landmarks: dict) -> None:
    travel = json.loads((ROOT / "data/travel/wickermoor_hollow.json").read_text())
    pos = {p["id"]: p["pos"] for p in travel["places"]}
    by_loc = {str(p["location"]).split(":")[0]: p["pos"] for p in travel["places"]}
    region_pos = {r: pos[pl] for r, pl in REGION_PLACE.items() if pl in pos}
    places = {}
    for f in sorted(glob.glob(str(ROOT / "data/locations/*.json"))):
        d = json.loads(Path(f).read_text())
        at = by_loc.get(d["id"]) or region_pos.get(str(d.get("region", "")))
        if at:
            places[d["id"]] = at
    path = ROOT / "art/vistas/vistas.json"
    cfg = json.loads(path.read_text())
    cfg["places"] = {"test_hillside": [0.5, 0.5], **places}
    marks = {}
    for k, r in landmarks.items():
        art = ROOT / f"art/vistas/{k}.png"
        if art.exists() and r["place"] in pos:
            marks[k] = {"at": pos[r["place"]], "within": r["within"], "distance": float(r["distance"]), "height": float(r["height_world"]),
                        "sink": float(r["sink"]), "art": f"art/vistas/{k}.png"}
            if "near" in r:
                marks[k]["near"] = r["near"]   # a place nearer than this is the landmark's own and does not see it
    cfg["landmarks"] = marks
    path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
    print("places", len(cfg["places"]), "landmarks", len(marks))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--generate", action="store_true")
    p.add_argument("--places", action="store_true")
    p.add_argument("--only", nargs="*", default=[])
    a = p.parse_args()
    landmarks = {k: v for k, v in json.loads(RECIPES.read_text())["landmarks"].items() if not a.only or k in a.only}
    if a.generate:
        generate(landmarks)
    out_dir = ROOT / "art/vistas"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, r in landmarks.items():
        src = ASSETS / f"{name}_{r['take']}.png"
        if src.exists():
            img = cut(src, int(r["height"]))
            img.save(out_dir / (name + ".png"))
            print("backdrop", name, img.size)
    if a.places:
        places_json(json.loads(RECIPES.read_text())["landmarks"])


if __name__ == "__main__":
    main()
