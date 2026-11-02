#!/usr/bin/env /usr/bin/python3
"""The look-P art specs (tools/art/specs/*.json, vista_recipes.json) turned into photoreal ones (Ashwin, 2026-11-02): each prompt keeps
its subject and composition, loses the cel style words (the style preamble, `Style: ...` sentences, "bold black ink outlines, flat
cel-painted ...", "gouache", "cartoon"), and tools/art/photoreal.py adds the photoreal preamble (no LoRA). Writes
tools/art/specs/photoreal/<name>.json with the kind `<kind>_photo`, so the originals under the asset root stay beside the new ones.

  /usr/bin/python3 tools/art/photoreal_specs.py          writes them all and prints the prompts for a read-through
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPECS = ROOT / "tools/art/specs"
OUT = SPECS / "photoreal"

CEL = [
    r"\bStyle: vintage Saturday-morning monster cartoon[^.]*(?:\.[^.]*)?\.?",       # the style words, once or twice
    r"[Bb]old (?:clean )?black ink outlines,? ",
    r"flat cel-painted[^,.]*[,.]? ?",
    r"(?:vintage )?(?:Saturday-morning )?monster cartoon (?:still|style|background painting)[^,.]*[,.]? ?",
    r"hand-painted ", r"heavy gouache[^,.]*[,.]? ?", r"gouache[^,.]*[,.]? ?", r"painted gouache ", r"deep inky shadows[^,.]*[,.]? ?",
    r"with a real horror edge,? ?",
]


def photoreal(prompt: str) -> str:
    p = prompt
    pre = (ROOT / "art/prompts/style_preamble.txt").read_text().strip()
    vpre = ROOT / "art/prompts/vista_preamble.txt"
    for t in (pre, vpre.read_text().strip() if vpre.exists() else ""):
        if t:
            p = p.replace(t, "")
    for rx in CEL:
        p = re.sub(rx, "", p)
    p = re.sub(r"\s+", " ", p).strip()
    p = re.sub(r"\s+([,.])", r"\1", p)
    return p


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for f in ["loading_cards", "moon", "moon_stages", "oak_faces", "train_window", "set_pieces", "map", "title"]:
        spec = json.loads((SPECS / f"{f}.json").read_text())
        spec["kind"] = spec["kind"] + "_photo"
        for k, it in spec["items"].items():
            it["prompt"] = photoreal(it["prompt"])
            it.pop("preamble", None)
            it.pop("lora", None)
        (OUT / f"{f}.json").write_text(json.dumps(spec, indent=1) + "\n")
    vr = json.loads((SPECS.parent / "vista_recipes.json").read_text())
    items = {}
    for k, v in vr["landmarks"].items():
        items[k] = {"prompt": photoreal(v["prompt"]), "size": v.get("size", "1024x1536"), "seed": v.get("seed", 7500)}
    (OUT / "vistas.json").write_text(json.dumps({"kind": "vistas_photo", "items": items}, indent=1) + "\n")
    for f in sorted(OUT.glob("*.json")):
        d = json.loads(f.read_text())
        print("==", f.name, d["kind"], len(d["items"]))
        for k, it in list(d["items"].items())[:3]:
            print("  ", k, "|", it["prompt"][:260])


if __name__ == "__main__":
    main()
