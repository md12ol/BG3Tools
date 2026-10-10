# Testing in the game

Helpers for checking Loot Advisor and Build Advisor in a running Baldur's Gate 3 (Windows, Steam, Script Extender).
PowerShell scripts run as `powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/<script>.ps1`; shell
scripts from Git Bash.

There are two kinds. **Shared** helpers behave the same for every use: they start, inspect and stop the game.
**Test shortcuts** break the game's rules on purpose (teleport instead of walking, spawn instead of looting, set a flag
instead of playing a dialogue, recruit, change ability scores with boosts) so a test reaches its state in seconds.
Use the shortcuts on test saves only; saving afterwards keeps their changes.

| Script | Kind | What it does |
|---|---|---|
| `launch.ps1` | shared | start the game through Steam (skips the Larian launcher) and wait for its window |
| `saves.py` | shared | list saves as the Load Game list orders them, to find a save's row by name |
| `ev.sh` | shared | run Lua in the game through a mod's dev eval hook and print the answer |
| `screenshot.ps1` | shared | full-resolution screenshot of the primary screen |
| `quit.ps1` | shared | ask the game to close and wait for it (never force-kills) |
| `cheat.py` | test shortcut | teleport, spawn items, story flags, recruit, boosts, ability-score respec, statuses |

## The dev eval hook
Loot Advisor (and any mod with the same hook) runs Lua sent by file when its settings say so:
1. Set `"Dev": true` in `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\LootAdvisor_settings.json`
   (create the file with `{"Dev": true}` if it is missing). In the game, `!la_dev` in the Script Extender console
   flips the setting and saves the file; load a save afterwards so both the client and the server read it.
2. Load a save. The mod then polls `LootAdvisor_server_eval.lua` / `LootAdvisor_client_eval.lua` in that folder about
   three times a second, runs the file once and writes what it printed or returned to `*_eval_out.txt`.

```bash
echo 'return Osi.GetHostCharacter()' | tools/testing/ev.sh server -
python tools/testing/cheat.py pos                       # where the host stands
python tools/testing/cheat.py tp -650 0 -330            # teleport there (the party follows)
python tools/testing/cheat.py spawn <root template GUID> # into the host's inventory
python tools/testing/cheat.py respec STR=17 CON=16      # ability scores through boosts; respec --reset undoes it
python tools/testing/cheat.py --dry-run flag set <flag> # print the Lua only; works without the game
```
`python tools/testing/test_cheat.py` checks offline that every command builds Lua that compiles (CI runs it).

## Script Extender settings
- Loot Advisor's item frames, map painting and tooltip lines need Script Extender v33 or newer; until v33 is a normal
  release use the Devel channel (`ScriptExtenderUpdaterConfig.json` with `{"UpdateChannel": "Devel"}` in the game's
  `bin` folder). The Devel build shows an "experimental version" dialog at every start: click Accept.
- After a pak rebuild, loading a save shows the game's "Mod Verification" dialog: click Start Game.
- The Script Extender console (`ScriptExtenderSettings.json` in `bin` with `{"CreateConsole": true}`) shows the mods'
  log lines and accepts `!la_dev` and the other console commands.

## Loot Advisor's gauntlet
The gauntlet measures gear sets in the game; its tools are in Loot Advisor's `tools/gauntlet/` and use the same eval
hook (`tools/gauntlet/engine.py`). Loot Advisor's README, section "Gauntlet and optimizer", lists the steps.
