#!/usr/bin/env python3
"""ONE-SHOT (R19). Sends every `<<key|brief>>` of maidenmist_dialogue.FILES to Gemini through the ai-bridge (batches, run in parallel,
briefs and raw replies kept in docs/plans/gemini_r19/), then writes narrative/maidenmist/<file>.dialogue with the drafts in place.
    python3 tools/content/maidenmist_fill.py send     # sends the batches that have no reply yet
    python3 tools/content/maidenmist_fill.py write    # writes the .dialogue files from the replies
Never prints the bridge token; does not start or restart the bridge."""
import json, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import maidenmist_dialogue as D

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "docs/plans/gemini_r19"
OUT = ROOT / "narrative/maidenmist"
PID = "ai-bridge-885bb429a2"
BRIDGE = str(Path.home() / ".crooked-moon/bridge.py")
BATCH = 34

CONTEXT = """You are drafting DIALOGUE LINES for a video game. Reply in plain text only, in the exact format asked. No commentary.

## The game
"The Crooked Moon" is a single-player turn-based tactical party RPG (fully voiced, branching dialogue, skill checks, a storyteller Narrator). Folk-horror campaign set in Druskenvald, an afterlife realm of endless night under a gargantuan crescent moon with a leering crone's face. Drawn like a 1960s monster cartoon stuck in Halloween, but the story is real folk horror: stakes, doomed innocents, sacrifice. Humour is deadpan and sits inside the dread. Everything is our own invention in our own words.

## This chapter: Maidenmist Cemetery
South-east of the village of Wickermoor, an endless fogbound cemetery fenced with cold iron is really a prison built over a tear into the Shroud, the mist of death that rings the realm. Wrathful soul-stripped spirits called the shrouded would pour out of it. Its sexton is YORGRIM, the ghost of an orc seer of the Shadestone Clan, who was tricked by his chieftain into a ritual that annihilated his whole clan's souls; he drags a gravestone carved with their names chained to his back as penance. He is dour, stoic, few words, never cruel, tells what matters, and grows vaguer and more distracted as the chapter goes; deep slow orc bass, short flat sentences, long pauses. His spectral black hound ISOLDE (white eyes, a hooded lantern in her mouth) does not speak: only the Narrator describes her. He asked five friends to kindle balefire beacons from fragments of their souls: Sir Marius Renathyr (knight of a morning god, horse Dawn, King Viktor Denathria), Lethica Nightborne (priestess of the Nightmother, barn owl, loved Marius), Ol' Jericho Sticks (kindly scarecrow banjo man), Captain Briggsy Kratch (pirate with a heart of gold, lucky, a swordsman and schemer), Farryn of the Greenwood (satyr druid of the Green Queen, loved Gwenna). They fell to the Horned King's sin and the heroes (the player's party of four, level nine) killed them. The beacons went dark, the tear grew, the dead walked into Wickermoor. The heroes relight the beacons with Final Rites that honour who the Fallen were before they fell, then go below, where Yorgrim breaks and becomes the Chained Reaper; they destroy him and perform his own rites to seal the tear.
Wickermoor people: MORI SHADE, undertaker, grave, stately, white hair, all black, a fount of folklore, follows the Strangers' ways learned from Yorgrim; DORIS SQUIRE, constable, tall, stocky, says the fewest words possible, flat northern burr; TOBIAS DIBBS, Mori's apprentice, relentlessly cheerful and practical; HESTER BOLTON, annoyed her husband Gregor is now a ghast and still owes rent; ADELA DRUSKENVALD (transatlantic 1920s patter); WESTON MURDOCH (warm revival preacher); Theodora Mayville the postmaster is secretly a pigeon hag.

## The Narrator
The Narrator is the Vagrant, a frog-faced ferryman telling the tale afterwards: warm, folksy, wry, fond of the party; never gloats. Second person, present tense, only what a hero could perceive, concrete senses (smell, sound, texture), no game words (HP, roll, level, check, DC, save), no modern slang, never "suddenly". Never name a specific hero (the party is addressed as "you" or "the party").

## Format rules
- One line of plain text per key, written as `key: text`. No quotes around the text, no stage directions, no asterisks, no emoji, no em dashes (use commas, periods, colons), straight quotes only, no brackets.
- A spoken line is one to three short sentences, 12 to 38 words, never over 45. Narrator lines are one or two sentences, never over 45 words. People speak plainly in their own voice; they do not explain the plot to the audience.
- Obey each brief's sentence count and content. Every line must carry a concrete detail.
- Do not put speaker names at the start of the text. Do not repeat the brief.
"""

