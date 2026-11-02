#!/usr/bin/env python3
"""Headless QA (the QA lane): the story bot, the fight series and their report. Stdlib only.

  python3 tools/qa/qa.py story  [--out DIR] [--dice high|seeded] [--seeds 1,2] [--steps N] [--trace]
  python3 tools/qa/qa.py fights [--out DIR] [--seeds 1-8] [--modes story,balanced,tactician,honour] [--only loc:id,id]
                                [--regions a,b] [--jobs N] [--play auto|plain|sharp|full] [--levels FILE]
  python3 tools/qa/qa.py report [--out DIR]
  python3 tools/qa/qa.py act1   [--out DIR] [--seeds 1-4] [--mode balanced] [--shuffled] [--checkpoint DIR/SLOT] [--resume DIR/SLOT]

act1    plays tools/qa/act1_player.tscn: the real title, roster and difficulty pages, then the real game scene driven by
        clicks, through the Ghostlight Express, Wickermoor and the Crooked House to Vessla dead at level 4; prints each
        run's blockers. --checkpoint saves the game where the Express ends; --resume starts from such a save.

story   plays tools/qa/story_bot.tscn once per seed and writes story-<dice>-<seed>.json, plus levels.json (the level the
        party reached each fight at, which `fights` then reads).
fights  plays tools/qa/fight_series.tscn in --jobs processes (each takes every n-th fight) and writes fights.jsonl.
report  turns what's in DIR into DIR/report.md: the bot's runs, the problems it found, and a win-rate table per fight
        and difficulty, the fights won least first.

NO TUNING RUNS (Ashwin's standing rule): never run `fights` (or any other battle tuning, difficulty or party-performance run:
autopilot fight series, win and wipe rates, multi-seed fights) unless Ashwin explicitly asks for it. `story` and `act1` are for
finding bugs, hangs and softlocks, which is fine.

Every Godot process runs headless with its own user data folder (never the owner's saves), and is stopped by its own PID
when it overruns --timeout. GODOT names the binary (default: the Mac's). DIR defaults to captures/qa (git-ignored).
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import threading
import time
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import run_tests  # noqa: E402  (the shared Godot slots)
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
MODES = ["story", "balanced", "tactician", "honour"]


def godot(scene: str, user_args: list[str], timeout: int, log_path: str) -> int:
    """Runs `scene` headless, in one of the shared test slots (tools/run_tests.py's, so QA counts against the Mac's cap of
    eight headless Godots across all lanes and both games); returns the exit code (124 on timeout). The scenes keep
    their saves and settings in user://qa_saves/<pid>/, never the player's."""
    slot = run_tests.take_slot("test", int(os.environ.get("TEST_SLOTS", run_tests.POOL_SIZE["test"])), threading.Event())
    cmd = [GODOT, "--headless", "--path", ROOT, "--audio-driver", "Dummy", scene, "--"] + user_args
    try:
        with open(log_path, "w") as log:
            p = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
            if slot:
                with open(os.path.join(slot, "pid"), "w") as f:
                    f.write(str(p.pid))
            try:
                return p.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                p.kill()     # our own PID only
                p.wait()
                return 124
    finally:
        run_tests.free_slot(slot)


def script_errors(log_path: str) -> list[str]:
    out = []
    try:
        lines = open(log_path, errors="replace").read().splitlines()
    except OSError:
        return out
    for i, line in enumerate(lines):
        if "SCRIPT ERROR" in line or line.startswith("ERROR:") or "Parse Error" in line:
            at = lines[i + 1].strip() if i + 1 < len(lines) else ""
            out.append((line.strip() + " " + at).strip())
    return out


