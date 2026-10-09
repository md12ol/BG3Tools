#!/bin/sh
# loadqs.sh ROWY: from the main menu: Load Game, click the save row at frame y ROWY (QuickSave 38 = 252 while AutoSave 7
# is the newest), Load, wait for the scanner. Prints seconds taken.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
t0=$(date +%s)
powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "308,479" -WaitMs 1500 < /dev/null > /dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "230,${1:-252}" < /dev/null > /dev/null; sleep 0.6
m0=$(stat -c %Y "$D/BuildAdvisor_scan.txt")
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "785,808" < /dev/null > /dev/null
for i in $(seq 1 120); do [ "$(stat -c %Y "$D/BuildAdvisor_scan.txt")" != "$m0" ] && break; sleep 1; done
sleep 2; echo "loaded in $(( $(date +%s) - t0 )) s"; sed -n 3p "$D/BuildAdvisor_scan.txt"
