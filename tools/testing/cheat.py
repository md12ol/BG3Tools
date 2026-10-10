"""Engine shortcuts for tests in the running game: teleport, spawn, flags, party, ability boosts.

These deliberately break the game's rules (no walking, no looting, no dialogue, no Withers) so a test reaches the
state it needs in seconds. Use them on TEST SAVES ONLY: they change the save the way a console cheat would, and
saving afterwards keeps the change.

Every command sends Lua through a mod's dev eval hook, the same file protocol as ev.sh: the mod (default LootAdvisor)
must have "Dev": true in <Mod>_settings.json in the Script Extender folder, and a save must be loaded.

  python tools/testing/cheat.py eval "return Osi.GetHostCharacter()"   any Lua (server; --client for the client)
  python tools/testing/cheat.py pos                                    position and region of the character
  python tools/testing/cheat.py tp X Y Z                               teleport (the party follows)
  python tools/testing/cheat.py tpto TARGET                            teleport next to an object or character GUID
  python tools/testing/cheat.py spawn TEMPLATE [COUNT]                 root template GUID into the inventory
  python tools/testing/cheat.py flag set|clear|get FLAG                story flag on the character
  python tools/testing/cheat.py party add CHARACTER                    recruit a character GUID into the party
  python tools/testing/cheat.py boost add|remove "Ability(Strength,2)" any boost string; remove takes the same text
  python tools/testing/cheat.py respec STR=17 DEX=14 CON=16 ...        set ability scores through boosts
  python tools/testing/cheat.py respec --reset                         remove every boost respec added
  python tools/testing/cheat.py status STATUS [TURNS]                  apply a status (-1 = until removed)
  python tools/testing/cheat.py reactions list                         every party character's reactions and settings
  python tools/testing/cheat.py reactions apply [--policy auto|never] [--set Interrupt_X=never ...]
                                                                       scripted runs: the game never asks (see below)
  python tools/testing/cheat.py reactions restore                      put the saved own settings back
  python tools/testing/cheat.py autosave off|restore|status            the game's autosave during a test (see below)

Reactions: a reaction the game asks about ("Use reaction?") stops a scripted turn until someone answers. `apply`
saves each party character's own settings (once, in the running game) and sets every reaction to fire on its own
("auto", the default) or not at all ("never"), then reads them back; `restore` puts the saved settings back. Use it
only around a scripted or agent-driven run, never while a person plays: their reactions are their choice.

Autosave: the game autosaves after fights and story beats, also in a test save, and a test's cheats then sit in the
newest save of the campaign. `autosave off` records the current setting in the Script Extender folder
(cheat_autosave_saved.json, kept across loads) and switches it off; `autosave restore` puts the recorded value back
and removes the record; `status` reads it. Run restore at the end of every test, also after an abort.

Options: --who GUID (default: the host character), -m MOD (another mod with the same hook), --timeout S,
--dry-run (print the Lua and send nothing; works without the game).
Osiris calls used: TeleportToPosition, TeleportTo, TemplateAddTo, SetFlag / ClearFlag / GetFlag, AddBoosts /
RemoveBoosts, ApplyStatus and the story procedure PROC_GLO_PartyMembers_Add (RegisterAsCompanion as fallback).
"""
import argparse
import os
import sys
import time

SE_DIR = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Larian Studios", "Baldur's Gate 3", "Script Extender")
CAUSE = "TestRespec"
ABIL = {"STR": "Strength", "DEX": "Dexterity", "CON": "Constitution", "INT": "Intelligence", "WIS": "Wisdom",
        "CHA": "Charisma"}


