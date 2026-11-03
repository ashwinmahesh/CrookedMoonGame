"""The voice wiring tool (tools/content/wire_voice.py) copies a finished take into audio/voice/<speaker>/<key>.mp3 only while its line is
still spoken, leaves unfinished and edited-away takes out, counts the gaps, prunes a clip no line speaks, and wires a {name} line once per
roster hero and a custom hero's Player line once per creator voice. No Godot.
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

    def test_a_re_recorded_take_wins_over_the_old_one_and_replaces_a_wired_clip(self):
        k = f"narrator/{key(SPOKEN)}"
        wire_voice.wire(self.repo, self.root)
        old_clip = (self.repo / f"audio/voice/{k}.mp3").read_bytes()
        newer = self.root / "voice/act1-full"
        (newer / "narrator").mkdir(parents=True)
        (newer / f"{k}.mp3").write_bytes(b"ID3 re-recorded")
        (newer / "jobs.json").write_text(json.dumps({k: {"speaker": "narrator", "key": key(SPOKEN), "text": SPOKEN, "state": "ok"}}))
        r = wire_voice.wire(self.repo, self.root)
        self.assertEqual((self.repo / f"audio/voice/{k}.mp3").read_bytes(), b"ID3 re-recorded", "the -full take is the clip now")
        self.assertNotEqual(old_clip, b"ID3 re-recorded")
        self.assertEqual(r["counts"]["older takes replaced by the re-recorded ones"], 1)
        self.assertEqual(wire_voice.wire(self.repo, self.root)["counts"]["already wired"], 1, "and it stays wired on the next run")
        # a -fill batch and narrator-gaps count as re-recorded too; a plain batch does not
        order = [wire_voice._batch_order(Path(f"x/{n}/jobs.json")) for n in ("act1", "act1-full", "act1-fill", "narrator-gaps", "banter")]
        self.assertEqual([o[0] for o in order], [1, 0, 0, 0, 1])

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


class VariantTest(unittest.TestCase):
    def test_name_lines_per_roster_hero_and_player_lines_per_creator_voice(self):
        with tempfile.TemporaryDirectory() as d:
            repo, root = Path(d) / "repo", Path(d) / "assets"
            (repo / "narrative/train").mkdir(parents=True)
            (repo / "narrative/train/car.dialogue").write_text("~ start\nNarrator: {name} checks the lettering.\nPlayer: I remember this song.\n")
            (repo / "data/pregens").mkdir(parents=True)
            (repo / "data/pregens/rook.json").write_text(json.dumps({"name": "Rook Coldwake", "roster": True}))
            (repo / "data/pregens/old.json").write_text(json.dumps({"name": "Godrick Pendlebrook", "roster": False}))
            batch = root / "voice/act1names"
            jobs = {}
            for sp, text in (("narrator", "Rook checks the lettering."), ("hero_male", "I remember this song."), ("narrator", "Godrick checks the lettering.")):
                k = f"{sp}/{key(text)}"
                jobs[k] = {"speaker": sp, "key": key(text), "text": text, "state": "ok"}
                (batch / sp).mkdir(parents=True, exist_ok=True)
                (batch / f"{k}.mp3").write_bytes(b"ID3" + text.encode())
            (batch / "jobs.json").write_text(json.dumps(jobs))
            r = wire_voice.wire(repo, root)
            self.assertEqual(r["counts"]["name and Player variants wired now"], 2)
            self.assertEqual(r["counts"]["takes whose line was edited or removed"], 1, "only roster heroes get a name take")
            self.assertTrue((repo / f"audio/voice/hero_male/{key('I remember this song.')}.mp3").exists())
            self.assertEqual(r["orphans"], [])


if __name__ == "__main__":
    unittest.main()
