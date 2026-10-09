param([double]$Seconds = 30, [int]$IntervalMs = 200, [string]$Out = "$PSScriptRoot\frames", [int]$Width = 320)
# Screen recorder: saves a small JPEG every IntervalMs, named by Unix time in ms.
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
New-Item -ItemType Directory -Force $Out | Out-Null
Get-ChildItem $Out -Filter *.jpg | Remove-Item -Force
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$h = [int]($Width * $b.Height / $b.Width)
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 60L
$full = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($full)
$end = [DateTimeOffset]::UtcNow.AddSeconds($Seconds)
while ([DateTimeOffset]::UtcNow -lt $end) {
  $t = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $small = New-Object System.Drawing.Bitmap $full, $Width, $h
  $small.Save("$Out\$t.jpg", $codec, $ep); $small.Dispose()
  $wait = $IntervalMs - ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $t)
  if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
}
"frames: " + (Get-ChildItem $Out -Filter *.jpg).Count
