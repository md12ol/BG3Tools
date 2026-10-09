#!/bin/sh
# restart.sh [menu]: (game must be closed) install dist/BuildAdvisor.pak + dist/Autopilot.pak, launch BG3 and click through each screen the
# moment it appears (startgame.ps1, screen recognition); default Continues the latest save and waits for the scanner,
# "menu" stops at the main menu (to load a specific save). Never force-kill BG3 - quit with quit.sh.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
if tasklist | grep -qi bg3_dx11; then echo "BG3 is running - quit it first (quit.sh)"; exit 1; fi
# installs dist/BuildAdvisor.pak + dist/Autopilot.pak and enables both in modsettings.lsx (idempotent, .bak backup)
python ../../tools/install_mods.py || { echo "install failed"; exit 1; }
powershell -NoProfile -ExecutionPolicy Bypass -File startgame.ps1 -Mode "${1:-continue}" < /dev/null
[ "${1:-continue}" = continue ] && { sleep 1; head -3 "$D/BuildAdvisor_scan.txt"; }
