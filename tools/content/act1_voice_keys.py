#!/usr/bin/env python3
"""Checks that Act 1's spoken lines still hash to the voice jobs' keys (a clip is keyed by its text: an edited line goes silent).
The key is the first 16 hex digits of the SHA-1 of the stripped line (core/voice_over.gd VoiceOver.key), the clip
res://audio/voice/<speaker>/<key>.mp3. Reads the voice jobs file (CM_VOICE_JOBS, default the asset drive's act1/jobs.json) and the dialogue under
narrative/ghostlight_express/ and narrative/narrator/ghostlight_express.dialogue; skips quietly when the jobs file isn't there.
Exit 1 when a job's line is no longer in the dialogue (it was edited or removed). Lines with {name}, and a class interject whose
speaker is whichever hero matches, are never voiced and are not counted.
    python3 tools/content/act1_voice_keys.py [--region crooked_house|camp|banter] [--list]
--region camp and --region banter read narrative/camp/ and narrative/banter/ (the companions' camp talks and party banter, which have no Narrator file:
the Narrator rows are in the talks); --list prints every line with no job yet, whether or not a jobs file exists."""
import glob
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
## --region crooked_house checks Act 2's first chapter instead (narrative/crooked_house/ and narrative/narrator/crooked_house.dialogue, jobs in
## .../voice/crooked_house/jobs.json); the default is Act 1's Ghostlight Express.
REGION = sys.argv[sys.argv.index("--region") + 1] if "--region" in sys.argv else "ghostlight_express"
JOBS = Path(os.environ.get("CM_VOICE_JOBS", "/Volumes/ASH-SSD/CrookedMoon/assets/voice/%s/jobs.json" % ("act1" if REGION == "ghostlight_express" else REGION)))
NOT_STATEMENTS = ("set", "if", "elif", "quest", "cutscene", "give", "take", "gold", "xp", "move", "combat", "narrate", "reveal", "approve", "attitude",
                  "appear", "vanish", "join", "time", "inspire", "reading", "lead", "end")


def key(text: str) -> str:
    return hashlib.sha1(text.strip().encode()).hexdigest()[:16]


def spoken_lines():
    """(speaker, text, file, line number) for every line the game can speak."""
    narrator_file = ROOT / ("narrative/narrator/%s.dialogue" % REGION)
    files = sorted(glob.glob(str(ROOT / ("narrative/%s/*.dialogue" % REGION)))) + ([str(narrator_file)] if narrator_file.exists() else [])
    yield from lines_in(files)


def lines_in(files):
    """(speaker, text, file, line number) for every spoken line in these dialogue files (tools/content/wire_voice.py reads them all)."""
    for f in files:
        narrator_file = "/narrator/" in f
        for n, line in enumerate(open(f, encoding="utf-8"), 1):
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            if narrator_file:
                if line.startswith("|"):
                    text = line[1:].strip()
                    tag = re.match(r"\[[^\]]*\]\s*(.*)", text)
                    yield "narrator", (tag.group(1) if tag else text), f, n
                continue
            m = re.match(r"^Narrator:\s*(.+)$", line)
            if m:
                yield "narrator", m.group(1), f, n
                continue
            m = re.match(r"^interject\s+name:([a-z0-9_]+):\s+(.+)$", line)
            if m:
                yield m.group(1), m.group(2), f, n
                continue
            m = re.match(r"^([a-z][a-z0-9_]*)(?:\s+\[[a-z]+\])?:\s+(.+)$", line)
            if m and m.group(1) not in NOT_STATEMENTS:
                yield m.group(1), m.group(2), f, n


def main() -> int:
    if not JOBS.exists() and "--list" not in sys.argv:
        print(f"voice keys: {JOBS} isn't here; skipped")
        return 0
    ## No jobs file yet (the camp and banter lines were drafted before the voice lane): --list names every line as one with no job.
    jobs = json.load(open(JOBS)) if JOBS.exists() else {}
    lines = [(sp, t, f, n) for sp, t, f, n in spoken_lines() if "{name}" not in t]
    have = {f"{sp}/{key(t)}" for sp, t, _, _ in lines}
    missing = sorted(set(jobs) - have)
    unvoiced = [(sp, t, f, n) for sp, t, f, n in lines if f"{sp}/{key(t)}" not in jobs]
    print(f"voice keys: {len(lines)} lines, {len(jobs)} jobs, {len(missing)} jobs whose line was edited or removed, "
          f"{len(unvoiced)} lines with no job yet")
    for k in missing:
        tagged = " (the job's text starts with a condition tag: strip it and re-key)" if jobs[k]["text"].startswith("[") else ""
        print(f"  EDITED/REMOVED  {k}: {jobs[k]['text'][:100]}{tagged}")
    if "--list" in sys.argv:
        for sp, t, f, n in unvoiced:
            print(f"  no job  {sp} {Path(f).name}:{n}: {t[:100]}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
