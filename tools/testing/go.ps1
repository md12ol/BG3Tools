param([string]$Seq = "", [int]$GapMs = 700, [int]$WaitMs = 4000, [switch]$Mini, [int]$Wheel = 0)
# go.ps1 [-Seq "x,y;..."] [-GapMs 700] [-WaitMs 4000] [-Wheel n] [-Mini]: bring the game to the front, optionally turn
# the mouse wheel, click the points (1389x868 frame), wait, bring the game forward again and save a 900 px snapshot
# (crop.png, see crop.ps1). -Mini also saves the top-right minimap area as mini.png next to it.
& "$PSScriptRoot\front.ps1" | Out-Null
if ($Wheel -ne 0) { & "$PSScriptRoot\wheel.ps1" -Notches $Wheel | Out-Null }
if ($Seq) { & "$PSScriptRoot\clickseq.ps1" -Seq $Seq -GapMs $GapMs | Out-Null }
Start-Sleep -Milliseconds $WaitMs
& "$PSScriptRoot\front.ps1" | Out-Null
& "$PSScriptRoot\crop.ps1" -MaxW 900 | Out-Null
if ($Mini) {
  $dir = if ($env:BG3_SHOT_DIR) { $env:BG3_SHOT_DIR } else { Join-Path (Split-Path (Split-Path $PSScriptRoot)) "screenshots" }
  & "$PSScriptRoot\crop.ps1" -X0 0.8 -Y0 0 -X1 1 -Y1 0.33 -MaxW 400 -Out (Join-Path $dir "mini.png") | Out-Null
}
"ok"
