param([string]$Seq, [int]$GapMs = 700)
# gclick.ps1 -Seq "x,y;x,y" [-GapMs 700]: bring the game to the front (front.ps1), then click like clickseq.ps1.
& "$PSScriptRoot\front.ps1" -SettleMs 300 | Out-Null
& "$PSScriptRoot\clickseq.ps1" -Seq $Seq -GapMs $GapMs
