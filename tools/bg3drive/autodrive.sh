#!/bin/sh
# autodrive.sh [maxsec]: companion of the in-game autopilot (Server/Auto.lua). Watches BuildAdvisor_events.txt and
# - REQMOVE <who> x y z : selects <who>, real left-click on that floor point (engine camera projection, game pathing)
# - REQPICK <who> x y z : real left-click on the item there (the game walks in range and picks it up)
#   then waits until <who> stops and sends "moved <who>" so the autopilot continues;
# - AUTO <who> endturn  : if no TURNEND follows within 2 s, clicks End Turn (endturn.sh);
# - stops on ASK, COMBAT end or a party member's death.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"; E="$D/BuildAdvisor_events.txt"
n=$(wc -l < "$E"); start=$(date +%s)
pmpos() { grep "^pm $1 " "$D/BuildAdvisor_scan.txt" | sed 's/.*@//'; }
click_world() { # who x y z : click the projected point; if it is outside the safe area, click the farthest safe point on the line
  who=$1; tx=$2; ty=$3; tz=$4
  powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys home < /dev/null > /dev/null; sleep 0.5
  set -- $(pmpos "$who" | tr ',' ' '); x0=$1; z0=$3
  for f in 1 0.85 0.7 0.55 0.4; do
    wx=$(awk -v a=$x0 -v b=$tx -v f=$f 'BEGIN{print a+(b-a)*f}'); wz=$(awk -v a=$z0 -v b=$tz -v f=$f 'BEGIN{print a+(b-a)*f}')
    p=$(./w2s.sh $wx $ty $wz); px=${p% *}; py=${p#* }
    if [ "$px" -gt 230 ] && [ "$px" -lt 1080 ] && [ "$py" -gt 100 ] && [ "$py" -lt 690 ]; then
      powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$px,$py" -GapMs 50 < /dev/null > /dev/null
      echo "  click $who f=$f $px,$py"; return 0
    fi
  done
  echo "  no safe click point for $who"; return 1
}
waitstop() { prev=""; for i in $(seq 1 20); do sleep 0.7; cur=$(pmpos "$1"); [ "$cur" = "$prev" ] && break; prev=$cur; done; }
while [ $(( $(date +%s) - start )) -lt ${1:-600} ]; do
  total=$(wc -l < "$E")
  if [ "$total" -gt "$n" ]; then
    new=$(tail -n +$((n + 1)) "$E"); n=$total
    echo "$new"     # (items no longer get TURN lines: Auto.lua skips non-characters; the helm item-name filter is gone)
    echo "$new" | grep -E "^[0-9]+ REQ(MOVE|PICK) " > "$D/BA_reqs.tmp"
    while read -r req; do
      set -- $req; kind=$2; who=$3; [ "$who" = "Lae'zel" ] || true
      # names with spaces are not used by party members, so fields are fixed: kind who x y z
      ./select.sh "$who" > /dev/null
      if [ "$kind" = REQPICK ]; then
        powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys home < /dev/null > /dev/null; sleep 0.5
        p=$(./w2s.sh $4 $5 $6); px=${p% *}; py=${p#* }
        if [ "$px" -gt 150 ] && [ "$px" -lt 1250 ] && [ "$py" -gt 90 ] && [ "$py" -lt 740 ]; then
          powershell -NoProfile -ExecutionPolicy Bypass -File hover.ps1 -X $px -Y $py -NoSnap < /dev/null > /dev/null; sleep 0.3
          powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$px,$py" -GapMs 50 < /dev/null > /dev/null; echo "  pick-click $who $px,$py"
        else click_world "$who" $4 $5 $6; fi
      else click_world "$who" $4 $5 $6; fi
      sleep 0.6; waitstop "$who"
      printf "moved %s" "$who" > "$D/BuildAdvisor_cmd.txt"; sleep 0.5
    done < "$D/BA_reqs.tmp"
    n=$(wc -l < "$E")
    who=$(echo "$new" | sed -n 's/^[0-9]* AUTO \(.*\) endturn.*/\1/p' | tail -1)
    if [ -n "$who" ]; then sleep 2; tail -n 8 "$E" | grep -q "TURNEND $who" || { echo "  (End Turn for $who)"; ./endturn.sh > /dev/null; }; n=$(wc -l < "$E"); fi
    echo "$new" | grep -q -E "^[0-9]+ (ASK|COMBAT end)" && exit 0
    # a party member died: the party = the scanner's pm lines (generic; the helm party's names were hard-coded here)
    for pm in $(grep "^pm " "$D/BuildAdvisor_scan.txt" | awk '{print $2}'); do
      echo "$new" | grep -q -F " DIED $pm" && exit 0
    done
  fi
  sleep 0.3
done
echo "autodrive timeout"
