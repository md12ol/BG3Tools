param([string]$Out = "", [int]$MaxW = 4000)
# screenshot.ps1 [-Out file.png] [-MaxW 4000]: saves the whole primary screen as PNG (default: screenshots/<time>.png
# in the BG3Tools folder) and prints the file name. Per-monitor DPI aware, so a scaled display is captured at full
# resolution. Bring the game to the front yourself first (borderless window or fullscreen).
Add-Type -Name D -Namespace ShotDpi -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);'
[ShotDpi.D]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing
if (-not $Out) {
  $dir = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "screenshots"
  New-Item -ItemType Directory -Force $dir | Out-Null
  $Out = Join-Path $dir ((Get-Date -Format "yyyy-MM-dd_HHmmss") + ".png")
}
$W = [ShotDpi.D]::GetSystemMetrics(0); $H = [ShotDpi.D]::GetSystemMetrics(1)
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size $W, $H))
$g.Dispose()
if ($bmp.Width -gt $MaxW) {
  $small = New-Object System.Drawing.Bitmap $bmp, $MaxW, ([int]($bmp.Height * $MaxW / $bmp.Width))
  $bmp.Dispose(); $bmp = $small
}
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$Out