def seeds_of(s: str) -> list[int]:
    out = []
    for part in s.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def cmd_story(a: argparse.Namespace) -> int:
    os.makedirs(a.out, exist_ok=True)
    levels: dict[str, int] = {}
    rc = 0
    for s in seeds_of(a.seeds):
        tag = f"-{a.order.replace(',', '')}" if a.order else ""
        out = os.path.join(a.out, f"story-{a.dice}-{s}{tag}.json")
        log = os.path.join(a.out, f"story-{a.dice}-{s}{tag}.log")
        t = time.time()
        code = godot("res://tools/qa/story_bot.tscn", [f"--out={out}", f"--dice={a.dice}", f"--seed={s}",
                     f"--steps={a.steps}", f"--trace={1 if a.trace else 0}"] + ([f"--order={a.order}"] if a.order else []), a.timeout, log)
        if code != 0 or not os.path.exists(out):
            print(f"story {a.dice} seed {s}: Godot exited {code}; see {log}")
            for e in script_errors(log)[:10]:
                print("  " + e)
            rc = 1
            continue
        r = json.load(open(out))
        print(f"story {a.dice} seed {s}: {r['end']} after {r['steps']} steps ({time.time() - t:.0f} s) at {r['location']}, "
              f"level {r['level']}; main quests ended {len(r['main_ended'])}; {len(r['problems'])} problems")
        for c in r.get("chapters", []):
            print(f"  {c['chapter']} ({c['quest']}) {c['ending']} at step {c['step']}, level {c['level']}")
        for pr in r["problems"]:
            print(f"  problem {pr['kind']} at {pr['where']}: {pr['detail'][:300]}")
        for k, v in r["levels"].items():
            levels.setdefault(k, v)
    if levels:
        json.dump(levels, open(os.path.join(a.out, "levels.json"), "w"), indent=1, sort_keys=True)
    return rc


def act1_levels(r: dict, out: str) -> None:
    """The party a player run met each fight with, for the fight series: levels.json gains "loc:id" -> the highest
    level of a living hero at that fight's first try, and "_party" -> the heroes picked on the roster page."""
    path = os.path.join(out, "levels.json")
    levels = json.load(open(path)) if os.path.exists(path) else {}
    ids = {i.split("_")[0].capitalize(): i for i in r.get("roster", [])}
    for f in r.get("fights", []):
        heroes = [h.strip() for h in str(f.get("party_before", "")).split(",") if h.strip()]
        alive = [int(h.split()[1][1:]) for h in heroes if not h.endswith("dead") and len(h.split()) > 1]
        key = f"{f['place']}:{f['id']}"
        if alive and key not in levels:
            levels[key] = max(alive)
        party = [ids[h.split()[0]] for h in heroes if h.split()[0] in ids]
        if party and "_party" not in levels:
            levels["_party"] = party
    with open(path, "w") as fh:
        json.dump(levels, fh, indent=1, sort_keys=True)


