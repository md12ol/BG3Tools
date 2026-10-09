param([string]$Mod = "shift", [string]$Key = "space")
# Sends Mod+Key as scan codes to BG3 (focus first). Mod: shift|ctrl|alt.
& "$PSScriptRoot\minclaude.ps1" | Out-Null; & "$PSScriptRoot\focuswin.ps1" -TitleLike "Baldur's Gate 3 (" | Out-Null; Start-Sleep -Milliseconds 400
$src = Get-Content "$PSScriptRoot\sendkey.ps1" -Raw; $i = $src.IndexOf('Add-Type @"'); $j = $src.IndexOf('"@', $i) + 2; Invoke-Expression $src.Substring($i, $j - $i)
$mods = @{ shift = 0x2A; ctrl = 0x1D; alt = 0x38 }; $keys = @{ space = 0x39; g = 0x22; e = 0x12; q = 0x10 }
[SK]::Key([uint16]$mods[$Mod], $false, $false); Start-Sleep -Milliseconds 80
[SK]::Key([uint16]$keys[$Key], $false, $false); Start-Sleep -Milliseconds 100; [SK]::Key([uint16]$keys[$Key], $false, $true)
Start-Sleep -Milliseconds 80; [SK]::Key([uint16]$mods[$Mod], $false, $true)
