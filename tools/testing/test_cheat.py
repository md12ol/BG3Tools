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
    ["reactions", "list"], ["reactions", "apply"], ["reactions", "apply", "--policy", "never", "--set", "Interrupt_X=auto"],
    ["reactions", "restore"],
]

REACTION_STUB = r"""
local store = { c1 = { Interrupt_A = "InterruptInteractionTypes(Ask,Enabled)", Interrupt_B = "InterruptInteractionTypes(Enabled)" } }
local function prefsFor(u)
  return setmetatable({}, {
    __index = function(_, k) local v = store[u][k]; if type(v) == "table" then
      return "InterruptInteractionTypes(" .. table.concat(v, ",") .. ")" end; return v end,
    __newindex = function(_, k, v) store[u][k] = v end,
    __pairs = function(t) local k; return function() k = next(store[u], k); if k then return k, t[k] end end end })
end
Osi = { DB_Players = { Get = function() return { { "S_Player_X_00000000-0000-0000-0000-0000000000c1" } } end } }
Ext = { Entity = { Get = function(u) if u == "00000000-0000-0000-0000-0000000000c1" then
  return { InterruptPreferences = { Preferences = prefsFor("c1") }, Replicate = function() end } end end } }
function T_state() local P = prefsFor("c1"); return P.Interrupt_A .. " " .. P.Interrupt_B end
"""


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

    def test_reaction_policy_mapping(self):
        self.assertEqual(cheat.reaction_policy(["Interrupt_X=never"]), {"Interrupt_X": "never"})
        for bad in (["Interrupt_X=sometimes"], ["=never"]):
            with self.assertRaises(SystemExit):
                cheat.reaction_policy(bad)
        with self.assertRaises(SystemExit):
            cheat.reaction_policy([], "maybe")
        self.assertEqual(cheat.REACTION_FLAGS["auto"], ["Enabled"])
        self.assertEqual(cheat.REACTION_FLAGS["never"], [])

    @unittest.skipIf(lupa is None, "pip install lupa")
    def test_reactions_saved_applied_restored(self):
        rt = lupa.LuaRuntime()
        rt.execute(REACTION_STUB)
        before = rt.eval("T_state()")
        rt.execute(self.code(["reactions", "apply", "--set", "Interrupt_B=never"]))
        self.assertEqual(rt.eval("T_state()"), "InterruptInteractionTypes(Enabled) InterruptInteractionTypes()")
        rt.execute(self.code(["reactions", "apply", "--policy", "never"]))   # a second apply keeps the first copy
        self.assertEqual(rt.eval("T_state()"), "InterruptInteractionTypes() InterruptInteractionTypes()")
        rt.execute(self.code(["reactions", "restore"]))
        self.assertEqual(rt.eval("T_state()"), before)
        self.assertIsNone(rt.eval("CHEAT_REACTIONS_SAVED"))

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
