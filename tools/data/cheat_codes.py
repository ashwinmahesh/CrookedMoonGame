#!/usr/bin/env python3
"""Writes every playable item's cheat code, from the item data (`make cheat-codes`): docs/cheat_codes.md in the repo and
Cheat Codes.md in the vault (skipped when there's no vault, as on another machine). Ported from Curse of Strahd's list.

The codes are the engine's story/cheat_codes.gd (the pause menu's Cheat codes page): the first six hex digits of
sha256("cheat:<id>"), upper case. Two ids that share a code are settled in id order over every item file of the engine and
the game, playable or not: the first keeps it, the next hashes "cheat:<id>#1" (then #2...). Only playable items are
listed, since only they answer to a code. An item built on a base (a +1 Weapon, a Spell Scroll) has one code, and the
player picks the base in the game. Every item file gets a code by itself, so a new item needs no code written for it:
run this again so the list shows it (`make validate` fails while docs/cheat_codes.md is behind).

The repo's copy is the same for the same data (no date), so `--check` can tell when it's behind the items.

    python3 tools/data/cheat_codes.py [--check] [--stdout] [--out <path>]
"""
import argparse
import datetime
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dataroots  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = Path.home() / "Documents" / "Obsidian Vault" / "Crooked Moon" / "Cheat Codes.md"
REPO_OUT = ROOT / "docs" / "cheat_codes.md"
FOLDERS = ["items", "magic_items"]
SALT = "cheat:"
LENGTH = 6
# tests/unit/test_cheat_codes.gd pins the same codes, so the game and this list can't drift apart. The first two are
# the codes Curse of Strahd's list had for them too.
PINNED = {"arrow": "359A02", "weapon_plus_1": "3360D9", "scythe_of_the_harvest_terror": "1B04C6"}
RARITIES = ["common", "uncommon", "rare", "very_rare", "legendary", "artifact"]
BASE_WORDS = {"weapon": "a weapon", "armor": "an armor", "shield": "a shield", "ammunition": "ammunition",
              "weapon_or_ammunition": "a weapon or ammunition", "spell": "a spell"}


def hash_code(item_id, n=0):
    key = SALT + item_id if n == 0 else f"{SALT}{item_id}#{n}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:LENGTH].upper()


def assign(ids):
    taken, out = set(), {}
    for item_id in sorted(ids):
        n = 0
        code = hash_code(item_id, n)
        while code in taken:
            n += 1
            code = hash_code(item_id, n)
        taken.add(code)
        out[item_id] = code
    return out


def load(folder):
    """{id: entry} over the engine's files and the game's (the game's file of a name wins, as in the Compendium)."""
    out = {}
    for f in dataroots.data_files(folder):
        d = json.loads(f.read_text())
        out[str(d.get("id", f.stem))] = d
    return out


def playable(d):
    return bool(d.get("playable", True))


def kind(d):
    return str(d.get("category", "item")).replace("_", " ").capitalize()


def pick_note(d):
    t = d.get("template")
    if t is None:
        return ""
    items = t.get("items", [])
    if len(items) == 1:
        return ""
    return f"pick {BASE_WORDS.get(t.get('on', 'weapon'), 'a base')}"


def ours(d):
    return str((d.get("source") or {}).get("book", "")) == "CrookedMoon"


def esc(text):
    return str(text).replace("|", "\\|")


HOW_TO = [
    "## How to use a code",
    "",
    "1. Press **Esc** for the pause menu and choose **Cheat codes** (beside Settings; it shows once you have a party).",
    "2. Pick the hero to get the item (the one you have selected is picked already), type the code and press **Give** or",
    "   Enter. Case, spaces and dashes don't matter.",
    "3. Each press gives the item again. Ammunition comes as a bundle (20 Arrows), and magic items arrive identified.",
    "4. A code marked *pick* is an item built on a base, like a +1 Weapon or a Spell Scroll: choose the weapon, armor or",
    "   spell in the box before you give it.",
    "",
    "Codes the two games share (Arrows, +1 Weapon and every other rules item) are the same as in Curse of Strahd's list.",
    "",
]


