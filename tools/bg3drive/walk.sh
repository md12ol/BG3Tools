#!/bin/sh
# walk.sh NAME X Z: select NAME and repeat mv.sh clicks toward (X,Z) until arrived (<1.5 m), out of Movement or stuck.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
./select.sh "$1" > /dev/null
for i in 1 2 3 4; do
  l=$(grep "^pm $1 " "$D/BuildAdvisor_scan.txt"); mvv=$(echo "$l" | sed 's/.*Move=\([0-9.]*\).*/\1/'); x=$(echo "$l" | sed 's/.*@\([-0-9.]*\),.*/\1/'); z=$(echo "$l" | sed 's/.*,\([-0-9.]*\)$/\1/')
  awk -v m=$mvv -v x=$x -v z=$z -v tx=$2 -v tz=$3 'BEGIN{exit !(m < 0.8 || sqrt((tx-x)^2+(tz-z)^2) < 1.5)}' && break
  r=$(./mv.sh "$1" "$2" "$3"); echo "$r"; echo "$r" | grep -q "Move=$mvv @" && break
done
