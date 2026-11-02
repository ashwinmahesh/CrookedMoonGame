#!/usr/bin/env /opt/homebrew/bin/python3
"""Photoreal pictures from the local ImageGen-Service (Ashwin, 2026-11-02: every picture photorealistic): Z-Image Turbo with NO
LoRA (the recipe the portraits use, Build/Portrait UI Wiring) and the style words of art/prompts/photoreal_preamble.txt after
every prompt. Like tools/art/generate_local.py (the cel recipe, kept beside it): jobs go to the standalone queue with
`generate_immediately`, originals are kept under <asset root>/<kind>/<id>.png.

  photoreal.py <spec.json> [--wait]
  spec.json: {"kind": "title", "items": {"<id>": {"prompt": "...", "size": "1408x768", "seed": 8801}}}
"""
from __future__ import annotations
import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_local as gl  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def preamble() -> str:
    return (ROOT / "art/prompts/photoreal_preamble.txt").read_text().strip()


def submit(kind: str, item_id: str, prompt: str, size: str, seed: int, **kw) -> str:
    """Queues one photoreal picture (no LoRA, the photoreal words after the prompt); returns the job id."""
    return gl.submit(kind, item_id, prompt.strip() + " " + preamble(), size, seed, use_preamble=False, lora=False,
                     extra_tags=["photoreal"], **kw)


def main(argv: list[str]) -> None:
    wait = "--wait" in argv
    spec = json.loads(Path([a for a in argv if not a.startswith("--")][0]).read_text())
    jobs = {}
    for item_id, it in spec["items"].items():
        jobs[item_id] = submit(spec["kind"], item_id, it["prompt"], it.get("size", "1408x768"), int(it["seed"]),
                               **{k: it[k] for k in ("reference", "strength") if k in it})
        print("queued", spec["kind"], item_id, jobs[item_id], flush=True)
    if wait:
        for item_id, job in jobs.items():
            rec = gl.wait(job)
            if rec["status"] == "succeeded":
                print("OK", gl.fetch(rec, spec["kind"], item_id), flush=True)
            else:
                print(rec["status"].upper(), item_id, rec.get("error"), flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
