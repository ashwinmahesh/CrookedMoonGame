#!/usr/bin/env python3
"""R20: turns tools/content/rookery_templates/<name>.tpl (nodes, logic, jumps and conditions written by hand; every spoken line, option and
Narrator line a `<<brief>>` placeholder) into narrative/rookery/<name>.dialogue. Gemini (through the ai-bridge, never the token printed) drafts each
placeholder's text in one request per file; the structure is never in its hands. Briefs and raw replies go to docs/plans/gemini_r20/.
    python3 tools/content/rookery_fill.py [name ...]"""
import json, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TPL = ROOT / "tools/content/rookery_templates"
OUT = ROOT / "narrative/rookery"
LOG = ROOT / "docs/plans/gemini_r20"
BRIDGE = Path.home() / ".crooked-moon/bridge.py"
PID = "ai-bridge-885bb429a2"
MODEL = "gemini-4-argon-medium"

CONTEXT = """You are drafting DIALOGUE TEXT for a video game. Reply in plain text only, in exactly the format asked at the end.

"The Crooked Moon" is a single-player, turn-based tactical party RPG (think Baldur's Gate 3: fully voiced, branching dialogue, skill checks, a storyteller Narrator). It is folk horror set in Druskenvald, an afterlife realm of endless night under a gargantuan crescent moon with a leering crone's face; drawn like a 1960s monster cartoon stuck in Halloween, but the stakes are real. Humour is deadpan and sits beside the dread.

THIS SCENE: Chapter 20, "The Roving Rookery". The village of Wickermoor has been swept into a mass hysteria by Golub Graygullet, a pigeon hag who has lived seventy years among the villagers wearing other women's skins, lately as the postmaster Theodora Mayville. She staged a murder, pinned it on the party (four level 10 heroes) with a forged letter, and charmed the whole village: every neighbour is hostile, doors are barred, shops shut, mobs with torches walk the lanes, and grey pigeons line every roof. A tell of the charm is a lilac glint in the eyes. Her flying, walking dovecote stands up on pigeon legs and roams between four roosts. Peeping Albert is her spy: a pudgy pigeon with a wrinkled bald human head, human ears, and hands for talons; he is terrified of dogs. Cast: Constable Doris Squire (tall, stocky, laconic, writes poetry in secret), Deputy Howie Butterman (friendly, false, a hidden cultist), Mayor Wendel Somerton (officious, loves forms, bowler hat, waxed moustache), Tamsin Ledger (deadpan auditor, treats strangeness as a clerical error), Ambrose Quill (grand hopeless poet), Sergeant Gaunt (overconfident coward), Pip Oakum (a small boy who trades buttons), Mrs. Oakum (hill-country twang, a werewolf who only wants to hurt no one), Marianna Grey (shy stablemistress), Weston Murdoch (warm Brightsinger preacher), Hilda Brom (terse huntress), Geneva Fairchild (earnest assistant, lilac eyes), Phillip and Adela Druskenvald (dapper theatrical lord; bright slangy lady), Dani Jenkin (child with a hound called Shuck), Jeremiah Stover (stubborn tuber farmer).

RULES FOR THE TEXT
- Spoken lines: 1 to 3 short sentences, about 12 to 30 words, never over 45. Contractions are normal. People talk in their own voice and do not explain the plot to the audience. Accent is word choice and rhythm, never phonetic spelling.
- Option lines (what the player's party says or does): under 12 words, plain, in the party's voice ("We..." or an imperative).
- Narrator lines ("The Vagrant", a frog-faced ferryman telling the tale afterwards: warm, folksy, wry, never gloating): second person, present tense, one or two sentences, only what a hero could perceive, concrete senses (smell, sound, texture), no game words (HP, roll, level, check, DC, save), no modern slang, never the word "suddenly". Never mention the Vagrant by name inside the line.
- No stage directions, asterisks, italics, brackets, placeholders, emoji or em dashes (use commas, periods, colons). Straight quotes only. Do not use the arrow characters -> or => inside the text.
- Content is dark but restrained: no gore, no graphic detail.
- Each brief inside <<...>> says what the line must do; keep its facts, write it as the speaker would say it. Where it says "The Vagrant:" it is a Narrator line.
"""


