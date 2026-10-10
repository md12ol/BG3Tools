param([double]$X0 = 0, [double]$Y0 = 0, [double]$X1 = 1, [double]$Y1 = 1, [string]$Out = "", [int]$MaxW = 1000)
# crop.ps1 [-X0 0 -Y0 0 -X1 1 -Y1 1] [-Out file.jpg] [-MaxW 1000]: save a JPEG of part of the screen, given as fractions
# of its width and height (default: all of it), scaled down to at most MaxW pixels wide. Default file: crop.png in
# BG3_SHOT_DIR (environment) or the screenshots folder of this repository.
# Per-monitor-v2 DPI awareness and no Windows Forms: SetProcessDPIAware + Screen.Bounds return a magnified top-left
# part of the screen on a scaled (e.g. 125 %) display.
if (-not $Out) {
  $dir = if ($env:BG3_SHOT_DIR) { $env:BG3_SHOT_DIR } else { Join-Path (Split-Path (Split-Path $PSScriptRoot)) "screenshots" }
  New-Item -ItemType Directory -Force $dir | Out-Null
  $Out = Join-Path $dir "crop.png"
}
Add-Type -Name D -Namespace CropDpi -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);'
[CropDpi.D]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing
$W = [CropDpi.D]::GetSystemMetrics(0); $H = [CropDpi.D]::GetSystemMetrics(1)
$f = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($f); $g.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size $W, $H))
$r = New-Object System.Drawing.Rectangle ([int]($X0 * $W)), ([int]($Y0 * $H)), ([int](($X1 - $X0) * $W)), ([int](($Y1 - $Y0) * $H))
$c = $f.Clone($r, $f.PixelFormat)
if ($c.Width -gt $MaxW) { $s = New-Object System.Drawing.Bitmap $c, $MaxW, ([int]($c.Height * $MaxW / $c.Width)); $c.Dispose(); $c = $s }
$c.Save($Out, [System.Drawing.Imaging.ImageFormat]::Jpeg)
"saved ${W}x${H} crop"
