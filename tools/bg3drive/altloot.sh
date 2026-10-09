#!/bin/sh
# altloot.sh "x,y;x,y;...": loot several "Name*" labels read from ONE Alt screenshot (frame coords). For each label:
# shift it by the host's movement since the screenshot (camera follows the host; calib.env mapping), Alt+click it
# (real click: the host walks there and opens it), wait until stopped, Space = Take All.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
[ -f calib.env ] && . ./calib.env
pos() { head -1 "$D/BuildAdvisor_scan.txt" | sed -n 's/.*x=\(-*[0-9.]*\) y=.* z=\(-*[0-9.]*\) .*/\1 \2/p'; }
list=$1; set -- $(pos); x0=$1; z0=$2
for p in $(echo "$list" | tr ';' ' '); do
  set -- $(pos)
  pt=$(awk -v p=$p -v x0=$x0 -v z0=$z0 -v x=$1 -v z=$2 -v a=$EXX -v b=$EXY -v c=$EZX -v d=$EZY 'BEGIN{split(p,q,","); dx=x-x0; dz=z-z0;
    printf "%d,%d", q[1]-(dx*a+dz*c), q[2]-(dx*b+dz*d)}')
  powershell -NoProfile -ExecutionPolicy Bypass -File altclick.ps1 -X ${pt%,*} -Y ${pt#*,} < /dev/null > /dev/null
  prev=""; for i in $(seq 1 12); do sleep 1.1; cur=$(pos); [ "$cur" = "$prev" ] && break; prev=$cur; done
  powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys space < /dev/null > /dev/null; sleep 0.6
  echo "label $p -> clicked $pt, host now $(pos), $(sed -n 3p "$D/BuildAdvisor_scan.txt" | sed 's/.*(//')"
done
