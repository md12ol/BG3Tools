param([int]$Notches = -5, [int]$X = 694, [int]$Y = 434)
# wheel.ps1 [-Notches -5] [-X 694 -Y 434]: turn the mouse wheel at a 1389x868 frame point, game brought to the front
# first. Negative = towards the user (zooms the camera out in the game, scrolls a list down).
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Name WH -Namespace W2 -MemberDefinition '[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i); [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, int d, IntPtr e);'
& "$PSScriptRoot\front.ps1" -SettleMs 0 | Out-Null
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$px = [int]($X * $b.Width / 1389.0); $py = [int]($Y * $b.Height / 868.0)
$w = [W2.WH]::GetSystemMetrics(0); $h = [W2.WH]::GetSystemMetrics(1)
[W2.WH]::mouse_event(0x8001, [int]($px * 65535 / ($w - 1)), [int]($py * 65535 / ($h - 1)), 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 100
$step = if ($Notches -lt 0) { -120 } else { 120 }
for ($i = 0; $i -lt [Math]::Abs($Notches); $i++) { [W2.WH]::mouse_event(0x0800, 0, 0, $step, [IntPtr]::Zero); Start-Sleep -Milliseconds 80 }
"wheel $Notches"
