#!/bin/sh
# setview.sh: CINEMATIC (normal third-person) camera, zoomed out as far as the game allows (user 2026-10-06; until a66
# this script switched to the tactical top-down view). Reads the camera pitch from the client probe (90 = straight down
# = tactical) and toggles O only when the tactical view is on, then scrolls fully out (game maximum: distance 12) and
# (re)installs the camera director (camdirector.lua, idle until the bot gives it characters to frame).
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
pitch() { sed -n 's/.*pitch=\([0-9-]*\).*/\1/p' "$D/BuildAdvisor_client.txt" | head -1; }
for i in 1 2 3; do
  p=$(pitch); [ -n "$p" ] && [ "$p" -lt 60 ] && break
  powershell -NoProfile -ExecutionPolicy Bypass -File gamekey.ps1 -Keys o < /dev/null > /dev/null; sleep 1
done
# 2026-10-06 (user: "it takes way too long to do something after a save loads"): the zoom survives a load, so only
# scroll when the camera is not already at the game's maximum distance (the 40-notch scroll alone took ~4 s)
dist=$(./cq.sh "(function() local c=Ext.Entity.GetAllEntitiesWithComponent('GameCameraBehavior')[1].GameCameraBehavior return string.format('%.1f', c.DistanceDestination) end)()")
case "$dist" in 12.*) ;; *) powershell -NoProfile -ExecutionPolicy Bypass -File wheel.ps1 -Notches -40 < /dev/null > /dev/null; sleep 0.5;; esac
./cam.sh install > /dev/null
./cq.sh "(function() local B=Mods.Autopilot.BA_CAM B.on=false B.uuids={} B.dist=12 return 'idle' end)()" > /dev/null
echo "pitch $(pitch) dist-before $dist $(./cam.sh status)"
