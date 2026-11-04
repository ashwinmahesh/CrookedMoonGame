#!/usr/bin/env /usr/bin/python3
"""Fun pass, lane D: tightening Wickermoor's dialogue (narrative/wickermoor/*.dialogue) through Gemini.

    trim.py briefs     numbers every spoken line (Narrator, NPC and interject lines; options are left alone) and writes
                       sent_NN.txt briefs of about 12,000 characters (the bridge takes 16,000 at most), with lines.json
                       mapping each number to its file, line and text
    trim.py apply      reads reply_NN.json, checks each answer (KEEP, CUT or new text) and rewrites the files: a CUT is
                       taken only where the node keeps another spoken line; writes edited.json (old and new text of every
                       changed line, for the voice queue: a clip is keyed by its text, so an edited line is silent until
                       read again) and prints the word counts before and after
"""
import json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SRC = ROOT / "narrative/wickermoor"
SPOKEN = re.compile(r"^(\s*)((?:interject [^:]+)|[A-Za-z_]+)(\s*\[[^\]]*\])?: (.+)$")
LIMIT = 12000


def spoken_lines():
    out = []
    for f in sorted(SRC.glob("*.dialogue")):
        node = ""
        for i, raw in enumerate(f.read_text().splitlines()):
            s = raw.strip()
            if s.startswith("~"):
                node = s[1:].strip()
                continue
            if s.startswith(("*", "#", "->")) or not s:
                continue
            m = SPOKEN.match(raw)
            if m and not m.group(4).startswith("[") and m.group(2) not in ("if", "elif", "set", "approve", "inspire", "disadvantage", "advantage"):
                out.append({"file": f.name, "line": i, "node": node, "speaker": m.group(2), "text": m.group(4)})
    return out


def briefs():
    pre = (HERE / "preamble.txt").read_text()
    rows = spoken_lines()
    for n, r in enumerate(rows, 1):
        r["n"] = n
    (HERE / "lines.json").write_text(json.dumps(rows, indent=1))
    chunks, cur, size, last = [], [], 0, None
    for r in rows:
        head = f"\n### {r['file']}\n" if r["file"] != last else ""
        row = f"{head}{r['n']}. [{r['node']}] {r['speaker']}: {r['text']}\n"
        if size + len(row) > LIMIT - len(pre) and cur:
            chunks.append(cur); cur, size = [], 0
            row = f"\n### {r['file']}\n{r['n']}. [{r['node']}] {r['speaker']}: {r['text']}\n"
        cur.append(row); size += len(row); last = r["file"]
    if cur:
        chunks.append(cur)
    for k, c in enumerate(chunks, 1):
        nums = [int(re.search(r"^(\d+)\.", x.strip().splitlines()[-1]).group(1)) for x in c]
        body = pre + "\n## The lines\n" + "".join(c) + (
            f"\n## Reply format\nOne line per numbered line above ({len(c)} lines, {nums[0]} to {nums[-1]}), in order, exactly "
            "`n => text`, `n => KEEP` or `n => CUT`. No quotes around the text, no commentary.\n")
        (HERE / f"sent_{k:02d}.txt").write_text(body)
        print(f"sent_{k:02d}.txt {len(body)} chars, lines {nums[0]}-{nums[-1]}")


def words(t):
    return len(t.split())


def apply():
    rows = {r["n"]: r for r in json.loads((HERE / "lines.json").read_text())}
    answers = {}
    for p in sorted(HERE.glob("reply_*.json")):
        for row in str(json.loads(p.read_text()).get("result") or "").splitlines():
            m = re.match(r"^\s*(\d+)\s*=>\s*(.*)$", row)
            if m:
                answers[int(m.group(1))] = m.group(2).strip()
    by_file = {}
    for n, r in rows.items():
        by_file.setdefault(r["file"], []).append(r)
    edited, before, after = [], 0, 0
    for fname, rs in by_file.items():
        path = SRC / fname
        lines = path.read_text().splitlines()
        # Find each line again by its text (the file may have moved on since the briefs were numbered): the match
        # nearest its old line number wins.
        for r in rs:
            hits = [i for i, l in enumerate(lines) if (m := SPOKEN.match(l)) and m.group(4) == r["text"]]
            r["line"] = min(hits, key=lambda i: abs(i - r["line"])) if hits else -1
        rs = [r for r in rs if r["line"] >= 0]
        # A node keeps at least one spoken line: CUTs past that are dropped, last first.
        spoken_in = {}
        for r in rs:
            spoken_in.setdefault(r["node"], []).append(r["n"])
        drop = set()
        for r in rs:
            before += words(r["text"])
            a = answers.get(r["n"], "KEEP")
            if a == "CUT":
                left = [x for x in spoken_in[r["node"]] if x not in drop and x != r["n"]]
                if left and not r["speaker"].startswith("interject"):
                    drop.add(r["n"])
                    edited.append({"file": fname, "node": r["node"], "speaker": r["speaker"], "old": r["text"], "new": None})
                    continue
                a = "KEEP"
            if a == "KEEP" or a == r["text"] or not a:
                after += words(r["text"])
                continue
            m = SPOKEN.match(lines[r["line"]])
            lines[r["line"]] = f"{m.group(1)}{m.group(2)}{m.group(3) or ''}: {a}"
            after += words(a)
            edited.append({"file": fname, "node": r["node"], "speaker": r["speaker"], "old": r["text"], "new": a})
        for r in sorted((rows[n] for n in drop), key=lambda r: -r["line"]):
            del lines[r["line"]]
        path.write_text("\n".join(lines) + "\n")
    (HERE / "edited.json").write_text(json.dumps(edited, indent=1))
    print(f"{len(edited)} lines edited or cut; spoken words {before} -> {after}")


if __name__ == "__main__":
    {"briefs": briefs, "apply": apply}[sys.argv[1]]()
