#!/bin/sh
# grab.sh "name" [n]: loot the n-th closest corpse/container matching name: click it on screen (engine projection;
# the game walks there and opens it), wait until the host stops, Space = Take All. Prints carried-item count before/after.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
c0=$(sed -n 3p "$D/BuildAdvisor_scan.txt" | sed 's/.*items: \([0-9]*\).*/\1/')
powershell -NoProfile -ExecutionPolicy Bypass -File rclick.ps1 -X 1300 -Y 600 < /dev/null > /dev/null; sleep 0.3  # cancel any selected action first
KIND=corpse ./hit.sh "$1" "${2:-1}" > /dev/null || exit 1
prev=""; for i in $(seq 1 12); do sleep 0.8; cur=$(head -1 "$D/BuildAdvisor_scan.txt" | sed 's/t=.*//'); [ "$cur" = "$prev" ] && break; prev=$cur; done
sleep 0.6; powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys space < /dev/null > /dev/null; sleep 1.2
c1=$(sed -n 3p "$D/BuildAdvisor_scan.txt" | sed 's/.*items: \([0-9]*\).*/\1/'); echo "grab $1: items $c0 -> $c1"
