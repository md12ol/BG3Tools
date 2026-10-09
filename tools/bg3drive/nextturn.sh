#!/bin/sh
# nextturn.sh [endfirst]: optionally click End Turn, then wait until a party member is host with AP or BA left
# (= our next turn), print state. No screenshots.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
h0=$(head -1 "$D/BuildAdvisor_scan.txt" | awk '{print $2}')
if [ "$1" = endfirst ]; then
  powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "1119,792" -WaitMs 0 < /dev/null > /dev/null; sleep 2
fi
for i in $(seq 1 60); do
  h=$(head -1 "$D/BuildAdvisor_scan.txt" | awk '{print $2}')
  line=$(grep "^pm $h " "$D/BuildAdvisor_scan.txt")
  if [ "$h" != "$h0" ] || [ "$1" != endfirst ]; then echo "$line" | grep -q -E "AP=1|BA=1" && break; fi
  sleep 1
done
sleep 0.5; ./st.sh
