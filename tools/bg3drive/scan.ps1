# Alt-highlight snapshot (holds Alt in a background job, captures mid-hold)
$j = Start-Job -ScriptBlock { param($d) & "$d\gamekey.ps1" -Keys alt -HoldMs 2600 | Out-Null } -ArgumentList $PSScriptRoot
Start-Sleep -Milliseconds 1900
& "$PSScriptRoot\crop.ps1" -MaxW 1200 | Out-Null
Wait-Job $j -Timeout 5 | Out-Null; Remove-Job $j -Force
"ok"
