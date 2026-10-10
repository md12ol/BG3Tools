param([string]$Out = "", [int]$MaxW = 4000, [switch]$Window)
# screenshot.ps1 [-Out file.png] [-MaxW 4000] [-Window]: saves the whole primary screen as PNG (default: screenshots/<time>.png
# in the BG3Tools folder) and prints the file name. Per-monitor DPI aware, so a scaled display is captured at full
# resolution. Bring the game to the front yourself first (borderless window or fullscreen).
# -Window captures only the game window with PrintWindow instead, even while other windows cover it.
Add-Type -Name D -Namespace ShotDpi -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);'
[ShotDpi.D]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing
if (-not $Out) {
  $dir = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "screenshots"
  New-Item -ItemType Directory -Force $dir | Out-Null
  $Out = Join-Path $dir ((Get-Date -Format "yyyy-MM-dd_HHmmss") + ".png")
}
if ($Window) {
  $p = Get-Process -Name "bg3_dx11", "bg3" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { "the game is not running"; exit 1 }
  Add-Type @"
using System; using System.Runtime.InteropServices;
public class ShotWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
}
"@
  $r = New-Object ShotWin+RECT; [ShotWin]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
  $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
  [ShotWin]::PrintWindow($p.MainWindowHandle, $dc, 2) | Out-Null   # 2 = PW_RENDERFULLCONTENT (DirectX content)
  $g.ReleaseHdc($dc); $g.Dispose()
} else {
  $W = [ShotDpi.D]::GetSystemMetrics(0); $H = [ShotDpi.D]::GetSystemMetrics(1)
  $bmp = New-Object System.Drawing.Bitmap $W, $H
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size $W, $H))
  $g.Dispose()
}
if ($bmp.Width -gt $MaxW) {
  $small = New-Object System.Drawing.Bitmap $bmp, $MaxW, ([int]($bmp.Height * $MaxW / $bmp.Width))
  $bmp.Dispose(); $bmp = $small
}
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$Out
