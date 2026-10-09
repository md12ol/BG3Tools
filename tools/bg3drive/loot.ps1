param([int]$X, [int]$Y, [int]$WalkMs = 3500)
# Click a lootable at frame (X,Y); after walking, the loot window opens: click Take All wherever it is.
# Take All is located by searching the screen for the window's "Take All" button row (bright text on dark)
# - simpler: the window opens centred on the object; we press the Take All via keyboard shortcut? none known,
# so we snapshot for the caller.
& "$PSScriptRoot\clickseq.ps1" -Seq "$X,$Y" | Out-Null
Start-Sleep -Milliseconds $WalkMs
& "$PSScriptRoot\crop.ps1" -MaxW 900 | Out-Null
"ok"
