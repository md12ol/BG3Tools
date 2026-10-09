#!/bin/sh
# rpick.sh "name": pick up a world object (chest, box...) like a player: right-click it (screen position from the
# scanner + calib.env) and choose "Pick Up" (first context-menu entry, about +46,+25 from the click).
cd "$(dirname "$0")"; name=$1
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
. ./calib.env
r=$(grep -i -E -m1 "item +(%%% )?$1" "$D/BuildAdvisor_scan.txt"); [ -n "$r" ] || { echo "no $1"; exit 1; }
pt=$(echo "$r" | awk -v a=$EXX -v b=$EXY -v c=$EZX -v d=$EZY '{for(i=1;i<=NF;i++){if($i ~ /^dx=/){v=substr($i,4); dx=(v==""?$(i+1):v)} if($i ~ /^dz=/){v=substr($i,4); dz=(v==""?$(i+1):v)}}
  printf "%d %d", 694+dx*a+dz*c, 438+dx*b+dz*d}')
set -- $pt
powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -WaitMs 0 < /dev/null > /dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File hover.ps1 -X $1 -Y $2 -NoSnap < /dev/null > /dev/null; sleep 0.4
powershell -NoProfile -ExecutionPolicy Bypass -File rclick.ps1 -X $1 -Y $2 < /dev/null > /dev/null; sleep 0.9
powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -X0 0.3 -Y0 0.3 -X1 0.8 -Y1 0.9 -MaxW 500 < /dev/null > /dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$(($1+46)),$(($2+25))" < /dev/null > /dev/null; sleep 2
echo inv > "$D/BuildAdvisor_cmd.txt"; sleep 1.5; echo "$name: $(grep -c -i "$name" "$D/BuildAdvisor_inv.txt") in party inventory"
