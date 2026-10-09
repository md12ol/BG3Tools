#!/bin/sh
# lootat.sh "name" [verb]: loot the closest corpse/item matching name like a player: one long click to ~1.8 m from it
# (clickgo), a real click on the object itself (screen position from scanner dx/dz + calib.env), then Space = the
# game's Take All (takes equipped gear too, unlike the scanner's takeall). verb pickup/use/takeall = scanner command
# instead (in reach only). Refuses targets out of reach (> 3 m or |dy| >= 2).
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
[ -f calib.env ] && . ./calib.env
row() { grep -i -E -m1 "(corpse|item) +(%%% )?$1" "$D/BuildAdvisor_scan.txt"; }
f() { echo "$1" | awk -v k="$2" '{for(i=1;i<=NF;i++) if($i ~ "^"k"="){v=substr($i,length(k)+2); print (v==""?$(i+1):v); exit}}'; }
host() { head -1 "$D/BuildAdvisor_scan.txt" | sed -n 's/.*x=\(-*[0-9.]*\) y=.* z=\(-*[0-9.]*\) .*/\1 \2/p'; }
r=$(row "$1"); [ -n "$r" ] || { echo "no $1 in scan"; exit 1; }
set -- "$1" "$2" $(host); dx=$(f "$r" dx); dz=$(f "$r" dz)
ap=$(awk -v x=$3 -v z=$4 -v dx=$dx -v dz=$dz 'BEGIN{L=sqrt(dx*dx+dz*dz); if (L<=2.6) {print "near"; exit} s=(L-1.8)/L; printf "%.1f %.1f", x+dx*s, z+dz*s}')
[ "$ap" = "near" ] || ./clickgo.sh $ap | tail -1
sleep 1.1; r=$(row "$1"); dx=$(f "$r" dx); dz=$(f "$r" dz); dy=$(f "$r" dy)
awk -v dx=$dx -v dz=$dz -v dy=$dy 'BEGIN{exit !(sqrt(dx*dx+dz*dz)<=3 && dy<2 && dy>-2)}' || { echo "NOT IN REACH: $r"; exit 1; }
if [ -n "$2" ]; then ./cmd.sh "$2 $1" 2 | sed -n 2p; exit; fi
pt=$(awk -v dx=$dx -v dz=$dz -v a=${EXX:--19} -v b=${EXY:--33} -v c=${EZX:--31.5} -v d=${EZY:-20} 'BEGIN{printf "%d,%d", 694+dx*a+dz*c, 438+dx*b+dz*d}')
powershell -NoProfile -ExecutionPolicy Bypass -File hover.ps1 -X ${pt%,*} -Y ${pt#*,} -NoSnap < /dev/null > /dev/null; sleep 0.3
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$pt" < /dev/null > /dev/null; sleep 1.6
powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys space < /dev/null > /dev/null; sleep 0.8
echo "$1: $(sed -n 3p "$D/BuildAdvisor_scan.txt" | sed 's/.*carried/carried/')"