def ev(code, mod="LootAdvisor", side="server", timeout=10.0):
    """Run Lua in the game through <mod>'s dev eval hook; returns what it printed or returned."""
    base = os.path.join(SE_DIR, "%s_%s" % (mod, side))
    out = base + "_eval_out.txt"
    if os.path.exists(out):
        os.remove(out)
    with open(base + "_eval.lua", "w", encoding="utf-8") as f:
        f.write(code)
    t0 = time.time()
    while time.time() - t0 < timeout:
        if os.path.exists(out):
            time.sleep(0.05)
            with open(out, encoding="utf-8", errors="replace") as f:
                return f.read()
        time.sleep(0.1)
    raise TimeoutError("no answer after %.0f s: is the game running, a save loaded and \"Dev\": true set for %s?"
                       % (timeout, mod))


def lua_str(s):
    return "[==[" + s + "]==]"


def who_lua(who):
    return "Osi.GetHostCharacter()" if who in (None, "", "host") else lua_str(who)


def build(a):
    """The Lua for one command (pure, so it can be tested and dry-run without the game)."""
    w = "local who = %s\n" % who_lua(a.who)
    c = a.cmd
    if c == "eval":
        return a.code if a.code != "-" else sys.stdin.read()
    if c == "pos":
        return w + "local x, y, z = Osi.GetPosition(who)\nreturn string.format('%s %.2f %.2f %.2f %s', who, x, y, z, " \
                   "tostring(Osi.GetRegion(who)))"
    if c == "tp":
        return w + "Osi.TeleportToPosition(who, %s, %s, %s, '', 0, 1, 1, 0, 1)\nreturn 'teleported'" % (
            float(a.x), float(a.y), float(a.z))
    if c == "tpto":
        return w + "Osi.TeleportTo(who, %s, '', 0)\nreturn 'teleported'" % lua_str(a.target)
    if c == "spawn":
        return w + "Osi.TemplateAddTo(%s, who, %d, 1)\nreturn 'spawned'" % (lua_str(a.template), a.count)
    if c == "flag":
        f = lua_str(a.flag)
        if a.op == "set":
            return w + "Osi.SetFlag(%s, who, 0, 1)\nreturn Osi.GetFlag(%s, who)" % (f, f)
        if a.op == "clear":
            return w + "Osi.ClearFlag(%s, who, 0, 1)\nreturn Osi.GetFlag(%s, who)" % (f, f)
        return w + "return Osi.GetFlag(%s, who)" % f
    if c == "party":
        return ("local host = Osi.GetHostCharacter()\nlocal ch = %s\n"
                "local ok = pcall(Osi.PROC_GLO_PartyMembers_Add, ch, host)\n"
                "if not ok then ok = pcall(Osi.RegisterAsCompanion, ch, host) end\n"
                "return ok and 'added' or 'failed'") % lua_str(a.character)
    if c == "boost":
        if a.op == "add":
            return w + "Osi.AddBoosts(who, %s, %s, who)\nreturn 'boost added'" % (lua_str(a.boost), lua_str(CAUSE))
        return w + "Osi.RemoveBoosts(who, %s, 0, %s, who)\nreturn 'boost removed'" % (lua_str(a.boost), lua_str(CAUSE))
    if c == "respec":
        if a.reset:
            return w + "Osi.RemoveBoosts(who, '', 0, %s, who)\nreturn 'respec boosts removed'" % lua_str(CAUSE)
        want = {}
        for kv in a.scores:
            k, _, v = kv.partition("=")
            if k.upper() not in ABIL or not v.isdigit():
                raise SystemExit("respec: expected ABIL=score with ABIL one of %s, got %r" % (" ".join(ABIL), kv))
            want[ABIL[k.upper()]] = int(v)
        order = list(ABIL.values())
        rows = ", ".join("{%s, %d}" % (lua_str(n), want[n]) for n in order if n in want)
        return w + (
            "local ORDER = {%s}\nlocal a = Ext.Entity.Get(who).Stats.Abilities\nlocal out = {}\n"
            "for _, row in ipairs({%s}) do\n"
            "  local i\n  for k, n in ipairs(ORDER) do if n == row[1] then i = k end end\n"
            "  local d = row[2] - a[i + 1]\n"
            "  if d ~= 0 then Osi.AddBoosts(who, string.format('Ability(%%s,%%d)', row[1], d), %s, who) end\n"
            "  out[#out + 1] = string.format('%%s %%d -> %%d', row[1], a[i + 1], row[2])\nend\n"
            "return table.concat(out, ', ')") % (", ".join(lua_str(n) for n in order), rows, lua_str(CAUSE))
    if c == "status":
        return w + "Osi.ApplyStatus(who, %s, %s, 1, who)\nreturn 'status applied'" % (lua_str(a.status),
                                                                                    float(a.turns) * 6.0
                                                                                    if a.turns >= 0 else -1)
    if c == "autosave":
        return autosave_lua(a.op)
    if c == "reactions":
        return reactions_lua(a.op, a.policy, a.set or [])
    raise SystemExit("unknown command " + c)


