#!/usr/bin/env python3
"""Import settings for the photoreal portraits (vault Build/Portrait UI Wiring.md; the engine's PortraitArt).

Usage: /usr/bin/python3 tools/art/portrait_import.py [--check] [--force]

A portrait is drawn 34 to 44 px wide in the turn order and 240 px in the Bestiary, from a 1024 px picture, so Godot's
default import (no mipmaps, lossless) shimmers when it shrinks them and holds 4 MB of video memory a picture. Every file
in art/portraits/monsters and art/portraits/characters gets a `.import` beside it that asks for VRAM compression at high
quality and mipmaps; a file with one already is left alone (--force writes it again). Run it after adding pictures, then
`make import` (Godot fills in the uid and the cache path) and `git add -f` the .import files (*.import is ignored).
--check only lists the files that have no sidecar or the wrong settings and exits 1 if there are any.
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRS = [ROOT / "art" / "portraits" / "monsters", ROOT / "art" / "portraits" / "characters"]
EXTS = {".webp", ".png"}

TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://{rel}"

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.9
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def pictures():
    for d in DIRS:
        if d.is_dir():
            for p in sorted(d.iterdir()):
                if p.suffix.lower() in EXTS:
                    yield p


def right(sidecar: Path) -> bool:
    text = sidecar.read_text()
    return "mipmaps/generate=true" in text and "compress/mode=2" in text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    todo = []
    for p in pictures():
        sidecar = p.with_name(p.name + ".import")
        if args.force or not sidecar.exists() or (args.check and not right(sidecar)):
            todo.append((p, sidecar))
    for p, sidecar in todo:
        if args.check:
            print("needs settings:", p.relative_to(ROOT))
        else:
            old = sidecar.read_text() if sidecar.exists() else ""
            text = TEMPLATE.format(rel=p.relative_to(ROOT).as_posix())
            # Keep the uid and cache path Godot already gave it, so a re-import is a change of settings, not a new picture.
            keep = [l for l in old.splitlines() if l.startswith(("uid=", "path=", "dest_files="))]
            if keep:
                text = text.replace('type="CompressedTexture2D"\n', 'type="CompressedTexture2D"\n' + "\n".join(
                    l for l in keep if l.startswith(("uid=", "path="))) + "\n", 1)
            sidecar.write_text(text)
            print("wrote", sidecar.relative_to(ROOT))
    if not todo:
        print("every portrait has its import settings")
    return 1 if (args.check and todo) else 0


if __name__ == "__main__":
    sys.exit(main())
