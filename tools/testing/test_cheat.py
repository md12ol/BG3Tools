"""Offline tests of cheat.py (no game): every command builds Lua that compiles, and the arguments land in it.

    python tools/testing/test_cheat.py        (needs pip install lupa)
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cheat  # noqa: E402

try:
    import lupa
except ImportError:
    lupa = None

CASES = [
    ["pos"], ["tp", "1", "2.5", "-3"], ["tpto", "S_Obj_00000000-0000-0000-0000-000000000001"],
    ["spawn", "00000000-0000-0000-0000-000000000002", "3"], ["flag", "set", "SOME_FLAG"], ["flag", "get", "F"],
    ["flag", "clear", "F"], ["party", "add", "00000000-0000-0000-0000-000000000003"],
    ["boost", "add", "Ability(Strength,2)"], ["boost", "remove", "AC(1)"], ["respec", "STR=17", "dex=14"],
    ["respec", "--reset"], ["status", "BLESS"], ["status", "HASTE", "3"], ["--who", "abc", "pos"],
]


class Cheat(unittest.TestCase):
    def code(self, argv):
        return cheat.build(cheat.parser().parse_args(argv))

    @unittest.skipIf(lupa is None, "pip install lupa")
    def test_every_command_compiles(self):
        rt = lupa.LuaRuntime()
        for argv in CASES:
            src = self.code(argv)
            ok = rt.eval("function(s) local f, e = load(s); return f ~= nil, e end")(src)
            self.assertTrue(ok[0], "%s: %s\n%s" % (argv, ok[1], src))

    def test_arguments_reach_the_lua(self):
        self.assertIn("TeleportToPosition(who, 1.0, 2.5, -3.0", self.code(["tp", "1", "2.5", "-3"]))
        self.assertIn("TemplateAddTo([==[T]==], who, 3, 1)", self.code(["spawn", "T", "3"]))
        self.assertIn("Osi.GetHostCharacter()", self.code(["pos"]))
        self.assertIn("[==[abc]==]", self.code(["--who", "abc", "pos"]))
        self.assertIn("{[==[Strength]==], 17}", self.code(["respec", "STR=17"]))
        self.assertIn("RemoveBoosts(who, '', 0, [==[TestRespec]==]", self.code(["respec", "--reset"]))
        self.assertIn("18.0", self.code(["status", "HASTE", "3"]))

    def test_bad_respec_is_refused(self):
        with self.assertRaises(SystemExit):
            self.code(["respec", "LUCK=3"])

    def test_dry_run_sends_nothing(self):
        old = cheat.SE_DIR
        cheat.SE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "no-such-folder")
        try:
            self.assertEqual(cheat.main(["--dry-run", "tp", "0", "0", "0"]), 0)
            self.assertFalse(os.path.exists(cheat.SE_DIR))
        finally:
            cheat.SE_DIR = old


if __name__ == "__main__":
    unittest.main()
