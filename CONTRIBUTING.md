# Contributing to Loot Advisor and Build Advisor

BG3Tools is the entry point for contributors. The two mods live in their own repositories,
[LootAdvisor](https://github.com/md12ol/LootAdvisor) and [BuildAdvisor](https://github.com/md12ol/BuildAdvisor); this
repository holds what both need: the pak builder, the installer, release checks, the shared pre-push hook and a few
helpers for testing in the game.

## Setup
You need Windows with Baldur's Gate 3 (Steam), [Script Extender](https://github.com/Norbyte/bg3se), Git (Git Bash),
Python 3.12 and, for the tests, `pip install lz4 zstandard pillow lupa`.
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
python BG3Tools/tools/build_pak.py              # both mods -> BG3Tools/dist/<Mod>.pak (+ each repo's install folder)
python BG3Tools/tools/install_mods.py --dry-run # what would change in the game's Mods folder and modsettings.lsx
python BG3Tools/tools/install_mods.py           # install and enable (quit the game first)
python BG3Tools/tools/builds.py list            # earlier local builds; builds.py restore <Mod> <id> puts one back
```

## Test
- **Offline**: `python LootAdvisor/tests/run.py` (add `--mutate` to prove every check can fail),
  `python BuildAdvisor/tools/run_tests.py`. CI runs the parts that need no game data on every pull request.
- **Pre-push hook** (`hooks/pre-push`, installed by `setup.sh`): runs each repo's full local suite, including the
  tests that need game data, before every push. Missing data or a missing sibling repo is a skip, never a failure.
- **In the game**, with the helpers in `tools/testing/` (PowerShell scripts run as
  `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`):

  | Step | How |
  |---|---|
  | start the game | `tools/testing/launch.ps1` (through Steam, skips the Larian launcher, waits for the window) |
  | load a save by name | `python tools/testing/saves.py <part of the save name>` prints its row in the Load Game list; then load it by hand: title screen -> Load Game -> that row |
  | run Lua in the game | set `"Dev": true` in `LootAdvisor_settings.json` (Script Extender folder), then `echo 'print(1)' \| tools/testing/ev.sh server -` (`-m <Mod>` for another mod with the same hook) |
  | screenshot | `tools/testing/screenshot.ps1 [-Out file.png]` (whole screen, full resolution; bring the game to the front first) |
  | quit cleanly | `tools/testing/quit.ps1` (asks the game to close and waits; confirm in the game if it asks; never force-kill the game) |

  Everything that depends on the screen layout (menus, clicking items, opening windows) is done by hand. Describe
  what you checked in the pull request, with screenshots where it helps.

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
- Never commit extracted game files (item texts, localisation, icons, textures, models) or built paks other than the
  install folder's; they are rebuilt from each player's own game.
