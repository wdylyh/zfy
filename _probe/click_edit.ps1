Add-Type @'
using System;
using System.Runtime.InteropServices;
public class W3 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint data, UIntPtr extra);
  public struct RECT { public int L, T, R, B; }
}
'@
[W3]::SetProcessDpiAwareness(2) | Out-Null
$p = Get-Process | Where-Object {$_.MainWindowTitle -like "zfy*"} | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "NOWINDOW"; exit }
$r = New-Object W3+RECT
[W3]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
# 客户区起点 ≈ 左边框 8px + 标题栏 47px；菜单标题 y 中心 ≈ +35
$cx = $r.L + 8
$cy = $r.T + 47
# 点击 "编辑"（第二个标题，"文件"≈110px 宽 + 间距）→ 约 x=+170
[W3]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 200
[W3]::SetCursorPos($cx + 110, $cy + 30) | Out-Null
Start-Sleep -Milliseconds 150
[W3]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)   # down
[W3]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)   # up
Start-Sleep -Milliseconds 400
Write-Output "CLICKED open $($cx+110),$($cy+30)"
