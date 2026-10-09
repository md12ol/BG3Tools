param([string]$Mode = "continue", [string]$RefFile = (Join-Path $PSScriptRoot "refs.txt"))
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
  $bg3 = if ($env:BG3_DIR) { $env:BG3_DIR } else { "D:\SteamLibrary\steamapps\common\Baldurs Gate 3" }   # game install folder (env BG3_DIR overrides)
  Start-Process -FilePath "$bg3\bin\bg3_dx11.exe" -WorkingDirectory "$bg3\bin" -ArgumentList "--skip-launcher"
  Log "launched"
}
# Bring the game forward as soon as its window exists
while (((Now) - $t0) / 1000 -lt 90) { $p = Get-Process bg3_dx11 -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p -and $p.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 200 }
Focus; Log "focused"

# startgame.ps1 -Mode continue|menu: launch BG3 and react to each screen as soon as it appears (no fixed waits).
# continue = also click Continue until the mod's scanner file updates (game loaded); menu = stop at the main menu.
# 2026-10-07: the splash alternates between (at least) two artworks; only one is in refs.txt. If it is not recognised
# within the time limit, click through anyway (a click on the splash only dismisses it).
if (-not (WaitFor "anykey" 15 120 { Focus } 1000)) { Log "anykey not recognised - clicking through anyway"; Focus }
# click "press any key" every 300 ms until the screen stops looking like it (main menu up)
$start = Now; $away = 0
while (((Now) - $start) / 1000 -lt 40) {
  Click 694 600; Start-Sleep -Milliseconds 300
  $v = Grab; $d = Dist $v $refs["anykey"]; $mean = ($v | Measure-Object -Average).Average
  if ($d -gt 40 -and $mean -gt 8) { $away++ } else { $away = 0 }
  if ($away -ge 2) { Log "main menu (anykey dist $d)"; break }
}
if ($Mode -ne "continue") { exit 0 }
$scan = Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3\Script Extender\BuildAdvisor_scan.txt"
$m0 = (Get-Item $scan).LastWriteTimeUtc
$start = Now
while (((Now) - $start) / 1000 -lt 150) {
  if (((Now) - $start) -lt 4000) { Click 307 386 }
  Start-Sleep -Milliseconds 700
  if ((Get-Item $scan).LastWriteTimeUtc -ne $m0) { Log "game loaded (scanner running)"; exit 0 }
}
Log "TIMEOUT waiting for the scanner"; exit 1
