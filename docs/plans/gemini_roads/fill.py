#!/usr/bin/env /usr/bin/python3
"""Fills a structure file's [[n]] markers from Gemini's raw replies (`n => text` lines) and prints the result; markers the
structure doesn't hold are printed after it as `n => text` (the road fights' narration, for fight_texts.json).
    /usr/bin/python3 docs/plans/gemini_roads/fill.py act1_structure.dialogue reply_act1a.json reply_act1b.json"""
import json, re, sys

struct = open(sys.argv[1]).read()
lines = {}
for path in sys.argv[2:]:
    m = json.load(open(path))
    for row in str(m.get("result") or "").splitlines():
        got = re.match(r"^\s*(\d+)\s*=>\s*(.*)$", row)
        if got:
            lines[int(got.group(1))] = got.group(2).strip()
used = set()


def put(m):
    n = int(m.group(1)); used.add(n)
    return lines.get(n, f"[[MISSING {n}]]")


print(re.sub(r"\[\[(\d+)\]\]", put, struct), end="")
for n in sorted(set(lines) - used):
    print(f"{n} => {lines[n]}", file=sys.stderr)
