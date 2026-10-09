param([int]$Taps = 4, [int]$GapMs = 2500)
# synctap.ps1: A/V sync markers for testing rec.sh. Each tap toggles the game HUD (F10 = hide/show interface: a sharp
# one-frame picture change) and in the same instant plays a loud 1 kHz beep (generated in memory, default device).
# An even number of taps leaves the HUD as it was. Analyse the recording with avsync.py --beep.
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class ST {
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KEYBDINPUT ki; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] i, int size);
  public static void Key(ushort scan, bool up) {
    var i = new INPUT[1]; i[0].type = 1; i[0].ki.wScan = scan; i[0].ki.dwFlags = 0x0008u | (up ? 0x0002u : 0u);
    SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
  }
}
"@
# 150 ms 1 kHz tone, 16-bit mono 48 kHz WAV in memory
$sr = 48000; $n = [int]($sr * 0.15)
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $ms
$bw.Write([Text.Encoding]::ASCII.GetBytes("RIFF")); $bw.Write([int](36 + $n * 2)); $bw.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
$bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1); $bw.Write([int]$sr); $bw.Write([int]($sr * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
$bw.Write([Text.Encoding]::ASCII.GetBytes("data")); $bw.Write([int]($n * 2))
for ($i = 0; $i -lt $n; $i++) { $bw.Write([int16](26000 * [Math]::Sin(2 * [Math]::PI * 1000 * $i / $sr))) }
$bw.Flush(); $ms.Position = 0
$player = New-Object System.Media.SoundPlayer $ms; $player.Load()
& "$dir\minclaude.ps1" | Out-Null
& "$dir\focuswin.ps1" -TitleLike "Baldur's Gate 3 (" | Out-Null
Start-Sleep -Milliseconds 800
$sw = [Diagnostics.Stopwatch]::StartNew()
for ($t = 0; $t -lt $Taps; $t++) {
  [ST]::Key(0x44, $false); $player.Play(); Start-Sleep -Milliseconds 60; [ST]::Key(0x44, $true)
  "tap $t at $($sw.ElapsedMilliseconds) ms"
  Start-Sleep -Milliseconds $GapMs
}
