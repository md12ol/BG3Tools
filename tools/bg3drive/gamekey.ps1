param([string[]]$Keys, [int]$HoldMs = 120, [int]$GapMs = 300)
# Minimise Claude, bring BG3 to the front, then send scan-code keys (the game ignores VK-only input).
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-Type -Name W -Namespace GK -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { [GK.W]::ShowWindow($_.MainWindowHandle, 6) | Out-Null }
& "$dir\focuswin.ps1" -TitleLike "Baldur's Gate 3 (" | Out-Null
Start-Sleep -Milliseconds 600
& "$dir\sendkey.ps1" -Keys $Keys -HoldMs $HoldMs -GapMs $GapMs