def parse(text: str):
    """Returns (rendered text with [[n]] markers, list of items)."""
    items = []
    node = ""
    out = []
    for line in text.splitlines():
        m = re.match(r"~\s*(\S+)", line)
        if m:
            node = m.group(1)
        def sub(mm):
            n = len(items) + 1
            kind = "narrator" if (line.startswith("Narrator") or line.startswith("|")) else ("option" if line.lstrip().startswith("*") else "spoken")
            who = line.split("[")[0].split(":")[0].strip() if kind == "spoken" else kind
            items.append({"n": n, "node": node, "kind": kind, "who": who, "brief": mm.group(1).strip()})
            return f"[[{n}]]"
        out.append(re.sub(r"<<(.*?)>>", sub, line))
    return "\n".join(out), items


def clean(t: str) -> str:
    t = t.replace("—", ", ").replace("–", ", ").replace("‘", "'").replace("’", "'").replace("“", '"').replace("”", '"')
    t = re.sub(r"\s+", " ", t).strip().strip("`")
    t = t.replace("->", "to").replace("=>", "to")
    return t


def run(name: str):
    src = (TPL / f"{name}.tpl").read_text()
    shown, items = parse(src)
    LOG.mkdir(parents=True, exist_ok=True)
    table = "\n".join(f"{i['n']}. node `{i['node']}`, {i['kind']}" + (f" by {i['who']}" if i['kind'] == 'spoken' else "") + f": {i['brief']}" for i in items)
    body = (CONTEXT + f"\n## The conversation file `{name}` (structure is fixed; only the [[n]] markers are yours)\n\n```\n{shown}\n```\n\n## Briefs\n\n{table}\n\n"
            f"## Reply format\nOne line per marker, in order, exactly `n => text` (no quotes around the text, no extra lines, no commentary). {len(items)} lines.\n")
    sent = LOG / f"sent_{name}.txt"
    reply = LOG / f"reply_{name}.json"
    sent.write_text(body)
    if reply.exists():
        reply.unlink()
    r = subprocess.run(["/opt/homebrew/bin/python3", "-I", str(BRIDGE), "send", PID, str(sent), MODEL, str(reply)], capture_output=True, text=True)
    print(name, r.stdout[-100:], r.stderr[-160:], flush=True)
    if not reply.exists():
        print("NO REPLY", name)
        return False
    text = json.loads(reply.read_text()).get("result") or ""
    got = {}
    for line in text.splitlines():
        m = re.match(r"\s*\**(\d+)\**\s*(?:=>|:|\.)\s*(.*)$", line)
        if m:
            got[int(m.group(1))] = clean(m.group(2))
    missing = [i["n"] for i in items if i["n"] not in got or not got[i["n"]]]
    if missing:
        print("MISSING", name, missing)
        return False
    filled = src
    for i in items:
        filled = re.sub(r"<<.*?>>", lambda mm: got[i["n"]], filled, count=1)
    long = [i["n"] for i in items if i["kind"] == "spoken" and len(got[i["n"]].split()) > 45]
    if long:
        print("LONG", name, long)
    OUT.mkdir(parents=True, exist_ok=True)
    dest = ROOT / "narrative/narrator/rookery.dialogue" if name == "narrator" else OUT / f"{name}.dialogue"
    dest.write_text(filled.replace("# R20", "# Drafted by Gemini (R20), edited. R20", 1) if filled.startswith("# R20") else filled)
    print("wrote", name, len(items), flush=True)
    return True


if __name__ == "__main__":
    names = sys.argv[1:] or sorted(p.stem for p in TPL.glob("*.tpl"))
    for n in names:
        run(n)
