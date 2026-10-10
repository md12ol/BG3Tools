#!/bin/sh
# waitload.sh arm [--no-eval] | wait [EXPECT] [TIMEOUT]: confirm that a save finished loading (used by loadsave.sh and
# restart.sh; a test can call it around its own load click too).
#   arm   just before the click that starts the load: marks the running game session through the dev eval hook and
#         notes the signal file's time. --no-eval skips the mark (at the main menu there is no session to mark).
#   wait  after the click: polls until the load is confirmed (TIMEOUT s, default 120). Meanwhile it accepts the game's
#         Mod Verification dialog (shown after a pak rebuild changed the save's mod list), recognised by its text.
# How a load is confirmed:
#   BG3_LOAD_SIGNAL_FILE set (environment): a file a mod rewrites while a level runs. The load counts once the file
#     changed after arm and every "&&"-separated extended regex of EXPECT matches one of its lines; without EXPECT,
#     once it changed, 6 s passed and no dialog is up. BG3_LOAD_SHOW (a regex) picks lines of it to print at the end.
#   otherwise the dev eval hook (ev.sh; the mod is BG3_EVAL_MOD, default LootAdvisor, with "Dev": true): the load
#     counts once the server answers from a new session in the Running state. Script Extender starts a fresh Lua state
#     for each loaded save, so the mark set by arm is gone there. Without a mark it also waits 6 s first.
# Exit 0 = confirmed, 2 = not confirmed in time (a screenshot is saved to BG3_SHOT_DIR, default ../../screenshots).
here=$(cd "$(dirname "$0")" && pwd)
SHOTS=${BG3_SHOT_DIR:-$here/../../screenshots}
STATE=${TMPDIR:-/tmp}/bg3_waitload.state
MOD=${BG3_EVAL_MOD:-LootAdvisor}
SIG=${BG3_LOAD_SIGNAL_FILE:-}
ps1() { f=$1; shift; powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/$f")" "$@" < /dev/null 2>/dev/null; }
mtime() { if [ -n "$SIG" ] && [ -f "$SIG" ]; then stat -c %Y "$SIG"; else echo 0; fi; }
ev() { printf '%s\n' "$1" | EV_TIMEOUT=${2:-2} "$here/ev.sh" -m "$MOD" server - 2>/dev/null; }

case "$1" in
  arm)
    mark=none
    if [ "$2" != --no-eval ] && [ -z "$SIG" ]; then
      ev '_G.BG3ToolsLoadMark = true; return "marked"' 3 | grep -q "marked" && mark=marked
    fi
    echo "m0=$(mtime) mark=$mark" > "$STATE"
    echo "armed (session mark: $mark)"; exit 0;;
  wait) ;;
  *) echo "usage: waitload.sh arm [--no-eval] | wait [EXPECT] [TIMEOUT]"; exit 2;;
esac

EXPECT=$2
LIMIT=${3:-120}
t0=$(date +%s)
m0=$t0; mark=none; armed=no
if [ -f "$STATE" ]; then
  armed=yes; m0=$(sed -n 's/.*m0=\([0-9]*\).*/\1/p' "$STATE"); mark=$(sed -n 's/.*mark=\([a-z]*\).*/\1/p' "$STATE"); rm -f "$STATE"
fi
elapsed() { echo $(( $(date +%s) - t0 )); }

expect_ok() {   # every "&&"-separated regex of $EXPECT matches a line of the signal file
  rest=$EXPECT
  while [ -n "$rest" ]; do
    pat=${rest%%&&*}
    grep -E -q "$pat" "$SIG" || return 1
    [ "$pat" = "$rest" ] && break
    rest=${rest#*&&}
  done
  return 0
}
# The Mod Verification dialog stops the load until "Start Game" is clicked: clicked where OCR found it, else at its
# usual spot.
modverif() {
  r=$(ps1 ocrscreen.ps1 -Find "Mod Verification")
  case "$r" in found*) ;; *) return 1;; esac
  b=$(ps1 ocrscreen.ps1 -Find "Start Game")
  case "$b" in found*) set -- $b; xy="$2,$3";; *) xy="639,765";; esac
  ps1 go.ps1 -Seq "$xy" -WaitMs 500 > /dev/null
  echo "Mod Verification dialog -> Start Game ($xy)" >&2
  return 0
}
last_check=0
dialog_due() {   # true at most once per 3 s
  now=$(date +%s); [ $(( now - last_check )) -ge 3 ] || return 1; last_check=$now; return 0
}
loaded() {
  if [ -n "$SIG" ]; then
    # changed since arm (any other time), or written after this wait started when nothing was armed
    if [ $armed = yes ]; then [ -f "$SIG" ] && [ "$(mtime)" != "$m0" ] || return 1
    else [ -f "$SIG" ] && [ "$(mtime)" -gt "$m0" ] || return 1; fi
    if [ -n "$EXPECT" ]; then expect_ok; return; fi
    [ "$(elapsed)" -gt 6 ]; return
  fi
  [ "$mark" = marked ] || [ "$(elapsed)" -gt 6 ] || return 1
  ev 'local ok, st = pcall(function() return tostring(Ext.Server.GetGameState()) end)
return (_G.BG3ToolsLoadMark == nil and (not ok or st:find("Running") ~= nil)) and "loaded" or "waiting"' 2 | grep -q "=> loaded"
}

while [ "$(elapsed)" -lt "$LIMIT" ]; do
  sleep 1
  if loaded; then
    # confirmed only with no dialog on screen; a dialog just accepted means the load is still running
    if modverif; then m0=$(mtime); last_check=$(date +%s); continue; fi
    echo "load confirmed after $(elapsed) s"
    [ -n "$SIG" ] && [ -n "${BG3_LOAD_SHOW:-}" ] && grep -E "$BG3_LOAD_SHOW" "$SIG" | cut -c1-90
    exit 0
  fi
  dialog_due && modverif
done
mkdir -p "$SHOTS"; shot="loadfail_$(date +%H%M%S).png"
ps1 crop.ps1 -Out "$(cygpath -w "$SHOTS/$shot")" > /dev/null
how="the dev eval hook never answered from a new session (\"Dev\": true for $MOD?)"
[ -n "$SIG" ] && how="$(basename "$SIG") never changed${EXPECT:+ to match: $EXPECT}"
echo "load NOT confirmed after $LIMIT s ($how) - screen: $SHOTS/$shot"; exit 2
