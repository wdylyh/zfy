Add-Type @'
using System;
using System.Runtime.InteropServices;
public class W6 {
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
[W6]::SetProcessDpiAwareness(2) | Out-Null
$p = Get-Process | Where-Object {$_.MainWindowTitle -like "zfy*"} | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "NOWINDOW"; exit }
$h = $p.MainWindowHandle
$rc = New-Object W6+RECT
[W6]::GetClientRect($h, [ref]$rc) | Out-Null
$pt = New-Object W6+PT
$pt.X = 0; $pt.Y = 0
[W6]::ClientToScreen($h, [ref]$pt) | Out-Null
Write-Output ("origin {0},{1} size {2}x{3}" -f $pt.X, $pt.Y, $rc.R, $rc.B)
[W6]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 200
# 1) 移到菜单栏内"编辑"标题（client 110,19），多次小步移动确保 WM_MOUSEMOVE
for ($i = 0; $i -le 10; $i++) {
  [W6]::SetCursorPos($pt.X + 10 + $i * 10, $pt.Y + 19) | Out-Null
  Start-Sleep -Milliseconds 40
}
Write-Output "MOVED - check mx now"
