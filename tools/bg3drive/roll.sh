#!/bin/sh
# roll.sh [guidance]: on a skill-check screen, optionally add Guidance (free cantrip) via Add Bonus, roll, wait, capture
# the result, then click Continue. Result image: crop.png (check it said SUCCESS).
cd "$(dirname "$0")"
c() { powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$1" < /dev/null > /dev/null; }
[ "$1" = "guidance" ] && { c "694,728"; sleep 1; c "684,733"; sleep 0.8; }
c "694,355"; sleep 3.8
powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -X0 0.3 -Y0 0.15 -X1 0.7 -Y1 0.4 -MaxW 300 < /dev/null > /dev/null
c "694,657"; sleep 2
