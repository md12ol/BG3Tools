#!/bin/sh
# ent.sh "name" [n] [kind]: frame (1389x868) screen position of the n-th scan row matching name (optionally only rows of
# kind corpse|character|item), from the client probe (engine camera projection). Prints "x y onscreen | row".
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
grep -i -E "\| +[0-9.]+m +${3:-[a-z]+} +(%%% )?$1" "$D/BuildAdvisor_client.txt" | sed -n "${2:-1}p" |
  awk '{printf "%d %d %s |", $1*1389/2560, $2*868/1600, $3; for(i=5;i<=NF;i++) printf " %s", $i; print ""}'
