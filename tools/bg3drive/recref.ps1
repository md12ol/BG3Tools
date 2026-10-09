param([Parameter(Mandatory=$true)][string]$Name, [string]$RefFile = (Join-Path $PSScriptRoot "refs.txt"))
# recref.ps1 <name>: record the CURRENT screen as the reference thumbnail <name> in refs.txt (same pipeline as
# startgame.ps1 Grab: full screen -> 320x200 -> 32x20 grey). Replaces an existing row; the old row is kept as <name>_old.
# 2026-10-05: the "press any key" splash art changed and restart.sh timed out (dist 55 > 15) - re-recorded with this.
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$full = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($full)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$s = New-Object System.Drawing.Bitmap $full, 320, 200
$th = New-Object System.Drawing.Bitmap $s, 32, 20; $s.Dispose()
$v = New-Object int[] 640
for ($y = 0; $y -lt 20; $y++) { for ($x = 0; $x -lt 32; $x++) { $c = $th.GetPixel($x, $y); $v[$y * 32 + $x] = [int](($c.R + $c.G + $c.B) / 3) } }
$th.Dispose(); $full.Dispose()
$row = $Name + "`t" + ($v -join ',')
$lines = @(Get-Content $RefFile) | Where-Object { $_ -notmatch ("^" + [regex]::Escape($Name) + "_old`t") }
$out = @()
foreach ($l in $lines) {
  if ($l -match ("^" + [regex]::Escape($Name) + "`t")) { $out += ($Name + "_old`t" + $l.Split("`t")[1]) } else { $out += $l }
}
$out += $row
[IO.File]::WriteAllText($RefFile, (($out -join "`n") + "`n"))
Write-Host ("recorded {0} ({1} rows; screen {2}x{3}, mean {4:N0})" -f $Name, $out.Count, $b.Width, $b.Height, ($v | Measure-Object -Average).Average)
