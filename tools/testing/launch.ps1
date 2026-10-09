param([int]$TimeoutSec = 180, [switch]$WithLauncher)
# launch.ps1 [-TimeoutSec 180] [-WithLauncher]: starts Baldur's Gate 3 through Steam (skipping the Larian launcher
# unless -WithLauncher) and waits until the game window is up. Prints the seconds it took.
# What happens next is manual: press a key on the title screen, then Continue or Load Game (see CONTRIBUTING).
$names = "bg3_dx11", "bg3"
if (Get-Process -Name $names -ErrorAction SilentlyContinue) { "Baldur's Gate 3 is already running"; exit 0 }
$url = if ($WithLauncher) { "steam://rungameid/1086940" } else { "steam://run/1086940//--skip-launcher/" }
Start-Process $url
$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  $p = Get-Process -Name $names -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($p) { "game window up after {0:N0} s ({1})" -f ((Get-Date) - $t0).TotalSeconds, $p.ProcessName; exit 0 }
  Start-Sleep -Seconds 2
}
"no game window after $TimeoutSec s - check Steam"
exit 1
