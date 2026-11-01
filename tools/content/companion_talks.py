#!/usr/bin/env python3
"""Builds the companions' camp and banter files from Gemini's raw replies (docs/plans/gemini_companions/).

The words are Gemini's (edited, every edit listed in docs/plans/gemini_companions/README.md); the logic is ours: which condition opens
a talk, which flags and quests it moves, how big each approval is. A reply is plain text in a small row format (see the briefs):

    TALK <key>                    one camp talk
    NARRATOR: / SAY: ...          its opening lines (SAY is the companion)
    OPTION 1: .. OPTION 3: ..     the party's words
    REPLY 1 .. REPLY 3            what happens after each option: NARRATOR / SAY rows, REASON: (approval memory), INSPIRE:
    EXCHANGE <n>                  one banter exchange: SAY <companion id>: line

    python3 tools/content/companion_talks.py thread|acts|banter [<companion id>|<act>]   writes narrative/camp/ and narrative/banter/
    python3 tools/content/companion_talks.py check                                       parses every reply and reports row problems

Edits to a draft live beside its reply as edits_<brief>.json ([{"find", "replace", "why"}], applied to the reply's text before parsing).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANS = ROOT / "docs/plans/gemini_companions"
CAMP = ROOT / "narrative/camp"
BANTER = ROOT / "narrative/banter"

## id -> everything the files need that is not Gemini's words. `disc` / `conf` are the chapter flags the Discovery and Confrontation wait for
## (data/threads, the README's table); `echo` is the Incitement as it was played (narrative/crooked_house/ and ghostlight_express/incitements.dialogue):
## the flags the scene sets, and Heroic Inspiration's reason for the engaging option and the quiet one.
COMPANIONS: dict[str, dict] = {
    "rook_coldwake": {
        "first": "Rook", "thread": "pilgrimage", "disc": "flag.raum_slain", "conf": "flag.nm_chapter_done",
        "echo": {"choices": ["asked", "moved_on"], "connection_quest": False, "choice_flag": "rook_inc_choice",
                 "inspire": ["logged the spirits' plea", "shut the ledger on the frost"]},
    },
    "tobin_hayward": {
        "first": "Tobin", "thread": "rejuvenation", "disc": "flag.stonoga_slain", "conf": "flag.gorthos_slain",
        "echo": {"choices": ["asked", "moved_on"], "connection_quest": False, "choice_flag": "tobin_inc_choice",
                 "inspire": ["vowed to trace the valley's blight", "splinted the bough and moved on"]},
    },
    "silas_vane": {
        "first": "Silas", "thread": "liberation", "disc": "flag.crossroads_done", "conf": "flag.chuckles_dead",
        "echo": {"choices": ["shown", "pocketed"], "connection_quest": True, "choice_flag": "silas_inc_choice",
                 "inspire": ["read a dead clerk's warning", "read a dead clerk's warning"]},
    },
    "delphine_ravelle": {
        "first": "Delphine", "thread": "ascendancy", "disc": "flag.renathyr_slain", "conf": "flag.chuckles_dead",
        "echo": {"choices": ["shared", "alone"], "connection_quest": True, "choice_flag": "delphine_inc_choice",
                 "inspire": ["met the Fool's silence over a handbill", "met the Fool's silence over a handbill"]},
    },
    "lucan_houndstooth": {
        "first": "Lucan", "thread": "slaughter", "disc": "flag.raum_slain", "conf": "flag.gorthos_slain",
        "echo": {"choices": ["shared", "alone"], "connection_quest": False, "choice_flag": "lucan_inc_choice",
                 "inspire": ["shared a hunter's reading of the crow", "logged the burnt-straw crow in silence"]},
    },
    "cordelia_skein": {
        "first": "Cordelia", "thread": "evolution", "disc": "flag.lethica_slain", "conf": "flag.nm_chapter_done",
        "echo": {"choices": ["read", "packed"], "connection_quest": True, "choice_flag": "cordelia_inc_choice",
                 "inspire": ["found a doctor's unfinished notes", "found a doctor's unfinished notes"]},
    },
}
ORDER = list(COMPANIONS)

## The three banter files' act gates (the README).
ACTS = {
    "act1": "flag.gl_crashed and not flag.act2_done",
    "act2": "flag.vessla_slain and flag.act2_done < 5",
    "act3": "flag.act2_done >= 5",
}

## Size of the approval each option carries, by the kind of talk and the option's number (None: no approval line).
## An option 3 that brushes the companion off costs a little; "say nothing" costs nothing.
APPROVE = {
    "strained": [8, -3, None],
    "doubt": [5, -2, None],
    "act": [2, 3, -1],
    "warm": [2, 3, -1],
    "close": [3, 2, -1],
    "devoted": [3, 3, 2],
    "discovery": [2, 3, -1],
    "confrontation": [4, 6, -2],
    "wait": [6, -2, None],
    "incitement": [None, None],
}


# --- Reading a reply ---------------------------------------------------------------------------------------------------------

ROW = re.compile(r"^(?:[-*•]\s*)?(?:\*\*)?(TALK|EXCHANGE|OPTION|REPLY|NARRATOR|SAY|REASON|INSPIRE)(?:\s+([A-Za-z0-9_]+))?(?:\*\*)?\s*:?\s*(?:\*\*)?\s*(.*)$")


def clean(text: str) -> str:
    """Straight quotes and dots, no markdown; the words are left alone."""
    text = text.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"').replace("…", "...")
    text = text.replace("**", "").replace("`", "")
    return re.sub(r"\s+", " ", text).strip()


def reply_text(name: str) -> str:
    """A brief's reply (the bridge's record) with its edits applied."""
    rec = json.loads((PLANS / f"reply_{name}.json").read_text(encoding="utf-8"))
    text = str(rec.get("result", ""))
    edits = PLANS / f"edits_{name}.json"
    if edits.exists():
        for e in json.loads(edits.read_text(encoding="utf-8")):
            if e["find"] not in text:
                raise SystemExit(f"edits_{name}.json: not in the reply: {e['find']!r}")
            text = text.replace(e["find"], e["replace"], 1)
    return text


def parse_talks(text: str) -> dict[str, dict]:
    """{key: {"body": [(speaker, text)], "options": [str], "replies": [{"rows": [(speaker, text)], "reason": str, "inspire": str}]}}."""
    talks: dict[str, dict] = {}
    talk: dict | None = None
    reply: dict | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        m = ROW.match(line)
        if not m:
            continue
        kind, arg, rest = m.group(1), (m.group(2) or ""), clean(m.group(3))
        if kind == "TALK":
            talk = {"body": [], "options": ["", "", ""], "replies": []}
            talks[arg.lower().removeprefix("talk_")] = talk
            reply = None
        elif talk is None:
            continue
        elif kind == "OPTION":
            i = int(arg) - 1
            while len(talk["options"]) <= i:
                talk["options"].append("")
            talk["options"][i] = rest
            reply = None
        elif kind == "REPLY":
            reply = {"rows": [], "reason": "", "inspire": ""}
            talk["replies"].append(reply)
        elif kind in ("NARRATOR", "SAY"):
            (reply["rows"] if reply is not None else talk["body"]).append((kind, rest))
        elif kind == "REASON" and reply is not None:
            reply["reason"] = rest.rstrip(".")
        elif kind == "INSPIRE" and reply is not None:
            reply["inspire"] = (rest[:1].lower() + rest[1:]).rstrip(".")
    for t in talks.values():
        t["options"] = [o for o in t["options"] if o]
    return talks


def parse_exchanges(text: str) -> list[list[tuple[str, str]]]:
    """[[(companion id, line)]] per EXCHANGE."""
    out: list[list[tuple[str, str]]] = []
    for raw in text.splitlines():
        line = raw.strip().lstrip("-*• ").replace("**", "")
        if re.match(r"^EXCHANGE\b", line):
            out.append([])
            continue
        m = re.match(r"^SAY\s+([a-z_]+)\s*:\s*(.+)$", line)
        if m and out:
            out[-1].append((m.group(1), clean(m.group(2))))
    return out


# --- Problems with the words (reported, never silently fixed) ---------------------------------------------------------------------

BAD = [("—", "em dash"), ("–", "en dash"), (";", "semicolon"), ("(", "bracket"), ("[", "bracket"), ("{", "brace"), ("*", "asterisk"),
       ("suddenly", "'suddenly'"), ("“", "curly quote")]
GAME_WORDS = re.compile(r"\b(hit points?|hp|dc|saving throws?|level up|skill checks?|d20|proficien\w+)\b", re.I)


def problems(speaker: str, text: str, limit: int | None = None) -> list[str]:
    out = []
    for token, name in BAD:
        if token in text:
            out.append(name)
    if GAME_WORDS.search(text):
        out.append("game word")
    if limit and len(text.split()) > limit + 2:   # "under about": two words over is fine
        out.append(f"{len(text.split())} words")
    return out


def word_limit(kind: str) -> int:
    return 34 if kind == "NARRATOR" else 28


def split_long(text: str, limit: int) -> list[str]:
    """A line over the limit becomes consecutive lines at its sentence ends (the packs are as full as the limit allows)."""
    if len(text.split()) <= limit:
        return [text]
    sentences = re.split(r'(?<=[.!?])\s+(?=[A-Z"\'])', text)
    out: list[str] = []
    cur = ""
    for s in sentences:
        if cur and len((cur + " " + s).split()) > limit:
            out.append(cur)
            cur = s
        else:
            cur = (cur + " " + s).strip()
    if cur:
        out.append(cur)
    return out


# --- Writing the dialogue --------------------------------------------------------------------------------------------------------

def line_for(cid: str, kind: str, text: str) -> str:
    return f"Narrator: {text}" if kind == "NARRATOR" else f"interject name:{cid}: {text}"


def esc_option(text: str) -> str:
    return text.replace("->", "-")


class Writer:
    """One camp file: a header, then talks in the order they are offered."""

    def __init__(self, cid: str, header: str) -> None:
        self.cid = cid
        self.out: list[str] = [header.rstrip(), ""]
        self.problems: list[str] = []

    def talk(self, key: str, kind: str, cond: str, talk: dict, tail: list[str] | None = None, tail_for: callable = None,
             approve_kinds: str | None = None) -> None:
        """A talk: the opener node `talk_<key>` (never played itself), the scene node, and one node per option."""
        cid = self.cid
        sizes = APPROVE[approve_kinds or kind]
        opts, replies = talk["options"], talk["replies"]
        if len(replies) != len(opts):
            self.problems.append(f"{cid}/{key}: {len(opts)} options but {len(replies)} replies")
        if len(opts) != len(sizes):
            self.problems.append(f"{cid}/{key}: {len(opts)} options, expected {len(sizes)}")
        self.out += [f"~ talk_{key}", f"if {cond}", f"-> {key}", "endif", "-> END", "", f"~ {key}"]
        for kind_, whole in talk["body"]:
            for text in split_long(whole, word_limit(kind_)):
                self.out.append(line_for(cid, kind_, text))
                for p in problems(cid, text, word_limit(kind_)):
                    self.problems.append(f"{cid}/{key}: {p}: {text[:60]}")
        for i, o in enumerate(opts):
            self.out.append(f"* {esc_option(o)} -> {key}_{i + 1}")
            for p in problems(cid, o, 14):
                self.problems.append(f"{cid}/{key} option {i + 1}: {p}: {o[:60]}")
        self.out.append("")
        for i, r in enumerate(replies):
            self.out.append(f"~ {key}_{i + 1}")
            for kind_, whole in r["rows"]:
                for text in split_long(whole, word_limit(kind_)):
                    self.out.append(line_for(cid, kind_, text))
                    for p in problems(cid, text, word_limit(kind_)):
                        self.problems.append(f"{cid}/{key}_{i + 1}: {p}: {text[:60]}")
            size = sizes[i] if i < len(sizes) else None
            if tail_for is not None:
                self.out += tail_for(i)
            if size is not None:
                reason = r["reason"] or f"You answered {COMPANIONS[cid]['first']} at the fire"
                if not r["reason"]:
                    self.problems.append(f"{cid}/{key}_{i + 1}: no REASON")
                self.out.append(f"approve {cid} {'+' if size > 0 else ''}{size}: {reason}")
                for p in problems(cid, reason, 18):
                    self.problems.append(f"{cid}/{key}_{i + 1} reason: {p}: {reason[:60]}")
            for t in (tail or []):
                if "{inspire}" in t and not r["inspire"]:
                    self.problems.append(f"{cid}/{key}_{i + 1}: no INSPIRE")
                self.out.append(t.replace("{inspire}", r["inspire"]))
            self.out += ["-> END", ""]

    def text(self) -> str:
        return "\n".join(self.out).rstrip() + "\n"


def thread_file(cid: str) -> tuple[str, list[str]]:
    c = COMPANIONS[cid]
    t, first = c["thread"], c["first"]
    talks = parse_talks(reply_text(f"thread_{cid}"))
    w = Writer(cid, f"""# {first}'s Thread of Fate at camp ({t.title()}): the beats that wait for a rest (story/camp_talk.gd offers the first `talk_` node whose opening `if` holds,
