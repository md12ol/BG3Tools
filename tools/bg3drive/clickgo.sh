#!/bin/sh
# clickgo.sh X Z [maxhop]: REAL movement (mouse clicks, like a player) to world (X,Z) in TACTICAL view (press O first).
# Zoom fully out first (go.ps1 -Wheel -25). First click after focusing is swallowed, so hop 1 clicks twice.
# The camera follows the selected character, which sits at screen centre C. World->screen px per metre:
# ex (world +x) and ez (world +z); calibrated 2026-10-04 at default tactical zoom, camera not rotated. Each hop is
# re-aimed from the scanner position; followers follow as with normal clicks. Never uses the scanner's walk.
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
cd "$(dirname "$0")"
tx=$1; tz=$2; max=${3:-40}  # default: as far as the screen allows in one click (user: fewer, longer clicks)
[ -f calib.env ] && . ./calib.env
CX=${CX:-694}; CY=${CY:-438}; EXX=${EXX:--19}; EXY=${EXY:--33}; EZX=${EZX:--31.5}; EZY=${EZY:-20}
pos() { head -1 "$D/BuildAdvisor_scan.txt" | sed -n 's/.*x=\(-*[0-9.]*\) y=\(-*[0-9.]*\) z=\(-*[0-9.]*\) .*/\1 \3/p'; }
first=1
for hop in $(seq 1 30); do
  set -- $(pos); x=$1; z=$2
  pt=$(awk -v x=$x -v z=$z -v tx=$tx -v tz=$tz -v m=$max -v cx=$CX -v cy=$CY -v a=$EXX -v b=$EXY -v c=$EZX -v d=$EZY 'BEGIN{
    dx=tx-x; dz=tz-z; L=sqrt(dx*dx+dz*dz); if (L<0.8) {print "done"; exit}
    s=(L>m)?m/L:1; dx*=s; dz*=s
    for (k=0;k<20;k++) { sx=cx+dx*a+dz*c; sy=cy+dx*b+dz*d; if (sx>150 && sx<1250 && sy>90 && sy<680) break; dx*=0.8; dz*=0.8 }
    printf "%d,%d", sx, sy }')
  [ "$pt" = "done" ] && { echo "arrived ($x, $z)"; exit 0; }
  if [ $first = 1 ]; then powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "$pt;$pt" -GapMs 300 -WaitMs 0 < /dev/null > /dev/null; first=0
  else powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$pt" < /dev/null > /dev/null; fi
  prev=""; sleep 0.4; for i in $(seq 1 15); do sleep 1.1; cur=$(pos); [ "$cur" = "$prev" ] && break; prev=$cur; done
  set -- $(pos)
  echo "hop $hop: click $pt  ($x,$z) -> ($1,$2)"
  # progress toward the target < 0.5 m: the clicked spot is probably an obstacle/object -> side-step 50 deg left/right
  if awk -v a=$x -v b=$z -v c=$1 -v d=$2 -v tx=$tx -v tz=$tz 'BEGIN{exit !(sqrt((tx-a)^2+(tz-b)^2)-sqrt((tx-c)^2+(tz-d)^2)<0.5)}'; then
    awk -v c=$1 -v d=$2 -v tx=$tx -v tz=$tz 'BEGIN{exit !(sqrt((tx-c)^2+(tz-d)^2)<2.5)}' && { echo "arrived near ($1, $2)"; exit 0; }
    fails=$((${fails:-0}+1)); [ $fails -ge 4 ] && { echo "blocked near ($1,$2) - pick another waypoint"; exit 3; }
    set -- $(pos)
    side=$(awk -v x=$1 -v z=$2 -v tx=$tx -v tz=$tz -v f=$fails 'BEGIN{dx=tx-x; dz=tz-z; L=sqrt(dx*dx+dz*dz); if(L>3){dx*=3/L;dz*=3/L}
      t=((f%2)?1:-1)*0.87*(f>2?1.6:1); printf "%.2f %.2f", x+dx*cos(t)-dz*sin(t), z+dx*sin(t)+dz*cos(t)}')
    set -- $side
    pt=$(awk -v x=$x -v z=$z -v px=$1 -v pz=$2 -v cx=$CX -v cy=$CY -v a=$EXX -v b=$EXY -v c=$EZX -v d=$EZY 'BEGIN{set=0; sx=cx+(px-x)*a+(pz-z)*c; sy=cy+(px-x)*b+(pz-z)*d; printf "%d,%d", sx, sy}')
    powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$pt" < /dev/null > /dev/null
    sleep 0.4; prev=""; for i in $(seq 1 8); do sleep 1.1; cur=$(pos); [ "$cur" = "$prev" ] && break; prev=$cur; done
    echo "  side-step $fails: click $pt -> $(pos)"
  else fails=0; fi
done
echo "gave up at $(pos)"
