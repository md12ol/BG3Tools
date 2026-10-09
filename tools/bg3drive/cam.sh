#!/bin/sh
# cam.sh install | frame <uuid,uuid,...> | off | status : camera director (camdirector.lua) through the client channel.
cd "$(dirname "$0")"
case "$1" in
  install) ./cq.sh "$(cat camdirector.lua)";;
  frame)   ./cq.sh "(function() local B=Mods.Autopilot.BA_CAM B.on=true B.uuids={} for u in string.gmatch('$2','[^,]+') do B.uuids[#B.uuids+1]=u end return #B.uuids end)()";;
  off)     ./cq.sh "(function() Mods.Autopilot.BA_CAM.on=false return 'off' end)()";;
  status)  ./cq.sh "(function() local B=Mods.Autopilot.BA_CAM local c=Ext.Entity.GetAllEntitiesWithComponent('GameCameraBehavior')[1].GameCameraBehavior return string.format('on=%s n=%d frames=%s rotY=%.0f dist=%.1f pitch=%.1f target=%.1f,%.1f err=%s', tostring(B.on), #(B.uuids or {}), tostring(B.frames), c.RotationY, c.Distance, c.PitchDegrees, c.TargetCurrent[1], c.TargetCurrent[3], tostring(B.err)) end)()";;
esac
