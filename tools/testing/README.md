# Testing in the game

Helpers for checking Loot Advisor and Build Advisor in a running Baldur's Gate 3 (Windows, Steam, Script Extender).
PowerShell scripts run as `powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/<script>.ps1`; shell
scripts from Git Bash.

There are two kinds. **Shared** helpers behave the same for every use: they start, drive, inspect and stop the game.
**Test shortcuts** break the game's rules on purpose (teleport instead of walking, spawn instead of looting, set a flag
instead of playing a dialogue, recruit, change ability scores with boosts) so a test reaches its state in seconds.
Use the shortcuts on test saves only; saving afterwards keeps their changes.

| Script | Kind | What it does |
|---|---|---|
| `launch.ps1` | shared | start the game through Steam (skips the Larian launcher) and wait for its window |
| `startgame.ps1` | shared | start the game (BG3_DIR or Steam) and click through its start screens to the main menu (`-Mode menu`) or Continue (`-Mode continue`), accepting Script Extender's experimental-version dialog |
| `restart.sh` | shared | with the game closed: install the local builds (`../install_mods.py`), `startgame.ps1`, and for `continue` wait for the load |
| `borderless.ps1` | shared | check the game runs borderless, never windowed; `-Fix` (game closed) sets it in `graphicSettings.lsx` and keeps the old file |
| `saves.py` | shared | list saves as the Load Game list orders them, to find a save's row by name |
| `loadsave.sh` | shared | load a save by folder suffix or name from the main menu or the in-game menu and wait until it is loaded |
| `waitload.sh` | shared | confirm a load (dev eval hook, or a signal file a mod rewrites) and accept the Mod Verification dialog |
| `findrow.py` | shared | find a save's row in a Load list screenshot from a template image (loadsave.sh; needs numpy and Pillow) |
| `ev.sh` | shared | run Lua in the game through a mod's dev eval hook and print the answer |
| `screenshot.ps1` | shared | full-resolution screenshot of the primary screen, or of the game window only (`-Window`) |
| `crop.ps1` | shared | JPEG of part of the screen (fractions of width and height), scaled down |
| `ocrscreen.ps1` | shared | read the text on screen (Windows OCR): `-Find text` prints its position, `-All` every line |
| `waitplay.ps1` | shared | wait until a cutscene's letterbox is gone, then snapshot |
| `front.ps1`, `focuswin.ps1`, `minwin.ps1`, `listwin.ps1` | shared | bring the game (or any window by title) to the front, minimise a window, list windows |
| `clickseq.ps1`, `gclick.ps1`, `go.ps1`, `step.ps1` | shared | click points (`-Seq "x,y;x,y"`); gclick/go/step bring the game to the front first, go/step also snapshot |
| `hover.ps1`, `rclick.ps1`, `drag.ps1`, `wheel.ps1` | shared | move the mouse without clicking, right-click, drag, turn the wheel |
| `sendkey.ps1`, `gamekey.ps1`, `combo.ps1` | shared | press keys as scan codes (the game ignores virtual-key input); gamekey/combo focus the game first |
| `quit.sh` | shared | quit from the game's menu (clicks) and wait for the process to exit |
| `quit.ps1` | shared | ask the game to close and wait for it (never force-kills) |
| `cheat.py` | test shortcut | teleport, spawn items, story flags, recruit, boosts, ability-score respec, statuses, reactions that never ask (scripted runs), autosave off during a test |
| `respec.py` | test shortcut | make a build through the game's own respec and level-up screens: class, subclass, point buy, racial bonuses, skills, styles, feats; spells listed for a click |

Prefer the engine to the screen: read and change the game through `ev.sh` and `cheat.py`, then keys, and click only
where nothing else reaches (the start screens, the Load list, the dialogs above, or UI that is itself under test).

## Driving the game with clicks and keys
- **Borderless, never windowed.** Click points assume the game fills the screen with no title bar: a title bar shifts
  every point, and a click meant for the game's menu button can close the window. `launch.ps1` and `startgame.ps1`
  run `borderless.ps1 -Fix` before starting the game; in the game, Options > Video > Display Mode > Borderless.
- **Coordinates** are in a 1389x868 reference frame (a 16:10 screen) and are scaled to the primary screen. The
  points in the scripts were measured on a 16:10 display; on another aspect ratio, measure again with `ocrscreen.ps1
  -All` (it prints frame coordinates) or a screenshot.
- **Environment** (all optional):

