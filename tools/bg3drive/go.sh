#!/bin/sh
# go.sh X Y Z: walk the host to (X,Z) in straight hops of <=8 m with "walk" commands, stopping if a hop teleports
# (more than 6 m in the first second = faster than running) or makes no progress. No long-distance walk commands:
# the game teleports the character when a far target has no path.
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
tx=$1; ty=$2; tz=$3
pos() { head -1 "$D/BuildAdvisor_scan.txt" | sed -n 's/.*x=\(-*[0-9.]*\) y=\(-*[0-9.]*\) z=\(-*[0-9.]*\) .*/\1 \2 \3/p'; }
for hop in $(seq 1 25); do
  set -- $(pos); x=$1; y=$2; z=$3
  next=$(awk -v x=$x -v z=$z -v tx=$tx -v tz=$tz 'BEGIN{dx=tx-x; dz=tz-z; d=sqrt(dx*dx+dz*dz); if (d<1.2) {print "done"; exit} s=(d>8)?8/d:1; printf "%.1f %.1f %.1f", x+dx*s, z+dz*s, d}')
  [ "$next" = "done" ] && { echo "arrived ($x, $z)"; exit 0; }
  set -- $next
  echo "walk $1 $ty $2" > "$D/BuildAdvisor_cmd.txt"
  sleep 1.1; set -- $(pos); x1=$1; z1=$3
  tele=$(awk -v a=$x -v b=$z -v c=$x1 -v d=$z1 'BEGIN{m=sqrt((c-a)^2+(d-b)^2); if (m>6) print m}')
  [ -n "$tele" ] && { echo "TELEPORT detected ($tele m in 1.1 s) at hop $hop - stop"; exit 2; }
  sleep 2.2; set -- $(pos)
  moved=$(awk -v a=$x -v b=$z -v c=$1 -v d=$3 'BEGIN{print (sqrt((c-a)^2+(d-b)^2)<0.5)?"no":"yes"}')
  [ "$moved" = "no" ] && { echo "blocked at ($1, $3) after $hop hops"; exit 3; }
done
echo "gave up at $(pos)"
