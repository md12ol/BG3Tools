#!/bin/sh
# c.sh "<scanner command>": send one command (no trailing newline) and print the result line.
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
printf "%s" "$1" > "$D/BuildAdvisor_cmd.txt"; sleep ${2:-1.2}; sed -n 2p "$D/BuildAdvisor_scan.txt" | sed 's/^last command: //'
