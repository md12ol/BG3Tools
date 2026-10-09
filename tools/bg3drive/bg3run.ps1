param([string]$RefFile = "$PSScriptRoot\refs.txt", [string]$Frames = "$PSScriptRoot\run2", [int]$TimeoutSec = 300, [switch]$NoLaunch)
# BG3 auto-runner: launch -> press any key -> New Game -> Start -> (cutscene) -> dismiss tutorial prompt
# -> Half-Orc / Paladin / Vengeance / Abilities. Screens are recognised by comparing a 32x20 grayscale
# thumbnail of the screen with reference thumbnails (refs.txt); clicks happen as soon as a screen matches.
# Coordinates are in the 1389x868 screenshot frame and scaled to the real screen.
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class M {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  // Real move events (MOUSEEVENTF_MOVE|ABSOLUTE) so IMGUI sees hover, then down/up
  static void Move(int x, int y) { int w = GetSystemMetrics(0), h = GetSystemMetrics(1); mouse_event(0x8001, (uint)(x * 65535 / (w - 1)), (uint)(y * 65535 / (h - 1)), 0, IntPtr.Zero); }
  public static void Click(int x, int y) { Move(x - 3, y - 3); System.Threading.Thread.Sleep(30); Move(x, y); System.Threading.Thread.Sleep(70); mouse_event(2, 0, 0, 0, IntPtr.Zero); System.Threading.Thread.Sleep(50); mouse_event(4, 0, 0, 0, IntPtr.Zero); }
}
"@
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$sx = $b.Width / 1389.0; $sy = $b.Height / 868.0
$refs = @{}
foreach ($l in Get-Content $RefFile) { $n, $v = $l.Split("`t"); $refs[$n] = [int[]]$v.Split(',') }
New-Item -ItemType Directory -Force $Frames | Out-Null
Get-ChildItem $Frames -Filter *.jpg | Remove-Item -Force
$full = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($full)
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 55L
$t0 = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$lastSave = 0
function Now { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
function Log($m) { Write-Host ("{0,7:N2}s  {1}" -f (((Now) - $t0) / 1000.0), $m) }
function Grab {
  $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
  $t = Now
  # Same pipeline as the references: full screen -> 320x200 -> 32x20
  $s = New-Object System.Drawing.Bitmap $full, 320, 200
  if ($t - $script:lastSave -ge 200) { $s.Save("$Frames\$t.jpg", $codec, $ep); $script:lastSave = $t }
  $th = New-Object System.Drawing.Bitmap $s, 32, 20; $s.Dispose()
  $v = New-Object int[] 640
  for ($y = 0; $y -lt 20; $y++) { for ($x = 0; $x -lt 32; $x++) { $c = $th.GetPixel($x, $y); $v[$y * 32 + $x] = [int](($c.R + $c.G + $c.B) / 3) } }
  $th.Dispose(); return ,$v
}
function Dist($a, $r) { $d = 0; for ($i = 0; $i -lt 640; $i++) { $d += [Math]::Abs($a[$i] - $r[$i]) }; return [int]($d / 640) }
function Click($fx, $fy) { [M]::Click([int]($fx * $sx), [int]($fy * $sy)) }
function WaitFor($name, $thr, $maxSec, [scriptblock]$whileWaiting = $null, $everyMs = 0) {
  $start = Now; $last = 0; $lastLog = $start
  while (((Now) - $start) / 1000 -lt $maxSec) {
    $v = Grab; $d = Dist $v $refs[$name]
    if ($d -le $thr) { Log "$name seen (dist $d)"; return $true }
    if (((Now) - $lastLog) -ge 5000) { Log "  waiting for $name, dist $d"; $lastLog = Now }
    if ($whileWaiting -and ((Now) - $last) -ge $everyMs) { & $whileWaiting; $last = Now }
    Start-Sleep -Milliseconds 30
  }
  Log "TIMEOUT waiting for $name"; return $false
}
function Focus {
  $p = Get-Process bg3_dx11 -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p -and $p.MainWindowHandle -ne 0) {
    Add-Type -Name F -Namespace R -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);' -ErrorAction SilentlyContinue
    [R.F]::ShowWindow($p.MainWindowHandle, 9) | Out-Null; [R.F]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  }
}

if (-not $NoLaunch) {
  Start-Process -FilePath "D:\SteamLibrary\steamapps\common\Baldurs Gate 3\bin\bg3_dx11.exe" -WorkingDirectory "D:\SteamLibrary\steamapps\common\Baldurs Gate 3\bin" -ArgumentList "--skip-launcher"
  Log "launched"
}
# Bring the game forward as soon as its window exists
while (((Now) - $t0) / 1000 -lt 90) { $p = Get-Process bg3_dx11 -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p -and $p.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 200 }
Focus; Log "focused"

if (-not (WaitFor "anykey" 15 90 { Focus } 2000)) { exit 1 }
# The prompt only accepts input a while after the picture appears: click every 300 ms until the menu shows
if (-not (WaitFor "menu" 10 40 { Click 694 600 } 300)) { exit 1 }
Start-Sleep -Milliseconds 150
if (-not (WaitFor "difficulty" 6 15 { Click 308 440 } 700)) { exit 1 }
Start-Sleep -Milliseconds 150
Click 780 808; Log "start clicked"
# Cutscene; the tutorial prompt dims the screen a few seconds after the creation screen appears
if (-not (WaitFor "cc" 5 200)) { exit 1 }
if (-not (WaitFor "prompt" 3 20)) { exit 1 }
Click 631 33; Start-Sleep -Milliseconds 200        # collapse advisor (it covers the prompt)
# The prompt ignores clicks for a moment after it appears: click Don't Reset until it is gone
$tries = 0
while ($tries -lt 40) {
  Click 786 487; $tries++; Start-Sleep -Milliseconds 250
  $v = Grab; if ((Dist $v $refs["prompt"]) -gt 8) { break }
}
Log "prompt gone after $tries click(s)"
Click 631 33; Start-Sleep -Milliseconds 300        # expand advisor
Log "prompt dismissed"
foreach ($c in @(@(60,150), @(436,345), @(60,205), @(435,240), @(70,258), @(435,160), @(70,363))) {
  Click $c[0] $c[1]; Start-Sleep -Milliseconds 800
}
Log "selections done (Half-Orc, Paladin, Vengeance, Abilities)"
