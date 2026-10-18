Add-Type @'
using System;
using System.Runtime.InteropServices;
public class W4 {
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref PT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint data, UIntPtr extra);
  [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v);
  public struct RECT { public int L, T, R, B; }
  public struct PT { public int X, Y; }
}
'@
[W4]::SetProcessDpiAwareness(2) | Out-Null
$p = Get-Process | Where-Object {$_.MainWindowTitle -like "zfy*"} | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "NOWINDOW"; exit }
$h = $p.MainWindowHandle
$rc = New-Object W4+RECT
[W4]::GetClientRect($h, [ref]$rc) | Out-Null
$pt = New-Object W4+PT
$pt.X = 0; $pt.Y = 0
[W4]::ClientToScreen($h, [ref]$pt) | Out-Null
Write-Output ("client origin {0},{1} size {2}x{3}" -f $pt.X, $pt.Y, $rc.R, $rc.B)
[W4]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 200
# 先滑入窗口触发 WM_MOUSEMOVE，再点"编辑"标题（约 client 110,19）
[W4]::SetCursorPos($pt.X + 60, $pt.Y + 19) | Out-Null
Start-Sleep -Milliseconds 120
[W4]::SetCursorPos($pt.X + 110, $pt.Y + 19) | Out-Null
Start-Sleep -Milliseconds 120
[W4]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
[W4]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 400
Write-Output "CLICKED client 110,19"
