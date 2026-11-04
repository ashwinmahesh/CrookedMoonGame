"""Companion reactions in the story's big conversations, Acts II and III (fun pass lane A, 2026-11-03): Gemini's drafts in
docs/plans/gemini_companions/reply_reactions_<chapter>.json, our edits in edits_reactions.json beside them, written into the
chapters' dialogue files.

    approve  an `approve <id> <+n> ...: You ...` line first in a node a player's option leads to
    asides   an `interject name:<id>: ...` line right after the spoken line it answers, in the same node

A draft is left out (and listed) when its node isn't there, its approve node isn't an option's target, its aside's line isn't
found, the line after it is an option, the node already holds one of ours, or it breaks the line rules (companion ids, sizes,
word counts, game words). Run it on clean chapter files: it adds lines and never edits a line that is there.

    python3 tools/content/companion_reactions.py [--dry-run]
"""
from __future__ import annotations

import glob
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANS = ROOT / "docs/plans/gemini_companions"
IDS = {"rook_coldwake", "tobin_hayward", "silas_vane", "delphine_ravelle", "lucan_houndstooth", "cordelia_skein"}
GAME_WORDS = re.compile(r"\b(hit points?|level|quest|roll|spell slot|saving throw|check|npc|party)\b", re.I)


def reply(path: Path) -> dict:
    """A batch's drafts, or none for a batch whose send failed (it is sent again later)."""
    got = json.load(open(path))
    if got.get("state") != "done":
        return {}
    text = str(got["result"]).strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
    return json.loads(text)


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", s.lower()).split()


def node_span(lines: list[str], node: str) -> tuple[int, int] | None:
    """[start, end) of a node's lines, the `~ node` line excluded."""
    for i, l in enumerate(lines):
        if l.strip() == "~ " + node:
            j = i + 1
            while j < len(lines) and not lines[j].startswith("~ "):
                j += 1
            while j > i + 1 and lines[j - 1].strip() == "":
                j -= 1
            return i + 1, j
    return None


def spoken(l: str) -> bool:
    s = l.strip()
    return bool(re.match(r"^([a-z0-9_]+(\s*\[[^\]]*\])?|Narrator):\s", s)) or s.startswith("interject ")


def main() -> int:
    dry = "--dry-run" in sys.argv
    edits = json.load(open(PLANS / "edits_reactions.json")) if (PLANS / "edits_reactions.json").exists() else {}
    skip, replace = set(edits.get("skip", [])), edits.get("replace", {})
    files: dict[str, list[str]] = {}
    left_out: list[str] = []
    counts = {"approve": 0, "asides": 0}

    def load(name: str) -> list[str] | None:
        name = re.sub(r"\s*\(continued\)\s*$", "", name.strip()).removeprefix("narrative/")
        p = ROOT / "narrative" / name
        if not p.exists():
            return None
        if name not in files:
            files[name] = open(p, encoding="utf-8").read().split("\n")
        return files[name]

    for path in sorted(PLANS.glob("reply_reactions_*.json")):
        got = reply(path)
        for a in got.get("approve", []):
            key = "%s:%s" % (a["file"], a["node"])
            if key in skip:
                continue
            lines = load(a["file"])
            why = str(replace.get(key, a["reason"])).strip().rstrip(".")
            changes = {k: int(v) for k, v in a["changes"].items()}
            span = lines and node_span(lines, a["node"])
            problem = ""
            if not span:
                problem = "no such node"
            elif not any(re.search(r"(->|\|)\s*%s\b" % re.escape(a["node"]), l) and l.strip().startswith("*") for l in lines):
                problem = "not an option's target"
            elif any(l.strip().startswith("approve ") for l in lines[span[0]:span[1]]):
                problem = "the node already approves"
            elif not changes or any(k not in IDS or v == 0 or abs(v) > 10 for k, v in changes.items()):
                problem = "bad changes %s" % changes
            elif not why.startswith("You") or len(why.split()) > 16 or GAME_WORDS.search(why):
                problem = "reason: " + why
            if problem:
                left_out.append(f"approve {key}: {problem}")
                continue
            line = "approve " + " ".join("%s %+d" % (k, v) for k, v in changes.items()) + ": " + why
            # First in the node: the choice is what they react to, and every path through the node runs it.
            lines.insert(span[0], line)
            counts["approve"] += 1
        for a in got.get("asides", []):
            key = "%s:%s:%s" % (a["file"], a["node"], a["who"])
            if key in skip:
                continue
            lines = load(a["file"])
            text = str(replace.get(key, a["line"])).strip()
            span = lines and node_span(lines, a["node"])
            problem, at = "", -1
            if not span:
                problem = "no such node"
            elif a["who"] not in IDS:
                problem = "who " + a["who"]
            if not problem:
                s, e = span
                if any(l.strip().startswith("interject name:") for l in lines[s:e]):
                    problem = "the node already has an aside"
                # The drafts quote the line with or without its speaker: match the opening words either way.
                want = norm(re.sub(r"^\s*[A-Za-z0-9_]+(\s*\[[^\]]*\])?:\s*", "", a["after"]))[:5]
                for i in range(s, e):
                    said = re.sub(r"^\s*(interject\s+)?[A-Za-z0-9_:]+(\s*\[[^\]]*\])?:\s*", "", lines[i])
                    if spoken(lines[i]) and want and norm(said)[:len(want)] == want:
                        at = i
                        break
                if not problem and at < 0:
                    problem = "line not found: " + a["after"]
                elif not problem:
                    nxt = next((lines[j].strip() for j in range(at + 1, e) if lines[j].strip()), "")
                    if nxt.startswith("*"):
                        problem = "an option follows"
                    elif len(text.split()) > 20 or len(text.split()) < 4 or GAME_WORDS.search(text):
                        problem = "line rules: " + text
            if problem:
                left_out.append(f"aside {key}: {problem}")
                continue
            lines.insert(at + 1, "interject name:%s: %s" % (a["who"], text))
            counts["asides"] += 1
    if not dry:
        for name, lines in files.items():
            open(ROOT / "narrative" / name, "w", encoding="utf-8").write("\n".join(lines))
    print("approve %(approve)d, asides %(asides)d" % counts)
    for l in left_out:
        print("left out:", l)
    return 0


if __name__ == "__main__":
    sys.exit(main())
