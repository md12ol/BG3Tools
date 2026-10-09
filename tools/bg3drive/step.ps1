param([string]$Seq = "", [int]$GapMs = 700, [int]$WaitMs = 2500)
# Click (frame coords) then wait and save a 900px snapshot to crop.png. Seq may be empty (just snapshot).
if ($Seq) { & "$PSScriptRoot\gclick.ps1" -Seq $Seq -GapMs $GapMs | Out-Null }
Start-Sleep -Milliseconds $WaitMs
& "$PSScriptRoot\crop.ps1" -MaxW 900 | Out-Null
"ok"
