#!/bin/sh
# hit.sh "name" [n] [rclick]: focus BG3, hover + click (or right-click) the entity on screen via the engine projection.
cd "$(dirname "$0")"
set -- "$1" "${2:-1}" "$3"
p=$(./ent.sh "$1" "$2" "$KIND"); [ -n "$p" ] || { echo "no $1 on probe"; exit 1; }
x=$(echo $p | awk '{print $1}'); y=$(echo $p | awk '{print $2}'); on=$(echo $p | awk '{print $3}')
[ "$on" = 1 ] || { echo "off-screen: $p"; exit 2; }
powershell -NoProfile -ExecutionPolicy Bypass -File minclaude.ps1 < /dev/null > /dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File focuswin.ps1 -TitleLike "Baldur's Gate 3 (" < /dev/null > /dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File hover.ps1 -X $x -Y $y -NoSnap < /dev/null > /dev/null; sleep 0.25
if [ "$3" = rclick ]; then powershell -NoProfile -ExecutionPolicy Bypass -File rclick.ps1 -X $x -Y $y < /dev/null > /dev/null
else powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$x,$y" -GapMs 50 < /dev/null > /dev/null; fi
echo "clicked $x,$y $p"
