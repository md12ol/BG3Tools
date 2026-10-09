Add-Type -Name W -Namespace MC -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { [MC.W]::ShowWindow($_.MainWindowHandle, 6) | Out-Null; "claude minimized" }
