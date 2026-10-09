#!/bin/sh
# pick.sh N [N...]: choose dialogue option N with the number key, then right-click+Space skip to the next choice;
# repeats for each N. Prints the final state (options / ended). Fast path for known dialogue answers.
cd "$(dirname "$0")"
for n in "$@"; do
  powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys "$n" < /dev/null > /dev/null; sleep 1.5
  r=$(timeout 60 powershell -NoProfile -ExecutionPolicy Bypass -File skipto.ps1 -RClick -Max 40 < /dev/null 2>/dev/null | tail -1); echo "$n -> $r"
done
powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -X0 0 -Y0 0.55 -X1 0.7 -Y1 1 -MaxW 800 < /dev/null > /dev/null
