#!/bin/sh
# restart.sh [continue|menu]: with the game closed, install the mods' local builds (../install_mods.py: each mod repo's
# dist/<Mod>.pak, plus BG3_EXTRA_MODS), start the game and click through its start screens (startgame.ps1). continue
# (default) also Continues the latest save and waits until it is loaded (waitload.sh); menu stops at the main menu,
# to load a particular save with loadsave.sh. Never force-kill the game: quit it with quit.sh or quit.ps1.
here=$(cd "$(dirname "$0")" && pwd)
mode=${1:-continue}
case "$mode" in continue|menu) ;; *) echo "usage: restart.sh [continue|menu]"; exit 2;; esac
if tasklist | grep -qi bg3_dx11; then echo "the game is running - quit it first (quit.sh)"; exit 1; fi
python "$here/../install_mods.py" || { echo "install failed"; exit 1; }
powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/startgame.ps1")" -Mode "$mode" < /dev/null || exit 1
[ "$mode" = continue ] && exec "$here/waitload.sh" wait
exit 0
