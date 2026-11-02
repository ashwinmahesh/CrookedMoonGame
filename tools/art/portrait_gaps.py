#!/usr/bin/env python3
"""Which speaking NPCs have no face in dialogue, and a photoreal spec to paint them.

Usage: python3 tools/art/portrait_gaps.py [--check] [--spec out.json] [--seeds n]

The dialogue box shows art/portraits/<portrait id>.png (DialogueUI._show_portrait) and the bust beside it
art/busts/<portrait id>.webp (DialogueBusts, made from that png by tools/art/build_portrait_busts.py). A portrait that
lives only in art/portraits/characters/ (the turn order and Bestiary, PortraitArt) is NOT read by the dialogue box: copy
it to art/portraits/<id>.png and build its bust. This walks every speaker in narrative/**/*.dialogue, resolves it the way
DialogueRunner does (id, else the NPC whose name fits, lowest id first), and lists those whose portrait id has no png.

--check exits 1 when a speaker has a characters/ portrait but no dialogue png (a lookup gap that needs no new art).
--spec writes a photoreal.py spec (kind "portraits", normal priority) for every speaker with no picture at all, Act 1
places first; ids that tools/art/specs/portraits_act1_photoreal.json already covers by hand are left out. Prompts are
built from each NPC's name, title and summary (our own words) and the region's setting; pick, copy the picture to
art/portraits/<id>.png, then build_portrait_busts.py --only <id>.
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "addons" / "dnd_core"
HAND_SPECS = [ROOT / "tools/art/specs/portraits_act1_photoreal.json"]
LINE = re.compile(r"^([a-z][a-z0-9_]*)\s*(\[[a-z_]+\])?:\s", re.I)
ACT_ORDER = ["ghostlight_express", "wickermoor", "crooked_house", "foxwillow", "crooked_nightmare", "crimson_monastery",
             "dawns_gate", "drowned_crossroads", "skitterdeep_mine", "memorys_rest", "hartsblight_forest", "maidenmist_cemetery"]
SETTING = {
    "ghostlight_express": "inside a dim 1920s passenger railcar at night, brass sconces and worn velvet blurred behind",
    "wickermoor": "on a crooked autumn village lane at night, leaning half-timbered cottages, carved pumpkins and lanterns blurred behind",
    "crooked_house": "inside a crooked, decaying Victorian house at night, peeling wallpaper and a guttering candle blurred behind",
    "foxwillow": "in a moonlit autumn farm town at night, a windmill and corn rows blurred behind",
    "crooked_nightmare": "in a dreamlike, warped nightmare landscape under a huge crooked moon, mist curling behind",
    "crimson_monastery": "in a cold stone monastery at night, red banners and candlelit arches blurred behind",
    "dawns_gate": "at a snowbound fortress gate at night, torches and falling snow blurred behind",
    "drowned_crossroads": "on a flooded bayou crossroads at night, cypress trees, a riverboat's lights and swamp mist behind",
    "skitterdeep_mine": "deep in a lantern-lit mine at night, timber props and wet rock blurred behind",
    "memorys_rest": "in a faded old asylum by dark water at night, peeling plaster and a hanging lamp blurred behind",
    "hartsblight_forest": "in a rotting blighted forest at night, twisted trees and fungal glow blurred behind",
    "maidenmist_cemetery": "in a misty old cemetery at night, leaning headstones and a bell tower blurred behind",
}


def npcs() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for root in (ENGINE / "data/npcs", ROOT / "data/npcs"):   # the game's entry replaces the engine's of the same id
        for f in sorted(glob.glob(str(root / "**/*.json"), recursive=True)):
            try:
                d = json.loads(Path(f).read_text())
            except (OSError, ValueError):
                continue
            if isinstance(d, dict) and "id" in d:
                out[str(d["id"])] = d
    return out


def has_art(rel: str) -> bool:
    return (ROOT / rel).exists() or (ENGINE / rel).exists()


def speakers(table: dict[str, dict]) -> dict[str, set[str]]:
    """NPC id -> the dialogue files it speaks in."""
    by_name: dict[str, str] = {}
    for nid in sorted(table):
        by_name.setdefault(str(table[nid].get("name", "")).lower(), nid)
    out: dict[str, set[str]] = {}
    for f in sorted(glob.glob(str(ROOT / "narrative/**/*.dialogue"), recursive=True)):
        for line in Path(f).read_text().splitlines():
            m = LINE.match(line)
            if not m or m.group(1).lower() in ("narrator", "player"):
                continue
            low = m.group(1).lower()
            nid = low if low in table else by_name.get(low.replace("_", " "), "")
            if nid:
                out.setdefault(nid, set()).add(str(Path(f).relative_to(ROOT)))
    return out


def portrait_ids(npc: dict) -> list[str]:
    ids = [str(npc.get("portrait", npc["id"]))]
    ids += [str(look["portrait"]) for look in npc.get("looks", []) if "portrait" in look]
    return ids


def prompt(npc: dict) -> str:
    who = str(npc.get("name", npc["id"]))
    title = str(npc.get("title", "")).strip()
    summary = str(npc.get("summary", "")).strip()
    setting = SETTING.get(str(npc.get("region", "")), "at night, a dark old-world backdrop blurred behind")
    return (f"Head-and-shoulders portrait of {who}{', ' + title[0].lower() + title[1:] if title else ''}, facing the viewer. "
            f"{summary} Every detail of the figure true to that description, a face full of character. Photographed {setting}, a warm lantern glow on the face and cold moonlight at the edges.")


def seed_for(pid: str, n: int) -> int:
    return 50000 + int(hashlib.md5(pid.encode()).hexdigest()[:6], 16) % 40000 + n


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--spec", default="")
    ap.add_argument("--seeds", type=int, default=1)
    args = ap.parse_args(argv)
    table = npcs()
    spoken = speakers(table)
    hand: set[str] = set()
    for spec in HAND_SPECS:
        if spec.exists():
            hand |= {k.rsplit("_", 1)[0] for k in json.loads(spec.read_text())["items"]}
    gaps, lookup = [], []
    for nid, files in spoken.items():
        npc = table[nid]
        for pid in portrait_ids(npc):
            if has_art(f"art/portraits/{pid}.png"):
                continue
            if has_art(f"art/portraits/characters/{pid}.webp") or has_art(f"art/portraits/characters/{pid}.png"):
                lookup.append(pid)
            else:
                gaps.append((pid, npc, sorted(files)))
    order = {r: i for i, r in enumerate(ACT_ORDER)}
    gaps.sort(key=lambda g: (order.get(str(g[1].get("region", "")), 99), g[0]))
    for pid in sorted(lookup):
        print(f"LOOKUP {pid}: art/portraits/characters/ only; copy it to art/portraits/{pid}.png and build its bust")
    for pid, npc, files in gaps:
        print(f"MISSING {pid} ({npc.get('region', '?')}): {npc.get('name', '')}, in {', '.join(files)}")
    print(f"{len(spoken)} speaking NPCs, {len(gaps)} portraits missing, {len(lookup)} lookup gaps", file=sys.stderr)
    if args.spec:
        items = {}
        for pid, npc, _ in gaps:
            if pid in hand:
                continue
            for n in range(args.seeds):
                key = pid if args.seeds == 1 else f"{pid}_{'abcdefgh'[n]}"
                items[key] = {"size": "896x1152", "seed": seed_for(pid, n), "prompt": prompt(npc)}
        spec = {"_doc": "Dialogue portraits for every speaking NPC with none (tools/art/portrait_gaps.py --spec). Queued at "
                        "normal priority: photoreal.py <this file>. Pick, copy to art/portraits/<id>.png, then "
                        "tools/art/build_portrait_busts.py --only <id>.",
                "kind": "portraits", "immediate": False, "items": items}
        Path(args.spec).write_text(json.dumps(spec, indent=1) + "\n")
        print(f"wrote {len(items)} jobs to {args.spec}", file=sys.stderr)
    return 1 if args.check and lookup else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
