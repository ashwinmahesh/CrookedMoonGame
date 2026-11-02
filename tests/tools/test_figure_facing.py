"""Every 3D figure faces the way it walks (Ashwin, 2026-11-02: the Corrupted Passenger walked backwards). The engine
turns a figure's model toward its heading assuming its front is +z after the manifest's `turn`; a rig made facing
another way walks sideways or backwards. tools/art/rig_facing.py reads the front from the skeleton (its left joints
against its right), and tools/art/figures.py writes the `turn` a new figure needs as it copies it in. Figures whose GLB
isn't pulled (a Git LFS pointer) or has no named left and right joints (the locomotive) are skipped."""
import json
import sys
import unittest

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/art"))
import rig_facing  # noqa: E402


class FigureFacing(unittest.TestCase):
    def test_every_figure_faces_the_way_it_walks(self):
        manifest = json.loads((ROOT / "art/figures/manifest.json").read_text())
        checked = 0
        for fid, (path, turn) in rig_facing.figure_files(manifest).items():
            if not path.exists():
                continue
            front = rig_facing.facing(path)
            if front is None:
                continue
            checked += 1
            with self.subTest(figure=fid):
                z = rig_facing.turned(front, turn)[1]
                self.assertGreater(z, 0.7, f"{fid} faces the wrong way at turn {turn:g}: its skeleton needs "
                                   f'"turn": {rig_facing.turn_needed(front):g} in art/figures/manifest.json')
        if checked == 0:
            self.skipTest("no figure GLBs pulled (git lfs pull)")

    def test_the_turn_arithmetic_matches_the_engine(self):
        # Node3D.rotation.y: +90 degrees takes +x to -z, and +z to +x.
        x, z = rig_facing.turned((1.0, 0.0), 90)
        self.assertAlmostEqual(x, 0.0)
        self.assertAlmostEqual(z, -1.0)
        self.assertEqual(rig_facing.turn_needed((0.0, -1.0)), 180)
        self.assertEqual(rig_facing.turn_needed((1.0, 0.0)), 270)
        self.assertEqual(rig_facing.turn_needed((-1.0, 0.0)), 90)
        self.assertEqual(rig_facing.turn_needed((0.0, 1.0)), 0)


if __name__ == "__main__":
    unittest.main()
