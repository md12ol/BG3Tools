#!/bin/sh
# loadsave.sh SAVENAME [menu|ingame] [EXPECT]: load a save by folder suffix (e.g. QuickSave_38) from the main menu or
# from the in-game menu. The Load list is sorted newest first like the Savegames folders, so the row is computed from the
# folder order (row 0 at y=169, 27.3 px per row in the 1389x868 frame). Waits until the scanner sees the party.
# EXPECT (generic, audit 2026-10-09): extended regexes joined by "&&" that BuildAdvisor_scan.txt must all match before
# the load counts as done - the caller knows where its save starts (attempt.sh passes the helm start positions, which
# used to be hard-coded here). Without EXPECT: the scan file changed and 6 s passed.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
S="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/PlayerProfiles"
idx=$(ls -t "$S"/*/Savegames/Story/ | grep -n "__$1\$" | head -1 | cut -d: -f1)
[ -z "$idx" ] && { echo "no save $1"; exit 1; }
idx=$((idx - 1))
y=$(awk -v i=$idx 'BEGIN{printf "%d", 169 + i * 27.3}')
notches=0
# rows below y 700 need the list scrolled: one wheel notch moves it 19 px (calibrated 2026-10-05)
[ "$y" -gt 700 ] && notches=$(( (y - 700 + 18) / 19 )) && y=$(( y - notches * 19 ))
if [ "${2:-ingame}" = menu ]; then
  powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "308,479" -WaitMs 6000 < /dev/null > /dev/null
else
  # first click after focusing is swallowed: spend it on Tav's portrait (harmless), then open the menu
  powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "39,420" -WaitMs 500 < /dev/null > /dev/null
  powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "1370,15" < /dev/null > /dev/null; sleep 1.2
  powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "694,456" < /dev/null > /dev/null; sleep 6
fi
# find the row on screen (the game caches its list, so folder order can be stale): template tpl_<name>.png if present
tpl="tpl_$(echo "$1" | tr ' A-Z' '_a-z').png"
if [ -f "$tpl" ]; then
  y=""
  for k in $(seq 1 44); do
    powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -Out "$(cygpath -w "$PWD")\list_now.png" -MaxW 2560 < /dev/null > /dev/null 2>&1
    r=$(python findrow.py list_now.png "$tpl"); case "$r" in none*) ;; *) y=${r% *}; break;; esac
    # the list fills late (autosave "Saving..." / many saves): wait first, scroll only after 12 s
    if [ $k -le 40 ]; then sleep 2; else powershell -NoProfile -ExecutionPolicy Bypass -File wheel.ps1 -Notches -5 -X 400 -Y 500 < /dev/null > /dev/null; sleep 0.8; fi
  done
  [ -z "$y" ] && { echo "load of $1: row not found on screen"; exit 2; }
  notches="found"
else
  [ "$notches" -gt 0 ] && { powershell -NoProfile -ExecutionPolicy Bypass -File wheel.ps1 -Notches -$notches -X 400 -Y 500 < /dev/null > /dev/null; sleep 0.6; }
fi
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "235,$y" < /dev/null > /dev/null; sleep 0.7
# a click right after another tool had focus can be swallowed: click the row again (single clicks, not a double-click)
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "235,$y" < /dev/null > /dev/null; sleep 0.6
m0=$(stat -c %Y "$D/BuildAdvisor_scan.txt")
powershell -NoProfile -ExecutionPolicy Bypass -File clickseq.ps1 -Seq "780,808" < /dev/null > /dev/null
t0=$(date +%s)
# a level change keeps the old level's scan running until it unloads: poll for the caller's expected state
expect_ok() {   # every "&&"-separated regex of $1 matches a line of the scan file
  rest=$1
  while [ -n "$rest" ]; do
    pat=${rest%%&&*}
    grep -E -q "$pat" "$D/BuildAdvisor_scan.txt" || return 1
    [ "$pat" = "$rest" ] && break
    rest=${rest#*&&}
  done
  return 0
}
# the game's "Mod Verification" dialog (after a pak rebuild the save's mod list differs) stops the load until "Start
# Game" is clicked - the one dialog the user lets the scripts accept (2026-10-09). Recognised by its text (Windows OCR,
# ocrscreen.ps1), checked a few times while the load is not confirmed yet; the button is clicked where OCR found it.
modverif() {
  r=$(powershell -NoProfile -ExecutionPolicy Bypass -File ocrscreen.ps1 -Find "Mod Verification" < /dev/null 2>/dev/null)
  case "$r" in found*) ;; *) return 1;; esac
  b=$(powershell -NoProfile -ExecutionPolicy Bypass -File ocrscreen.ps1 -Find "Start Game" < /dev/null 2>/dev/null)
  case "$b" in found*) set -- $b; xy="$2,$3";; *) xy="639,765";; esac
  powershell -NoProfile -ExecutionPolicy Bypass -File go.ps1 -Seq "$xy" -WaitMs 500 < /dev/null > /dev/null
  echo "Mod Verification dialog -> Start Game ($xy)" >&2
  return 0
}
if [ -n "$3" ]; then
  ok=0
  for i in $(seq 1 90); do
    sleep 1
    if [ "$(stat -c %Y "$D/BuildAdvisor_scan.txt")" != "$m0" ] && expect_ok "$3"; then ok=1; break; fi
    case $i in 6|14|24|36) modverif;; esac
  done
  if [ $ok != 1 ]; then
    shot="loadfail_$(date +%H%M%S).png"
    powershell -NoProfile -ExecutionPolicy Bypass -File crop.ps1 -Out "$(cygpath -w "$PWD")\$shot" < /dev/null > /dev/null 2>&1
    echo "load of $1 NOT confirmed after 90 s (scan never matched: $3) - screen: $shot"; exit 2
  fi
else
  for i in $(seq 1 120); do sleep 1; [ "$(stat -c %Y "$D/BuildAdvisor_scan.txt")" != "$m0" ] && [ $(( $(date +%s) - t0 )) -gt 6 ] && break
    case $i in 6|14|24|36) modverif;; esac; done
fi
sleep 2
echo "loaded $1 (row $idx, y $y, scrolled $notches) in $(( $(date +%s) - t0 )) s"; grep "^pm" "$D/BuildAdvisor_scan.txt" | cut -c1-90
