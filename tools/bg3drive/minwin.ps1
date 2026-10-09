param([string]$TitleLike = "Script Extender")
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
}
"@
$found = $null
[FW]::EnumWindows({ param($h, $l)
  $sb = New-Object Text.StringBuilder 256; [FW]::GetWindowText($h, $sb, 256) | Out-Null
  if ($sb.ToString() -like "*$TitleLike*") { $script:found = $h; return $false }; return $true }, [IntPtr]::Zero) | Out-Null
if (-not $found) { "not found"; exit 1 }
[FW]::ShowWindow($found, 6) | Out-Null
"minimized $found"
