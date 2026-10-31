"""The dialogue linter (tools/data/dialogue_lint.py) knows the engine's statements that heal, shield, bless, cheer and pay each
hero (docs/reference/contracts/dialogue.md), and still refuses a malformed one. No Godot.
Run with: make tools-test"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/data"))
import dialogue_lint  # noqa: E402


def errors_of(*statements):
    body = "~ start\nNarrator: Something happens.\n" + "\n".join(statements) + "\n"
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


if __name__ == "__main__":
    unittest.main()
