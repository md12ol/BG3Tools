param([int]$X, [int]$Y, [int]$WalkMs = 3000)
# Alt-click a loot label (frame coords), wait for the window, then press Take All.
# Take All is found by scanning the screen for the window's "Take All" button: a dark-gold bar under the grid.
& "$PSScriptRoot\altclick.ps1" -X $X -Y $Y | Out-Null
Start-Sleep -Milliseconds $WalkMs
Add-Type -Name D -Namespace LootDpi -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);'
[LootDpi.D]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing
$W = [LootDpi.D]::GetSystemMetrics(0); $H = [LootDpi.D]::GetSystemMetrics(1)
$f = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($f); $g.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size $W, $H))
$s = New-Object System.Drawing.Bitmap $f, 1389, 868
$s.Save("$PSScriptRoot\crop.png", [System.Drawing.Imaging.ImageFormat]::Jpeg)
"saved"
