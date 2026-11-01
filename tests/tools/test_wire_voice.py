"""The voice wiring tool (tools/content/wire_voice.py) copies a finished take into audio/voice/<speaker>/<key>.mp3 only while its line is
still spoken, leaves unfinished and edited-away takes out, counts the gaps, and prunes a clip no line speaks. No Godot.
Run with: make tools-test"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/content"))
import wire_voice  # noqa: E402
from act1_voice_keys import key  # noqa: E402

SPOKEN = "The lamps gutter as the train leans into the bend."
EDITED = "This line was cut from the scene."
UNVOICED = "Nobody has read this one yet."
NAMED = "Well met, {name}."


class WireVoiceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.repo, self.root = base / "repo", base / "assets"
        (self.repo / "narrative/train").mkdir(parents=True)
        (self.repo / "narrative/train/car.dialogue").write_text(
            "~ start\nNarrator: %s\nconductor: %s\nconductor: %s\n" % (SPOKEN, UNVOICED, NAMED))
        batch = self.root / "voice/act1"
        jobs = {}
        for sp, text, state in (("narrator", SPOKEN, "ok"), ("narrator", EDITED, "ok"), ("conductor", UNVOICED, "failed")):
            k = f"{sp}/{key(text)}"
            jobs[k] = {"speaker": sp, "key": key(text), "text": text, "state": state}
            (batch / sp).mkdir(parents=True, exist_ok=True)
            (batch / f"{k}.mp3").write_bytes(b"ID3" + text.encode())
        (batch / "jobs.json").write_text(json.dumps(jobs))

    def tearDown(self):
        self.tmp.cleanup()

    def test_only_spoken_finished_takes_are_wired(self):
        r = wire_voice.wire(self.repo, self.root)
        wired = sorted(str(p.relative_to(self.repo / "audio/voice")) for p in (self.repo / "audio/voice").rglob("*.mp3"))
        self.assertEqual(wired, [f"narrator/{key(SPOKEN)}.mp3"])
        self.assertEqual(r["counts"]["wired now"], 1)
        self.assertEqual(r["counts"]["takes whose line was edited or removed"], 1)
        self.assertEqual(r["counts"]["takes not finished"], 1)
        self.assertEqual((r["have"]["train"], r["total"]["train"]), (1, 2), "the {name} line is never counted")
        self.assertEqual(wire_voice.wire(self.repo, self.root)["counts"]["already wired"], 1)

    def test_a_dry_run_copies_nothing(self):
        r = wire_voice.wire(self.repo, self.root, dry_run=True)
        self.assertFalse((self.repo / "audio/voice").exists())
        self.assertEqual(r["have"]["train"], 1)

    def test_a_clip_no_line_speaks_is_reported_then_pruned(self):
        wire_voice.wire(self.repo, self.root)
        stray = self.repo / "audio/voice/narrator/0000000000000000.mp3"
        stray.write_bytes(b"ID3")
        self.assertEqual(wire_voice.wire(self.repo, self.root)["orphans"], ["narrator/0000000000000000"])
        self.assertEqual(wire_voice.wire(self.repo, self.root, prune=True)["orphans"], [])
        self.assertFalse(stray.exists())


if __name__ == "__main__":
    unittest.main()
