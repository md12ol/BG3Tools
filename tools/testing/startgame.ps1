param([string]$Mode = "continue", [int]$TimeoutSec = 180, [switch]$NoLaunch)
# startgame.ps1 [-Mode continue|menu] [-TimeoutSec 180] [-NoLaunch]: start the game and click through its start
# screens as each appears, recognised by their text (ocrscreen.ps1), with no fixed waits.
#   menu      stop at the main menu (then load a save with loadsave.sh)
#   continue  also click Continue and return once the main menu is gone; waitload.sh wait confirms the load
#             (restart.sh does both).
# The game is started from BG3_DIR (environment: the install folder holding bin\bg3_dx11.exe) when set, else through
# Steam; both skip the Larian launcher. -NoLaunch works on a game that is already starting or at its menu.
# Before a launch the display mode is checked (borderless.ps1 -Fix: borderless, never windowed).
# Script Extender's Devel builds show an "experimental version" dialog at every start and the game waits until Accept
# is clicked: it is clicked where OCR finds the button, else at its usual spot (694,497).
. "$PSScriptRoot\lib_input.ps1"
$names = "bg3_dx11", "bg3"
$t0 = Get-Date
function Log($m) { Write-Host ("{0,7:N1}s  {1}" -f ((Get-Date) - $t0).TotalSeconds, $m) }
function Ocr { & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\ocrscreen.ps1" -All }
function Has($lines, $text) { foreach ($l in $lines) { if ($l.ToLower().Contains($text)) { return $true } }; return $false }
function At($lines, $text) {   # frame x,y of the first OCR line containing $text, or $null
  foreach ($l in $lines) { $x, $y, $t = $l.Split(' ', 3); if ($t -and $t.ToLower().Contains($text)) { return [int]$x, [int]$y } }
  return $null
}
function Front { & "$PSScriptRoot\front.ps1" | Out-Null }

if (-not $NoLaunch) {
  if (Get-Process -Name $names -ErrorAction SilentlyContinue) { Log "the game is already running (use -NoLaunch)"; exit 1 }
  & "$PSScriptRoot\borderless.ps1" -Fix | ForEach-Object { Log $_ }
  if ($env:BG3_DIR) {
    Start-Process -FilePath "$env:BG3_DIR\bin\bg3_dx11.exe" -WorkingDirectory "$env:BG3_DIR\bin" -ArgumentList "--skip-launcher"
  } else {
    Start-Process "steam://run/1086940//--skip-launcher/"
  }
  Log "launched"
}
while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  $p = Get-Process -Name $names -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($p) { break }; Start-Sleep -Milliseconds 300
}
if (-not $p) { Log "TIMEOUT: no game window"; exit 1 }
Front; Log "game window up"

# Title screen -> main menu. The main menu is recognised by its "Load Game" entry; until then: accept the Script
# Extender dialog when it shows, else click the middle of the screen ("press any key"; a click on a splash only
# dismisses it).
$menu = $false; $warned = $false
while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSec) {
  Front
  $lines = @(Ocr)
  if (Has $lines "experimental version") {
    $xy = At $lines "accept"; if (-not $xy) { $xy = 694, 497 }
    FrameClick $xy[0] $xy[1]; Log "Script Extender experimental-version dialog -> Accept ($($xy -join ','))"
    Start-Sleep -Milliseconds 800; continue
  }
  if ((Has $lines "load game") -and ((Has $lines "quit") -or (Has $lines "options"))) { $menu = $true; break }
  if (-not $warned) { & "$PSScriptRoot\borderless.ps1" | Where-Object { $_ -like "WINDOWED*" } | ForEach-Object { Log $_ }; $warned = $true }
  FrameClick 694 600
  Start-Sleep -Milliseconds 700
}
if (-not $menu) { Log "TIMEOUT: main menu not recognised"; exit 1 }
Log "main menu"
if ($Mode -ne "continue") { exit 0 }

# Continue: click it (where OCR read it, else its usual spot) until the main menu is gone.
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt 60) {
  $xy = At $lines "continue"; if (-not $xy) { $xy = 307, 386 }
  FrameClick $xy[0] $xy[1]; Start-Sleep -Milliseconds 1500
  $lines = @(Ocr)
  if (Has $lines "mod verification") { Log "Continue clicked: Mod Verification dialog up (waitload.sh accepts it)"; exit 0 }
  if (-not (Has $lines "load game")) { Log "Continue clicked: loading the latest save"; exit 0 }
  Front
}
Log "TIMEOUT: the main menu stayed up after Continue"; exit 1
