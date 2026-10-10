param([string]$Seq, [int]$GapMs = 800)
# clickseq.ps1 -Seq "631,33;60,150" [-GapMs 800]: left-click each point (1389x868 frame) with GapMs between clicks.
# It does not focus the game: gclick.ps1 and go.ps1 bring it to the front first.
. "$PSScriptRoot\lib_input.ps1"
foreach ($p in $Seq.Split(';')) { $x, $y = $p.Split(','); FrameClick ([int]$x) ([int]$y); Start-Sleep -Milliseconds $GapMs }
"done"
