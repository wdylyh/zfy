Add-Type @'
using System;
using System.Runtime.InteropServices;
public class W5 {
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
}
'@
$p = Get-Process | Where-Object {$_.MainWindowTitle -like "zfy*"} | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "NOWINDOW"; exit }
$h = $p.MainWindowHandle
function MkLp([int]$x, [int]$y) { return [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF)) }
# 移动到编辑标题 → 按下 → 抬起
[W5]::PostMessage($h, 0x0200, [IntPtr]0, (MkLp 63 40)) | Out-Null
[W5]::PostMessage($h, 0x0200, [IntPtr]0, (MkLp 63 40)) | Out-Null
[W5]::PostMessage($h, 0x0201, [IntPtr]1, (MkLp 63 40)) | Out-Null
[W5]::PostMessage($h, 0x0202, [IntPtr]0, (MkLp 63 40)) | Out-Null
Start-Sleep -Milliseconds 300
Write-Output "POSTED"
