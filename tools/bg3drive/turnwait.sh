#!/bin/sh
# turnwait.sh NAME: wait (max 90 s) until the scanner host (= active party member in combat) is NAME, then print state
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
for i in $(seq 1 45); do h=$(head -1 "$D/BuildAdvisor_scan.txt" | awk '{print $2}'); [ "$h" = "$1" ] && break; sleep 2; done
sleep 1.5; grep -E "host|party" "$D/BuildAdvisor_scan.txt"
