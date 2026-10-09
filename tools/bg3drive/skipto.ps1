param([int]$Max = 25, [int]$GapMs = 220, [switch]$RClick, [switch]$NoEnd, [int]$Pick = 0)
# skipto.ps1 (rewritten 2026-10-06; old version: skipto_old.ps1, user: "speed up dialogue choices"): drop-in replacement for skipto.ps1 - same switches and
# output ("options" / "ended" / "timeout"). Space until dialogue options appear or the dialogue ends (hotbar visible).
# The old script started two new PowerShell processes per Space press (rclick.ps1 + gamekey.ps1, which re-focused the
# game and slept 600 ms each time) and read the screen with GetPixel: ~2 s per step. This one focuses the game ONCE and
# sends right-click + Space + screen checks from one process (~0.3 s per step). -Pick N: when options appear, press
# number key N and keep skipping (one pick per call). Never presses Esc.
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public class SF {
  [DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KEYBDINPUT ki; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] i, int size);
  public static int SW, SH;
  public static void Init() { SetProcessDpiAwarenessContext(new IntPtr(-4)); SW = GetSystemMetrics(0); SH = GetSystemMetrics(1); }
  public static void Key(ushort scan) {
    var i = new INPUT[1]; i[0].type = 1; i[0].ki.wScan = scan; i[0].ki.dwFlags = 0x0008u;
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT))); System.Threading.Thread.Sleep(60);
    i[0].ki.dwFlags = 0x000Au; SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
  // frame coords 1389x868 like the other scripts; mouse_event absolute uses the logical (non-DPI-aware) metrics,
  // which are the same normalised 0..65535 range either way
  public static void Move(double fx, double fy) { mouse_event(0x8001, (uint)(fx / 1389.0 * 65535), (uint)(fy / 868.0 * 65535), 0, IntPtr.Zero); }
  public static void RClick(double fx, double fy) { Move(fx, fy); System.Threading.Thread.Sleep(20); mouse_event(0x0008, 0, 0, 0, IntPtr.Zero); System.Threading.Thread.Sleep(40); mouse_event(0x0010, 0, 0, 0, IntPtr.Zero); }
  // count "gold" pixels (option text / hourglass ring) in a screen region given as fractions, sampling every 4th pixel
  public static int Gold(double x0, double y0, double x1, double y1) {
    int w = (int)((x1 - x0) * SW), h = (int)((y1 - y0) * SH);
    using (var b = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(b)) g.CopyFromScreen((int)(x0 * SW), (int)(y0 * SH), 0, 0, new Size(w, h));
      var d = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      var px = new byte[d.Stride * h]; Marshal.Copy(d.Scan0, px, 0, px.Length); b.UnlockBits(d);
      int n = 0;
      for (int y = 0; y < h; y += 4) for (int x = 0; x < w; x += 4) {
        int o = y * d.Stride + x * 4; int B = px[o], G = px[o + 1], R = px[o + 2];
        if (R > 190 && G > 150 && G < 215 && B < 140 && R - B > 80) n++;
      }
      return n;
    }
  }
}
"@ -ReferencedAssemblies System.Drawing
[SF]::Init()
& "$PSScriptRoot\minclaude.ps1" | Out-Null
& "$PSScriptRoot\focuswin.ps1" -TitleLike "Baldur's Gate 3 (" | Out-Null
Start-Sleep -Milliseconds 250
[SF]::Move(694, 150)            # park the mouse: Space picks a hovered option
$digit = @{1=0x02; 2=0x03; 3=0x04; 4=0x05; 5=0x06; 6=0x07}
$picked = $false
for ($i = 0; $i -lt $Max; $i++) {
  if (-not $NoEnd -and [SF]::Gold(0.79, 0.84, 0.84, 0.98) -gt 15) { "ended"; exit 0 }    # hotbar hourglass = no dialogue
  if ([SF]::Gold(0.1, 0.72, 0.55, 0.98) -gt 40) {
    if ($Pick -gt 0 -and -not $picked) { [SF]::Key([uint16]$digit[$Pick]); $picked = $true; Start-Sleep -Milliseconds 700; continue }
    "options"; exit 0
  }
  if ($RClick) { [SF]::RClick(694, 150); Start-Sleep -Milliseconds 60 }   # user tip: right-click then Space skips cutscenes
  [SF]::Key(0x39)
  Start-Sleep -Milliseconds $GapMs
}
"timeout"
