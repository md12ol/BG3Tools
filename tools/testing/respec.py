"""Make a character's build through the game's own respec and level-up screens, driven from outside the game.

Nothing is granted by boosts: every pick goes through the same view-model commands the screens' buttons use, so the
game applies its own rules (point buy, racial bonuses, class levels, feats, prepared spells). Uses the dev eval hook
of a mod (default LootAdvisor, see README "The dev eval hook"), like cheat.py.

  python tools/testing/respec.py open CHARACTER          open the respec screen (Withers' respec) for a character
  python tools/testing/respec.py levelup CHARACTER       open the level-up screen (needs a pending level)
  python tools/testing/respec.py state                   which screen is open, its step, and whether it can finish
  python tools/testing/respec.py class Wizard            respec: the class; level-up: the class to take this level
  python tools/testing/respec.py subclass LightDomain    subclass by its internal name (EvocationSchool, BattleMaster ...)
  python tools/testing/respec.py deity Talos
  python tools/testing/respec.py abilities STR=8 DEX=14 CON=15 INT=15 WIS=10 CHA=8     point buy (before racial bonuses)
  python tools/testing/respec.py bonus INT CON           racial +2 and +1
  python tools/testing/respec.py skills Insight SleightOfHand [--race | --expertise]   skills by internal name
  python tools/testing/respec.py passives "Fighting Style: Defence"  ...   fighting styles, manoeuvres, favoured enemy
  python tools/testing/respec.py feat "Great Weapon Master"
  python tools/testing/respec.py asi WIS=2               the Ability Improvement feat with its raises
  python tools/testing/respec.py spells "Fireball" "Lightning Bolt" [--click]   spell or cantrip picks (see below)
  python tools/testing/respec.py finish                  level-up: apply the level
  python tools/testing/respec.py history CHARACTER       every level's class, subclass, feat, passives, spells, skills

CHARACTER is a GUID or a full template name (S_Player_Gale_...). Names in passives/feat/spells are the game's
English labels as the screen shows them; skills take the internal name (Insight, SleightOfHand, AnimalHandling).

What needs a click: spells and cantrips. Their buttons pass a two-part parameter that the extender cannot build, so
`spells` prints each wanted spell's position in the open list (the list as the screen draws it: known spells left
out) and, with --click, clicks those positions with gclick.ps1, last first. The grid's first row sits at --grid-y,
measured on the level-up Spells list; check it once on another screen. Open the list first by clicking its step in the left column
(Spells / Cantrips; ocrscreen.ps1 -All finds it). The respec's Confirm button is clicked too (no tested command).

Timing: commands are deferred. The screen's view model changes at once; the character definition the game applies
follows up to about 5 s later. This tool waits between steps; wait a few seconds before Confirm / finish yourself.
The level-up intro plays only while the game window is in front (front.ps1); `levelup` brings it to the front.

Never call layout queries such as FrameworkElement:PointToScreen through the eval hook: it deadlocks the game.
"""
import argparse
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cheat import ev, lua_str  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ABIL = {"STR": "Strength", "DEX": "Dexterity", "CON": "Constitution", "INT": "Intelligence", "WIS": "Wisdom",
        "CHA": "Charisma"}
# Spell lists in the respec and level-up screens: 8 icons a row, first icon and spacing in the 1389x868 frame
GRID_X0, GRID_DX, GRID_Y0, GRID_DY = 261.5, 35.4, 382.0, 35.8
# Point-buy cost of each score from 8; the screen has 27 points
COST = {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9}
# Replies of the stepping commands that mean "call again"; anything else but DONE is an error
PROGRESS = ("step", "lowered", "removed", "raised", "added")

# Helpers prepended to every client snippet: the open creation / level-up screen and its data context
LIB = r"""
local function P(f, ...) local ok, r = pcall(f, ...) if ok then return r end end
local function findDC(types)
  local hit
  local function go(e, d)
    if hit or d > 60 then return end
    local dc = P(function() return e.DataContext end)
    local t = dc and P(function() return dc.Type end)
    if t and types[t] then hit = dc return end
    local n = P(function() return e.VisualChildrenCount end) or 0
    for i = 1, n do local c = P(function() return e:VisualChild(i) end) if c then go(c, d + 1) end end
  end
  go(Ext.UI.GetRoot(), 0)
  return hit
end
local dc = findDC({ ["gui::DCCharacterCreation"] = true, ["gui::DCCharacterLevelUp"] = true })
local function name(h) return Ext.Loca.GetTranslatedString(h) end
local function each(c) local i = 0 return function() i = i + 1 if c and i <= #c then return c[i] end end end
if not dc then return "no respec or level-up screen open" end
local levelup = dc.Type == "gui::DCCharacterLevelUp"
"""