AUTOSAVE_RECORD = "cheat_autosave_saved.json"


def autosave_lua(op):
    """The game's global switch CanAutoSave (Ext.Utils.GetGlobalSwitches); the original value is kept in a file so a
    reload or an aborted test cannot lose it."""
    head = "local g = Ext.Utils.GetGlobalSwitches()\n"
    if op == "status":
        return head + "return 'CanAutoSave = ' .. tostring(g.CanAutoSave)"
    if op == "off":
        return head + ("local rec = Ext.IO.LoadFile(%s)\nif not rec or rec == '' then Ext.IO.SaveFile(%s, tostring(g.CanAutoSave)) end\n"
                       "g.CanAutoSave = false\n"
                       "return 'CanAutoSave = ' .. tostring(Ext.Utils.GetGlobalSwitches().CanAutoSave) .. ' (recorded: ' .. "
                       "tostring(Ext.IO.LoadFile(%s)) .. ')'") % ((lua_str(AUTOSAVE_RECORD),) * 3)
    return head + ("local rec = Ext.IO.LoadFile(%s)\n"
                   "if rec and rec ~= '' then g.CanAutoSave = (rec ~= 'false') else g.CanAutoSave = true end\n"
                   "Ext.IO.SaveFile(%s, '')\n"
                   "return 'CanAutoSave = ' .. tostring(Ext.Utils.GetGlobalSwitches().CanAutoSave)") % (
        lua_str(AUTOSAVE_RECORD), lua_str(AUTOSAVE_RECORD))


REACTION_FLAGS = {"auto": ["Enabled"], "never": [], "ask": ["Ask", "Enabled"]}


def reaction_policy(sets, default="auto"):
    """--set Interrupt_X=never ... -> {name: policy}; refuses unknown policies."""
    if default not in REACTION_FLAGS:
        raise SystemExit("reactions: policy must be one of %s" % ", ".join(REACTION_FLAGS))
    out = {}
    for kv in sets:
        k, _, v = kv.partition("=")
        if not k or v not in REACTION_FLAGS:
            raise SystemExit("reactions: expected Interrupt_X=%s, got %r" % ("|".join(REACTION_FLAGS), kv))
        out[k] = v
    return out