def table(group, picks=True):
    head = ["| Item | Code | Kind | Pick |", "|---|---|---|---|"] if picks else ["| Item | Code | Kind |", "|---|---|---|"]
    rows = []
    for d in group:
        row = f"| {esc(d.get('name', d['id']))} | `{CODES[d['id']]}` | {kind(d)} |"
        rows.append(row + (f" {pick_note(d)} |" if picks else ""))
    return head + rows


CODES = {}


def by_name(ds):
    return sorted(ds, key=lambda d: str(d.get("name", d["id"])))


def render(items, magic, repo=False):
    """The list for the repo (`repo`: the same for the same data) or the vault (dated)."""
    gear = by_name(d for d in items.values() if playable(d))
    wonders = [d for d in magic.values() if playable(d)]
    count = f"{len(gear) + len(wonders)} items, {len(wonders)} of them magic"
    if repo:
        lines = [
            "# Cheat codes",
            "",
            f"Every code the game's Cheat codes page accepts: {count}.",
            "Each code gives that item to the hero you pick, as many times as you like. `make cheat-codes` rewrites this file",
            "(and the vault's Cheat Codes.md) from the item data, so run it after adding items rather than editing this by",
            "hand; `make validate` fails while it's behind.",
            "",
            "The codes come from the engine's `story/cheat_codes.gd`: the first six hex digits of sha256(\"cheat:<item id>\"), in",
            "upper case, with any clash settled in id order. Every item file has one by itself, and codes don't change when items",
            "are added, so a new item only adds a row here. Only playable items answer to a code; an entry marked",
            "`\"playable\": false` keeps its code for later but isn't given.",
            "",
        ]
    else:
        lines = [
            "# Cheat Codes",
            "",
            f"Every item in the game and its code: {count}. Rebuilt from the game's item data by `make cheat-codes` on "
            f"{datetime.date.today().isoformat()}, which also rewrites docs/cheat_codes.md in the game's repo; the next run "
            "rewrites this note, so don't edit it by hand.",
            "",
            "Codes never change when new items are added.",
            "",
        ]
    lines += HOW_TO
    crooked = by_name(d for d in wonders if ours(d))
    if crooked:
        lines += ["## Crooked Moon's own magic items", ""] + table(crooked) + [""]
    lines += ["## Magic items"]
    for rarity in RARITIES:
        group = by_name(d for d in wonders if str((d.get("magic") or {}).get("rarity", "")) == rarity)
        if group:
            lines += ["", f"### {rarity.replace('_', ' ').capitalize()}", ""] + table(group)
    other = by_name(d for d in wonders if str((d.get("magic") or {}).get("rarity", "")) not in RARITIES)
    if other:
        lines += ["", "### Other", ""] + table(other)
    lines += ["", "## Gear, weapons and armor", ""] + table(gear, picks=False)
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="only check that docs/cheat_codes.md is up to date (exit 1 if not)")
    ap.add_argument("--stdout", action="store_true", help="print the repo's list instead of writing anything")
    ap.add_argument("--out", type=Path, help="write the vault's note here instead of the vault (the repo's copy too)")
    args = ap.parse_args()
    items, magic = load("items"), load("magic_items")
    CODES.update(assign(list(items) + list(magic)))
    for item_id, code in PINNED.items():
        if CODES.get(item_id) != code:
            raise SystemExit(f"cheat_codes.py: {item_id} came out {CODES.get(item_id)}, not {code}: the game and this "
                             "tool no longer agree (the engine's story/cheat_codes.gd)")
    repo_text = render(items, magic, repo=True)
    if args.stdout:
        print(repo_text, end="")
        return
    rel = REPO_OUT.relative_to(ROOT)
    if args.check:
        if not REPO_OUT.exists() or REPO_OUT.read_text() != repo_text:
            raise SystemExit(f"{rel} is behind the item data: run make cheat-codes and commit it")
        print(f"{rel} is up to date")
        return
    listed = sum(1 for d in list(items.values()) + list(magic.values()) if playable(d))
    REPO_OUT.write_text(repo_text)
    print(f"Wrote {listed} cheat codes to {rel}")
    vault = args.out or OUT
    if not vault.parent.is_dir():
        print(f"No folder {vault.parent}: the vault's note was skipped")
        return
    vault.write_text(render(items, magic))
    print(f"Wrote {listed} cheat codes to {vault}")


if __name__ == "__main__":
    main()
