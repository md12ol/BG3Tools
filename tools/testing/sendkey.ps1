param([string[]]$Keys, [int]$HoldMs = 80, [int]$GapMs = 300)
# sendkey.ps1 -Keys esc,f5 [-HoldMs 80] [-GapMs 300]: press keys as hardware scan codes (the game reads raw input and
# ignores virtual-key-only SendInput). Names: letters, digits, f1-f12, esc, tab, enter, space, alt, shift, ctrl,
# backspace, grave, home, arrows. It does not focus the game: gamekey.ps1 does.
. "$PSScriptRoot\lib_input.ps1"
$Keys = $Keys | ForEach-Object { $_.Split(',') } | Where-Object { $_ }   # "esc,f5" through powershell -File is one string
foreach ($k in $Keys) {
  $code = $BG3KeyMap[$k.ToLower()]
  if ($null -eq $code) { Write-Error "unknown key $k"; continue }
  $ext = $code -ge 0xE000; $scan = [uint16]($code -band 0xFF)
  [BG3Keys]::Key($scan, $ext, $false); Start-Sleep -Milliseconds $HoldMs
  [BG3Keys]::Key($scan, $ext, $true); Start-Sleep -Milliseconds $GapMs
}
