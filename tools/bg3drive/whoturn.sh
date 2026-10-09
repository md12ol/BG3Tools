#!/bin/sh
# whoturn.sh: tiny crop of the active character's name plate under the hotbar (cheap check whose turn it is)
cd "$(dirname "$0")"
powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -X0 0.44 -Y0 0.955 -X1 0.56 -Y1 1 -MaxW 200 -Out "C:\Users\micha\Desktop\BG3Mods\BG3Tools\tools\bg3drive\who.png" < /dev/null > /dev/null
