#!/bin/sh
# endturn.sh: end the selected party member's turn: focus BG3 (first click after focusing is swallowed, so no click then),
# click End Turn, and retry until the engine logs a TURNEND (max 3 tries).
cd "$(dirname "$0")"
E="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender/BuildAdvisor_events.txt"
powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -WaitMs 0 < /dev/null > /dev/null; sleep 0.3
for i in 1 2 3; do
  n=$(wc -l < "$E")
  powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "1119,792" -GapMs 50 < /dev/null > /dev/null
  for j in $(seq 1 10); do sleep 0.3; tail -n +$((n + 1)) "$E" | grep -q TURNEND && { tail -n +$((n + 1)) "$E" | grep TURNEND; exit 0; }; done
done
echo "endturn: no TURNEND"; exit 1
