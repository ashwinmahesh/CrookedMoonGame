#!/usr/bin/env /opt/homebrew/bin/python3
"""Look P pictures from the local ImageGen-Service (CLAUDE.md, plan 8.1 and 9): Z-Image Turbo with the custom-giallo LoRA at 0.6
and the style preamble (art/prompts/style_preamble.txt) after every prompt. Jobs go to the standalone queue (port 55302, which
takes work even while the other generator has the GPU) with `generate_immediately` only when a job asks for it (`immediate=True`: such a job runs even while the queue is paused, which Ashwin does
to free his GPU, so by default a job waits its turn at normal priority). Originals are kept under the asset root (cm.assetRoot or /Volumes/ASH-SSD/CrookedMoon/assets) in
<kind>/, and every finished picture is appended to art/generation_log.jsonl.

As a tool:   generate_local.py <spec.json> [--wait]
  spec.json: {"kind": "title", "items": {"<id>": {"prompt": "...", "size": "1408x768", "seed": 7001, "preamble": true,
              "reference": "/abs/path.png", "strength": 0.55}}}
  Submits one job per item (Idempotency-Key cm-look-<kind>-<id>-<seed>); --wait polls until each is done and copies the
  originals to <asset root>/<kind>/<id>.png.
As a module: submit(...) / wait(...) / fetch(...) for scripts that crop or compose the result.

The GPU lock (~/.crooked-moon/gpu.lock) is for switching generators: this tool never switches one, it only queues.
"""
from __future__ import annotations
import json, os, shutil, sys, time, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = os.environ.get("CM_IMAGE_QUEUE", "http://localhost:55302")
MODEL = "z-image-turbo"
LORA = "custom-giallo"
LORA_STRENGTH = 0.6
ASSETS = Path(os.environ.get("CM_ASSET_ROOT", "/Volumes/ASH-SSD/CrookedMoon/assets"))


def preamble() -> str:
    return (ROOT / "art/prompts/style_preamble.txt").read_text().strip()


def _call(method: str, path: str, body: dict | None = None, headers: dict | None = None) -> dict:
    req = urllib.request.Request(QUEUE + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json", **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def submit(kind: str, item_id: str, prompt: str, size: str, seed: int, use_preamble: bool = True, lora: bool = True,
           extra_tags: list[str] | None = None, reference: str | None = None, strength: float = 0.55, immediate: bool = False) -> str:
    """Queues one picture; returns the job id. `size` is WxH, each a multiple of 64 from 256 to 2048. A `reference` (a path on
    this Mac) makes it a variation of that picture, `strength` how much of it is kept (0 to 1, higher keeps more). `immediate`
    False queues it at normal priority behind other work (for a batch queued while the server is paused)."""
    text = prompt.strip() + (" " + preamble() if use_preamble else "")
    request = {"prompt": text, "size": size, "seed": seed, "generate_immediately": immediate,
               "tags": ["crooked-moon", f"look-{kind}", item_id] + (extra_tags or []),
               "output_dir": str(ASSETS / kind)}
    if lora:
        request.update({"lora": LORA, "lora_strength": LORA_STRENGTH})
    if reference:
        request.update({"reference_image": reference, "image_strength": strength})
    job = _call("POST", "/v1/jobs", {"model": MODEL, "request": request}, {"Idempotency-Key": f"cm-look-{kind}-{item_id}-{seed}"})
    return job["id"]


def wait(job_id: str, poll: float = 15.0, limit: float = 3 * 3600) -> dict:
    """Polls until the job has finished; returns its record (status succeeded, failed or cancelled)."""
    start = time.time()
    while time.time() - start < limit:
        try:
            job = _call("GET", f"/v1/jobs/{job_id}")
        except urllib.error.URLError:
            time.sleep(poll)
            continue
        if job["status"] in ("succeeded", "failed", "cancelled"):
            return job
        time.sleep(poll)
    raise TimeoutError(job_id)


def fetch(job: dict, kind: str, item_id: str) -> Path:
    """Copies a finished job's picture to <asset root>/<kind>/<id>.png and logs it; returns that path."""
    src = Path(job["result"]["file_path"])
    dst = ASSETS / kind / f"{item_id}.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dst)
    req = job.get("request", {})
    with open(ROOT / "art/generation_log.jsonl", "a") as log:
        log.write(json.dumps({"kind": kind, "id": item_id, "job": job["id"], "model": MODEL, "lora": req.get("lora"),
                              "lora_strength": req.get("lora_strength"), "seed": req.get("seed"), "size": req.get("size"),
                              "prompt": req.get("prompt"), "file": str(dst)}) + "\n")
    return dst


def main(argv: list[str]) -> int:
    if not argv or argv[0].startswith("-"):
        print(__doc__)
        return 2
    spec = json.loads(Path(argv[0]).read_text())
    kind = spec["kind"]
    jobs = {}
    for item_id, it in spec["items"].items():
        jobs[item_id] = submit(kind, item_id, it["prompt"], it.get("size", "1024x1024"), int(it.get("seed", 7001)),
                               bool(it.get("preamble", True)), bool(it.get("lora", True)), None,
                               it.get("reference"), float(it.get("strength", 0.55)))
        print(f"queued {kind}/{item_id}: {jobs[item_id]}", flush=True)
    if "--wait" in argv:
        for item_id, jid in jobs.items():
            job = wait(jid)
            if job["status"] == "succeeded":
                print(f"OK {fetch(job, kind, item_id)}", flush=True)
            else:
                print(f"{job['status'].upper()} {item_id}: {str(job.get('error'))[:160]}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
