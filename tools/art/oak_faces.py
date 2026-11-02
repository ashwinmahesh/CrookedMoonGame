#!/usr/bin/env /usr/bin/python3
"""Cuts the painted bark faces (<asset root>/oak/face_<n>.png, each on plain black, from tools/art/specs/oak_faces.json) into the
decal pictures of the Oak of Many Faces (art/props/oak_faces/face_<n>.png, 512 x 512): the black becomes alpha (a soft ramp
over the darkest values), the face is cropped and centred in a square. PIL only.
  /usr/bin/python3 tools/art/oak_faces.py [--photo]     --photo: the photoreal faces (tools/art/photoreal_fetch.py names them first)"""
import glob
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = Path("/Volumes/ASH-SSD/CrookedMoon/assets/oak_photo" if "--photo" in __import__("sys").argv else "/Volumes/ASH-SSD/CrookedMoon/assets/oak")
OUT = ROOT / "art/props/oak_faces"
OUT.mkdir(parents=True, exist_ok=True)
for f in sorted(glob.glob(str(SRC / "face_*.png"))):
    im = Image.open(f).convert("RGB")
    lum = im.convert("L")
    alpha = lum.point(lambda v: 0 if v < 14 else (255 if v > 46 else int((v - 14) * 255 / 32))).filter(ImageFilter.GaussianBlur(1.2))
    box = alpha.point(lambda v: 255 if v > 60 else 0).getbbox()
    if box is None:
        print("empty", f)
        continue
    side = max(box[2] - box[0], box[3] - box[1])
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    sq = (cx - side // 2 - 8, cy - side // 2 - 8, cx - side // 2 + side + 8, cy - side // 2 + side + 8)
    out = im.copy()
    out.putalpha(alpha)
    out = out.crop(sq).resize((512, 512), Image.LANCZOS)
    name = OUT / Path(f).name
    out.save(name)
    print(name)
