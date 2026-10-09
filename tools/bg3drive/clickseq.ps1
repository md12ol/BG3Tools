param([string]$Seq, [int]$GapMs = 800)
# -Seq "631,33;60,150;..." clicks in the 1389x868 frame with GapMs between clicks
$src = Get-Content "$PSScriptRoot\bg3run.ps1" -Raw
$i = $src.IndexOf('Add-Type @"'); $j = $src.IndexOf('"@', $i) + 2
Add-Type -AssemblyName System.Windows.Forms
Invoke-Expression $src.Substring($i, $j - $i)
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
foreach ($p in $Seq.Split(';')) { $x, $y = $p.Split(','); [M]::Click([int]([int]$x * $b.Width / 1389.0), [int]([int]$y * $b.Height / 868.0)); Start-Sleep -Milliseconds $GapMs }
"done"
