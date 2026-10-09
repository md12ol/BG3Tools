param([string]$Dir, [long]$T0)
# Prints frames where the picture changes a lot (mean abs diff of an 32x20 grayscale thumbnail).
Add-Type -AssemblyName System.Drawing
$prev = $null
foreach ($f in Get-ChildItem $Dir -Filter *.jpg | Sort-Object Name) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $bmp = New-Object System.Drawing.Bitmap $img, 32, 20; $img.Dispose()
  $v = New-Object int[] 640; $sum = 0
  for ($y = 0; $y -lt 20; $y++) { for ($x = 0; $x -lt 32; $x++) { $c = $bmp.GetPixel($x, $y); $g = [int](($c.R + $c.G + $c.B) / 3); $v[$y * 32 + $x] = $g; $sum += $g } }
  $bmp.Dispose()
  if ($prev) {
    $d = 0; for ($i = 0; $i -lt 640; $i++) { $d += [Math]::Abs($v[$i] - $prev[$i]) }; $d = [int]($d / 640)
    $t = [long]$f.BaseName
    if ($d -ge 12) { "{0,8:N1}s  diff={1,3}  mean={2,3}  {3}" -f (($t - $T0) / 1000.0), $d, [int]($sum / 640), $f.Name }
  }
  $prev = $v
}
