#!/bin/sh
# waitev.sh "regex" [maxsec]: wait until a NEW line matching regex appears in BuildAdvisor_events.txt; print new lines.
E="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender/BuildAdvisor_events.txt"
[ -f "$E" ] || : > "$E"
n0=$(wc -l < "$E")
for i in $(seq 1 $(( ${2:-120} * 4 ))); do
  if tail -n +$((n0 + 1)) "$E" | grep -q -E "$1"; then break; fi
  sleep 0.25
done
tail -n +$((n0 + 1)) "$E"
