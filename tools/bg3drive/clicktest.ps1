param([int]$X, [int]$Y)
$src = Get-Content "$PSScriptRoot\bg3run.ps1" -Raw
$i = $src.IndexOf('Add-Type @"'); $j = $src.IndexOf('"@', $i) + 2
Add-Type -AssemblyName System.Windows.Forms
Invoke-Expression $src.Substring($i, $j - $i)
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
[M]::Click([int]($X * $b.Width / 1389.0), [int]($Y * $b.Height / 868.0)); "clicked"
