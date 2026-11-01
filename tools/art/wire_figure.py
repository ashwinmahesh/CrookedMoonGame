#!/usr/bin/env python3
"""Wires a Tripo model into the game as a 3D figure (vault Build/Character Creator and Layered Figures.md).

Two kinds, as Ashwin set them (2026-11-01): a minor NPC or a monster is one model, head and body together; a major
NPC or a lead is a headless body with its own head on the Head bone, the head cut a talking jaw in Blender.

  one model:      python3 tools/art/wire_figure.py <id> --body tripo/models/<x>.glb --height 1.2
  body and head:  python3 tools/art/wire_figure.py <id> --body tripo/models/<x>.glb --height 1.2 \\
                      --head tripo/models/<y>.glb --jaw <mouth z>,<left x>,<right x>,<chin z> [--head-size 1.4]
  then:           python3 tools/art/figures.py <id> [<id>_head]; make import;
                  python3 tools/art/wire_figure.py <id> --close-ups     (VRAM compression and mipmaps for the 4K pictures)

What it writes:
- art/figures/manifest.json: the figure (`file`, `source`, a 4K `close_up` for conversations unless --no-close-up,
  the old art as its stand-in `sprite`); with a head, the `<id>_head` part (Head bone, turned with it, sized by the body: `fit` "head")
  and the body's own head shrunk away (`bones` Head 0.01);
- art/creature_looks.json: its height;
- the stat block or NPC that names it: data/npcs/<id>.json's `sprite`, or data/monsters/<id>.json's `art`, becomes the
  id, so the model shows (the old art stays as the manifest's stand-in);
- with --jaw: runs blender/head_jaw.py on the head into tripo/jaw/<id>_head_jaw.glb (mouth numbers are read by eye off
  the head's front picture, in the head's own units: see head_jaw.py).
A walk-only rig (a beast) wants --walk-only (it idles on its walk). Run tools/art/aim_gear.tscn after wiring a figure
that holds gear. Nothing is removed; running it again updates the same entries.
"""
import argparse
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "art/figures/manifest.json")
LOOKS = os.path.join(ROOT, "art/creature_looks.json")
ASSETS = os.environ.get("CROOKED_MOON_ASSETS", os.path.expanduser("~/Documents/ASH-SSD/CrookedMoon/assets"))
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"


def entry_line(key: str, value: dict) -> str:
    return '    "%s": %s' % (key, json.dumps(value, separators=(", ", ": ")))


def put(text: str, section: str, key: str, value: dict) -> str:
    """`key`'s line in the manifest's `section` set to `value`: replaced where it is, else added as the section's first."""
    line = entry_line(key, value)
    own = re.compile(r'^    "%s": \{.*?\},?$' % re.escape(key), re.M)
    start = text.index('  "%s": {\n' % section)
    end = text.index("\n  }", start)
    found = own.search(text, start, end)
    if found:
        comma = "," if found.group(0).endswith(",") else ""
        return text[:found.start()] + line + comma + text[found.end():]
    at = start + len('  "%s": {\n' % section)
    return text[:at] + line + ",\n" + text[at:]


def name_it(rel: str, field: str, art_id: str) -> str:
    """The data file's `field` set to `art_id`; the art it named before (the stand-in), or "" when it had none."""
    path = os.path.join(ROOT, rel)
    text = open(path).read()
    found = re.search(r'\n  "%s": "([^"]*)"' % field, text)
    if found:
        old = found.group(1)
        if old != art_id:
            text = text[:found.start(1)] + art_id + text[found.end(1):]
            open(path, "w").write(text)
        return old if old != art_id else ""
    return ""


def height(art_id: str, units: float) -> None:
    text = open(LOOKS).read()
    own = re.compile(r'^    "%s": [0-9.]+(,?)$' % re.escape(art_id), re.M)
    found = own.search(text)
    if found:
        text = text[:found.start()] + '    "%s": %s%s' % (art_id, units, found.group(1)) + text[found.end():]
    else:
        at = text.index('  "heights": {\n') + len('  "heights": {\n')
        text = text[:at] + '    "%s": %s,\n' % (art_id, units) + text[at:]
    open(LOOKS, "w").write(text)


