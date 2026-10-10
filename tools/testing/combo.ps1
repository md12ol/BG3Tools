param([string]$Mod = "shift", [string]$Key = "space")
# combo.ps1 [-Mod shift|ctrl|alt] [-Key space]: press Mod+Key as scan codes with the game brought to the front first.
& "$PSScriptRoot\front.ps1" -SettleMs 400 | Out-Null
. "$PSScriptRoot\lib_input.ps1"
$m = $BG3KeyMap[$Mod.ToLower()]; $k = $BG3KeyMap[$Key.ToLower()]
if ($null -eq $m -or $null -eq $k -or $k -ge 0xE000) { Write-Error "unknown key $Mod+$Key"; exit 1 }
[BG3Keys]::Key([uint16]$m, $false, $false); Start-Sleep -Milliseconds 80
[BG3Keys]::Key([uint16]$k, $false, $false); Start-Sleep -Milliseconds 100; [BG3Keys]::Key([uint16]$k, $false, $true)
Start-Sleep -Milliseconds 80; [BG3Keys]::Key([uint16]$m, $false, $true)
