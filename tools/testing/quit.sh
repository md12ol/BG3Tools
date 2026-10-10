#!/bin/sh
# quit.sh: quit the game cleanly from its in-game menu and wait for the process to exit (never force-kill it: a killed
# game can leave a damaged profile or save behind). Menu button top-right (1370,15) -> Quit Game (695,653) -> Yes
# (602,477). At the main menu (e.g. after a Game Over) it uses Quit Game (307,698) -> Yes instead.
# quit.ps1 asks the window to close instead (no clicks); use this one when that shows a confirmation.
here=$(cd "$(dirname "$0")" && pwd)
ps1() { f=$1; shift; powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/$f")" "$@" < /dev/null > /dev/null 2>&1; }
tasklist | grep -qi bg3_dx11 || { echo "not running"; exit 0; }
ps1 go.ps1 -Seq "1370,15" -WaitMs 1200
ps1 clickseq.ps1 -Seq "695,653"; sleep 1.2
ps1 clickseq.ps1 -Seq "602,477"
for i in $(seq 1 40); do tasklist | grep -qi bg3_dx11 || { echo "quit after ${i}s"; exit 0; }; sleep 1; done
ps1 go.ps1 -Seq "307,698" -WaitMs 1500
ps1 clickseq.ps1 -Seq "602,477"
for i in $(seq 1 40); do tasklist | grep -qi bg3_dx11 || { echo "quit from the main menu after ${i}s"; exit 0; }; sleep 1; done
echo "still running - check the screen"; exit 1
