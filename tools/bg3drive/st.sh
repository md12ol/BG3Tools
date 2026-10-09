#!/bin/sh
# st.sh: combat + party state from the engine (who is host/active, HP, AP/BA/Move/R, slots, weapon)
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
sed -n '1p;2p;4,8p' "$D/BuildAdvisor_scan.txt" | grep -E "^host|^last|^combat|^pm" | sed 's/ @.*//'
