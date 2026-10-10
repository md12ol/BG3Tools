param([string[]]$Keys, [int]$HoldMs = 120, [int]$GapMs = 300)
# gamekey.ps1 -Keys space [-HoldMs 120] [-GapMs 300]: bring the game to the front (front.ps1), then press the keys as
# scan codes (sendkey.ps1).
& "$PSScriptRoot\front.ps1" -SettleMs 600 | Out-Null
& "$PSScriptRoot\sendkey.ps1" -Keys $Keys -HoldMs $HoldMs -GapMs $GapMs
