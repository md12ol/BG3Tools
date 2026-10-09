#!/bin/sh
# dlg.sh [n] [optionY]: optionally click a dialogue option at frame y (x=330), then press Space n times, capture bottom half
cd "$(dirname "$0")"
[ -n "$2" ] && powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "330,$2" < /dev/null > /dev/null && sleep 2.5
for i in $(seq 1 "${1:-0}"); do powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys space < /dev/null > /dev/null; sleep 2.3; done
powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -X0 0.1 -Y0 0.6 -X1 0.9 -Y1 1 -MaxW 800 < /dev/null > /dev/null
