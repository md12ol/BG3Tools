param([int]$X0, [int]$Y0, [int]$X1, [int]$Y1)
# drag.ps1 -X0 -Y0 -X1 -Y1: drag with the left button between two 1389x868 frame points, game brought to the front
# first (e.g. a portrait onto another portrait chains the two party members).
& "$PSScriptRoot\front.ps1" -SettleMs 300 | Out-Null
Add-Type -Name DR -Namespace Drag -MemberDefinition '[DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);'
function MoveTo($fx, $fy) { [Drag.DR]::mouse_event(0x8001, [uint32]($fx * 65535 / 1389.0), [uint32]($fy * 65535 / 868.0), 0, [IntPtr]::Zero) }
MoveTo ($X0 - 3) ($Y0 - 3); Start-Sleep -Milliseconds 60; MoveTo $X0 $Y0; Start-Sleep -Milliseconds 150
[Drag.DR]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 150
for ($i = 1; $i -le 12; $i++) { MoveTo ($X0 + ($X1 - $X0) * $i / 12) ($Y0 + ($Y1 - $Y0) * $i / 12); Start-Sleep -Milliseconds 40 }
Start-Sleep -Milliseconds 200; [Drag.DR]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
"dragged"
