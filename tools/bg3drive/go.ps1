param([string]$Seq = "", [int]$GapMs = 700, [int]$WaitMs = 4000, [switch]$Mini, [int]$Wheel = 0)
# Minimise Claude + focus BG3, optional wheel, click (frame coords), park cursor, wait, snapshot.
function Front { & "$PSScriptRoot\minclaude.ps1" | Out-Null; & "$PSScriptRoot\focuswin.ps1" -TitleLike "Baldur's Gate 3 (" | Out-Null; Start-Sleep -Milliseconds 250 }
Front
if ($Wheel -ne 0) { & "$PSScriptRoot\wheel.ps1" -Notches $Wheel | Out-Null }
if ($Seq) { & "$PSScriptRoot\clickseq.ps1" -Seq $Seq -GapMs $GapMs | Out-Null }
# (no cursor parking: user asked to drop the move to the bottom-left)
Start-Sleep -Milliseconds $WaitMs
Front
& "$PSScriptRoot\crop.ps1" -MaxW 900 | Out-Null
if ($Mini) { & "$PSScriptRoot\crop.ps1" -X0 0.8 -Y0 0 -X1 1 -Y1 0.33 -MaxW 400 -Out "$PSScriptRoot\mini.png" | Out-Null }
"ok"
