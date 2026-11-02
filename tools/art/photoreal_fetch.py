#!/usr/bin/env /usr/bin/python3
"""Names the finished photoreal pictures: the image service saves each as <job id>.png (with its settings in the .json beside it) in
<asset root>/<kind>/ (tools/art/photoreal.py queues without waiting); this copies each one to <kind>/<item id>.png by matching the
spec item's seed, size and the start of its prompt (several items can share a seed), so the fitters (oak_faces.py, loading_cards.py, look_finish.py, build_vistas.py) find them by name.

  /usr/bin/python3 tools/art/photoreal_fetch.py tools/art/specs/photoreal/oak_faces.json [more specs]
"""
import glob, json, shutil, sys
from pathlib import Path

ASSETS = Path("/Volumes/ASH-SSD/CrookedMoon/assets")

for spec_path in sys.argv[1:]:
    spec = json.loads(Path(spec_path).read_text())
    kind = spec["kind"]
    seen = {}
    for f in glob.glob(str(ASSETS / kind / "*.json")):
        j = json.loads(Path(f).read_text())
        if j.get("lora"):
            continue
        seen.setdefault((int(j.get("seed", -1)), str(j.get("size")), str(j.get("prompt", ""))[:160]), []).append(Path(f).with_suffix(".png"))
    for item_id, it in spec["items"].items():
        hits = seen.get((int(it["seed"]), str(it.get("size", "1408x768")), it["prompt"][:160]), [])
        hits = [h for h in hits if h.exists() and not h.stem.startswith(("face_", "load_"))]
        if not hits:
            print("not yet", kind, item_id)
            continue
        newest = max(hits, key=lambda p: p.stat().st_mtime)
        shutil.copy(newest, ASSETS / kind / f"{item_id}.png")
        print("ok", kind, item_id, newest.name)
