#!/usr/bin/env /opt/homebrew/bin/python3
"""Swaps finished R10 cutscene pictures from the image queue into art/cutscenes (replacing the placeholders), as 1792 x 1024 jpgs.
The jobs were submitted with the tag r10-cutscene and the picture's id (tools/content/ghostlight_cutscenes.json holds the prompts);
originals are kept under the asset root (cm.assetRoot or ~/Documents/ASH-SSD/CrookedMoon/assets/cutscenes/r10).
    /opt/homebrew/bin/python3 tools/content/fetch_cutscenes.py [--queue http://localhost:55302]"""
import json, subprocess, sys, urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
QUEUE = sys.argv[sys.argv.index("--queue") + 1] if "--queue" in sys.argv else "http://localhost:55302"
SRC = Path.home() / "Documents/ASH-SSD/CrookedMoon/assets/cutscenes/r10"
pics = json.loads((ROOT / "tools/content/ghostlight_cutscenes.json").read_text())["pictures"]
SRC.mkdir(parents=True, exist_ok=True)
jobs, off = [], 0
while True:
    page = json.load(urllib.request.urlopen(f"{QUEUE}/v1/jobs?limit=100&offset={off}")).get("data", [])
    jobs += page
    if len(page) < 100 or off > 1500:
        break
    off += 100
done = {}
for j in jobs:
    tags = j.get("request", {}).get("tags", [])
    if "r10-cutscene" in tags and j.get("status") == "succeeded":
        done[[t for t in tags if t not in ("crooked-moon", "r10-cutscene")][0]] = j["result"]["file_path"]
n = 0
for cid in pics:
    if cid in done:
        subprocess.run(["/usr/bin/python3", "-c", f"from PIL import Image;Image.open({done[cid]!r}).convert('RGB').save({str(ROOT / 'art/cutscenes' / (cid + '.jpg'))!r}, quality=88)"], check=True)
        subprocess.run(["cp", done[cid], str(SRC / (cid + ".png"))])
        n += 1
print(f"{n} of {len(pics)} pictures swapped in")
