param([int]$Notches = -5, [int]$X = 694, [int]$Y = 434)
# Mouse wheel at a frame position (negative = towards the user = zoom out in BG3)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Name WH -Namespace W2 -MemberDefinition '[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i); [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, int d, IntPtr e);'
& "$PSScriptRoot\minclaude.ps1" | Out-Null
& "$PSScriptRoot\focuswin.ps1" -TitleLike "Baldur's Gate 3 (" | Out-Null
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$px = [int]($X * $b.Width / 1389.0); $py = [int]($Y * $b.Height / 868.0)
$w = [W2.WH]::GetSystemMetrics(0); $h = [W2.WH]::GetSystemMetrics(1)
[W2.WH]::mouse_event(0x8001, [int]($px * 65535 / ($w - 1)), [int]($py * 65535 / ($h - 1)), 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 100
$step = if ($Notches -lt 0) { -120 } else { 120 }
for ($i = 0; $i -lt [Math]::Abs($Notches); $i++) { [W2.WH]::mouse_event(0x0800, 0, 0, $step, [IntPtr]::Zero); Start-Sleep -Milliseconds 80 }
"wheel $Notches"
