param([string]$Seq = "", [int]$GapMs = 700, [int]$WaitMs = 2500)
# step.ps1 [-Seq "x,y;..."] [-GapMs 700] [-WaitMs 2500]: click (1389x868 frame, game brought to the front), wait, then
# save a 900 px snapshot (crop.png, see crop.ps1). With no -Seq it only takes the snapshot.
if ($Seq) { & "$PSScriptRoot\gclick.ps1" -Seq $Seq -GapMs $GapMs | Out-Null }
Start-Sleep -Milliseconds $WaitMs
& "$PSScriptRoot\crop.ps1" -MaxW 900 | Out-Null
"ok"
