#!/bin/sh
# dialog_open.sh: exit 0 when a dialogue is on screen: a party member within 20 m of the host is a reserved speaker
# (companions in their own scenes elsewhere on the beach are reserved too - a30 false positive) (Osi.IsSpeakerReserved),
# which also works when a save was loaded mid-dialogue; the events log (unmatched "DIALOG start") is the fallback.
cd "$(dirname "$0")"
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
r=$(./q.sh 'lua (function() local h=Osi.GetHostCharacter(); local hx,_,hz=Osi.GetPosition(h); local n=0 for _,e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do local u=e.Uuid.EntityUuid if Osi.IsPartyMember(u,1)==1 and Osi.IsSpeakerReserved(u)==1 then local x,_,z=Osi.GetPosition(u); if x and math.abs(x-hx)+math.abs(z-hz) < 20 then n=n+1 end end end return "speakers "..n end)()')
case "$r" in *"speakers 0"*) exit 1;; *"speakers "[1-9]*) exit 0;; esac
last=$(grep " DIALOG " "$D/BuildAdvisor_events.txt" | tail -1)
case "$last" in *"DIALOG start"*) exit 0;; *) exit 1;; esac
