#!/usr/bin/env python3
"""Every spell, item and ability of ours has an icon tile (make validate runs this; make icons builds the tiles).

A tile is art/icons/<spells|items|features>/<key>.png, ours or the core's (addons/dnd_core/art/icons). The keys follow
the core's ui/common/icons.gd:
- a spell or item: its data's "icon", else its own id (an item's template's or base item's icon before that);
- the book's hotbar actions (combat/**/*.gd parts, "feat:gm:<prefix><id>[:<choice>]"): <prefix><id>;
- a hit rider of ours (rider_options, "rider:<id>"): its id;
- a data-defined activation (FeatureRecipes, "activation" in a species, subclass or gift): the feature's id.
Without a tile the game shows nothing for a spell or item, and the plain rune for an ability. To give one a tile, add
its key to art/icons.json (a game-icons.net silhouette @ a tint) and run make icons.

python3 tools/art/audit_icons.py            lists what is missing; exits 1 if anything is
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORE = os.path.join(ROOT, "addons", "dnd_core")


def entries(root, kind):
    out = {}
    for f in sorted(glob.glob(os.path.join(root, "data", kind, "*.json"))):
        with open(f) as fh:
            d = json.load(fh)
        if isinstance(d, dict) and "id" in d:
            out[d["id"]] = d
    return out


def has_tile(kind, key):
    return any(os.path.exists(os.path.join(r, "art", "icons", kind, key + ".png")) for r in (ROOT, CORE))


def item_key(items, iid):
    d = items.get(iid, {})
    if "icon" in d:
        return str(d["icon"])
    template = items.get(str(d.get("template_id", "")), {})
    if "icon" in template:
        return str(template["icon"])
    base = str(d.get("base_item", ""))
    if base:
        return str(items.get(base, {}).get("icon", base))
    return iid


def activations(node, out):
    if isinstance(node, dict):
        if "activation" in node and "id" in node:
            out.add(str(node["id"]))
        for v in node.values():
            activations(v, out)
    elif isinstance(node, list):
        for v in node:
            activations(v, out)


def action_keys():
    """{key: file} for the hotbar actions and hit riders our combat parts offer."""
    keys = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "combat", "**", "*.gd"), recursive=True)):
        with open(f) as fh:
            src = fh.read()
        rel = os.path.relpath(f, ROOT)
        m = re.search(r'const PREFIX\s*:?=\s*"([a-z_]*)"', src)
        prefix = m.group(1) if m else ""
        consts = dict(re.findall(r'const ([A-Z_]+)\s*:?=\s*"([a-z_]+)"', src))
        if prefix:
            for aid in re.findall(r'\b_act\("([a-z_]+)', src):
                keys[prefix + aid] = rel
            for aid in re.findall(r'"id":\s*PREFIX \+ "([a-z_]+)"', src):
                keys[prefix + aid] = rel
        # Riders: rider_options' rows ("id": "<key>" or a constant), and the species' row table.
        for body in re.findall(r'func rider_options\(.*?\n(.*?)(?=\nfunc |\Z)', src, re.S):
            for lit in re.findall(r'"id":\s*"([a-z_]+)"', body):
                keys[lit] = rel
            for const in re.findall(r'"id":\s*([A-Z_]+)\s*[,}]', body):
                if const in consts:
                    keys[consts[const]] = rel
            for const, k in re.findall(r'"id":\s*([A-Z_]+)\["([a-z_]+)"\]', body):
                table = re.search(const + r'\s*:?=\s*\{(.*?)\}', src, re.S)
                if table:
                    hit = re.search('"%s":\\s*"([a-z_]+)"' % k, table.group(1))
                    if hit:
                        keys[hit.group(1)] = rel
            if prefix and "PREFIX + id" in body:
                for rid in re.findall(r'\["([a-z_]+)", "', body):
                    keys[prefix + rid] = rel
    return keys


def main():
    missing = []
    for sid, d in entries(ROOT, "spells").items():
        key = str(d.get("icon", sid))
        if not has_tile("spells", key):
            missing.append("spell %s (tile %s)" % (sid, key))
    items = {}
    for root in (CORE, ROOT):
        items.update(entries(root, "items"))
        items.update(entries(root, "magic_items"))
    ours = {}
    ours.update(entries(ROOT, "items"))
    ours.update(entries(ROOT, "magic_items"))
    for iid in ours:
        key = item_key(items, iid)
        if not has_tile("items", key):
            missing.append("item %s (tile %s)" % (iid, key))
    feats = set()
    for kind in ("species", "subclasses", "dark_gifts", "feats", "backgrounds", "items", "magic_items"):
        for d in entries(ROOT, kind).values():
            activations(d, feats)
    for fid in sorted(feats):
        if not has_tile("features", fid):
            missing.append("activation %s (tile %s)" % (fid, fid))
    for key, where in sorted(action_keys().items()):
        if not has_tile("features", key):
            missing.append("ability %s in %s (tile %s)" % (key, where, key))
    for m in missing:
        print("icons: no tile for " + m)
    if missing:
        print("icons: %d without a tile; add them to art/icons.json and run make icons" % len(missing))
        return 1
    print("icons: every spell, item and ability of ours has a tile")
    return 0


if __name__ == "__main__":
    sys.exit(main())
