#!/usr/bin/env python3
"""Builds the palette files from the single list below (plan section 4.1). The Giallo look Ashwin locked (2026-10-30, Look Options/Models on P): inky navy-indigo nights under a cold pale moonlight, the crone moon's sea-green disc, deep orange lanterns, oxblood and timber pink; the other names keep the old game's colours until the look lane finishes the list (docs/PLACEHOLDERS.md).

Writes art/palette/palette.gpl (GIMP/Aseprite/Krita), palette.json (tools), and
palette.png (an N x 1 strip the palette post-process shader samples). Stdlib only.
"""
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "palette"

# name, hex. Near-black instead of pure black; ramps run dark to light.
PALETTE = [
    ("void", "07080d"), ("ink", "0d1017"), ("grave", "171c26"), ("ash_violet", "3a2a44"),
    ("blood_deep", "35120f"), ("blood", "5a1d18"), ("crimson", "a3192d"), ("vampire_red", "d6283a"), ("rose", "a85a5c"),
    ("bruise_deep", "2b1438"), ("bruise", "4a2160"), ("plum", "6d3486"), ("orchid", "9a5bb0"), ("lilac", "c495cf"),
    ("night_deep", "0d1226"), ("night", "18213f"), ("moon_blue", "2b3866"), ("mist_blue", "4a5a86"), ("moonlight", "a9bfd0"), ("frost", "d4e2ea"),
    ("bone_dark", "5b4c3e"), ("bone", "8e7a62"), ("parchment", "c7b18a"), ("vellum", "e6d6b0"), ("ivory", "f4ecd6"),
    ("bog_deep", "0f1f1d"), ("bog", "1d3a35"), ("moss", "3e6a3a"), ("sickly", "6f9a3e"), ("bile", "a9c450"),
    ("ember_deep", "4a1e0c"), ("ember", "8a3a12"), ("candle", "d4561a"), ("flame", "f07a22"), ("wick", "ffb347"),
    ("stone_deep", "22222a"), ("stone", "3b3b45"), ("slate", "5c5c69"), ("pewter", "8a8a96"), ("silver", "bdbdc6"),
    ("peat", "2b1f1a"), ("umber", "4d382a"), ("walnut", "664a35"),
    ("rust", "6b3a26"), ("leather", "8c5a3a"), ("tan", "b88a5e"),
    ("skin_shadow", "7a4a3c"), ("skin", "c48a6a"), ("skin_light", "e6b896"),
    # The crone moon's sea-green disc (a mood's moon_colour), apart from the cold light it casts.
    ("moon_green", "9fe0b8"),
]

# Menus and overlays only: Witchlight (Ashwin, 2026-10-31: option B of three HUD palettes, "It shouldn't be the same maroon
# as curse of Strahd"): charcoal-plum panels, violet trim, toxic witch-green highlights, ivory text. The keys keep the old
# game's names (the engine's Look reads them), so gilt_* is the violet trim and arch_gold* the green. Written to
# ui_palette.json, never to the strip or the .gpl, so the world's palette pass and the sprite pipeline don't change.
UI_PALETTE = [
    ("ui_black", "0d0a13"), ("ui_oxblood", "1a1424"), ("ui_wine", "2b1f3a"),
    ("gilt_dark", "5e3a73"), ("gilt", "9a5bb0"), ("gilt_light", "c9a6d6"),
    # The pause menu and settings pages (docs/ui/look.md), in the same colours.
    ("arch_back", "0d0a13"), ("arch_top", "2b1f3a"), ("arch_bottom", "120d1a"), ("arch_button", "1f1729"),
    ("arch_button_lit", "3a2a52"), ("arch_track", "0f0b15"), ("arch_gold", "8fd14f"), ("arch_gold_light", "b8e986"),
    ("arch_text", "f1ece0"),
    # The End Turn and finishing buttons, a pressed hotbar slot and the radial pick (the engine's Look.ui_key): a deep
    # witch-green instead of the old game's blood red, light enough under ivory text.
    ("ui_primary", "3f7a2a"), ("ui_primary_lit", "5a9e36"), ("ui_primary_deep", "284d1b"),
    # The big d20 (docs/ui/d20_roll.md): an emerald, from its shadowed facets to the glint on its edges (owner,
    # 2026-10-09: "I want the dice to be an emerald green color").
    ("emerald_deep", "03251a"), ("emerald", "0b6a42"), ("emerald_bright", "1fa86a"), ("emerald_light", "62e3a6"),
    ("emerald_glint", "d2fbe6"),
]


def png_strip(colors, path):
    # one row: filter byte then RGB triples
    row = b"\x00" + b"".join(bytes.fromhex(c) for c in colors)
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", len(colors), 1, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(row)) + chunk(b"IEND", b""))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["GIMP Palette", "Name: The Crooked Moon (placeholder)", "Columns: 8", "#"]
    for name, h in PALETTE:
        r, g, b = bytes.fromhex(h)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (OUT / "palette.gpl").write_text("\n".join(lines) + "\n")
    (OUT / "palette.json").write_text(json.dumps({n: "#" + h for n, h in PALETTE}, indent=2) + "\n")
    png_strip([h for _, h in PALETTE], OUT / "palette.png")
    (OUT / "ui_palette.json").write_text(json.dumps({n: "#" + h for n, h in UI_PALETTE}, indent=2) + "\n")
    print(f"{len(PALETTE)} colours (+{len(UI_PALETTE)} for the UI) written to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
