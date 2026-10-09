param([string[]]$Keys, [int]$HoldMs = 80, [int]$GapMs = 300)
# Sends keys as hardware scan codes (games using raw input ignore VK-only SendInput).
Add-Type @"
using System; using System.Runtime.InteropServices;
public class SK {
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KEYBDINPUT ki; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] i, int size);
  public static void Key(ushort scan, bool ext, bool up) {
    var i = new INPUT[1]; i[0].type = 1; i[0].ki.wScan = scan;
    i[0].ki.dwFlags = 0x0008u | (ext ? 0x0001u : 0u) | (up ? 0x0002u : 0u);
    uint r = SendInput(1, i, Marshal.SizeOf(typeof(INPUT))); if (r != 1) System.Console.WriteLine("SendInput failed, err=" + Marshal.GetLastWin32Error() + " size=" + Marshal.SizeOf(typeof(INPUT))); else System.Console.WriteLine("sent scan " + scan + (up ? " up" : " down"));
  }
}
"@
$map = @{
  esc=0x01; '1'=0x02; '2'=0x03; '3'=0x04; '4'=0x05; '5'=0x06; '6'=0x07; '7'=0x08; '8'=0x09; '9'=0x0A; '0'=0x0B;
  tab=0x0F; alt=0x38; enter=0x1C; space=0x39; backspace=0x0E; grave=0x29;
  f1=0x3B; f2=0x3C; f3=0x3D; f4=0x3E; f5=0x3F; f6=0x40; f7=0x41; f8=0x42; f9=0x43; f10=0x44; f11=0x57; f12=0x58;
  a=0x1E; b=0x30; c=0x2E; d=0x20; e=0x12; f=0x21; g=0x22; h=0x23; i=0x17; j=0x24; k=0x25; l=0x26; m=0x32;
  n=0x31; o=0x18; p=0x19; q=0x10; r=0x13; s=0x1F; t=0x14; u=0x16; v=0x2F; w=0x11; x=0x2D; y=0x15; z=0x2C;
  home=0xE047; up=0xE048; down=0xE050; left=0xE04B; right=0xE04D
}
foreach ($k in $Keys) {
  $code = $map[$k.ToLower()]
  if ($null -eq $code) { Write-Error "unknown key $k"; continue }
  $ext = $code -ge 0xE000; $scan = [uint16]($code -band 0xFF)
  [SK]::Key($scan, $ext, $false); Start-Sleep -Milliseconds $HoldMs
  [SK]::Key($scan, $ext, $true); Start-Sleep -Milliseconds $GapMs
}