# once a playthrough). Order matters: the Incitement's echo, the Discovery, the Confrontation (held back while {first} is Strained until the
# `talk_confrontation_wait` word has been had, never for good). Rewards come from Fateweaving when each beat's quest ends (story/fateweaving.gd).
# Drafted by Gemini (docs/plans/gemini_companions/), edited; every edit is listed in the README there. Lines are unvoiced until the voice lane reads them.
""")
    echo = c["echo"]
    # The Incitement's echo: the same flags and the same Heroic Inspiration the scene itself gives.
    if "incitement" in talks:
        def inc_tail(i: int) -> list[str]:
            ls = [f"set incitement_{t}"]
            if echo["connection_quest"]:
                ls.append(f"quest connection_{t} waiting")
            ls.append(f'set {echo["choice_flag"]} = "{echo["choices"][min(i, len(echo["choices"]) - 1)]}"')
            ls.append(f"inspire name:{cid}: {echo['inspire'][min(i, len(echo['inspire']) - 1)]}")
            return ls
        w.talk("incitement", "incitement", f"name:{cid} and flag.pending_{t}_incitement and not flag.incitement_{t}", talks["incitement"], tail_for=inc_tail)
    base = f"name:{cid} and flag.connection_{t}"
    if "discovery" in talks:
        w.talk("discovery", "discovery", f"{base} and {c['disc']} and not flag.discovery_{t}", talks["discovery"],
               tail=[f"set discovery_{t}", f"quest discovery_{t} done", f"quest confrontation_{t} waiting"])
    after = f"name:{cid} and flag.discovery_{t} and {c['conf']} and not flag.confrontation_{t}"
    if "confrontation_wait" in talks:
        w.talk("confrontation_wait", "wait", f"{after} and approval.{cid} <= strained and not flag.{cid}_confrontation_waited", talks["confrontation_wait"],
               tail=[f"set {cid}_confrontation_waited"])
    if "confrontation" in talks:
        w.talk("confrontation", "confrontation", f"{after} and (approval.{cid} > strained or flag.{cid}_confrontation_waited)", talks["confrontation"],
               tail=[f"set confrontation_{t}", f"quest confrontation_{t} done"])
    return w.text(), w.problems


def acts_file(cid: str) -> tuple[str, list[str]]:
    c = COMPANIONS[cid]
    first = c["first"]
    talks = parse_talks(reply_text(f"acts_{cid}")) | parse_talks(reply_text(f"secrets_{cid}"))
    w = Writer(cid, f"""# {first}'s camp talks (story/camp_talk.gd): offered after a Long Rest or at camp once the opening `if` holds, each once a playthrough, the first that