| Variable | Used by | Meaning |
|---|---|---|
| `BG3_DIR` | startgame.ps1 | game install folder (holding `bing3_dx11.exe`); unset = start through Steam |
| `BG3_MINIMIZE` | front.ps1 and every script that focuses the game | comma-separated process names whose windows are minimised first, e.g. `Code,WindowsTerminal` |
| `BG3_SHOT_DIR` | crop, go, step, hover, waitplay, loadsave, waitload | folder for snapshots (`crop.png`, `mini.png`, `loadfail_*.png`); default `screenshots/` in this repository |
| `BG3_TEMPLATE_DIR` | loadsave.sh | folder with `tpl_<save name>.png` row templates for findrow.py; default `BG3_SHOT_DIR` |
| `BG3_EVAL_MOD` | waitload.sh | the mod whose dev eval hook confirms a load; default `LootAdvisor` |
| `BG3_LOAD_SIGNAL_FILE`, `BG3_LOAD_SHOW` | waitload.sh | confirm loads by a file a mod rewrites while a level runs instead of the eval hook; lines matching `BG3_LOAD_SHOW` are printed |
| `BG3_EXTRA_MODS` | restart.sh (install_mods.py) | more mods to install besides Loot Advisor and Build Advisor |
| `EV_TIMEOUT` | ev.sh | seconds to wait for the answer (default 10) |

```bash
tools/testing/restart.sh menu                      # install the builds, start the game, stop at the main menu
tools/testing/loadsave.sh QuickSave_12 menu        # load a save from there and wait until it runs
powershell -NoProfile -ExecutionPolicy Bypass -File tools/testing/gamekey.ps1 -Keys esc
tools/testing/quit.sh
```

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
python tools/testing/cheat.py reactions apply           # scripted runs only: no "Use reaction?" prompts; restore puts
                                                        # the player's own reaction settings back
python tools/testing/cheat.py autosave off             # no autosave during a test; autosave restore at the end,
                                                        # then load a save before quitting (the game stores it then)
```
`python tools/testing/test_cheat.py` checks offline that every command builds Lua that compiles (CI runs it).

## Script Extender settings
- Loot Advisor's item frames, map painting and tooltip lines need Script Extender v33 or newer; until v33 is a normal
  release use the Devel channel (`ScriptExtenderUpdaterConfig.json` with `{"UpdateChannel": "Devel"}` in the game's
  `bin` folder). The Devel build shows an "experimental version" dialog at every start: click Accept.
- After a pak rebuild, loading a save shows the game's "Mod Verification" dialog: click Start Game.
- The Script Extender console (`ScriptExtenderSettings.json` in `bin` with `{"CreateConsole": true}`) shows the mods'
  log lines and accepts `!la_dev` and the other console commands.

## Builds through the respec and level-up screens
`respec.py` makes a character's build the way a player does, so the game applies its own rules (no boosts): `open`
starts the respec for any party character (no trip to Withers), `levelup` opens a pending level, and each pick goes
through the screen's own view-model command. Spells and cantrips are the exception: `spells --click` clicks them in
the open list, last first (`--grid-y` moves the grid if a list sits elsewhere). `history` reads back what each level
took, to check a build against its plan. Use it on test saves: `open` skips Withers, and Confirm keeps the result.

```bash
python tools/testing/respec.py open S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604
python tools/testing/respec.py abilities STR=8 DEX=14 CON=15 INT=15 WIS=10 CHA=8
python tools/testing/respec.py bonus INT CON
python tools/testing/respec.py skills Investigation Insight
# click the respec's Confirm, then once per level:
python tools/testing/respec.py levelup S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604
python tools/testing/respec.py spells "Fireball" "Lightning Bolt" --click    # after opening the Spells step
python tools/testing/respec.py finish
python tools/testing/respec.py history S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604
```
The picks are deferred: the screen changes at once, the definition the game applies a few seconds later, so wait
before Confirm or `finish`. The commands that need several calls (`abilities`, `bonus`, `skills`, `asi`) repeat
until the screen reports them done, and exit with 1 when it does not. Skills take the internal name (`SleightOfHand`).
Never send layout queries such as `FrameworkElement:PointToScreen` through the eval hook: they deadlock the game.
`python tools/testing/test_respec.py` checks the Lua offline (CI runs it).

## Loot Advisor's gauntlet
The gauntlet measures gear sets in the game; its tools are in Loot Advisor's `tools/gauntlet/` and use the same eval
hook (`tools/gauntlet/engine.py`). Loot Advisor's README, section "Gauntlet and optimizer", lists the steps.
