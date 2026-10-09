param([int]$X, [int]$Y)
# Hold Alt (labels shown) and click a label at frame (X,Y)
$j = Start-Job -ScriptBlock { param($d) & "$d\gamekey.ps1" -Keys alt -HoldMs 2500 | Out-Null } -ArgumentList $PSScriptRoot
Start-Sleep -Milliseconds 1400
& "$PSScriptRoot\clickseq.ps1" -Seq "$X,$Y" | Out-Null
Wait-Job $j -Timeout 5 | Out-Null; Remove-Job $j -Force
"ok"
