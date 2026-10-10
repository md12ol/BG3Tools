param([int]$MaxSec = 240, [string]$Out = "")
# waitplay.ps1 [-MaxSec 240] [-Out file.jpg]: wait until a cutscene's letterbox (black bands at the top and bottom of
# the screen) is gone, i.e. the game or dialogue UI is up, then save a 900 px snapshot (default crop.png, see crop.ps1).
if (-not $Out) {
  $dir = if ($env:BG3_SHOT_DIR) { $env:BG3_SHOT_DIR } else { Join-Path (Split-Path (Split-Path $PSScriptRoot)) "screenshots" }
  New-Item -ItemType Directory -Force $dir | Out-Null
  $Out = Join-Path $dir "crop.png"
}
Add-Type -Name D -Namespace Dpi2 -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v);'; [Dpi2.D]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$f = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($f)
$t0 = Get-Date; $ok = 0
while (((Get-Date) - $t0).TotalSeconds -lt $MaxSec) {
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $s = New-Object System.Drawing.Bitmap $f, 64, 40
  $top = 0; for ($x = 0; $x -lt 64; $x++) { for ($y = 0; $y -lt 3; $y++) { $c = $s.GetPixel($x, $y); $top += $c.R + $c.G + $c.B } }
  $bot = 0; for ($x = 0; $x -lt 64; $x++) { for ($y = 37; $y -lt 40; $y++) { $c = $s.GetPixel($x, $y); $bot += $c.R + $c.G + $c.B } }
  $s.Dispose()
  $top = $top / (64 * 3 * 3); $bot = $bot / (64 * 3 * 3)
  if ($top -gt 12 -and $bot -gt 12) { $ok++ } else { $ok = 0 }
  if ($ok -ge 2) { break }
  Start-Sleep -Milliseconds 1000
}
$o = New-Object System.Drawing.Bitmap $f, 900, 562; $o.Save($Out, [System.Drawing.Imaging.ImageFormat]::Jpeg)
"waited {0:N0}s (top {1:N0}, bottom {2:N0})" -f ((Get-Date) - $t0).TotalSeconds, $top, $bot
