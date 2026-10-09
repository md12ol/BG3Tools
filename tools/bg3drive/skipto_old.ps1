param([int]$Max = 25, [int]$GapMs = 300, [switch]$RClick, [switch]$NoEnd)
# -NoEnd: keep skipping even when the hotbar is visible (the helm-door cinematic keeps the hotbar on screen)
# Press Space until dialogue options appear (gold highlighted option text in the lower-left), or the dialogue ends
# (hotbar visible). Prints "options", "ended" or "timeout". Never presses Esc.
Add-Type -Name D -Namespace SkipDpi -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);'
[SkipDpi.D]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing
$SW = [SkipDpi.D]::GetSystemMetrics(0); $SH = [SkipDpi.D]::GetSystemMetrics(1)
function Grab($x0, $y0, $x1, $y1) {
  $w = [int](($x1 - $x0) * $SW); $h = [int](($y1 - $y0) * $SH)
  $b = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($b); $g.CopyFromScreen([int]($x0 * $SW), [int]($y0 * $SH), 0, 0, (New-Object System.Drawing.Size $w, $h)); $g.Dispose()
  return $b
}
function Count($b, $test) {
  $n = 0
  for ($y = 0; $y -lt $b.Height; $y += 4) { for ($x = 0; $x -lt $b.Width; $x += 4) { if (& $test $b.GetPixel($x, $y)) { $n++ } } }
  return $n
}
$gold = { param($p) $p.R -gt 190 -and $p.G -gt 150 -and $p.G -lt 215 -and $p.B -lt 140 -and ($p.R - $p.B) -gt 80 }
& "$PSScriptRoot\hover.ps1" -X 694 -Y 150 -NoSnap | Out-Null  # park the mouse: Space can pick a hovered option
for ($i = 0; $i -lt $Max; $i++) {
  $r = Grab 0.79 0.84 0.84 0.98; $ring = Count $r $gold; $r.Dispose()  # hotbar hourglass ring = no dialogue
  if (-not $NoEnd -and $ring -gt 15) { "ended"; exit 0 }
  $b = Grab 0.1 0.72 0.55 0.98; $opt = Count $b $gold; $b.Dispose()
  if ($opt -gt 40) { "options"; exit 0 }
  
  if ($RClick) { & "$PSScriptRoot\rclick.ps1" -X 694 -Y 150 | Out-Null; Start-Sleep -Milliseconds 150 }  # user tip: right-click then Space skips cutscenes
  & "$PSScriptRoot\gamekey.ps1" -Keys space | Out-Null
  Start-Sleep -Milliseconds $GapMs
}
"timeout"
