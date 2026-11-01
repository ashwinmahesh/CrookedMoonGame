#!/usr/bin/env python3
"""Sends one brief of this folder to Gemini 4 Argon medium through ai-bridge, once, and keeps the raw reply.

    /opt/homebrew/bin/python3 -I send_brief.py <name>        (brief_<name>.txt -> sent_<name>.txt, reply_<name>.json, send_<name>.log)

The same client as ~/.crooked-moon/bridge.py (project ai-bridge, token read from the service's token file and never printed), plus the
bridge's context files: its message body holds at most 16000 characters, so each companion's voice sheet and character file travel as
two attached documents (context_<id>-voice-and-beats.txt and context_<id>-camp-talks.txt here; banter's two cast sheets likewise), written to the
project's context store under tasks/crooked-moon-companions/ (32000 characters a file) and selected on the send. Nothing is resent: a
reply file that exists stops the script.
"""
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = "ai-bridge-885bb429a2"
MODEL = "gemini-4-argon-medium"
CTX_DIR = "tasks/crooked-moon-companions/"

svc = json.load(open(os.path.expanduser("~/Library/Application Support/AI Bridge/service.json")))
TOKEN = open(os.path.expanduser(svc["token_file"])).read().strip()
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
P = f"{svc['url']}/v1/projects/{PROJECT}"


def call(method: str, path: str, body: dict | None = None, timeout: int = 60) -> dict:
    req = urllib.request.Request(P + path, data=None if body is None else json.dumps(body).encode(), method=method)
    req.add_header("Authorization", "Bearer " + TOKEN)
    req.add_header("Content-Type", "application/json")
    try:
        with OPENER.open(req, timeout=timeout) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code} on {method} {path.split('?')[0]}: {e.read()[:300].decode()}")


def ensure_context(path: str, text: str) -> int:
    """Makes the store's copy of `path` equal `text`; returns its version."""
    cur = call("GET", "/context/file?path=" + urllib.parse.quote(path))
    if cur.get("exists") and cur.get("content") == text:
        return int(cur["version"])
    r = call("POST", "/context/file", {"path": path, "content": text, "expected_version": int(cur.get("version", 0)), "writer": "claude"})
    return int(r.get("version", 1))


def attachments(name: str) -> list[str]:
    """The context paths a brief selects, from the brief's own ATTACHED DOCUMENTS paragraph."""
    text = (HERE / f"brief_{name}.txt").read_text(encoding="utf-8")
    out = []
    for part in text.split("`")[1::2]:
        if part.startswith(CTX_DIR) and part not in out:
            out.append(part)
    return out


def main() -> int:
    name = sys.argv[1]
    reply = HERE / f"reply_{name}.json"
    if reply.exists():
        print(f"reply_{name}.json exists: not sending again")
        return 3
    brief = HERE / f"brief_{name}.txt"
    body = brief.read_text(encoding="utf-8")
    if not 1 <= len(body) <= 16000:
        raise SystemExit(f"body is {len(body)} characters; the bridge takes 1-16000")
    paths = attachments(name)
    versions = {}
    for path in paths:
        src = HERE / ("context_" + path.removeprefix(CTX_DIR).replace(".md", ".txt"))
        versions[path] = ensure_context(path, src.read_text(encoding="utf-8"))
    shutil.copyfile(brief, HERE / f"sent_{name}.txt")
    msg = {"sender": "claude", "to": "gemini", "body": body, "model": MODEL, "context_files": paths}
    r = call("POST", "/messages", msg)
    mid, conv = r["id"], r["conversation"]
    print("queued", mid, conv, "attached", json.dumps(versions), flush=True)
    deadline = time.time() + 600
    while time.time() < deadline:
        time.sleep(4)
        rows = call("GET", f"/messages?conversation={conv}")
        rows = rows.get("messages", rows) if isinstance(rows, dict) else rows
        m = next((x for x in rows if x.get("id") == mid), None)
        if m and m.get("state") in ("done", "failed", "cancelled"):
            json.dump(m, open(reply, "w"), indent=1)
            print(m.get("state"), "model", m.get("model"), "effort", m.get("effort"), "result chars", len(str(m.get("result") or "")),
                  "error", (m.get("error") or "")[:300])
            return 0 if m.get("state") == "done" else 1
    print("still waiting after 600 s; not resending. Message", mid, "conversation", conv)
    return 2


if __name__ == "__main__":
    sys.exit(main())
