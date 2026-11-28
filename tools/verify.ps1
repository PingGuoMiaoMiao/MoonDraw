param(
  [switch]$SkipE2E,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$script:fail = 0

function Section($name) {
  Write-Host ""
  Write-Host "=== $name ===" -ForegroundColor Cyan
}

function Fail($msg) {
  Write-Host "FAIL: $msg" -ForegroundColor Red
  $script:fail++
}

function Ok($msg) {
  Write-Host "OK: $msg" -ForegroundColor Green
}

# --- type check + unit tests ------------------------------------------------
Section 'moon check'
moon check --target js
if ($LASTEXITCODE -ne 0) { Fail 'moon check' }

Section 'moon test'
moon test --target js
if ($LASTEXITCODE -ne 0) { Fail 'moon test' }

# --- build artifacts --------------------------------------------------------
if (-not $SkipBuild) {
  Section 'build single-file + portable exe'
  pwsh -NoProfile -File tools\build-exe.ps1
  if ($LASTEXITCODE -ne 0) { Fail 'build-exe' }
}

# --- engine CLI (native, headless) ------------------------------------------
Section 'cli (native)'
moon build src/cli --target native --release
if ($LASTEXITCODE -ne 0) {
  Fail 'cli build'
} else {
  $cli = Join-Path $root '_build\native\release\build\cli\cli.exe'
  $mmd = Join-Path $root 'examples\flow\ticket.mmd'
  $out = Join-Path $root 'examples\flow\_verify.svg'
  if ((Test-Path $cli) -and (Test-Path $mmd)) {
    $res = & $cli render $mmd $out 2>&1
    if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1000)) {
      Ok ('cli render -> ' + (Get-Item $out).Length + ' bytes')
    } else {
      Fail ('cli render produced nothing: ' + ($res -join ' '))
    }
    $chk = & $cli check $mmd 2>&1
    if (($chk -join ' ') -match '无环') {
      Ok ('cli check -> ' + ($chk -join ' '))
    } else {
      Fail ('cli check unexpected: ' + ($chk -join ' '))
    }
    $cyc = & $cli check (Join-Path $root 'examples\flow\cycle.mmd') 2>&1
    if (($cyc -join ' ') -match '存在环') {
      Ok ('cli cycle detection -> ' + ($cyc -join ' '))
    } else {
      Fail ('cli cycle detection failed: ' + ($cyc -join ' '))
    }
    # mindmap: outline -> tree layout, horizontal by default
    $mdFile = Join-Path $root 'examples\flow\plan.md'
    $mdOut = Join-Path $root 'examples\flow\_verify_plan.svg'
    $mdDown = Join-Path $root 'examples\flow\_verify_plan_down.svg'
    if (Test-Path $mdFile) {
      $null = & $cli mindmap $mdFile $mdOut 2>&1
      $null = & $cli mindmap $mdFile $mdDown --direction DOWN 2>&1
      if ((Test-Path $mdOut) -and (Test-Path $mdDown)) {
        $s1 = Get-Content $mdOut -Raw
        $s2 = Get-Content $mdDown -Raw
        if (($s1 -ne $s2) -and ((Get-Item $mdOut).Length -gt 1000)) {
          Ok ('cli mindmap -> ' + (Get-Item $mdOut).Length + ' bytes, direction override differs')
        } else {
          Fail 'cli mindmap: default and DOWN produced identical output'
        }
      } else {
        Fail 'cli mindmap produced nothing'
      }
      Remove-Item $mdOut, $mdDown -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $out -Force -ErrorAction SilentlyContinue
  } else {
    Fail 'cli binary or fixture missing'
  }
}
# --- artifact freshness -----------------------------------------------------
# dist must be newer than every source input, otherwise the shipped exe is
# stale. Checked after the build so it validates the end state.
Section 'artifact freshness'
$inputs = @(Get-ChildItem src -Filter *.mbt) + @(
  Get-Item -Path index.html
  Get-Item -Path style.css
  Get-Item -Path shell\launcher\main.rs
)
$artifacts = @(Get-Item dist\moondraw.html, dist\MoonDraw.exe -ErrorAction SilentlyContinue)
if ($artifacts.Count -lt 2) {
  Fail 'dist artifacts missing (run tools/build-exe.ps1)'
} else {
  $newestInput = $inputs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $oldestArtifact = $artifacts | Sort-Object LastWriteTime | Select-Object -First 1
  if ($newestInput.LastWriteTime -gt $oldestArtifact.LastWriteTime) {
    Fail ("{0} ({1:HH:mm:ss}) is newer than {2} ({3:HH:mm:ss}); artifacts are stale" -f `
        $newestInput.Name, $newestInput.LastWriteTime, $oldestArtifact.Name, $oldestArtifact.LastWriteTime)
  } else {
    Ok ("newest input {0} @ {1:HH:mm:ss}, oldest artifact {2} @ {3:HH:mm:ss}" -f `
        $newestInput.Name, $newestInput.LastWriteTime, $oldestArtifact.Name, $oldestArtifact.LastWriteTime)
  }
  $exeSize = (Get-Item dist\MoonDraw.exe).Length
  $htmlSize = (Get-Item dist\moondraw.html).Length
  Write-Host ("    MoonDraw.exe {0:N0} B  ·  moondraw.html {1:N0} B" -f $exeSize, $htmlSize)
}

# --- end-to-end -------------------------------------------------------------
if (-not $SkipE2E) {
  Section 'cdp end-to-end'
  pwsh -NoProfile -File tools\cdp-e2e.ps1
  if ($LASTEXITCODE -ne 0) { Fail 'cdp-e2e' }
}

Write-Host ""
if ($script:fail -eq 0) {
  Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green
  exit 0
} else {
  Write-Host ("{0} CHECK(S) FAILED" -f $script:fail) -ForegroundColor Red
  exit 1
}