def guid(s):
    g = s[-36:]
    if not re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", g):
        raise SystemExit("expected a GUID or a template name ending in one, got %r" % s)
    return g


def client(code, mod, timeout=15.0):
    return ev(code, mod, "client", timeout).strip()


def lua_list(items):
    return "{" + ", ".join(lua_str(x) for x in items) + "}"


def snippet(a):
    """(side, Lua) for one step of a command; pure, so it can be tested offline."""
    c = a.cmd
    if c == "open":
        return "server", "Osi.StartRespec(%s)\nreturn 'respec opened'" % lua_str(guid(a.character))
    if c == "history":
        return "server", HISTORY % lua_str(guid(a.character))
    if c == "levelup":
        return "client", LEVELUP % lua_str(guid(a.character))
    body = {
        "state": "return string.format('%s step=%s complete=%s level=%s', levelup and 'level-up' or 'respec', "
                 "tostring((P(function() return levelup and dc.LevelUpStep or dc.CharacterCreationStep end))), "
                 "tostring((P(function() if levelup then return dc.IsLevelUpComplete end return dc.IsCharacterComplete end))), "
                 "tostring((P(function() return dc.AvailableCharacterLevel end))))",
        "finish": "if not dc.IsLevelUpComplete then return 'choices pending' end\n"
                  "dc.FinishLevelUp:Execute(nil)\nreturn 'finished'",
    }
    if c in body:
        return "client", LIB + body[c]
    if c in ("class", "subclass", "deity"):
        coll, prop = {"subclass": ("SelectableSubClasses", "SelectedSubClass"),
                      "deity": ("SelectableDeities", "SelectedDeity")}.get(c, (None, None))
        if c == "class":
            sel = ("local coll, prop = 'SelectableClasses', 'SelectedClass'\n"
                   "if levelup then coll, prop = 'SelectableMultiClasses', 'SelectedMultiClass' end\n")
        else:
            sel = "local coll, prop = %s, %s\n" % (lua_str(coll), lua_str(prop))
        return "client", LIB + sel + (
            "for it in each(dc[coll]) do if it.IDString == %s then dc:SetProperty(prop, it)\n"
            "  return 'selected ' .. it.IDString end end\n"
            "local t = {} for it in each(dc[coll]) do t[#t + 1] = it.IDString end\n"
            "return 'not offered; choices: ' .. table.concat(t, ', ')") % lua_str(a.name)
    if c == "abilities":
        want = parse_scores(a.scores, 8, 15)
        if len(want) != 6:
            raise SystemExit("give each of the six abilities once")
        spent = sum(COST[v] for v in want.values())
        if spent > 27:
            raise SystemExit("those scores cost %d points; point buy has 27" % spent)
        rows = ", ".join("%s = %d" % (k, v) for k, v in want.items())
        return "client", LIB + ABILITIES % rows
    if c == "bonus":
        return "client", LIB + BONUS % (lua_str(ABIL[a.plus2.upper()]), lua_str(ABIL[a.plus1.upper()]))
    if c == "skills":
        where = "dc.AllSkills.ExpertiseSkills" if a.expertise else ("dc.RaceSkills" if a.race else "dc.ClassSkills")
        return "client", LIB + SKILLS % (lua_list(a.names), where)
    if c == "passives":
        return "client", LIB + PASSIVES % lua_list(a.names)
    if c == "feat":
        return "client", LIB + FEAT % lua_str(a.name)
    if c == "asi":
        want = parse_scores(a.raises, 1, 2)
        rows = ", ".join("%s = %d" % (k, v) for k, v in want.items())
        return "client", LIB + ASI % rows
    if c == "spells":
        return "client", LIB + SPELLS % lua_list(a.names)
    raise SystemExit("unknown command " + c)


