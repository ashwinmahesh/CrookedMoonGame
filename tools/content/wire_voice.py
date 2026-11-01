#!/usr/bin/env python3
"""Wires recorded voice clips into the game. Each finished take in the asset root's voice batches (<root>/voice/<batch>/jobs.json,
the clip at <root>/voice/<batch>/<speaker>/<key>.mp3) is copied to audio/voice/<speaker>/<key>.mp3, the path VoiceOver plays,
committed through Git LFS. A take is copied only while its line is still spoken somewhere under narrative/: the key is the first 16 hex
digits of the SHA-1 of the stripped line (act1_voice_keys.py), so an edited line's old take would never play. Prints what it copied and
skipped, and how many of the game's spoken lines have a clip, per narrative folder. Lines with {name} are never voiced.
    python3 tools/content/wire_voice.py [--dry-run] [--prune] [--list]
--prune deletes clips under audio/voice that no line speaks any more; --list names the spoken lines that have no clip yet.
Exit 1 when audio/voice holds a clip that no line speaks (wire again with --prune)."""
import collections
import filecmp
import glob
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
from act1_voice_keys import key, lines_in  # noqa: E402
from asset_root import asset_root  # noqa: E402

REPO = HERE.parents[1]


def game_lines(repo: Path) -> dict:
    """speaker/key -> (text, dialogue file relative to the repo) for every voiceable line under narrative/."""
    out = {}
    for sp, text, f, _n in lines_in(sorted(glob.glob(str(repo / "narrative/**/*.dialogue"), recursive=True))):
        if "{name}" not in text:
            out.setdefault(f"{sp}/{key(text)}", (text, str(Path(f).relative_to(repo))))
    return out


def wire(repo: Path, root: Path, dry_run: bool = False, prune: bool = False) -> dict:
    """Copies every finished, still-spoken take into repo/audio/voice; returns the counts (and the orphans and gaps by name)."""
    lines = game_lines(repo)
    audio = repo / "audio/voice"
    n = collections.Counter()
    seen = set()
    for jobs_file in sorted((root / "voice").glob("*/jobs.json")):
        batch = jobs_file.parent
        for k, e in json.loads(jobs_file.read_text()).items():
            if e.get("state") != "ok":
                n["takes not finished"] += 1
                continue
            src = batch / f"{k}.mp3"
            if not src.exists():
                n["finished takes with no clip file"] += 1
                continue
            if k not in lines:
                n["takes whose line was edited or removed"] += 1
                continue
            if k in seen:
                continue
            seen.add(k)
            dst = audio / f"{k}.mp3"
            if dst.exists() and filecmp.cmp(src, dst, shallow=False):
                n["already wired"] += 1
                continue
            n["wired now"] += 1
            if not dry_run:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, dst)
    orphans = sorted(str(p.relative_to(audio))[:-4] for p in audio.glob("*/*.mp3") if not p.name.startswith("._")
                     and str(p.relative_to(audio))[:-4] not in lines) if audio.exists() else []
    if prune and not dry_run:
        for o in orphans:
            (audio / f"{o}.mp3").unlink()
        orphans = []
    have = collections.Counter()
    total = collections.Counter()
    gaps = []
    for k, (text, f) in lines.items():
        folder = Path(f).parts[1]
        total[folder] += 1
        if (audio / f"{k}.mp3").exists() or (dry_run and k in seen):
            have[folder] += 1
        else:
            gaps.append((k, f, text))
    return {"counts": n, "have": have, "total": total, "orphans": orphans, "gaps": gaps}


def main(argv) -> int:
    dry, prune = "--dry-run" in argv, "--prune" in argv
    r = wire(REPO, asset_root(), dry, prune)
    print("wire voice:", ", ".join(f"{v} {k}" for k, v in r["counts"].items()) or "no voice batches under the asset root")
    for folder in sorted(r["total"]):
        print(f"  {folder}: {r['have'][folder]} of {r['total'][folder]} lines have a clip")
    print(f"  all: {sum(r['have'].values())} of {sum(r['total'].values())} spoken lines have a clip")
    if "--list" in argv:
        for k, f, text in r["gaps"]:
            print(f"  no clip  {k}  {f}: {text[:90]}")
    for o in r["orphans"]:
        print(f"  NO LINE SPEAKS audio/voice/{o}.mp3 (wire again with --prune)")
    return 1 if r["orphans"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
