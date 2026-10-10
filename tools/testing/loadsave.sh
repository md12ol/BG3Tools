#!/bin/sh
# loadsave.sh SAVE [menu|ingame] [EXPECT]: load a save by its folder suffix (QuickSave_38, AutoSave_12) or its name,
# from the main menu (menu) or from the in-game menu (ingame, default), and wait until it is loaded (waitload.sh: the
# dev eval hook, or BG3_LOAD_SIGNAL_FILE + EXPECT, see there). Prints "loaded SAVE (...)"; exit 2 when the save's
# row was not found or the load was not confirmed.
# The row is found by its label with OCR (QuickSave_10 is listed as "Quicksave 10 - <region>", a named save by its
# name); a folded campaign group is unfolded first. A template image tpl_<save name>.png (lower case, spaces as _) in
# BG3_TEMPLATE_DIR (default: BG3_SHOT_DIR) is matched instead when present (findrow.py, needs numpy and Pillow).
# From the main menu the row computed from the folder order is the last resort (row 0 at y=169, 27.3 px per row).
# Clicks are in the 1389x868 frame; the game must run borderless or fullscreen (borderless.ps1).
here=$(cd "$(dirname "$0")" && pwd)
SHOTS=${BG3_SHOT_DIR:-$here/../../screenshots}
TPLS=${BG3_TEMPLATE_DIR:-$SHOTS}
S="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/PlayerProfiles"
where=${2:-ingame}
[ -z "$1" ] && { echo "usage: loadsave.sh SAVE [menu|ingame] [EXPECT]"; exit 2; }
ps1() { f=$1; shift; powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/$f")" "$@" < /dev/null 2>/dev/null; }
idx=$(ls -t "$S"/*/Savegames/Story/ | grep -n "__$1\$" | head -1 | cut -d: -f1)
[ -z "$idx" ] && { echo "no save $1"; exit 1; }
idx=$((idx - 1))
y=$(awk -v i=$idx 'BEGIN{printf "%d", 169 + i * 27.3}')
notches=0
# rows below y 700 need the list scrolled: one wheel notch moves it 19 px
[ "$y" -gt 700 ] && notches=$(( (y - 700 + 18) / 19 )) && y=$(( y - notches * 19 ))
if [ "$where" = menu ]; then
  ps1 go.ps1 -Seq "308,479" -WaitMs 6000 > /dev/null
else
  # the first click after focusing is swallowed: spend it on the first portrait (harmless), then open the menu
  ps1 go.ps1 -Seq "39,420" -WaitMs 500 > /dev/null
  ps1 clickseq.ps1 -Seq "1370,15" > /dev/null; sleep 1.2
  ps1 clickseq.ps1 -Seq "694,456" > /dev/null; sleep 6
fi
tpl="$TPLS/tpl_$(echo "$1" | tr ' A-Z' '_a-z').png"
# The Load list is grouped by campaign (others folded), so a row computed from the folder order can land on another
# save of the same campaign. ocr_row prints the frame y of the row whose label matches, or "none".
ocr_row() {
  want=$(echo "$1" | sed -E 's/^QuickSave_/Quicksave /; s/^AutoSave_/Autosave /')
  ps1 ocrscreen.ps1 -All | python -c "
import re, sys
def norm(s): return re.sub(r'[^a-z0-9]', '', s.lower().replace('l', '1').replace('i', '1').replace('o', '0'))
want = sys.argv[1]
full, head = norm(want), norm(want.split(' - ')[0])
rows = [l.split(' ', 2) for l in sys.stdin.read().splitlines() if l.count(' ') >= 2]
rows = [(int(x), int(y), t) for x, y, t in rows if x.isdigit() and y.isdigit() and int(x) < 600 and int(y) > 120]
hit = [r for r in rows if norm(r[2]) == full or norm(r[2].split(' - ')[0]) == full]
if not hit and ' - ' in want:
    hit = [r for r in rows if norm(r[2].split(' - ')[0]) == head]
    hit = hit if len(hit) == 1 else []
print(hit[0][1] if hit else 'none')
" "$want"
}
if [ ! -f "$tpl" ]; then
  # the list can take well over 6 s to fill: read it until the label shows
  r=none
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    r=$(ocr_row "$1"); [ "$r" != none ] && break
    # the Load Game click can be swallowed while the pause menu fades in: the menu (its Resume button) is still up
    if [ "$where" != menu ] && ps1 ocrscreen.ps1 -Find "Resume" | grep -q found; then
      ps1 clickseq.ps1 -Seq "694,456" > /dev/null; sleep 4; continue
    fi
    ps1 ocrscreen.ps1 -Find "Save Files" | grep -q found && [ -n "$(ps1 ocrscreen.ps1 -All | awk '$1 < 600 && $2 > 150' | head -1)" ] && break
    sleep 2
  done
  if [ "$r" = none ]; then
    # the save's campaign may be a folded group: unfold it by its header (the folder name before "-<digits>__")
    camp=$(ls "$S"/*/Savegames/Story/ | grep "__$1\$" | head -1 | sed -E 's/-[0-9]+__.*$//')
    h=$([ -n "$camp" ] && ocr_row "$camp")
    if [ -n "$h" ] && [ "$h" != none ]; then
      ps1 clickseq.ps1 -Seq "235,$h" > /dev/null; sleep 1.5
      r=$(ocr_row "$1")
    fi
  fi
  if [ "$r" != none ]; then y=$r; notches="ocr"
  elif [ "$where" != menu ]; then echo "load of $1: row label not found in the in-game Load list"; exit 2; fi
fi
if [ -f "$tpl" ]; then
  mkdir -p "$SHOTS"; y=""
  for k in $(seq 1 44); do
    ps1 crop.ps1 -Out "$(cygpath -w "$SHOTS/list_now.png")" -MaxW 2560 > /dev/null
    r=$(python "$here/findrow.py" "$SHOTS/list_now.png" "$tpl"); case "$r" in none*) ;; *) y=${r% *}; break;; esac
    # the list fills late (autosave "Saving..." / many saves): wait first, scroll only after 80 s
    if [ "$k" -le 40 ]; then sleep 2; else ps1 wheel.ps1 -Notches -5 -X 400 -Y 500 > /dev/null; sleep 0.8; fi
  done
  [ -z "$y" ] && { echo "load of $1: row not found on screen"; exit 2; }
  notches="found"
else
  [ "$notches" != ocr ] && [ "$notches" -gt 0 ] && { ps1 wheel.ps1 -Notches -$notches -X 400 -Y 500 > /dev/null; sleep 0.6; }
fi
ps1 clickseq.ps1 -Seq "235,$y" > /dev/null; sleep 0.7
# a click right after another tool had focus can be swallowed: click the row again (single clicks, not a double-click)
ps1 clickseq.ps1 -Seq "235,$y" > /dev/null; sleep 0.6
if [ "$where" = menu ]; then "$here/waitload.sh" arm --no-eval > /dev/null; else "$here/waitload.sh" arm > /dev/null; fi
ps1 clickseq.ps1 -Seq "780,808" > /dev/null
t0=$(date +%s)
out=$("$here/waitload.sh" wait "$3" "$([ -n "$3" ] && echo 90 || echo 120)"); rc=$?
[ $rc -ne 0 ] && { echo "load of $1: $out"; exit 2; }
sleep 2
echo "loaded $1 (row $idx, y $y, scrolled $notches) in $(( $(date +%s) - t0 )) s"
echo "$out" | tail -n +2
