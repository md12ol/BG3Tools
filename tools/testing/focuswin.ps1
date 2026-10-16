param([string]$TitleLike = "Script Extender")
# focuswin.ps1 [-TitleLike text]: restore and bring to the front the first window whose title contains the text
# (default: the Script Extender console). Prints "focused <handle>", "not in front <handle>" when Windows kept another
# window in front (exit 2), or "not found" (exit 1).
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class FW {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
}
"@
$found = $null
[FW]::EnumWindows({ param($h, $l)
  $sb = New-Object Text.StringBuilder 256; [FW]::GetWindowText($h, $sb, 256) | Out-Null
  if ($sb.ToString() -like "*$TitleLike*") { $script:found = $h; return $false }; return $true }, [IntPtr]::Zero) | Out-Null
if (-not $found) { "not found"; exit 1 }
[FW]::ShowWindow($found, 9) | Out-Null
[FW]::SetForegroundWindow($found) | Out-Null
# Windows refuses SetForegroundWindow to a process that does not own the foreground (the call only flashes the
# taskbar); sharing the foreground window's input queue for the call lifts that.
if ([FW]::GetForegroundWindow() -ne $found) {
  $fg = [FW]::GetWindowThreadProcessId([FW]::GetForegroundWindow(), [IntPtr]::Zero); $me = [FW]::GetCurrentThreadId()
  [FW]::AttachThreadInput($me, $fg, $true) | Out-Null
  [FW]::BringWindowToTop($found) | Out-Null; [FW]::SetForegroundWindow($found) | Out-Null
  [FW]::AttachThreadInput($me, $fg, $false) | Out-Null
}
if ([FW]::GetForegroundWindow() -ne $found) { "not in front $found"; exit 2 }
"focused $found"
