#!/usr/bin/env python3
"""Every merchant's wares (Ashwin, 2026-11-02: every item that isn't the story's is for sale somewhere, mundane gear, magic items
and spell scrolls). Reads data/treasure/shop_stock.json and the item, magic item and spell data (the engine's and the game's,
tools/data/dataroots.py) and writes `shop.sells` and `shop.magic` into each merchant's file in data/npcs, leaving every other key
alone. Run from anywhere; safe to run again (tools/content/build_wickermoor.py calls it after it rewrites the village's people).

    python3 tools/content/build_shop_stock.py          write the shops
    python3 tools/content/build_shop_stock.py --check  only say whether the files are current (exit 1 if not)

tests/unit/test_shop_stock.gd holds the game to the same rule from inside Godot."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "data"))
import dataroots  # noqa: E402

STOCK = ROOT / "data" / "treasure" / "shop_stock.json"
ARCANE = {"bard", "sorcerer", "warlock", "wizard"}
DIVINE = {"cleric", "druid", "paladin", "ranger"}
SEP = "__"


def entries(folder):
    out = {}
    for f in dataroots.data_files(folder):
        d = json.loads(f.read_text())
        out[str(d.get("id", f.stem))] = d
    return out


def is_magic(d):
    return bool(d.get("magic"))


def for_sale(d, banned):
    """The same test as tests/unit/test_shop_stock.gd: what a counter somewhere must carry."""
    if str(d["id"]) in banned or not d.get("playable", True) or d.get("category") == "quest" or d.get("quest_locked"):
        return False
    if is_magic(d):
        if (d.get("magic") or {}).get("rarity") == "artifact" or (d.get("treasure") or {}).get("random") is False:
            return False
        if (d.get("template") or {}).get("on") == "spell":
            return False   # the Spell Scroll template: a scroll of each spell stands in for it
    return True


def scroll_ids(kind):
    out = []
    for sid, sp in sorted(entries("spells").items()):
        classes = set(sp.get("classes") or [])
        if not sp.get("playable", True) or not classes:
            continue
        if classes & (ARCANE if kind == "arcane" else DIVINE):
            out.append("spell_scroll" + SEP + sid)
    return out


def takes(rule, d):
    iid = str(d["id"])
    if str(d.get("category", "")) in rule.get("categories", []):
        return True
    if str(d.get("worn", "")) in rule.get("worn", []):
        return True
    return any(w in iid for w in rule.get("id_words", []))


def build():
    cfg = json.loads(STOCK.read_text())
    banned = set(cfg["not_for_sale"]["items"])
    merchants = {k: v for k, v in cfg["merchants"].items() if not k.startswith("_") and k != "fallback"}
    fallback = cfg["merchants"]["fallback"]
    items = {**entries("items"), **entries("magic_items")}
    magic = {m: [] for m in merchants}
    for iid in sorted(items):
        d = items[iid]
        if not is_magic(d) or not for_sale(d, banned):
            continue
        taken = False
        for m, spec in merchants.items():
            rule = spec.get("magic")
            if rule is None or not takes(rule, d):
                continue
            magic[m].append(iid)
            if not rule.get("also", False):
                taken = True
                break
        if not taken:
            magic[fallback].append(iid)
    for m, spec in merchants.items():
        kind = (spec.get("magic") or {}).get("scrolls")
        if kind:
            magic[m].extend(scroll_ids(kind))
    # Every mundane item that's for sale is on some counter.
    sold = {e["id"] if isinstance(e, dict) else e for spec in merchants.values() for e in spec.get("sells", [])}
    missing = [i for i in sorted(items) if not is_magic(items[i]) and for_sale(items[i], banned) and i not in sold]
    unknown = sorted(i for i in sold if i not in items)
    if missing or unknown:
        raise SystemExit("shop_stock.json: not on any counter: %s; no such item: %s" % (missing, unknown))
    return merchants, magic


def merged(path, spec, magic_ids):
    d = json.loads(path.read_text())
    shop = dict(d.get("shop") or {"markup": 1.0, "sell_rate": 0.5})
    had = {str(w["id"]): w for w in shop.get("sells", [])}
    rows = []
    for e in spec.get("sells", []):   # an id, or {id, price, qty, ...} to set a line's own terms
        line = dict(e) if isinstance(e, dict) else {"id": e}
        rows.append({**had.get(line["id"], {}), **line})
    out = {"sells": rows}
    for k, v in shop.items():
        if k not in ("sells", "magic"):
            out[k] = v
    out.setdefault("markup", 1.0)
    out.setdefault("sell_rate", 0.5)
    if magic_ids:
        out["magic"] = magic_ids
    for k, v in (spec.get("shop") or {}).items():
        out[k] = v
    d["shop"] = out
    return json.dumps(d, indent=2, ensure_ascii=False) + "\n"


def main():
    check = "--check" in sys.argv
    merchants, magic = build()
    stale = []
    for m, spec in merchants.items():
        path = ROOT / "data" / "npcs" / f"{m}.json"
        text = merged(path, spec, magic[m])
        if path.read_text() != text:
            stale.append(m)
            if not check:
                path.write_text(text)
    for m in merchants:
        print("%-18s %3d wares, %4d magic" % (m, len(merchants[m].get("sells", [])), len(magic[m])))
    if check and stale:
        print("stale: " + ", ".join(stale))
        sys.exit(1)


if __name__ == "__main__":
    main()