def close_ups(art_id: str) -> None:
    """The 4K conversation pictures as Godot should keep them: VRAM compressed, with mipmaps."""
    for name in (art_id, art_id + "_head"):
        imp = os.path.join(ROOT, "art/figures/close_up/%s_4k.jpg.import" % name)
        if not os.path.exists(imp):
            continue
        text = open(imp).read()
        text = re.sub(r"^compress/mode=\d+$", "compress/mode=2", text, flags=re.M)
        text = re.sub(r"^mipmaps/generate=\w+$", "mipmaps/generate=true", text, flags=re.M)
        open(imp, "w").write(text)
        print("set %s: VRAM compressed, mipmaps (make import again)" % os.path.relpath(imp, ROOT))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("id")
    ap.add_argument("--body", help="the model (head and body together, or the headless body), under the asset root")
    ap.add_argument("--height", type=float, help="standing height in world units (a person about 1.2)")
    ap.add_argument("--head", help="the head made apart, under the asset root")
    ap.add_argument("--jaw", help="mouth z, left x, right x, chin z on the head (head_jaw.py)")
    ap.add_argument("--head-size", type=float, default=0.0, help="the head's height over the body's own (a hat: 1.4)")
    ap.add_argument("--walk-only", action="store_true", help="a rig with only a walk clip idles on it")
    ap.add_argument("--no-close-up", action="store_true", help="no 4K picture: a creature that never talks")
    ap.add_argument("--close-ups", action="store_true", help="after make import: set the 4K pictures' import options")
    a = ap.parse_args()
    if a.close_ups:
        close_ups(a.id)
        return
    if not a.body or not a.height:
        ap.error("--body and --height are needed")
    if a.head and not a.jaw:
        ap.error("a head needs --jaw (its mouth, read off its front picture)")

    stand_in = ""
    for rel, field in (("data/npcs/%s.json" % a.id, "sprite"), ("data/monsters/%s.json" % a.id, "art")):
        if os.path.exists(os.path.join(ROOT, rel)):
            stand_in = name_it(rel, field, a.id) or stand_in
            print("%s: %s is %s" % (rel, field, a.id))

    text = open(MANIFEST).read()
    old = re.search(r'^    "%s": (\{.*?\}),?$' % re.escape(a.id), text, re.M)
    fig = json.loads(old.group(1)) if old else {}
    fig.update({"file": "art/figures/%s.glb" % a.id, "source": a.body})
    if not a.no_close_up:
        fig["close_up"] = {"albedo": "art/figures/close_up/%s_4k.jpg" % a.id}
    if stand_in and "sprite" not in fig:
        fig["sprite"] = stand_in
    if a.walk_only:
        fig["idle_from_walk"] = True
    if a.head:
        mouth_z, left_x, right_x, chin_z = (float(v) for v in a.jaw.split(","))
        jaw = "tripo/jaw/%s_head_jaw.glb" % a.id
        subprocess.run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(ROOT, "blender/head_jaw.py"), "--",
                        os.path.join(ASSETS, a.head), os.path.join(ASSETS, jaw), str(mouth_z), str(left_x), str(right_x),
                        str(chin_z)], check=True, stdout=subprocess.DEVNULL)
        part = {"file": "art/figures/heads/%s_head.glb" % a.id,
                "close_up": {"albedo": "art/figures/close_up/%s_head_4k.jpg" % a.id}, "source": jaw,
                "jaw_from": {"head": a.head, "mouth_z": mouth_z, "left_x": left_x, "right_x": right_x, "chin_z": chin_z},
                "bone": "Head", "follow": "turn", "fit": "head"}
        if a.head_size:
            part["size"] = a.head_size
        text = put(text, "parts", a.id + "_head", part)
        fig["layers"] = sorted(set(fig.get("layers", [])) | {a.id + "_head"})
        fig.setdefault("bones", {})["Head"] = 0.01
        print("head %s_head cut a jaw into %s" % (a.id, jaw))
    text = put(text, "figures", a.id, fig)
    json.loads(text)
    open(MANIFEST, "w").write(text)
    height(a.id, a.height)
    after = "; python3 tools/art/wire_figure.py %s --close-ups; make import" % a.id if "close_up" in fig or a.head else ""
    print("wired %s (%s). Next: python3 tools/art/figures.py %s; make import%s" % (a.id, "body and head" if a.head else
                                                                                   "one model", a.id, after))


if __name__ == "__main__":
    sys.exit(main())
