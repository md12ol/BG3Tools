#!/bin/sh
# ev.sh [-m Mod] client|server <lua file or ->: run Lua in the running game through a mod's dev eval hook and print
# the output. The mod (default LootAdvisor) must have "Dev": true in <Mod>_settings.json in the Script Extender
# folder; it then polls for <Mod>_<side>_eval.lua there and answers in <Mod>_<side>_eval_out.txt.
#   echo 'print(Ext.Utils.Version())' | tools/testing/ev.sh server -
mod=LootAdvisor
if [ "$1" = "-m" ]; then mod=$2; shift 2; fi
case "$1" in client|server) ;; *) echo "usage: ev.sh [-m Mod] client|server <lua file or ->"; exit 2;; esac
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
S="${mod}_$1"
rm -f "$D/${S}_eval_out.txt"
if [ "$2" = "-" ] || [ -z "$2" ]; then cat > "$D/${S}_eval.lua"; else cp "$2" "$D/${S}_eval.lua"; fi
for _ in $(seq 1 40); do
  [ -f "$D/${S}_eval_out.txt" ] && { cat "$D/${S}_eval_out.txt"; echo; exit 0; }
  sleep 0.25
done
echo "(no output after 10 s: is the game running, a save loaded and \"Dev\": true set for $mod?)"; exit 1