# holds in this order: when {first} is Strained or Doubtful (story/approval.gd), the acts' words, then Warm, Close and Devoted.
# {first}'s Thread of Fate beats are in {cid}_thread.dialogue. Dark secrets are the world lane's (Raum's gate): nothing here states one.
# Drafted by Gemini (docs/plans/gemini_companions/), edited; every edit is listed in the README there. Lines are unvoiced until the voice lane reads them.
""")
    spec = [
        ("strained", "strained", f"name:{cid} and approval.{cid} <= strained", None),
        ("doubt", "doubt", f"name:{cid} and approval.{cid} == doubtful", None),
        ("act1", "act", f"name:{cid} and flag.gl_crashed and not flag.vessla_slain", None),
        ("act2", "act", f"name:{cid} and flag.act2_done >= 2", None),
        ("act3", "act", f"name:{cid} and flag.act2_done >= 5", None),
        ("warm", "warm", f"name:{cid} and approval.{cid} >= warm and level >= 3", None),
        ("close", "close", f"name:{cid} and approval.{cid} >= close and level >= 5", None),
        ("devoted", "devoted", f"name:{cid} and approval.{cid} >= devoted and level >= 8", [f"inspire name:{cid}: {{inspire}}", "inspiration"]),
    ]
    for key, kind, cond, tail in spec:
        if key in talks:
            w.talk(key, kind, cond, talks[key], tail=tail)
        else:
            w.problems.append(f"{cid}: no TALK {key}")
    return w.text(), w.problems


def banter_file(act: str) -> tuple[str, list[str]]:
    gate = ACTS[act]
    exchanges = parse_exchanges(reply_text(f"banter_{act}"))
    out = [f"""# Party banter, {act[:3]} {act[3:]} (story/banter.gd): one exchange between two or three companions, played now and then on entering an area, once each. Every node opens
