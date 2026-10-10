param([string]$Find = "", [switch]$All)
# ocrscreen.ps1 [-Find "Start Game"] [-All]: read the text on the whole screen with the Windows OCR engine
# (Windows.Media.Ocr, offline). -Find: print "found X Y" (1389x868 frame, centre of the first line containing the
# text, case-insensitive) or "none"; -All: print every line as "x y text". Read-only: it never clicks.
# Used to recognise the game's dialogs (Mod Verification, Script Extender's experimental-version notice) by their text.
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type @"
using System; using System.Runtime.InteropServices;
public class OS { [DllImport("user32.dll")] public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr v);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i); }
"@
[OS]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
$SW = [OS]::GetSystemMetrics(0); $SH = [OS]::GetSystemMetrics(1)
$tmp = Join-Path $env:TEMP ("ocrscreen_" + $PID + ".png")
$bmp = New-Object System.Drawing.Bitmap($SW, $SH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size); $g.Dispose()
$bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime] | Out-Null
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$dec = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$sb = Await ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$eng = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
$res = Await ($eng.RecognizeAsync($sb)) ([Windows.Media.Ocr.OcrResult])
$stream.Dispose(); Remove-Item $tmp -ErrorAction SilentlyContinue
foreach ($ln in $res.Lines) {
  $w = $ln.Words; $x0 = ($w | ForEach-Object { $_.BoundingRect.X } | Measure-Object -Minimum).Minimum
  $x1 = ($w | ForEach-Object { $_.BoundingRect.X + $_.BoundingRect.Width } | Measure-Object -Maximum).Maximum
  $y0 = ($w | ForEach-Object { $_.BoundingRect.Y } | Measure-Object -Minimum).Minimum
  $y1 = ($w | ForEach-Object { $_.BoundingRect.Y + $_.BoundingRect.Height } | Measure-Object -Maximum).Maximum
  $fx = [int](($x0 + $x1) / 2 / $SW * 1389); $fy = [int](($y0 + $y1) / 2 / $SH * 868)
  if ($All) { "$fx $fy $($ln.Text)" }
  elseif ($Find -ne "" -and $ln.Text.ToLower().Contains($Find.ToLower())) { "found $fx $fy"; exit 0 }
}
if (-not $All) { "none" }