def parse_scores(pairs, lo, hi):
    out = {}
    for kv in pairs:
        k, _, v = kv.partition("=")
        if k.upper() not in ABIL or not v.isdigit() or not lo <= int(v) <= hi:
            raise SystemExit("expected ABIL=N with ABIL one of %s and N %d-%d, got %r" % (" ".join(ABIL), lo, hi, kv))
        out[ABIL[k.upper()]] = int(v)
    return out


LEVELUP = r"""
local function P(f, ...) local ok, r = pcall(f, ...) if ok then return r end end
local hit
local function go(e, d)
  if hit or d > 60 then return end
  local dc = P(function() return e.DataContext end)
  if dc and P(function() return dc.Type end) == "gui::DCHotBar" then hit = dc return end
  local n = P(function() return e.VisualChildrenCount end) or 0
  for i = 1, n do local c = P(function() return e:VisualChild(i) end) if c then go(c, d + 1) end end
end
go(Ext.UI.GetRoot(), 0)
if not hit then return "no hotbar (is a save loaded?)" end
local list = hit.CurrentPlayer.AssignedCharacters
for i = 1, #list do
  if list[i].EntityUUID == %s then
    if not hit.StartLevelUp:CanExecute(list[i]) then return "no level-up available" end
    hit.StartLevelUp:Execute(list[i]) return "level-up opened"
  end
end
return "character not in this player's party"
"""

ABILITIES = r"""
local want = { %s }
-- one direction per call: raises fail while the points are still spent
local down = false
for _, pass in ipairs({ "down", "up" }) do
  local seen, out = {}, {}
  local function visit(e, d)
    if d > 40 then return end
    local v = P(function() return e.DataContext end)
    if v and P(function() return v.Type end) == "ls.VMAbility" and want[v.Ability] and not seen[v.Ability] then
      seen[v.Ability] = true
      local diff = want[v.Ability] - v.BaseValue
      if pass == "down" and diff < 0 then for _ = 1, -diff do dc.DecreaseAbility:Execute(v) end down = true end
      if pass == "up" and diff > 0 and not down then for _ = 1, diff do dc.IncreaseAbility:Execute(v) end end
      if diff ~= 0 then out[#out + 1] = v.Ability .. " " .. v.BaseValue .. "->" .. want[v.Ability] end
    end
    local n = P(function() return e.VisualChildrenCount end) or 0
    for i = 1, n do local c = P(function() return e:VisualChild(i) end) if c then visit(c, d + 1) end end
  end
  visit(Ext.UI.GetRoot(), 0)
  if pass == "down" and down then return "lowered: " .. table.concat(out, ", ") .. " (run again to raise)" end
  if pass == "up" then
    local n = 0 for _ in pairs(seen) do n = n + 1 end
    if n < 6 then return "only " .. n .. " ability rows on screen: open the abilities step first" end
    return #out == 0 and "DONE" or ("raised: " .. table.concat(out, ", "))
  end
end
"""

BONUS = r"""
local want = { %s, %s }
local IDX = { Strength = 0, Dexterity = 1, Constitution = 2, Intelligence = 3, Wisdom = 4, Charisma = 5 }
local s = P(function() return dc.RaceProgressionDetails.AbilityBonusSelection end)
if not s or #s < 2 then return "no +2/+1 choice on this screen" end
local order = { 1, 2 }
if s[2].SelectedIndex == IDX[want[1]] then order = { 2, 1 } end
for _, i in ipairs(order) do
  local cur, t = s[i].SelectedIndex, IDX[want[i]]
  if cur ~= t then
    if t > cur then dc.SelectNextAbilityBonus:Execute(s[i]) else dc.SelectPrevAbilityBonus:Execute(s[i]) end
    return "step"
  end
end
return "DONE"
"""

