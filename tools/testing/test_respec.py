"""Offline tests of respec.py (no game): every command builds Lua that compiles, with its arguments in it.

    python tools/testing/test_respec.py        (needs pip install lupa)
"""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import respec  # noqa: E402

try:
    import lupa
except ImportError:
    lupa = None

GALE = "S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604"
CASES = [
    ["open", GALE], ["levelup", GALE], ["history", GALE], ["state"], ["finish"],
    ["class", "Cleric"], ["subclass", "TempestDomain"], ["deity", "Talos"], ["feat", "Great Weapon Master"],
    ["abilities", "STR=8", "DEX=14", "CON=15", "INT=15", "WIS=10", "CHA=8"], ["bonus", "INT", "con"],
    ["skills", "Insight", "Investigation"], ["skills", "Perception", "--race"], ["skills", "Stealth", "--expertise"],
    ["passives", "Defence", "Trip Attack"], ["asi", "WIS=2"], ["asi", "CON=1", "INT=1"],
    ["spells", "Hunter's Mark", "Fireball"],
]


class Respec(unittest.TestCase):
    def code(self, argv):
        return respec.snippet(respec.parser().parse_args(argv))

    @unittest.skipIf(lupa is None, "pip install lupa")
    def test_every_command_compiles(self):
        rt = lupa.LuaRuntime()
        check = rt.eval("function(s) local f, e = load(s); return f ~= nil, e end")
        for argv in CASES:
            side, src = self.code(argv)
            ok = check(src)
            self.assertTrue(ok[0] if isinstance(ok, tuple) else ok, "%s: %s" % (argv, ok))
            self.assertIn(side, ("client", "server"))

    def test_arguments_reach_the_lua(self):
        self.assertIn("ad9af97d-75da-406a-ae13-7071c563f604", self.code(["open", GALE])[1])
        self.assertNotIn("S_Player_Gale", self.code(["open", GALE])[1])
        self.assertIn("Constitution = 15", self.code(["abilities", "STR=8", "DEX=14", "CON=15", "INT=15", "WIS=10",
                                                      "CHA=8"])[1])
        self.assertIn("[==[Intelligence]==], [==[Constitution]==]", self.code(["bonus", "int", "CON"])[1])
        self.assertIn("dc.RaceSkills", self.code(["skills", "Perception", "--race"])[1])
        self.assertIn("ExpertiseSkills", self.code(["skills", "Stealth", "--expertise"])[1])
        self.assertIn("SelectableMultiClasses", self.code(["class", "Rogue"])[1])
        self.assertIn("Wisdom = 2", self.code(["asi", "WIS=2"])[1])
        self.assertIn("[==[Hunter's Mark]==]", self.code(["spells", "Hunter's Mark"])[1])

    def test_bad_scores_are_refused(self):
        for argv in (["abilities", "STR=7", "DEX=14", "CON=15", "INT=15", "WIS=10", "CHA=8"], ["asi", "WIS=3"],
                     ["asi", "LUCK=1"], ["abilities", "STR=15", "DEX=15", "CON=15", "INT=10", "WIS=8", "CHA=8"],
                     ["abilities", "STR=8", "STR=8", "CON=15", "INT=15", "WIS=10", "CHA=8"], ["open", "Gale"]):
            with self.assertRaises(SystemExit):
                self.code(argv)

    def setUp(self):
        for p in (mock.patch.object(respec.time, "sleep"), mock.patch.object(respec, "ps"), mock.patch("builtins.print")):
            p.start()
            self.addCleanup(p.stop)

    def test_grid_positions(self):
        clicks = []
        respec.ps.side_effect = lambda script, *args: clicks.append(args[-1])
        respec.click_grid(1)
        respec.click_grid(9)
        x1, y1 = map(int, clicks[0].split(","))
        x9, y9 = map(int, clicks[1].split(","))
        self.assertEqual(x1, x9)
        self.assertGreater(y9, y1)

    def test_spell_clicks_go_last_first_and_skip_picked(self):
        clicked = []
        a = respec.parser().parse_args(["spells", "Fireball", "Haste", "Shield", "--click"])
        reply = "\n".join(["=> Fireball=2", "Haste=11", "Shield=5*"])
        with mock.patch.object(respec, "ev", return_value=reply), \
                mock.patch.object(respec, "click_grid", lambda pos, y0: clicked.append(pos)):
            self.assertEqual(respec.run(a), 0)
        self.assertEqual(clicked, [11, 2])

    def test_stepping_commands_repeat_until_done(self):
        replies = ["=> lowered: Strength 10->8 (run again to raise)", "=> raised: Dexterity 13->14", "=> DONE"]
        a = respec.parser().parse_args(["abilities", "STR=8", "DEX=14", "CON=15", "INT=15", "WIS=10", "CHA=8"])
        with mock.patch.object(respec, "ev", side_effect=replies):
            self.assertEqual(respec.run(a), 0)
        a = respec.parser().parse_args(["bonus", "INT", "CON"])
        with mock.patch.object(respec, "ev", return_value="=> no +2/+1 choice on this screen"):
            self.assertEqual(respec.run(a), 1)


if __name__ == "__main__":
    unittest.main()
