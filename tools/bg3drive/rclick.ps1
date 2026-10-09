param([int]$X = 694, [int]$Y = 400)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Name RC -Namespace R3 -MemberDefinition '[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i); [DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, int d, IntPtr e);'
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$px = [int]($X * $b.Width / 1389.0); $py = [int]($Y * $b.Height / 868.0)
$w = [R3.RC]::GetSystemMetrics(0); $h = [R3.RC]::GetSystemMetrics(1)
[R3.RC]::mouse_event(0x8001, [int]($px * 65535 / ($w - 1)), [int]($py * 65535 / ($h - 1)), 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 80
[R3.RC]::mouse_event(8, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 50; [R3.RC]::mouse_event(16, 0, 0, 0, [IntPtr]::Zero)
"rclick"
