#!/bin/sh
# attack.sh "name" [#n]: in combat, hover then click the n-th closest living character matching name (screen position
# from scanner dx/dz relative to the active character, which the camera centres on; calib.env mapping). Shows hit %.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
[ -f calib.env ] && . ./calib.env
r=$(grep -E "character +$1.*hp=[1-9]" "$D/BuildAdvisor_scan.txt" | sed -n "${2:-1}p")
[ -n "$r" ] || { echo "no living $1"; exit 1; }
pt=$(echo "$r" | awk -v a=$EXX -v b=$EXY -v c=$EZX -v d=$EZY '{for(i=1;i<=NF;i++){if($i ~ /^dx=/){v=substr($i,4); dx=(v==""?$(i+1):v)} if($i ~ /^dz=/){v=substr($i,4); dz=(v==""?$(i+1):v)}}
  printf "%d,%d", 694+dx*a+dz*c, 438+dx*b+dz*d}')
echo "$r -> $pt"
powershell -NoProfile -ExecutionPolicy Bypass -File hover.ps1 -X ${pt%,*} -Y ${pt#*,} -NoSnap < /dev/null > /dev/null; sleep 0.7
powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -X0 0.3 -Y0 0.2 -X1 0.8 -Y1 0.8 -MaxW 600 < /dev/null > /dev/null
[ "$3" = "go" ] && powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$pt" < /dev/null > /dev/null