def reactions_lua(op, default, sets):
    pol = reaction_policy(sets, default)
    head = (
        "local FLAGS = {auto = {'Enabled'}, never = {}, ask = {'Ask', 'Enabled'}}\n"
        "local function parse(s) local o = {} for f in (tostring(s):match('%((.*)%)') or ''):gmatch('[%a_]+') do "
        "o[#o + 1] = f end return o end\n"
        "local function party() local o = {} for _, r in ipairs(Osi.DB_Players:Get(nil)) do "
        "o[#o + 1] = r[1]:match('(%x+%-%x+%-%x+%-%x+%-%x+)$') or r[1] end return o end\n"
        "local function prefs(u) local e = Ext.Entity.Get(u) return e, e and e.InterruptPreferences.Preferences end\n"
        "local out = {}\n")
    if op == "list":
        return head + (
            "for _, u in ipairs(party()) do local _, P = prefs(u) local t = {}\n"
            "  for k, v in pairs(P or {}) do t[#t + 1] = k .. '=' .. table.concat(parse(v), '+') end table.sort(t)\n"
            "  out[#out + 1] = u .. ': ' .. table.concat(t, ' ') end\nreturn table.concat(out, '\\n')")
    if op == "restore":
        return head + (
            "local n = 0\nfor u, own in pairs(CHEAT_REACTIONS_SAVED or {}) do local e, P = prefs(u)\n"
            "  if P then for k, f in pairs(own) do P[k] = f end pcall(function() e:Replicate('InterruptPreferences') end) "
            "n = n + 1 end end\nCHEAT_REACTIONS_SAVED = nil\nreturn 'restored ' .. n .. ' characters'")
    rows = ", ".join("[ %s ] = %s" % (lua_str(k), lua_str(v)) for k, v in sorted(pol.items()))
    return head + (
        "local POL, DEF = {%s}, %s\nCHEAT_REACTIONS_SAVED = CHEAT_REACTIONS_SAVED or {}\n"
        "for _, u in ipairs(party()) do local e, P = prefs(u)\n"
        "  if P then local own, bad = {}, 0\n"
        "    for k, v in pairs(P) do own[k] = parse(v) end\n"
        "    if CHEAT_REACTIONS_SAVED[u] == nil then CHEAT_REACTIONS_SAVED[u] = own end\n"
        "    for k in pairs(own) do P[k] = FLAGS[POL[k] or DEF] end\n"
        "    pcall(function() e:Replicate('InterruptPreferences') end)\n"
        "    for k in pairs(own) do if table.concat(parse(P[k]), '+') ~= table.concat(FLAGS[POL[k] or DEF], '+') then "
        "bad = bad + 1 end end\n"
        "    out[#out + 1] = string.format('%%s: %%d reactions set, %%d not as asked', u, #(function() local t = {} "
        "for k in pairs(own) do t[#t + 1] = k end return t end)(), bad) end end\n"
        "return table.concat(out, '\\n')") % (rows, lua_str(default))


def parser():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--who", default="host")
    ap.add_argument("-m", "--mod", default="LootAdvisor")
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("--dry-run", action="store_true")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("eval")
    p.add_argument("code", help="Lua, or - for stdin")
    p.add_argument("--client", action="store_true")
    sub.add_parser("pos")
    p = sub.add_parser("tp")
    p.add_argument("x")
    p.add_argument("y")
    p.add_argument("z")
    sub.add_parser("tpto").add_argument("target")
    p = sub.add_parser("spawn")
    p.add_argument("template")
    p.add_argument("count", nargs="?", type=int, default=1)
    p = sub.add_parser("flag")
    p.add_argument("op", choices=["set", "clear", "get"])
    p.add_argument("flag")
    p = sub.add_parser("party")
    p.add_argument("op", choices=["add"])
    p.add_argument("character")
    p = sub.add_parser("boost")
    p.add_argument("op", choices=["add", "remove"])
    p.add_argument("boost")
    p = sub.add_parser("respec")
    p.add_argument("scores", nargs="*")
    p.add_argument("--reset", action="store_true")
    sub.add_parser("autosave").add_argument("op", choices=["off", "restore", "status"])
    p = sub.add_parser("reactions")
    p.add_argument("op", choices=["list", "apply", "restore"])
    p.add_argument("--policy", default="auto", help="auto (fires without asking) or never")
    p.add_argument("--set", action="append", metavar="Interrupt_X=POLICY", help="per reaction, repeatable")
    p = sub.add_parser("status")
    p.add_argument("status")
    p.add_argument("turns", nargs="?", type=float, default=-1)
    return ap


def main(argv=None):
    a = parser().parse_args(argv)
    if a.cmd == "respec" and not a.reset and not a.scores:
        raise SystemExit("respec: give ABIL=score pairs or --reset")
    code = build(a)
    if a.dry_run:
        print(code)
        return 0
    side = "client" if a.cmd == "eval" and a.client else "server"
    try:
        print(ev(code, a.mod, side, a.timeout).strip())
    except TimeoutError as e:
        print(e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
