#!/bin/sh
# select.sh NAME: select a party member by its portrait (focus first: the first click after focusing is swallowed) and
# verify via the scanner host line. Portraits (frame): Tav 39,420  Lae'zel 39,505  Shadowheart 39,590  Us 89,431.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
case "$1" in Tav) p="39,420";; "Lae'zel") p="39,505";; Shadowheart) p="39,590";; Us) p="89,431";; *) echo "unknown $1"; exit 1;; esac
powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -WaitMs 0 < /dev/null > /dev/null; sleep 0.25
for i in 1 2 3; do
  powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "$p" -GapMs 50 < /dev/null > /dev/null; sleep 0.9
  [ "$(head -1 "$D/BuildAdvisor_scan.txt" | awk '{print $2}')" = "$1" ] && { echo "selected $1"; exit 0; }
  [ "$1" = Us ] && { echo "selected Us (unverified)"; exit 0; }
done
echo "select $1 failed"; exit 1
