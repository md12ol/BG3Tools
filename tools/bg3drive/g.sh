#!/bin/sh
# g.sh "Name: cmd" ["Name: cmd" ...] [-- Name Name ...]
# Runs each engine command for that party member in order (fwalk waits until the walk has settled), then ends the
# turns of the characters listed after "--" (fend), waits for the next ASK (a party turn needing input) and prints
# the state: party lines + living enemies. One call per turn group.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
ends=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--" ]; then shift; ends="$*"; break; fi
  who=${1%%:*}; cmd=${1#*: }
  case "$cmd" in
    fwalk*) n0=$(grep -c "MOVE $who fwalk" "$D/BuildAdvisor_events.txt")
            ./c.sh "as $who: $cmd" 0.5 > /dev/null
            for i in $(seq 1 30); do sleep 0.5; [ "$(grep -c "MOVE $who fwalk" "$D/BuildAdvisor_events.txt")" -gt "$n0" ] && break; done
            echo "$(grep "MOVE $who fwalk" "$D/BuildAdvisor_events.txt" | tail -1 | cut -d' ' -f2-)";;
    fcast*|fjump*) ./c.sh "as $who: $cmd" 3.5 | tail -1;;
    *) ./c.sh "as $who: $cmd" 1 | tail -1;;
  esac
  shift
done
[ -z "$ends" ] && exit 0
n0=$(grep -c "ASK" "$D/BuildAdvisor_events.txt")
for w in $ends; do ./c.sh "as $w: fend" 0.4 > /dev/null; done
for i in $(seq 1 120); do sleep 1; [ "$(grep -c "ASK" "$D/BuildAdvisor_events.txt")" -gt "$n0" ] && break; done
sleep 1.2
grep -E "^combat|^pm" "$D/BuildAdvisor_scan.txt" | sed 's/ R=1 slot1=[0-9]*//' | cut -c1-130
grep -E "character .*hp=" "$D/BuildAdvisor_scan.txt" | awk '{$2=$2; print}' | sed 's/ dx=.*hp=/ hp=/' | cut -c1-90
grep -E "TURN |DIED|ROUND" "$D/BuildAdvisor_events.txt" | tail -6 | cut -d' ' -f2- | tr '\n' '|'; echo
