# listwin.ps1: list the visible windows larger than 100x100 px: process, title, position and size. Shows whether the
# game window has a title bar (windowed) and which window holds the front.
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class LW {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
}
"@
[LW]::EnumWindows({ param($h, $l)
  if ([LW]::IsWindowVisible($h)) {
    $sb = New-Object Text.StringBuilder 256; [LW]::GetWindowText($h, $sb, 256) | Out-Null
    $p = 0; [LW]::GetWindowThreadProcessId($h, [ref]$p) | Out-Null
    $r = New-Object LW+RECT; [LW]::GetWindowRect($h, [ref]$r) | Out-Null
    $name = (Get-Process -Id $p -ErrorAction SilentlyContinue).Name
    if (($r.R - $r.L) -gt 100 -and ($r.B - $r.T) -gt 100) { "{0,-22} {1,-45} {2},{3} {4}x{5}" -f $name, $sb.ToString(), $r.L, $r.T, ($r.R-$r.L), ($r.B-$r.T) }
  }; return $true }, [IntPtr]::Zero) | Out-Null
