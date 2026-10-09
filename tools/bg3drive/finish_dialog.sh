#!/bin/sh
# finish_dialog.sh: answer/skip the open dialogue until the engine says no dialogue is running (Osi.IsSpeakerReserved)
# - the beach wake-up dialogue has several choice points; one pick left it open and blocked the menu (a27/a28 reloads).
cd "$(dirname "$0")"
# finish_dialog.sh wait: first wait up to 90 s for a dialogue to start (the beach loads, then the wake-up dialogue opens)
if [ "$1" = wait ]; then
  for w in $(seq 1 90); do ./dialog_open.sh && break; sleep 1; done
fi
steps=20; [ "$1" = max6 ] && steps=6
for i in $(seq 1 $steps); do
  ./dialog_open.sh || { echo "dialogue closed after $((i - 1)) steps"; exit 0; }
  # 2026-10-06: skipto.ps1 -Pick 1 answers the choice itself (number key) and keeps skipping in the same process
  # (was: skipto, then pick.sh = two more PowerShell starts + 1.5 s sleep per choice)
  r=$(powershell -NoProfile -ExecutionPolicy Bypass -File skipto.ps1 -RClick -Max 25 -Pick 1 < /dev/null 2>/dev/null | tail -1)
  ./dialog_open.sh || { echo "dialogue closed after $i steps"; exit 0; }
done
echo "dialogue still open after $steps steps"; exit 1
