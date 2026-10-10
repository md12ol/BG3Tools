param([string]$TitleLike = "Baldur's Gate 3 (", [int]$SettleMs = 250)
# front.ps1 [-TitleLike text] [-SettleMs 250]: bring the game window to the front before clicks or keys.
# BG3_MINIMIZE (environment, optional): comma-separated process names whose windows are minimised first, e.g.
# "Code,WindowsTerminal". A window that keeps the focus can hold the game, and Script Extender's dialogs, behind it.
if ($env:BG3_MINIMIZE) {
  Add-Type -Name W -Namespace FrontMin -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
  foreach ($n in $env:BG3_MINIMIZE.Split(',')) {
    $n = $n.Trim(); if (-not $n) { continue }
    Get-Process -Name $n -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } |
      ForEach-Object { [FrontMin.W]::ShowWindow($_.MainWindowHandle, 6) | Out-Null }
  }
}
$r = & "$PSScriptRoot\focuswin.ps1" -TitleLike $TitleLike
Start-Sleep -Milliseconds $SettleMs
$r
