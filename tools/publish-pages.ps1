# Build the single-file app and publish it into docs/ for GitHub Pages.
# GitHub Pages serves static files only, so the built JS/CSS is inlined into one
# self-contained index.html — no asset paths, no build step on the server.

param(
  [string]$OutDir = 'docs'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host '[1/3] moon build --target js --release'
moon build --target js --release | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'moon build failed' }

$jsPath = Join-Path $root '_build\js\release\build\app\app.js'
if (-not (Test-Path $jsPath)) { throw "missing $jsPath" }

Write-Host '[2/3] inline js + css'
$js = Get-Content -Raw -Encoding UTF8 $jsPath
$css = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'style.css')
$html = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'index.html')

$html = $html.Replace('<link rel="stylesheet" href="style.css" />', "<style>`n$css`n</style>")
$html = $html.Replace('<script src="_build/js/release/build/app/app.js"></script>', "<script>`n$js`n</script>")
if ($html -match 'src="_build' -or $html -match 'href="style\.css"') {
  throw 'inlining failed: external references remain'
}

# Pages-specific head bits
$html = $html.Replace(
  '<title>MoonDraw',
  '<meta name="description" content="MoonDraw — 用 MoonBit 写的流程图 / 白板编辑器，纯前端，离线可用。" />' + "`n    " + '<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=''http://www.w3.org/2000/svg'' viewBox=''0 0 32 32''%3E%3Crect width=''32'' height=''32'' rx=''8'' fill=''%232f6fed''/%3E%3Ctext x=''16'' y=''23'' font-size=''20'' font-family=''sans-serif'' fill=''white'' text-anchor=''middle''%3EM%3C/text%3E%3C/svg%3E" />' + "`n    " + '<title>MoonDraw'
)

$outDir = Join-Path $root $OutDir
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir 'index.html'
[IO.File]::WriteAllText($outFile, $html, [Text.UTF8Encoding]::new($false))

Write-Host '[3/3] verify'
if ($html -notmatch 'globalThis\.boot') { throw 'bundle does not export boot()' }
$size = (Get-Item $outFile).Length
Write-Host ("      {0}  {1:N0} bytes" -f (Join-Path $OutDir 'index.html'), $size)
Write-Host ("      self-contained: no external <script src> or <link href>: " +
  (-not ($html -match '<script src=' -or $html -match '<link rel="stylesheet"')))
