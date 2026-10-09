#!/bin/sh
# cq.sh "<lua>": run Lua in the CLIENT context (Probe.lua command channel) and print the result. Camera only.
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
seq=$(date +%s%N | cut -c8-16)
printf '%s|%s' "$seq" "$1" > "$D/BuildAdvisor_ccmd.txt"
for i in $(seq 1 60); do
  r=$(cat "$D/BuildAdvisor_cres.txt" 2>/dev/null)
  case "$r" in "$seq|"*) echo "${r#*|}"; exit 0;; esac
  sleep 0.05
done
echo "TIMEOUT (client channel)"; exit 1
