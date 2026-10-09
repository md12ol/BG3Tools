param([int]$TimeoutSec = 60)
# quit.ps1 [-TimeoutSec 60]: asks Baldur's Gate 3 to close (the same request as the window's close button) and waits
# for the process to exit. It never force-kills the game: a killed game can leave a damaged profile or save behind.
# If the game shows a "quit?" confirmation instead of closing, confirm it in the game (or quit from its menu).
$names = "bg3_dx11", "bg3"
$p = Get-Process -Name $names -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
if (-not $p) { "not running"; exit 0 }
$p | ForEach-Object { $_.CloseMainWindow() | Out-Null }
$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  if (-not (Get-Process -Name $names -ErrorAction SilentlyContinue)) { "quit after {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds; exit 0 }
  Start-Sleep -Seconds 1
}
"still running after $TimeoutSec s - confirm the quit in the game, or quit from its menu"
exit 1
