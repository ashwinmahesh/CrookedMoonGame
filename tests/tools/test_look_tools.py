"""The look lane's image tools (tools/art): the white-ground cut-out of the vistas, the moon's disc with alpha and the night
grade of the travel map. They need PIL (macOS /usr/bin/python3 has it); without it the tests skip."""
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/art"))
try:
    from PIL import Image, ImageDraw
    import build_vistas
    import look_finish
except ImportError:   # no PIL
    Image = None


@unittest.skipIf(Image is None, "PIL is not installed")
class LookTools(unittest.TestCase):
    def test_the_vista_cut_takes_the_white_ground_out_and_keeps_the_subject(self):
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "v.png"
            im = Image.new("RGB", (100, 150), (255, 255, 255))
            ImageDraw.Draw(im).rectangle([30, 40, 70, 140], fill=(20, 18, 30))
            im.save(src)
            out = build_vistas.cut(src, 75)
        self.assertEqual(out.size, (50, 75))
        self.assertEqual(out.getpixel((2, 2))[3], 0, "the white ground is clear")
        self.assertEqual(out.getpixel((25, 55))[3], 255, "the dark subject is solid")

    def test_the_moon_becomes_a_disc_with_alpha_on_the_square(self):
        with tempfile.TemporaryDirectory() as d:
            src, dst = Path(d) / "m.png", Path(d) / "out.png"
            im = Image.new("RGB", (400, 400), (0, 0, 0))
            ImageDraw.Draw(im).ellipse([60, 80, 340, 360], fill=(220, 215, 200))
            im.save(src)
            look_finish.moon(src, dst, size=256)
            out = Image.open(dst)
        self.assertEqual(out.size, (256, 256))
        self.assertEqual(out.mode, "RGBA")
        self.assertEqual(out.getpixel((128, 128))[3], 255, "the middle is the moon")
        self.assertEqual(out.getpixel((2, 2))[3], 0, "the corner is clear")

    def test_the_night_grade_darkens_a_daytime_painting_but_keeps_a_lit_window(self):
        im = Image.new("RGB", (200, 200), (90, 110, 60))
        ImageDraw.Draw(im).rectangle([90, 90, 110, 110], fill=(255, 220, 110))
        out = look_finish.night(im)
        grass = out.getpixel((100, 30))
        window = out.getpixel((100, 100))
        self.assertLess(sum(grass), 150, "the grass is dark")
        self.assertGreater(window[0], 180, "the window still glows")


if __name__ == "__main__":
    unittest.main()
