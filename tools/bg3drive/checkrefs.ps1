param([string]$Dir, [string]$RefFile, [long]$T0)
# For each recorded frame print the distance to every reference (only frames where some distance <= 35).
Add-Type -AssemblyName System.Drawing
$refs = [ordered]@{}
foreach ($l in Get-Content $RefFile) { $n, $v = $l.Split("`t"); $refs[$n] = [int[]]$v.Split(',') }
"time    " + (($refs.Keys | ForEach-Object { "{0,10}" -f $_ }) -join '')
foreach ($f in Get-ChildItem $Dir -Filter *.jpg | Sort-Object Name) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $bmp = New-Object System.Drawing.Bitmap $img, 32, 20; $img.Dispose()
  $v = New-Object int[] 640
  for ($y = 0; $y -lt 20; $y++) { for ($x = 0; $x -lt 32; $x++) { $c = $bmp.GetPixel($x, $y); $v[$y * 32 + $x] = [int](($c.R + $c.G + $c.B) / 3) } }
  $bmp.Dispose()
  $ds = foreach ($k in $refs.Keys) { $r = $refs[$k]; $d = 0; for ($i = 0; $i -lt 640; $i++) { $d += [Math]::Abs($v[$i] - $r[$i]) }; [int]($d / 640) }
  if (($ds | Measure-Object -Minimum).Minimum -le 35) { "{0,6:N1}s " -f (([long]$f.BaseName - $T0) / 1000.0) + (($ds | ForEach-Object { "{0,10}" -f $_ }) -join '') }
}
