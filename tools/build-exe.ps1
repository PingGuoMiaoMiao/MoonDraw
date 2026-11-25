param(
  [string]$VcVars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host '[1/4] moon build --target js --release'
moon build --target js --release | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'moon build failed' }

$jsPath = Join-Path $root '_build\js\release\build\moondraw.js'
if (-not (Test-Path $jsPath)) { throw "missing $jsPath" }
$js = Get-Content -Raw -Encoding UTF8 $jsPath
$css = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'style.css')
$html = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'index.html')

Write-Host '[2/4] inline js + css into one html'
$html = $html.Replace('<link rel="stylesheet" href="style.css" />', "<style>`n$css`n</style>")
$html = $html.Replace('<script src="_build/js/release/build/moondraw.js"></script>', "<script>`n$js`n</script>")
if ($html -match 'src="_build' -or $html -match 'href="style\.css"') {
  throw 'inlining failed: external references remain'
}
New-Item -ItemType Directory -Force -Path (Join-Path $root 'dist') | Out-Null
$distHtml = Join-Path $root 'dist\moondraw.html'
[IO.File]::WriteAllText($distHtml, $html, [Text.UTF8Encoding]::new($false))
# Tauri expects an index.html entry point; keep a copy for the shell build.
[IO.File]::WriteAllText((Join-Path $root 'dist\index.html'), $html, [Text.UTF8Encoding]::new($false))
Write-Host ("      dist/moondraw.html  {0:N0} bytes" -f (Get-Item $distHtml).Length)

Write-Host '[3/4] rustc launcher (needs MSVC linker from vcvars64)'
$exe = Join-Path $root 'dist\MoonDraw.exe'
$rs = Join-Path $root 'shell\launcher\main.rs'
$cmd = 'call "' + $VcVars + '" >nul 2>&1 && cd /d "' + $root + '" && rustc -O -C panic=abort "' + $rs + '" -o "' + $exe + '"'
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw 'rustc failed' }

Write-Host '[4/4] verify'
if (-not (Test-Path $exe)) { throw 'exe not produced' }
$size = (Get-Item $exe).Length
Write-Host ("      dist/MoonDraw.exe   {0:N0} bytes ({1:N0} KiB)" -f $size, ($size / 1KB))
Write-Host ("      total payload       {0:N0} bytes" -f ($size + (Get-Item $distHtml).Length))

# Shell shim: the verified launch path on machines where a GUI-subsystem exe is
# not allowed to start a browser (some locked-down environments). Double-click
# this instead of the exe when the exe shows no window.
$shim = @'
@echo off
setlocal
set "HTML=%~dp0moondraw.html"
if not exist "%HTML%" (
  "%~dp0MoonDraw.exe" --dump-html >nul 2>&1
)
set "PROFILE=%~dp0profile"
if not exist "%PROFILE%\First Run" (
  if not exist "%PROFILE%" mkdir "%PROFILE%" >nul 2>&1
  type nul > "%PROFILE%\First Run"
)
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not exist "%CHROME%" (
  echo Cannot find Edge or Chrome.
  pause
  exit /b 1
)
start "" "%CHROME%" "--app=file:///%HTML:\=/%" "--user-data-dir=%PROFILE%" --window-size=1440,900 --no-first-run --no-default-browser-check --disable-features=msEdgeFirstRunExperience,msEdgeWelcomePage --no-service-autorun --disable-sync
'@
[IO.File]::WriteAllText(
  (Join-Path $root 'dist\MoonDraw.cmd'),
  $shim.Replace("`r`n", "`n").Replace("`n", "`r`n"),
  [Text.UTF8Encoding]::new($false)
)
Write-Host '      dist/MoonDraw.cmd   (shell shim, verified launch path)'
