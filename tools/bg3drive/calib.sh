#!/bin/sh
# calib.sh: measure the world->screen mapping for clickgo.sh (tactical view, zoomed fully out) by clicking two
# screen offsets from the centred character and reading the scanner. Writes calib.env (EXX EXY EZX EZY).
# The camera follows the selected character, so it sits at screen centre (694,438) once it stops.
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
cd "$(dirname "$0")"
pos() { head -1 "$D/BuildAdvisor_scan.txt" | sed -n 's/.*x=\(-*[0-9.]*\) y=\(-*[0-9.]*\) z=\(-*[0-9.]*\) .*/\1 \3/p'; }
settle() { sleep 0.4; prev=""; for i in $(seq 1 10); do sleep 1.1; cur=$(pos); [ "$cur" = "$prev" ] && break; prev=$cur; done; }
res=""
for off in "${1:-0,-210}" "${2:-240,0}" "${3:-0,190}" "${4:--240,0}"; do  # far from the centre: companions stand within ~100 px
  ox=${off%,*}; oy=${off#*,}
  set -- $(pos); x0=$1; z0=$2
  powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "$((694+ox)),$((438+oy));$((694+ox)),$((438+oy))" -GapMs 300 -WaitMs 0 < /dev/null > /dev/null
  settle; set -- $(pos)
  echo "offset $ox,$oy -> world d=($(awk -v a=$x0 -v b=$1 'BEGIN{print b-a}'), $(awk -v a=$z0 -v b=$2 'BEGIN{print b-a}'))"
  res="$res $ox $oy $(awk -v a=$x0 -v b=$1 'BEGIN{print b-a}') $(awk -v a=$z0 -v b=$2 'BEGIN{print b-a}')"
done
# least squares: screen = M * world, M=[[EXX EZX],[EXY EZY]]; use samples that moved > 1 m
echo $res | awk '{n=0; for(i=1;i<=NF;i+=4){sx=$i;sy=$(i+1);dx=$(i+2);dz=$(i+3); if(dx*dx+dz*dz<1) continue;
  a+=dx*dx; b+=dx*dz; c+=dz*dz; px+=sx*dx; qx+=sx*dz; py+=sy*dx; qy+=sy*dz; n++}
  det=a*c-b*b; if(n<2||det==0){print "calibration failed (need 2 good moves)" > "/dev/stderr"; exit 1}
  printf "EXX=%.1f\nEZX=%.1f\nEXY=%.1f\nEZY=%.1f\n", (px*c-qx*b)/det, (qx*a-px*b)/det, (py*c-qy*b)/det, (qy*a-py*b)/det}' > calib.env && cat calib.env
