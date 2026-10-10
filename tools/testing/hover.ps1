param([int]$X, [int]$Y, [switch]$NoSnap)
# hover.ps1 -X 694 -Y 434 [-NoSnap]: move the mouse (real move events, no click) to a 1389x868 frame point, so the
# game shows its hover state or tooltip, then save a 900 px snapshot (crop.png, see crop.ps1) unless -NoSnap.
. "$PSScriptRoot\lib_input.ps1"
$px = FrameX $X; $py = FrameY $Y
foreach ($d in @(4, 0)) { [BG3Mouse]::Move($px - $d, $py - $d); Start-Sleep -Milliseconds 60 }
Start-Sleep -Milliseconds 600
if (-not $NoSnap) { & "$PSScriptRoot\crop.ps1" -MaxW 900 | Out-Null }
"hovered"