SKILLS = r"""
local want = {} for _, n in ipairs(%s) do want[n] = true end
local list = P(function() return %s.Skills end)
if not list then return "no such skill list on this screen" end
local out = {}
-- one direction per call: the selection holds a fixed number
for v in each(list) do if v.Enabled and v.Selected and not want[v.Skill] then dc.ToggleSkill:Execute(v) out[#out + 1] = "-" .. v.Skill end end
if #out > 0 then return "removed " .. table.concat(out, ", ") .. " (run again to add)" end
for v in each(list) do if v.Enabled and not v.Selected and want[v.Skill] then dc.ToggleSkill:Execute(v) out[#out + 1] = "+" .. v.Skill end end
return #out == 0 and "DONE" or ("added " .. table.concat(out, ", "))
"""

PASSIVES = r"""
local want = {} for _, n in ipairs(%s) do want[n] = true end
local out = {}
for _, k in ipairs({ "NotSubPassiveSelectors", "SubPassiveSelectors" }) do
  for sel in each(dc.ClassProgressionDetails[k]) do
    for p in each(sel.Passives) do
      local n = name(p.Name)
      -- toggling a wanted one on replaces the old pick in a one-of selector; toggling off does nothing there
      if want[n] and (p.Value or 0) <= 0 then dc.TogglePassive:Execute(p) out[#out + 1] = n end
    end
  end
end
return #out == 0 and "DONE" or ("selected " .. table.concat(out, ", "))
"""

FEAT = r"""
for f in each(dc.SelectableFeats) do
  if name(f.Name) == %s then dc:SetProperty("SelectedFeat", f) return 'feat ' .. name(f.Name) end
end
return "feat not offered"
"""

ASI = r"""
local want = { %s }
if name(dc.SelectedFeatDetails.Name) ~= "Ability Improvement" then
  for f in each(dc.SelectableFeats) do
    if name(f.Name) == "Ability Improvement" then dc:SetProperty("SelectedFeat", f) return "step" end
  end
  return "Ability Improvement not offered"
end
local fd = dc.SelectedFeatDetails.FeatDetails
-- one raise per call: two raises in one tick can count once
for v in each(fd.AbilitySelection) do
  if want[v.Ability] and (v.Improvement or 0) < want[v.Ability] then dc.SelectAbility:Execute(v) return "step" end
end
return "DONE"
"""

SPELLS = r"""
local want = {} for _, n in ipairs(%s) do want[n] = true end
local out = {}
for _, k in ipairs({ "ClassProgressionDetails", "RaceProgressionDetails" }) do
  local sels = P(function() return dc[k].SpellSelectors end)
  for sel in each(sels) do
    local shown = 0
    for it in each(sel.Available) do
      if not it.NotAvailable then
        shown = shown + 1
        local n = name(it.Spell.Name)
        if want[n] then out[#out + 1] = string.format("%%s=%%d%%s", n, shown, it.Selected and "*" or "") end
      end
    end
  end
end
return table.concat(out, "\n")
"""

HISTORY = r"""
local e = Ext.Entity.Get(%s)
local Z = "00000000-0000-0000-0000-000000000000"
local function cls(id) local c = Ext.StaticData.Get(id, "ClassDescription") return c and c.Name or "?" end
local function feat(id) local f = Ext.StaticData.Get(id, "Feat") return f and f.Name or id end
local out = {}
for i, l in ipairs(e.LevelUp.LevelUps) do
  local s = { i .. ": " .. cls(l.Class) .. (l.SubClass ~= Z and ("/" .. cls(l.SubClass)) or "") }
  if l.Feat and l.Feat ~= Z then s[#s + 1] = "feat=" .. feat(l.Feat) end
  local U = l.Upgrades or {}
  local function add(label, list, field)
    for _, x in ipairs(list or {}) do
      local t = {} for _, y in ipairs(x[field] or {}) do t[#t + 1] = tostring(y) end
      if #t > 0 then s[#s + 1] = label .. "=" .. table.concat(t, ",") end
    end
  end
  add("passives", U.Passives, "Passives")
  add("spells", U.Spells, "Spells")
  add("skills", U.Skills, "Proficiencies")
  add("expertise", U.SkillExpertise, "Expertise")
  for _, b in ipairs(U.AbilityBonuses or {}) do
    local t = {} for k, y in ipairs(b.Bonuses) do t[#t + 1] = tostring(y) .. "+" .. tostring(b.BonusAmounts[k]) end
    if #t > 0 then s[#s + 1] = "bonus=" .. table.concat(t, ",") end
  end
  out[#out + 1] = table.concat(s, "  ")
end
local a = e.Stats.Abilities
out[#out + 1] = string.format("abilities STR %%d DEX %%d CON %%d INT %%d WIS %%d CHA %%d, max HP %%d", a[2], a[3], a[4],
  a[5], a[6], a[7], e.Health.MaxHp)
return table.concat(out, "\n")
"""


