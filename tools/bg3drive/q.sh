#!/bin/sh
# q.sh "command": send one command to the Autopilot mod and print its own result (waits for the result file's sequence
# number to change - c.sh can print the previous command's result)
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
s0=$(cut -d'|' -f1 "$D/BuildAdvisor_result.txt" 2>/dev/null)
printf '%s' "$1" > "$D/BuildAdvisor_cmd.txt"
for i in $(seq 1 60); do
  sleep 0.1
  s=$(cut -d'|' -f1 "$D/BuildAdvisor_result.txt" 2>/dev/null)
  [ "$s" != "$s0" ] && { cut -d'|' -f2- "$D/BuildAdvisor_result.txt"; exit 0; }
done
echo "TIMEOUT"; exit 1
