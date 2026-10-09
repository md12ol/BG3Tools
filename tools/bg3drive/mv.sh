#!/bin/sh
# mv.sh NAME X Z: real move click for party member NAME toward world (X,Z). Centres the camera on NAME (Home), projects the
# target with the engine camera (w2s.sh) and, if that pixel is outside the safe play area (HUD, edges), clicks the farthest
# point on the line that is inside it. One click; prints the new position.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
line=$(grep "^pm $1 " "$D/BuildAdvisor_scan.txt"); x0=$(echo "$line" | sed 's/.*@\([-0-9.]*\),.*/\1/'); y0=$(echo "$line" | sed 's/.*@[-0-9.]*,\([-0-9.]*\),.*/\1/'); z0=$(echo "$line" | sed 's/.*,\([-0-9.]*\)$/\1/')
powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys home < /dev/null > /dev/null; sleep 0.6
for f in 1 0.85 0.7 0.55 0.4 0.3; do
  wx=$(awk -v a=$x0 -v b=$2 -v f=$f 'BEGIN{print a+(b-a)*f}'); wz=$(awk -v a=$z0 -v b=$3 -v f=$f 'BEGIN{print a+(b-a)*f}')
  p=$(./w2s.sh $wx $y0 $wz); px=${p% *}; py=${p#* }
  # safe area: not top bar, not minimap/quest panel, not portraits/hotbar/end-turn
  if [ "$px" -gt 230 ] && [ "$px" -lt 1080 ] && [ "$py" -gt 100 ] && [ "$py" -lt 690 ]; then
    powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$px,$py" -GapMs 50 < /dev/null > /dev/null
    prev=""; for i in $(seq 1 12); do sleep 0.8; cur=$(grep "^pm $1 " "$D/BuildAdvisor_scan.txt" | sed 's/.*@//'); [ "$cur" = "$prev" ] && break; prev=$cur; done
    echo "mv $1 f=$f click $px,$py -> $(grep "^pm $1 " "$D/BuildAdvisor_scan.txt" | sed 's/.*Move=\([0-9.]*\).*@/Move=\1 @/')"; exit 0
  fi
done
echo "mv $1: no safe click point"; exit 1
