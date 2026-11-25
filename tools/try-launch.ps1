param([int]$WaitSeconds = 12)

$ErrorActionPreference = 'Continue'
$root = 'D:\moonbit-compition\_moondraw'
$exe = Join-Path $root 'dist\MoonDraw.exe'

Write-Host '[1] kill previous moondraw browsers'
Get-Process chrome, msedge -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowTitle -like '*MoonDraw*' -or $_.MainWindowTitle -like '*moondraw.html*' } |
  Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host '[2] reset profile'
for ($i = 0; $i -lt 4; $i++) {
  Remove-Item -Recurse -Force (Join-Path $root 'dist\profile') -ErrorAction SilentlyContinue
  if (-not (Test-Path (Join-Path $root 'dist\profile'))) { break }
  Start-Sleep -Milliseconds 800
}

Write-Host '[3] launch'
cmd /c "start """" ""$exe"""
Start-Sleep -Seconds $WaitSeconds

Write-Host '[4] look for a window'
$hit = $null
for ($i = 0; $i -lt 8; $i++) {
  $hit = Get-Process chrome, msedge -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -like '*MoonDraw*' } |
    Select-Object -First 1
  if ($hit) { break }
  Start-Sleep -Seconds 2
}

if (-not $hit) {
  Write-Host 'RESULT: no window appeared'
  exit 2
}

Write-Host ("RESULT: window pid={0} title='{1}'" -f $hit.Id, $hit.MainWindowTitle)

Add-Type -Namespace Cap -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool PrintWindow(System.IntPtr hwnd, System.IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(System.IntPtr hwnd, out RECT r);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@
$h = $hit.MainWindowHandle
$r = New-Object Cap.Win+RECT
[void][Cap.Win]::GetWindowRect($h, [ref]$r)
$w = $r.Right - $r.Left
$ht = $r.Bottom - $r.Top
if ($w -le 0 -or $ht -le 0) { Write-Host 'RESULT: bad window rect'; exit 3 }

$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [Cap.Win]::PrintWindow($h, $hdc, 2)
$g.ReleaseHdc($hdc)
$g.Dispose()

$out = Join-Path $root 'docs\app-window.png'
New-Item -ItemType Directory -Force (Join-Path $root 'docs') | Out-Null
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)

$canvas = 0; $blue = 0; $diamond = 0
for ($y = 0; $y -lt $ht; $y += 2) {
  for ($x = 0; $x -lt $w; $x += 2) {
    $c = $bmp.GetPixel($x, $y)
    if ($c.R -eq 244 -and $c.G -eq 246 -and $c.B -eq 250) { $canvas++ }
    if ($c.B -gt 150 -and ($c.B - $c.R) -gt 60) { $blue++ }
    if ($c.R -eq 255 -and $c.G -eq 246 -and $c.B -eq 229) { $diamond++ }
  }
}
$bmp.Dispose()
Write-Host ("RESULT: captured {0}x{1} PrintWindow={2} canvas-bg={3} blue={4} diamond={5}" -f $w, $ht, $ok, $canvas, $blue, $diamond)
exit 0
