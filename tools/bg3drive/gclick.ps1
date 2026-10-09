param([string]$Seq, [int]$GapMs = 700)
# Minimise Claude, focus BG3, then run clickseq
& "$PSScriptRoot\minclaude.ps1" | Out-Null
& "$PSScriptRoot\focuswin.ps1" -TitleLike "Baldur's Gate 3 (" | Out-Null
Start-Sleep -Milliseconds 300
& "$PSScriptRoot\clickseq.ps1" -Seq $Seq -GapMs $GapMs
