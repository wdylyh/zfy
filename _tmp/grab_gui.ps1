param([string]$Exe = "d:\zfy\test.exe", [string]$Out = "d:\zfy\_tmp\gui_grab.png", [string]$TitlePart = "Aurora")

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class W {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
}
"@

$p = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds 2

$found = [IntPtr]::Zero
$cb = [W+EnumProc]{
  param($h, $l)
  $sb = New-Object System.Text.StringBuilder 256
  [W]::GetWindowText($h, $sb, 256) | Out-Null
  if ($sb.ToString() -like "*$TitlePart*" -and [W]::IsWindowVisible($h)) { $script:found = $h }
  return $true
}
[W]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null

if ($found -eq [IntPtr]::Zero) {
  "WINDOW_NOT_FOUND (pid alive: $(-not $p.HasExited))"
  if (-not $p.HasExited) { $p.Kill() }
  exit 1
}

[W]::SetWindowPos($found, [IntPtr](-1), 40, 40, 0, 0, 0x0001 -bor 0x0040 -bor 0x0008) | Out-Null
[W]::SetForegroundWindow($found) | Out-Null
Start-Sleep -Milliseconds 800

$cr = New-Object W+RECT
[W]::GetClientRect($found, [ref]$cr) | Out-Null
$pt = New-Object W+POINT
[W]::ClientToScreen($found, [ref]$pt) | Out-Null
$w = $cr.R - $cr.L; $h = $cr.B - $cr.T
"client: $w x $h  screen-origin: $($pt.X),$($pt.Y)"

$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($pt.X, $pt.Y, 0, 0, (New-Object System.Drawing.Size $w, $h))
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)

$c = $bmp.GetPixel([int]($w/2), [int]($h/2))
"center=" + $c.ToString()
$c2 = $bmp.GetPixel([int]($w/2), [int]($h/4))
"quarter=" + $c2.ToString()
$c3 = $bmp.GetPixel(20, 20)
"corner=" + $c3.ToString()
$bmp.Dispose()
if (-not $p.HasExited) { $p.Kill() }
