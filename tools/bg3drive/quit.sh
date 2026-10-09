#!/bin/sh
# quit.sh: quit BG3 cleanly from its in-game menu (never force-kill: it corrupted the profile once).
# Menu button top-right (1370,15) -> Quit Game (695,653) -> Yes (602,477), then wait for the process to exit.
cd "$(dirname "$0")"
tasklist | grep -qi bg3_dx11 || { echo "not running"; exit 0; }
powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "1370,15" -WaitMs 1200 < /dev/null > /dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "695,653" < /dev/null > /dev/null; sleep 1.2
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "602,477" < /dev/null > /dev/null
for i in $(seq 1 40); do tasklist | grep -qi bg3_dx11 || { echo "quit after ${i}s"; exit 0; }; sleep 1; done
# a122: after a Game Over the game sits at the MAIN menu (no top-right menu button) - Quit Game (307,698) -> Yes (602,477)
powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "307,698" -WaitMs 1500 < /dev/null > /dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "602,477" < /dev/null > /dev/null
for i in $(seq 1 40); do tasklist | grep -qi bg3_dx11 || { echo "quit from the main menu after ${i}s"; exit 0; }; sleep 1; done
echo "still running - check the screen"; exit 1
