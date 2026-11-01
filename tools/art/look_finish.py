#!/usr/bin/env /usr/bin/python3
"""Fits finished look-P pictures to the files the game loads (PIL only, macOS /usr/bin/python3). Originals stay under the asset root.

  look_finish.py title <picture.png>             art/ui/title_backdrop.png: centre-cropped and scaled to the placeholder's size (1376 x 768)
  look_finish.py icon <picture.png>              art/ui/app_icon.png at 1024 x 1024
  look_finish.py moon <picture.png> <out.png>    the moon on black as a disc with alpha for the sky (Look painted `moon_face`: the
                                                 square's edge is the moon's edge), at 1024 x 1024
  look_finish.py map <picture.png>               art/ui/map/wickermoor_hollow.png at 2528 x 1696 (the painting is made at 2048 x 1408)
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]


def cover(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scaled to cover `size`, then centre-cropped."""
    w, h = im.size
    k = max(size[0] / w, size[1] / h)
    im = im.resize((max(size[0], round(w * k)), max(size[1], round(h * k))), Image.LANCZOS)
    x, y = (im.width - size[0]) // 2, (im.height - size[1]) // 2
    return im.crop((x, y, x + size[0], y + size[1]))


def moon(src: Path, out: Path, size: int = 1024) -> None:
    im = Image.open(src).convert("RGB")
    lum = im.convert("L").point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MedianFilter(5))
    box = lum.getbbox()
    if box is None:
        raise SystemExit("no moon found in the picture")
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    r = max(box[2] - box[0], box[3] - box[1]) / 2
    side = int(r * 2 * 1.04)
    crop = im.crop((round(cx - side / 2), round(cy - side / 2), round(cx - side / 2) + side, round(cy - side / 2) + side))
    crop = crop.resize((size, size), Image.LANCZOS)
    k = size / side
    rr = r * k
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse([(size / 2 - rr * 0.985) * 4, (size / 2 - rr * 0.985) * 4,
                                  (size / 2 + rr * 0.985) * 4, (size / 2 + rr * 0.985) * 4], fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    crop.putalpha(mask)
    out.parent.mkdir(parents=True, exist_ok=True)
    crop.save(out)
    print(out, crop.size, f"disc radius {rr:.0f}px")


def main(a: list[str]) -> None:
    if len(a) < 2:
        raise SystemExit(__doc__)
    cmd, src = a[0], Path(a[1])
    if cmd == "title":
        out = ROOT / "art/ui/title_backdrop.png"
        cover(Image.open(src).convert("RGB"), (1376, 768)).save(out)
    elif cmd == "icon":
        out = ROOT / "art/ui/app_icon.png"
        cover(Image.open(src).convert("RGB"), (1024, 1024)).save(out)
    elif cmd == "map":
        out = ROOT / "art/ui/map/wickermoor_hollow.png"
        Image.open(src).convert("RGB").resize((2528, 1696), Image.LANCZOS).save(out)
    elif cmd == "moon":
        out = Path(a[2])
        moon(src, out)
        return
    else:
        raise SystemExit(__doc__)
    print(out, Image.open(out).size)


if __name__ == "__main__":
    main(sys.argv[1:])
