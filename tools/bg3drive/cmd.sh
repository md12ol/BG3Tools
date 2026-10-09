#!/bin/sh
# cmd.sh "walk x y z" | "walkto name" | "use/takeall/pickup name[#n]" [lines]: send a scanner command, wait until the
# host stops moving, show scan. Warns if a walk moved >12 m in the first ~1.5 s (game teleported: target unreachable).
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
pos() { head -1 "$D/BuildAdvisor_scan.txt" | sed -n 's/.*x=\(-*[0-9.]*\) y=.* z=\(-*[0-9.]*\) .*/\1 \2/p'; }
p0=$(pos)
echo "$1" > "$D/BuildAdvisor_cmd.txt"
sleep 1.5
p1=$(pos)
echo "$p0 $p1" | awk '{d=sqrt(($3-$1)^2+($4-$2)^2); if (d>12) print "WARNING: moved " d " m in 1.5 s - teleported, target probably unreachable"}'
prev=""
for i in $(seq 1 30); do
  cur=$(head -1 "$D/BuildAdvisor_scan.txt" | sed 's/t=.*//')
  [ "$cur" = "$prev" ] && break
  prev=$cur; sleep 1.1
done
head -"${2:-25}" "$D/BuildAdvisor_scan.txt"
