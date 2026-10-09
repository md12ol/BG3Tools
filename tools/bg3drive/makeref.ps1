param([string]$Dir, [string]$Spec, [string]$Out)
$Pairs = $Spec.Split(";")
# Builds reference thumbnails: -Pairs "name=frame.jpg", writes name<TAB>640 grayscale values per line.
Add-Type -AssemblyName System.Drawing
$lines = foreach ($p in $Pairs) {
  $name, $file = $p.Split('=')
  $img = [System.Drawing.Image]::FromFile((Join-Path $Dir $file))
  $bmp = New-Object System.Drawing.Bitmap $img, 32, 20; $img.Dispose()
  $v = for ($y = 0; $y -lt 20; $y++) { for ($x = 0; $x -lt 32; $x++) { $c = $bmp.GetPixel($x, $y); [int](($c.R + $c.G + $c.B) / 3) } }
  $bmp.Dispose()
  "$name`t" + ($v -join ',')
}
$lines | Set-Content -Encoding ascii $Out
"refs: " + $lines.Count
