param([double]$X0 = 0, [double]$Y0 = 0, [double]$X1 = 1, [double]$Y1 = 1, [string]$Out = "$PSScriptRoot\crop.png", [int]$MaxW = 1000)
# Saves a crop of the screen given as fractions of width/height. Per-monitor-v2 DPI awareness and no
# Windows Forms: SetProcessDPIAware + Screen.Bounds returned a magnified top-left 80% on this 125% display.
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