def ps(script, *args):
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(HERE, script)]
                       + list(args), capture_output=True, text=True, timeout=60)
    if r.returncode:
        raise SystemExit("%s failed: %s" % (script, (r.stderr or r.stdout).strip()))


def click_grid(index, y0=GRID_Y0):
    r, c = divmod(index - 1, 8)
    ps("gclick.ps1", "-Seq", "%d,%d" % (GRID_X0 + c * GRID_DX, y0 + r * GRID_DY))
    time.sleep(0.7)


def answer(code, a, side):
    out = ev(code, a.mod, side, a.timeout).strip()
    return out[3:] if out.startswith("=> ") else out


def failed(out):
    return (out.startswith(("ERROR", "COMPILE ERROR", "no ", "only ", "choices pending"))
            or "not offered" in out or "not in this" in out)


def run(a):
    side, code = snippet(a)
    if a.dry_run:
        print(code)
        return 0
    if a.cmd == "levelup":
        ps("front.ps1")
    # commands that settle one step per call are repeated until the screen reports DONE
    loops = {"abilities": 5, "bonus": 14, "skills": 4, "asi": 8}.get(a.cmd)
    if loops:
        for _ in range(loops):
            out = answer(code, a, side)
            print(out)
            if out == "DONE" or not out.startswith(PROGRESS):
                break
            time.sleep(1.2)
        if out != "DONE":
            print("not done after %d calls" % loops if out.startswith(PROGRESS) else "stopped")
            return 1
    else:
        out = answer(code, a, side)
        print(out)
        if failed(out):
            return 1
    if a.cmd == "spells" and a.click:
        picks = {}
        for line in out.splitlines():
            label, _, pos = line.rpartition("=")
            if label and pos.isdigit():
                picks.setdefault(label, int(pos))
        # last first: a pick can leave the list, which moves every icon after it
        for label, pos in sorted(picks.items(), key=lambda kv: -kv[1]):
            click_grid(pos, a.grid_y)
            print("clicked", label)
        if picks:
            print("run spells again without --click to check: picked ones are marked *")
    if a.cmd in ("abilities", "bonus", "skills", "passives", "asi", "spells", "class", "subclass", "deity", "feat"):
        time.sleep(a.settle)
    return 0


def parser():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("-m", "--mod", default="LootAdvisor")
    ap.add_argument("--timeout", type=float, default=15.0)
    ap.add_argument("--settle", type=float, default=3.0, help="seconds to wait after a pick (deferred commands)")
    ap.add_argument("--dry-run", action="store_true")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for c in ("open", "levelup", "history"):
        sub.add_parser(c).add_argument("character")
    for c in ("state", "finish"):
        sub.add_parser(c)
    for c in ("class", "subclass", "deity", "feat"):
        sub.add_parser(c).add_argument("name")
    sub.add_parser("abilities").add_argument("scores", nargs=6)
    p = sub.add_parser("bonus")
    p.add_argument("plus2", choices=list(ABIL) + [k.lower() for k in ABIL])
    p.add_argument("plus1", choices=list(ABIL) + [k.lower() for k in ABIL])
    p = sub.add_parser("skills")
    p.add_argument("names", nargs="+")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--race", action="store_true", help="the race's skill choice (e.g. Human Versatility)")
    g.add_argument("--expertise", action="store_true")
    sub.add_parser("passives").add_argument("names", nargs="+")
    sub.add_parser("asi").add_argument("raises", nargs="+")
    p = sub.add_parser("spells")
    p.add_argument("names", nargs="+")
    p.add_argument("--click", action="store_true", help="click the listed positions (the list must be open)")
    p.add_argument("--grid-y", type=float, default=GRID_Y0, help="y of the list's first icon row, 1389x868 frame")
    return ap


def main(argv=None):
    try:
        return run(parser().parse_args(argv))
    except TimeoutError as e:
        print(e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
