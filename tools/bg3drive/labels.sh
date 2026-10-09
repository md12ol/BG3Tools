#!/bin/sh
# labels.sh: focus BG3, hold Alt (item/corpse labels; "Name*" = still has loot) and save a full screenshot to crop.png.
cd "$(dirname "$0")"
powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -WaitMs 0 < /dev/null > /dev/null
(powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys alt -HoldMs 2300 < /dev/null > /dev/null &)
sleep 1.7; powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -MaxW 1389 < /dev/null > /dev/null; sleep 0.8