# with its act's gate and both speakers, so an exchange that can't be heard comes out empty and is skipped; any file named party_* plays anywhere.
# Drafted by Gemini (docs/plans/gemini_companions/), edited; every edit is listed in the README there. Lines are unvoiced until the voice lane reads them.
""", ""]
    probs: list[str] = []
    for n, ex in enumerate(exchanges, 1):
        who: list[str] = []
        for cid, _ in ex:
            if cid not in COMPANIONS:
                probs.append(f"{act} exchange {n}: unknown speaker {cid}")
            elif cid not in who:
                who.append(cid)
        node = f"{act}_{n:02d}_" + "_".join(COMPANIONS[c]["first"].lower() for c in who if c in COMPANIONS)
        out += [f"~ {node}", "if " + " and ".join(f"name:{c}" for c in who) + f" and {gate}"]
        for cid, whole in ex:
            for text in split_long(whole, word_limit("SAY")):
                out.append(f"interject name:{cid}: {text}")
                for p in problems(cid, text, word_limit("SAY")):
                    probs.append(f"{act} exchange {n}: {p}: {text[:60]}")
        if not 4 <= len(ex) <= 6:
            probs.append(f"{act} exchange {n}: {len(ex)} lines")
        out += ["endif", "-> END", ""]
    return "\n".join(out).rstrip() + "\n", probs


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    cmd = args[0]
    only = args[1] if len(args) > 1 else ""
    rc = 0
    if cmd in ("thread", "acts"):
        for cid in ORDER:
            if only and only != cid:
                continue
            body, probs = (thread_file if cmd == "thread" else acts_file)(cid)
            name = f"{cid}_thread.dialogue" if cmd == "thread" else f"{cid}.dialogue"
            CAMP.mkdir(parents=True, exist_ok=True)
            (CAMP / name).write_text(body, encoding="utf-8")
            print(f"{name}: {body.count(chr(10))} lines")
            for p in probs:
                print("  PROBLEM", p)
                rc = 1
    elif cmd == "banter":
        for act in ACTS:
            if only and only != act:
                continue
            body, probs = banter_file(act)
            BANTER.mkdir(parents=True, exist_ok=True)
            (BANTER / f"party_{act}.dialogue").write_text(body, encoding="utf-8")
            print(f"party_{act}.dialogue: {body.count(chr(10))} lines")
            for p in probs:
                print("  PROBLEM", p)
                rc = 1
    else:
        print(__doc__)
        return 2
    return rc


if __name__ == "__main__":
    sys.exit(main())
