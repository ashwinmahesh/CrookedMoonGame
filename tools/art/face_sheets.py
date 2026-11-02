#!/usr/bin/env /opt/homebrew/bin/python3
"""Generic head turnaround sheets for the people the game has no head model for (the reuse figures: crowds, children, background adults).

tools/art/specs/face_sheets.json names, for each sheet, one of the characters' own head sheets under <asset root>/turnarounds/tpose/
(the same pictures tools/art/face_heads.py paints heads from) and the person to draw instead; the image service's Qwen edit redraws
that sheet for the new person, so the layout (the white ground, three views, the head's size) and the look P art style carry over,
and the sheet comes out in the form face_heads.py reads. Jobs go to the standalone queue (port 55302) one picture each; no credits.

  face_sheets.py [id ...] [--wait]     queues them (all, or the named); --wait polls and copies each to <asset root>/faces/<id>.png
"""
from __future__ import annotations
import json, os, shutil, sys, time, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = os.environ.get("CM_IMAGE_QUEUE", "http://localhost:55302")
ASSETS = Path(os.environ.get("CM_ASSET_ROOT", "/Volumes/ASH-SSD/CrookedMoon/assets"))
SPEC = ROOT / "tools/art/specs/face_sheets.json"


def _call(method: str, path: str, body: dict | None = None, headers: dict | None = None) -> dict:
    req = urllib.request.Request(QUEUE + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json", **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def submit(spec: dict, item_id: str) -> str:
    item = spec["items"][item_id]
    ref = ASSETS / "turnarounds/tpose" / f"{item['from']}-head-sheet.png"
    request = {"task": "edit", "prompt": spec["prompt"].format(desc=item["desc"]), "reference_image": str(ref), "size": spec["size"],
               "seed": spec["seed"], "preserve": spec["preserve"], "output_dir": str(ASSETS / spec["kind"]), "generate_immediately": True,
               "tags": ["crooked-moon", "look-faces", item_id]}
    job = _call("POST", "/v1/jobs", {"model": "qwen-image-2.1-turbo", "request": request}, {"Idempotency-Key": f"cm-face2-{item_id}-{spec['seed']}"})
    return job["id"]


def main(argv: list[str]) -> None:
    wait = "--wait" in argv
    spec = json.loads(SPEC.read_text())
    names = [a for a in argv if not a.startswith("--")] or list(spec["items"])
    jobs = {n: submit(spec, n) for n in names}
    for n, j in jobs.items():
        print("queued", n, j, flush=True)
    done: set[str] = set()
    while wait and len(done) < len(jobs):
        for n, j in jobs.items():
            if n in done:
                continue
            try:
                rec = _call("GET", f"/v1/jobs/{j}")
            except urllib.error.URLError:
                continue
            if rec["status"] in ("succeeded", "failed", "cancelled"):
                done.add(n)
                if rec["status"] == "succeeded":
                    dst = ASSETS / spec["kind"] / f"{n}.png"
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy(rec["result"]["file_path"], dst)
                    print("OK", dst, flush=True)
                else:
                    print(rec["status"].upper(), n, rec.get("error"), flush=True)
        time.sleep(15)


if __name__ == "__main__":
    main(sys.argv[1:])