def cmd_perf(a: argparse.Namespace) -> int:
    """Each place's build time and per-frame CPU cost, headless (tools/qa/perf.gd), slowest first in perf.md."""
    os.makedirs(a.out, exist_ok=True)
    out = os.path.join(a.out, "perf.jsonl")
    log = os.path.join(a.out, "perf.log")
    args = [f"--out={out}", f"--frames={a.frames}"]
    if a.regions:
        args.append(f"--regions={a.regions}")
    if a.only:
        args.append(f"--only={a.only}")
    code = godot("res://tools/qa/perf.tscn", args, a.timeout, log)
    rows = [json.loads(l) for l in open(out) if l.strip()] if os.path.exists(out) else []
    rows.sort(key=lambda r: -r["frame_ms_p95"])
    lines = ["# Performance pass (headless: CPU only, no drawing)", "",
             "| Place | Build ms | Slowest settling frame ms | Frame ms median | p95 | max | Nodes | Objects | Static MB |",
             "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for r in rows:
        lines.append(f"| {r['loc']} | {r['build_ms']:.0f} | {r['settle_ms_max']} | {r['frame_ms_median']} | "
                     f"{r['frame_ms_p95']} | {r['frame_ms_max']} | {r['nodes']} | {r['objects']} | {r['static_mb']} |")
    open(os.path.join(a.out, "perf.md"), "w").write("\n".join(lines) + "\n")
    print(f"{len(rows)} places measured; see {os.path.join(a.out, 'perf.md')}")
    for e in script_errors(log)[:15]:
        print("  " + e)
    return code


def cmd_act1(a: argparse.Namespace) -> int:
    os.makedirs(a.out, exist_ok=True)
    rc = 0
    for s in seeds_of(a.seeds):
        tag = f"act1-{a.mode}-{'book' if a.book_order else 'shuffled'}-{s}"
        out = os.path.join(a.out, tag + ".json")
        log = os.path.join(a.out, tag + ".log")
        t = time.time()
        extra = [f"--checkpoint={a.checkpoint}"] if a.checkpoint else []
        if a.resume:
            extra.append(f"--resume={a.resume}")
        if a.revive:
            extra.append("--revive=1")
        code = godot("res://tools/qa/act1_player.tscn", [f"--out={out}", f"--seed={s}", f"--mode={a.mode}",
                     f"--book-order={1 if a.book_order else 0}"] + extra, a.timeout, log)
        errs = script_errors(log)
        if code != 0 or not os.path.exists(out):
            print(f"{tag}: Godot exited {code}; see {log}")
            rc = 1
        else:
            r = json.load(open(out))
            print(f"{tag}: {r['end']} ({time.time() - t:.0f} s), stage {r['stage']} at {r['location']}, "
                  f"{len(r['blockers'])} blockers, {len(r['fights'])} fights")
            for b in r["blockers"]:
                print(f"  BLOCKER {b['what']} at {b['location']} ({b['stage']}): {b['detail']}")
            act1_levels(r, a.out)
        for e in errs[:15]:
            print("  " + e)
    return rc


def cmd_fights(a: argparse.Namespace) -> int:
    os.makedirs(a.out, exist_ok=True)
    levels = a.levels or os.path.join(a.out, "levels.json")
    parts = []
    codes: dict[int, int] = {}

    def run(i: int) -> None:
        part = os.path.join(a.out, f"fights-{i}.jsonl")
        log = os.path.join(a.out, f"fights-{i}.log")
        args = [f"--out={part}", f"--seeds={a.seeds}", f"--modes={a.modes}", f"--shard={i}/{a.jobs}", f"--play={a.play}",
                f"--rounds={a.rounds}"]
        if os.path.exists(levels):
            args.append(f"--levels={os.path.abspath(levels)}")
        if a.only:
            args.append(f"--only={a.only}")
        if a.regions:
            args.append(f"--regions={a.regions}")
        codes[i] = godot("res://tools/qa/fight_series.tscn", args, a.timeout, log)
        parts.append(part)

    t = time.time()
    threads = [threading.Thread(target=run, args=(i,)) for i in range(a.jobs)]
    for th in threads:
        th.start()
    for th in threads:
        th.join()
    rows = []
    for i in range(a.jobs):
        part = os.path.join(a.out, f"fights-{i}.jsonl")
        if os.path.exists(part):
            rows += [json.loads(l) for l in open(part) if l.strip()]
        if codes.get(i) != 0:
            print(f"fight shard {i}: Godot exited {codes.get(i)}; see {os.path.join(a.out, f'fights-{i}.log')}")
            for e in script_errors(os.path.join(a.out, f"fights-{i}.log"))[:10]:
                print("  " + e)
    with open(os.path.join(a.out, "fights.jsonl"), "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
    print(f"{len(rows)} fights played in {time.time() - t:.0f} s")
    return 0 if all(c == 0 for c in codes.values()) else 1


def _table(rows: list[dict]) -> list[str]:
    by = defaultdict(lambda: defaultdict(list))
    meta = {}
    for r in rows:
        key = (r["loc"], r["id"], r["version"])
        by[key][r["mode"]].append(r)
        meta[key] = r
    modes = [m for m in MODES if any(m in v for v in by.values())]

    def rate(rs: list[dict]) -> float:
        return sum(1 for r in rs if r.get("outcome") == "victory") / max(1, len(rs))

    order = sorted(by, key=lambda k: (rate(by[k].get("balanced", sum(by[k].values(), []))), k))
    out = ["| Fight | Place | Level | " + " | ".join(m.capitalize() for m in modes) + " | Rounds (Balanced) | Downs | Notes |",
           "|---|---|---|" + "---|" * len(modes) + "---|---|---|"]
    for k in order:
        cells = []
        for m in modes:
            rs = by[k].get(m, [])
            if not rs:
                cells.append("")
                continue
            won = sum(1 for r in rs if r.get("outcome") == "victory")
            cells.append(f"{won}/{len(rs)}")
        bal = by[k].get("balanced", [])
        rounds = sum(r.get("rounds", 0) for r in bal) / max(1, len(bal))
        downs = sum(r.get("downs", 0) for r in bal) / max(1, len(bal))
        notes = set()
        for rs in by[k].values():
            for r in rs:
                o = r.get("outcome", "")
                if o not in ("victory", "defeat"):
                    notes.add(o)
                if r.get("deaths", 0):
                    notes.add("deaths")
        version = f" (v{k[2] + 1})" if k[2] else ""
        out.append(f"| {k[1]}{version} | {k[0]} | {meta[k]['level']} | " + " | ".join(cells) +
                   f" | {rounds:.1f} | {downs:.1f} | {', '.join(sorted(notes))} |")
    return out


def cmd_report(a: argparse.Namespace) -> int:
    lines = ["# Crooked Moon headless QA report", ""]
    stories = sorted(f for f in os.listdir(a.out) if f.startswith("story-") and f.endswith(".json"))
    if stories:
        lines += ["## Story bot", ""]
        for s in stories:
            r = json.load(open(os.path.join(a.out, s)))
            lines.append(f"### {s[:-5]}: {r['end']} after {r['steps']} steps, at {r['location']} (level {r['level']})")
            lines.append("")
            lines.append(f"Main quests ended: {', '.join(r['main_ended']) or 'none'}. Places visited {r['visited']} of "
                         f"{r['locations']}; {r['talked']} people talked to; {r['dialogue_nodes_seen']} conversation nodes "
                         f"reached; {len(r['fights'])} fights.")
            lines.append("")
            lines.append("| Step | Main quest | Stage | Place | Level |")
            lines.append("|---|---|---|---|---|")
            for t in r["timeline"]:
                lines.append(f"| {t['step']} | {t['quest']} | {t['stage']} | {t['location']} | {t['level']} |")
            lines.append("")
            if r["problems"]:
                lines.append("Problems:")
                lines.append("")
                for p in r["problems"]:
                    lines.append(f"- **{p['kind']}** at `{p['where']}` (step {p['step']}): {p['detail']}")
                lines.append("")
    fp = os.path.join(a.out, "fights.jsonl")
    if os.path.exists(fp):
        rows = [json.loads(l) for l in open(fp) if l.strip()]
        lines += ["## Fight series", "",
                  "Wins out of fights played, per difficulty, the companions on the engine's PartyAutopilot (bosses at full "
                  "ability, the rest sharp). Lowest Balanced win rate first.", ""]
        lines += _table(rows)
        lines.append("")
    path = os.path.join(a.out, "report.md")
    open(path, "w").write("\n".join(lines) + "\n")
    print(path)
    return 0


def main() -> int:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("story", "fights", "report", "act1", "perf"):
        s = sub.add_parser(name)
        s.add_argument("--out", default=os.path.join(ROOT, "captures", "qa"))
        s.add_argument("--timeout", type=int, default=3600)
        if name == "story":
            s.add_argument("--dice", default="high", choices=["high", "seeded"])
            s.add_argument("--seeds", default="1")
            s.add_argument("--steps", type=int, default=6000)
            s.add_argument("--trace", action="store_true")
            s.add_argument("--order", default="", help="Act II chapters in order, e.g. r13,r14,r15,r16,r17")
        if name == "act1":
            s.add_argument("--seeds", default="1")
            s.add_argument("--mode", default="balanced")
            s.add_argument("--book-order", dest="book_order", action="store_true", default=True)
            s.add_argument("--shuffled", dest="book_order", action="store_false")
            s.add_argument("--checkpoint", default="", help="save the game as the Express ends: /abs/dir/slot")
            s.add_argument("--resume", default="", help="start from that save instead of the title: /abs/dir/slot")
            s.add_argument("--revive", action="store_true", help="bring a fallen hero back between steps (a stand-in; noted in the report)")
        if name == "fights":
            s.add_argument("--seeds", default="1-8")
            s.add_argument("--modes", default=",".join(MODES))
            s.add_argument("--only", default="")
            s.add_argument("--regions", default="")
            s.add_argument("--jobs", type=int, default=2)
            s.add_argument("--play", default="auto", choices=["auto", "plain", "sharp", "full"])
            s.add_argument("--levels", default="")
            s.add_argument("--rounds", type=int, default=30)
        if name == "perf":
            s.add_argument("--regions", default="")
            s.add_argument("--only", default="")
            s.add_argument("--frames", type=int, default=180)
    a = p.parse_args()
    a.out = os.path.abspath(a.out)
    return {"story": cmd_story, "fights": cmd_fights, "report": cmd_report, "act1": cmd_act1, "perf": cmd_perf}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
