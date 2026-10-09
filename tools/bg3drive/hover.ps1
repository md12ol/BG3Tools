param([int]$X, [int]$Y, [switch]$NoSnap)
# Moves the mouse (real move events, no click) to a 1389x868 frame position, then snapshots.
$src = Get-Content "$PSScriptRoot\bg3run.ps1" -Raw
$i = $src.IndexOf('Add-Type @"'); $j = $src.IndexOf('"@', $i) + 2
Add-Type -AssemblyName System.Windows.Forms
Invoke-Expression $src.Substring($i, $j - $i)
Add-Type -Name GSM -Namespace H -MemberDefinition '[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i); [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);'
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$px = [int]($X * $b.Width / 1389.0); $py = [int]($Y * $b.Height / 868.0)
$w = [H.GSM]::GetSystemMetrics(0); $h = [H.GSM]::GetSystemMetrics(1)
foreach ($d in @(4, 0)) { [H.GSM]::mouse_event(0x8001, [uint32](($px - $d) * 65535 / ($w - 1)), [uint32](($py - $d) * 65535 / ($h - 1)), 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 60 }
Start-Sleep -Milliseconds 600
& "$PSScriptRoot\crop.ps1" -MaxW 900 | Out-Null
"hovered"