LINE = re.compile(r"^(?P<speaker>[A-Za-z_][A-Za-z_ :]*?)(?:\s*\[(?P<mood>[a-z, :]+)\])?:\s+(?P<rest>.*)$")


def collect():
    items = []   # (file, key, speaker, mood, brief)
    seen = set()
    for fname, text in D.FILES.items():
        for line in text.splitlines():
            for m in D.PLACEHOLDER.finditer(line):
                key, brief = m.group(1), m.group(2)
                if key in seen:
                    raise SystemExit(f"duplicate key {key}")
                seen.add(key)
                head = line.split("<<")[0].strip()
                head = head[:-1] if head.endswith(":") else head
                if head == "|":
                    sp, mood = "Narrator", ""
                elif head.startswith("interject "):
                    sp, mood = head.split(" ", 1)[1], ""
                else:
                    mm = re.match(r"^([a-z_A-Z]+)(?:\s*\[([a-z]+)\])?$", head)
                    sp, mood = (mm.group(1), mm.group(2) or "") if mm else (head, "")
                items.append((fname, key, sp, mood, brief))
    return items


def batches(items):
    out, cur = [], []
    for it in items:
        cur.append(it)
        if len(cur) >= BATCH:
            out.append(cur); cur = []
    if cur:
        out.append(cur)
    return out


def body(batch):
    lines = [CONTEXT, "\n## Lines to draft (key | speaker | mood | brief). Reply with one `key: text` line for each key and nothing else.\n"]
    for (_f, key, sp, mood, brief) in batch:
        lines.append(f"{key} | {sp} | {mood or '-'} | {brief}")
    return "\n".join(lines) + "\n"


def send_one(i, batch):
    WORK.mkdir(parents=True, exist_ok=True)
    sent, reply = WORK / f"sent_{i:02d}.txt", WORK / f"reply_{i:02d}.json"
    if reply.exists():
        return i, "have"
    sent.write_text(body(batch))
    r = subprocess.run(["/opt/homebrew/bin/python3", "-I", BRIDGE, "send", PID, str(sent), "gemini-4-argon-medium", str(reply)], capture_output=True, text=True)
    return i, (r.stdout[-120:] + r.stderr[-120:]).replace("\n", " ")


def drafts():
    got = {}
    for rp in sorted(WORK.glob("reply_*.json")):
        text = json.loads(rp.read_text()).get("result") or ""
        for ln in text.splitlines():
            m = re.match(r"^\s*([a-z0-9_]+)\s*:\s*(.+?)\s*$", ln)
            if m:
                got[m.group(1)] = m.group(2)
    return got


def clean(t):
    t = t.strip().strip('"').replace("—", ",").replace("–", "-").replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    t = re.sub(r"\s+", " ", t)
    return t


def main():
    items = collect()
    if sys.argv[1:] == ["send"]:
        have = drafts()
        todo = [it for it in items if it[1] not in have]
        start = len(list(WORK.glob("reply_*.json"))) if have else 0
        bs = batches(todo)
        print(len(todo), "of", len(items), "keys to draft,", len(bs), "batches", flush=True)
        with ThreadPoolExecutor(4) as ex:
            for i, msg in ex.map(lambda a: send_one(start + a[0], a[1]), list(enumerate(bs))):
                print(i, msg, flush=True)
    elif sys.argv[1:] == ["write"]:
        got = drafts()
        missing = [k for (_f, k, _s, _m, _b) in items if k not in got]
        if missing:
            raise SystemExit(f"no draft for {len(missing)} keys: {missing[:12]}")
        OUT.mkdir(parents=True, exist_ok=True)
        for fname, text in D.FILES.items():
            out = D.PLACEHOLDER.sub(lambda m: clean(got[m.group(1)]), text)
            dest = (ROOT / "narrative" / f"{fname}.dialogue") if fname.startswith("narrator/") else (OUT / f"{fname}.dialogue")
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(out.strip() + "\n")
            print("wrote", fname)
    else:
        print(len(items), "keys")


if __name__ == "__main__":
    main()
