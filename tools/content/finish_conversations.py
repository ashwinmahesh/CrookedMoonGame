#!/usr/bin/env python3
"""Finishes a drafted Wickermoor conversation file (narrative/wickermoor/<npc>.dialogue) the way the editor does: makes sure a `menu` node exists
(the start node's options, so every 'back to the menu' lands somewhere), opens the shop or services where the person has them, and marks the
first meeting with a `<npc>_met` flag. Run: python3 tools/content/finish_conversations.py [npc_id ...]"""
import re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
D = ROOT / "narrative/wickermoor"
SHOP = {"baltus_tolliver", "morgan", "jean_myriel", "oswick_frey", "siv_harga", "holly_aster", "thomasin_ardor", "eleanor_heyling", "hilda_brom", "beatrice_wells"}
SERVICES = {"alda_farnum", "randall_graham", "weston_murdoch"}
SKIP = {"arrival", "mayor_welcome", "children", "rumours", "connections", "connections_custom", "lottery", "oak", "gus", "play", "bad_seed"}


def fix(path):
    npc = path.stem
    text = path.read_text()
    lines = text.split("\n")
    # nodes
    nodes = {}
    order = []
    cur = None
    for i, ln in enumerate(lines):
        m = re.match(r"^~ (\S+)", ln)
        if m:
            cur = m.group(1)
            nodes[cur] = i
            order.append(cur)
    if "start" not in nodes:
        print("no start node:", npc)
        return
    start_end = nodes[order[1]] if len(order) > 1 else len(lines)
    options = [ln for ln in lines[nodes["start"]:start_end] if ln.startswith("* ")]
    changed = False
    if "menu" not in nodes and any("-> menu" in ln for ln in lines):
        block = ["", "~ menu"] + options
        lines = [ln for ln in lines]
        while lines and lines[-1] == "":
            lines.pop()
        lines += block + [""]
        changed = True
    text2 = "\n".join(lines)
    if "shop_open" in nodes or "service_open" in nodes:
        verb = "shop" if npc in SHOP else "services" if npc in SERVICES else None
        if verb and f"\n{verb}\n" not in text2:
            text2 = re.sub(r"(~ (?:shop|service)_open\n(?:[^\n~]*\n)*?)(-> menu)", lambda m: m.group(1) + verb + "\n" + m.group(2), text2, count=1)
            changed = True
        if not verb:
            # no shop here: the option is a plain remark
            changed = True
    if f"set {npc}_met" not in text2:
        text2 = re.sub(r"(~ start\n)", r"\1set %s_met\n" % npc, text2, count=1)
        changed = True
    if changed:
        path.write_text(text2 if text2.endswith("\n") else text2 + "\n")
        print("finished", npc)


if __name__ == "__main__":
    only = set(sys.argv[1:])
    for p in sorted(D.glob("*.dialogue")):
        if p.stem in SKIP or (only and p.stem not in only):
            continue
        fix(p)
