param([switch]$Fix)
# borderless.ps1 [-Fix]: check that the game runs borderless (or fullscreen), never in a window: a title bar shifts
# every click point of these helpers, and a click meant for the game's menu button can hit the window's close button.
#  - game running: reads its window style and exits 1 when the window has a title bar.
#  - game closed: reads FakeFullscreenEnabled (1 = borderless) from graphicSettings.lsx in the game's
#    %LOCALAPPDATA% folder. -Fix sets 0 to 1 and keeps the file as it was in graphicSettings.lsx.before-borderless
#    (written once, so it always holds the original value). The game rewrites this file while it runs and when it
#    quits, so the file is only ever changed with the game closed.
# In the game: Options > Video > Display Mode > Borderless does the same.
$names = "bg3_dx11", "bg3"
$p = Get-Process -Name $names -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($p) {
  Add-Type -Name W -Namespace Borderless -MemberDefinition '[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);'
  $style = [Borderless.W]::GetWindowLong($p.MainWindowHandle, -16)
  if (($style -band 0x00C00000) -eq 0x00C00000) {
    "WINDOWED: the game window has a title bar - switch to Options > Video > Display Mode > Borderless (or quit the game and run borderless.ps1 -Fix)"
    exit 1
  }
  "borderless or fullscreen (no title bar)"; exit 0
}
$file = Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3\graphicSettings.lsx"
if (-not (Test-Path $file)) { "no $file yet (the game writes it at its first start)"; exit 0 }
$text = [IO.File]::ReadAllText($file)
$rx = '(<attribute id="MapKey" type="FixedString" value="FakeFullscreenEnabled"\s*/>\s*<attribute id="Type"[^>]*/>\s*<attribute id="Value" type="int32" value=")(\d+)(")'
$m = [regex]::Match($text, $rx)
if (-not $m.Success) { "FakeFullscreenEnabled is not in graphicSettings.lsx: check Options > Video > Display Mode in the game"; exit 0 }
$old = $m.Groups[2].Value
if ($old -eq "1") { "FakeFullscreenEnabled=1 (borderless)"; exit 0 }
if (-not $Fix) { "FakeFullscreenEnabled=$old (not borderless): run borderless.ps1 -Fix with the game closed"; exit 1 }
$bak = "$file.before-borderless"
if (-not (Test-Path $bak)) { Copy-Item $file $bak }
[IO.File]::WriteAllText($file, [regex]::Replace($text, $rx, '${1}1${3}'))
"FakeFullscreenEnabled $old -> 1 (borderless); the file as it was: $bak"
