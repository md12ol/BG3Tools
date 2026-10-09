# Prints the frame (1389x868) position of the selected character's white selection ring (tactical view), or "none".
Add-Type -Name D -Namespace RingDpi -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);'
[RingDpi.D]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing
$W = [RingDpi.D]::GetSystemMetrics(0); $H = [RingDpi.D]::GetSystemMetrics(1)
$b = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($b); $g.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size $W, $H)); $g.Dispose()
$sx = $W / 1389.0; $sy = $H / 868.0
$xs = New-Object System.Collections.Generic.List[int]; $ys = New-Object System.Collections.Generic.List[int]
for ($fy = 60; $fy -lt 720; $fy += 2) {
  for ($fx = 140; $fx -lt 1380; $fx += 2) {
    if ($fx -gt 1110 -and $fy -lt 300) { continue }  # minimap
    $p = $b.GetPixel([int]($fx * $sx), [int]($fy * $sy))
    if ($p.R -gt 215 -and $p.G -gt 215 -and $p.B -gt 215) { $xs.Add($fx); $ys.Add($fy) }
  }
}
$b.Dispose()
if ($xs.Count -lt 6) { "none"; exit }
$xa = $xs.ToArray(); $ya = $ys.ToArray(); [Array]::Sort($xa); [Array]::Sort($ya)
"{0},{1},{2}" -f $xa[[int]($xa.Length / 2)], $ya[[int]($ya.Length / 2)], $xs.Count
