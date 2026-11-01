#!/usr/bin/env python3
"""R23: registers every flag Wicker's Vigil's dialogue, places and stat blocks set or read in data/flags/vigil.json (types from how they are used).
    python3 tools/content/vigil_flags.py"""
import glob, json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
existing = set()
for f in glob.glob(str(ROOT / "data/flags/*.json")):
    if f.endswith("vigil.json"):
        continue
    for fl in json.load(open(f))["flags"]:
        existing.add(fl["id"])
sets, reads, ints, strs, engine = set(), set(), set(), set(), set()
for f in list((ROOT / "narrative/vigil").glob("*.dialogue")) + [ROOT / "narrative/narrator/wickers_vigil.dialogue"]:
    for ln in f.read_text().splitlines():
        s = ln.strip()
        m = re.match(r"set (\w+)\s*(\+=|-=|=)?\s*(.*)$", s)
        if m:
            sets.add(m.group(1))
            if m.group(2) in ("+=", "-="):
                ints.add(m.group(1))
            elif m.group(2) == "=":
                v = m.group(3).strip()
                if v.startswith('"'):
                    strs.add(m.group(1))
                elif v not in ("false", "true"):
                    ints.add(m.group(1))
        for fm in re.finditer(r"flag\.(\w+)\s*(>=|<=|>|<|==|!=)?\s*(\S+)?", s):
            reads.add(fm.group(1))
            v = fm.group(3) or ""
            if fm.group(2) in (">=", "<=", ">", "<") or (fm.group(2) in ("==", "!=") and v[:1].isdigit()):
                ints.add(fm.group(1))
            if fm.group(2) in ("==", "!=") and v.startswith('"'):
                strs.add(fm.group(1))
for f in list(glob.glob(str(ROOT / "data/locations/wv_*.json"))):
    t = Path(f).read_text()
    for fm in re.finditer(r"flag\.(\w+)\s*(>=|<=|>|<|==|!=)?\s*(\S+)?", t):
        reads.add(fm.group(1))
        v = (fm.group(3) or "").strip('",')
        if fm.group(2) in (">=", "<=", ">", "<"):
            ints.add(fm.group(1))
    for fm in re.finditer(r'"(?:flag|until_flag)": "(\w+)"', t):
        sets.add(fm.group(1))
    for fm in re.finditer(r'"count": "(\w+)"', t):
        sets.add(fm.group(1)); ints.add(fm.group(1))
    for fm in re.finditer(r'"catch": \{\s*"flag": "(\w+)"', t):
        engine.add(fm.group(1))
for f in ("data/monsters/wicker_man_vigil.json",):
    for fm in re.finditer(r'"flag": "(\w+)"', (ROOT / f).read_text()):
        sets.add(fm.group(1))
for f in ["data/locations/wickermoor_village.json", "data/locations/nm_estate_ruins.json", "data/travel/wickermoor_hollow.json"]:
    for fm in re.finditer(r"flag\.(\w+)", (ROOT / f).read_text()):
        if fm.group(1).startswith(("wv_", "wicker_man", "vigil")):
            reads.add(fm.group(1))
# flags other chapters own that these files read (R22 sets them)
mine = sorted((sets | reads | engine) - existing)
out = []
for i in mine:
    t = "int" if i in ints else "string" if i in strs else "bool"
    d = {"id": i, "type": t, "summary": "Wicker's Vigil (R23): " + i.replace("_", " "), "read_later": True}
    if i in engine:
        d = {"id": i, "type": t, "summary": "Wicker's Vigil (R23): " + i.replace("_", " ") + " (set when the hero catches the villager in the fight)", "set_by": "engine"}
    out.append(d)
(ROOT / "data/flags/vigil.json").write_text(json.dumps({"flags": out}, indent=2) + "\n")
print(len(out), "flags; read but not set here:", sorted((reads - sets) - existing)[:30])
