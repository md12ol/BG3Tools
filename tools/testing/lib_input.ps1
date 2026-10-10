# lib_input.ps1: mouse and keyboard input shared by the click and key helpers; dot-source it (. "$PSScriptRoot\lib_input.ps1").
# Coordinates are in a 1389x868 reference frame (a 16:10 screen) and are scaled to the primary screen, so the same
# numbers work on any 16:10 resolution. The game must run borderless or fullscreen: a window title bar shifts every
# point (see borderless.ps1).
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class BG3Mouse {
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  // Real move events (MOUSEEVENTF_MOVE|ABSOLUTE) so the game's UI sees the hover before the button goes down.
  public static void Move(int x, int y) { int w = GetSystemMetrics(0), h = GetSystemMetrics(1); mouse_event(0x8001, (uint)(x * 65535 / (w - 1)), (uint)(y * 65535 / (h - 1)), 0, IntPtr.Zero); }
  public static void Click(int x, int y) { Move(x - 3, y - 3); System.Threading.Thread.Sleep(30); Move(x, y); System.Threading.Thread.Sleep(70); mouse_event(2, 0, 0, 0, IntPtr.Zero); System.Threading.Thread.Sleep(50); mouse_event(4, 0, 0, 0, IntPtr.Zero); }
}
public class BG3Keys {
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KEYBDINPUT ki; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] i, int size);
  // Hardware scan codes: the game reads raw input and ignores virtual-key-only events.
  public static void Key(ushort scan, bool ext, bool up) {
    var i = new INPUT[1]; i[0].type = 1; i[0].ki.wScan = scan;
    i[0].ki.dwFlags = 0x0008u | (ext ? 0x0001u : 0u) | (up ? 0x0002u : 0u);
    uint r = SendInput(1, i, Marshal.SizeOf(typeof(INPUT))); if (r != 1) System.Console.WriteLine("SendInput failed, err=" + Marshal.GetLastWin32Error() + " size=" + Marshal.SizeOf(typeof(INPUT))); else System.Console.WriteLine("sent scan " + scan + (up ? " up" : " down"));
  }
}
"@
$BG3Screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
function FrameX([double]$fx) { [int]($fx * $BG3Screen.Width / 1389.0) }
function FrameY([double]$fy) { [int]($fy * $BG3Screen.Height / 868.0) }
function FrameClick([double]$fx, [double]$fy) { [BG3Mouse]::Click((FrameX $fx), (FrameY $fy)) }
# Key names -> scan codes (0xE0xx = extended key)
$BG3KeyMap = @{
  esc=0x01; '1'=0x02; '2'=0x03; '3'=0x04; '4'=0x05; '5'=0x06; '6'=0x07; '7'=0x08; '8'=0x09; '9'=0x0A; '0'=0x0B;
  tab=0x0F; alt=0x38; enter=0x1C; space=0x39; backspace=0x0E; grave=0x29; shift=0x2A; ctrl=0x1D;
  f1=0x3B; f2=0x3C; f3=0x3D; f4=0x3E; f5=0x3F; f6=0x40; f7=0x41; f8=0x42; f9=0x43; f10=0x44; f11=0x57; f12=0x58;
  a=0x1E; b=0x30; c=0x2E; d=0x20; e=0x12; f=0x21; g=0x22; h=0x23; i=0x17; j=0x24; k=0x25; l=0x26; m=0x32;
  n=0x31; o=0x18; p=0x19; q=0x10; r=0x13; s=0x1F; t=0x14; u=0x16; v=0x2F; w=0x11; x=0x2D; y=0x15; z=0x2C;
  home=0xE047; up=0xE048; down=0xE050; left=0xE04B; right=0xE04D
}
