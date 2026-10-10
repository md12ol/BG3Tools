# Contributing to Loot Advisor and Build Advisor

BG3Tools is the entry point for contributors. The two mods live in their own repositories,
[LootAdvisor](https://github.com/md12ol/LootAdvisor) and [BuildAdvisor](https://github.com/md12ol/BuildAdvisor); this
repository holds what both need: the pak builder, the installer, release checks, the shared pre-push hook and a few
helpers for testing in the game.

## Setup
You need Windows with Baldur's Gate 3 (Steam), [Script Extender](https://github.com/Norbyte/bg3se), Git (Git Bash),
Python 3.12 and `pip install lz4 zstandard pillow lupa` (lz4 for the pak builder, the others for the game-data
pipeline and the tests). Nothing else is needed: the Lua tests run in `lupa`'s bundled Lua.
```bash
mkdir BG3Mods && cd BG3Mods
git clone https://github.com/md12ol/BG3Tools.git
sh BG3Tools/setup.sh
```
`setup.sh` clones LootAdvisor and BuildAdvisor next to BG3Tools (the scripts find each other as siblings:
`BG3Mods/BG3Tools`, `BG3Mods/LootAdvisor`, `BG3Mods/BuildAdvisor`) and installs the pre-push hook in all three. Keep
the folder names. Loot Advisor's game data is rebuilt from your own game install; see its README.

## Build and install
```bash
python BG3Tools/tools/build_pak.py              # both mods -> <Mod>/dist/<Mod>.pak + the player package <Mod>/dist/<Mod>/
python BG3Tools/tools/install_mods.py --dry-run # what would change in the game's Mods folder and modsettings.lsx
python BG3Tools/tools/install_mods.py           # install and enable (quit the game first)
python BG3Tools/tools/builds.py list            # earlier local builds; builds.py restore <Mod> <id> puts one back
```

## Test
Everything below runs from the folder that holds the three checkouts.
- **Offline**: `python LootAdvisor/tests/run.py` (add `--mutate` to prove every check can fail, `--ci` for the part
  that needs no game data), `python LootAdvisor/tests/test_optimizer.py [--ci] [--mutate]`,
  `python LootAdvisor/tests/test_gauntlet.py`, `python BuildAdvisor/tools/run_tests.py`,
  `python BuildAdvisor/tools/check_hl.py` (reads Loot Advisor's rebuilt `data/cache`, so run Loot Advisor's
  Rebuild first) and `python BG3Tools/tools/testing/test_cheat.py`. CI runs the parts that need no game data on every
  pull request.
- **Pre-push hook** (`hooks/pre-push`, installed by `setup.sh`): runs each repo's full local suite, including the
  tests that need game data, before every push. Missing data or a missing sibling repo is a skip, never a failure.

## Testing in the game
The helpers are in [`tools/testing/`](tools/testing/README.md); its README has the full table and the setup of the
dev eval hook. **Shared** helpers start, inspect and stop the game the same way for every use; **test shortcuts**
break the game's rules for speed and are for test saves only.

| Step | How | Kind |
|---|---|---|
| start the game | `tools/testing/launch.ps1` (through Steam, skips the Larian launcher, waits for the window) | shared |
| load a save by name | `python tools/testing/saves.py <part of the save name>` prints its row in the Load Game list; load it from the menu | shared |
| run Lua in the game | set `"Dev": true` in `LootAdvisor_settings.json` (Script Extender folder), then `echo 'print(1)' \| tools/testing/ev.sh server -` (`-m <Mod>` for another mod with the same hook) | shared |
| screenshot | `tools/testing/screenshot.ps1 [-Out file.png]` (whole screen, full resolution; bring the game to the front first) | shared |
| quit cleanly | `tools/testing/quit.ps1` (asks the game to close and waits; never force-kill the game) | shared |
| reach a test state fast | `python tools/testing/cheat.py tp X Y Z`, `spawn <template>`, `flag set <flag>`, `party add <character>`, `respec STR=17 ...`, `boost add <boost>`, `status <status>` | test shortcut |

Loot Advisor's gauntlet (gear sets measured in the game, F9 window for manual runs) loads its Lua through the same
eval hook; Loot Advisor's README, section "Gauntlet and optimizer", has the steps. Describe what you checked in the
pull request, with screenshots where it helps.

## Extending the mods
- **A build** (both mods read it): add it to `BuildAdvisor/BuildAdvisor/Mods/BuildAdvisor/ScriptExtender/Lua/Shared/Builds.lua`
  (each level's `hl` lists the exact English menu labels), run `python BuildAdvisor/tools/check_hl.py` and
  `python BuildAdvisor/tools/run_tests.py`; give it a profile in `LootAdvisor/tools/build_profiles.py` (a test fails
  until every Builds.lua build has one), then run Loot Advisor's Rebuild from `match_research.py` on and its tests.
- **Item advice**: the research notes in `LootAdvisor/data/research/<character>.md` are parsed by
  `tools/la_research.py` (the format is in its docstring) and scored by `tools/score_items.py` against each build's
  profile in `tools/build_profiles.py`; `tools/set_notes.py` holds the "why it works" text of each set. Re-run the Rebuild steps from `match_research.py` on.
- **A test**: Loot Advisor checks are `check_<name>(env)` functions in `LootAdvisor/tests/checks.py`, listed in
  `CHECKS` at its end, each with a mutation in `tests/run.py` (`mutations()`) that proves it can fail. A check that
  reads game data is listed in `LOCAL_ONLY` in `tests/run.py`. Build Advisor's mock tests are in
  `BuildAdvisor/tools/mock_test.lua`.
- **A game helper**: shared helpers and test shortcuts go in `tools/testing/` with a line in its README table;
  test shortcuts build their Lua in a pure function so `test_cheat.py`-style tests can compile it without the game.

## Branches, commits and pull requests
- **One branch per task**, named after its topic (`sets-page-header`, `tooltip-length`), cut from `main`. `main` is
  protected and only takes pull requests. For a change that spans repositories, use the same branch name in each:
  CI checks the siblings out side by side and uses the branch of the same name when it exists, else `main`.
- **Conventional Commits** for commit messages and PR titles: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`,
  `test:`, `ci:` (`feat!:` for a breaking change). A subject line plus at most one body line; no co-author,
  "generated with" or other attribution lines. The changelog is built from these messages.
- **Public text**: these repositories are public. PR titles and bodies, commit messages and files must not point at
  private or machine-local things: no absolute paths of your machine, no references to private notes, repositories or
  tools, no names of your own saves or campaigns. Describe the behaviour instead ("owners are chosen among the active
  party"). The `public-text` CI check enforces it; `python BG3Tools/tools/public_text.py text < message.txt` checks a
  message before you commit.
- Open the pull request against `main` (`gh pr create`). The checks `lint`, `tests`, `pr-title` and `public-text`
  must be green. Maintainers merge with a merge commit.
- Never commit extracted game files (item texts, localisation, icons, textures, models) or built paks; game data is
  rebuilt from each player's own game, and paks and the player package are built into `dist/` (locally) or by the
  release workflow (the zip on each GitHub Release).
