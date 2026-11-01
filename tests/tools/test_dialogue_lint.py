"""The dialogue linter (tools/data/dialogue_lint.py) knows the engine's statements that heal, hurt, shield, bless, cheer, pay and
rest each hero, tilt a check and gate a gory line (docs/reference/contracts/dialogue.md), and still refuses a malformed one. No Godot.
Run with: make tools-test"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/data"))
import dialogue_lint  # noqa: E402


def errors_of(*statements):
    body = "~ start\nNarrator: Something happens.\n" + "\n".join(statements) + "\n~ ok\nNarrator: Fine.\n~ bad\nNarrator: Not fine.\n"
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "probe.dialogue"
        p.write_text(body)
        return dialogue_lint.parse_file(str(p))["errors"]


class StatementTest(unittest.TestCase):
    def test_the_new_statements_read(self):
        for line in ["heal 1d6", "heal 2d4+2 party", "heal 1d6 party temp", "heal 5 temp party", "temp_hp 1d6", "temp_hp d8-1 party",
                     "bless", "bless party", "bless 30m", "bless party 2h", "inspiration", "inspiration party", "gold +5 each", "gold -3 each", "gold +25"]:
            self.assertEqual(errors_of(line), [], line)

    def test_malformed_ones_are_refused(self):
        for line in ["heal", "heal lots", "heal 1d6 everyone", "heal 1d6 party party", "temp_hp 1d6 temp", "bless 0m", "bless sometimes",
                     "inspiration 3", "gold each"]:
            self.assertNotEqual(errors_of(line), [], line)

    def test_hurting_resting_and_edge_statements_read(self):
        for line in ["damage 1d6 psychic", "damage 1d4 psychic party", "damage 2d8+1 necrotic party", "damage 3 cold",
                     "hit_dice restore all party", "hit_dice restore 2", "hit_dice grant 1 party", "hit_dice grant 2",
                     "advantage persuasion", "advantage persuasion next", "advantage checks 30m", "disadvantage checks 1h: the fog",
                     "advantage stealth 2h: a quiet dark", "disadvantage strength"]:
            self.assertEqual(errors_of(line), [], line)

    def test_malformed_hurting_resting_and_edge_statements_are_refused(self):
        for line in ["damage", "damage 1d6", "damage psychic", "damage 1d6 psychic everyone", "damage 1d6 psychic party party",
                     "hit_dice", "hit_dice restore", "hit_dice restore lots", "hit_dice grant all", "hit_dice grant 0", "hit_dice give 1",
                     "advantage", "advantage dancing", "advantage persuasion tomorrow", "disadvantage checks 0m"]:
            self.assertNotEqual(errors_of(line), [], line)

    def test_a_check_can_carry_advantage_or_disadvantage(self):
        for line in ["check Insight DC 12 dis -> ok | bad", "check Persuasion DC 15 adv -> ok | bad", "check Insight DC 12 -> ok | bad"]:
            self.assertEqual(errors_of(line), [], line)
        self.assertNotEqual(errors_of("check Insight DC 12 adv dis -> ok | bad"), [])
        self.assertNotEqual(errors_of("check Insight DC 12 maybe -> ok | bad"), [])
        self.assertEqual(errors_of("* [Persuasion DC 15 adv] Plead. -> ok | bad", "* [Performance DC 14 dis] Sing. -> ok | bad"), [])
        self.assertEqual(errors_of("* [if flag.x] [Performance DC 15 adv] Sing. -> ok | bad"), [])

    def test_the_graphic_condition_reads(self):
        self.assertEqual(errors_of("if graphic", "Narrator: Gory.", "else", "Narrator: Tame.", "endif"), [])
        self.assertEqual(errors_of("* [if not graphic] A tame way. -> ok"), [])


if __name__ == "__main__":
    unittest.main()
