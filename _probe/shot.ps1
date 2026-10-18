Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class W2 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v);
  public struct RECT { public int L, T, R, B; }
}
'@
[W2]::SetProcessDpiAwareness(2) | Out-Null
$p = Get-Process | Where-Object {$_.MainWindowTitle -like "zfy*"} | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "NOWINDOW"; exit }
$r = New-Object W2+RECT
[W2]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$w = $r.R - $r.L; $h = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$dc = $g.GetHdc()
[W2]::PrintWindow($p.MainWindowHandle, $dc, 2) | Out-Null   # 2 = PW_RENDERFULLCONTENT
$g.ReleaseHdc($dc)
$bmp.Save("D:\zfy\_probe\notepad_shot.png")
Write-Output "SAVED ${w}x${h}"
