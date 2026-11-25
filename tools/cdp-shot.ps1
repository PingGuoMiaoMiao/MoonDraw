param(
  [string]$Chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe',
  [string]$Url = 'file:///D:/moonbit-compition/_moondraw/index.html',
  [int]$Port = 9351,
  [string]$OutDir = 'D:\moonbit-compition\_moondraw\docs'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$profileDir = Join-Path $env:TEMP ("moondraw-shot-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $profileDir | Out-Null
$proc = Start-Process -FilePath $Chrome -PassThru -ArgumentList @(
  '--headless=new', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
  "--remote-debugging-port=$Port", "--user-data-dir=$profileDir",
  '--window-size=1440,900', $Url
)

try {
  $targets = $null
  for ($i = 0; $i -lt 80; $i++) {
    try {
      $targets = Invoke-RestMethod "http://127.0.0.1:$Port/json/list" -TimeoutSec 2
      if ($targets | Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl }) { break }
    } catch { Start-Sleep -Milliseconds 250 }
  }
  if (-not $targets) { throw "CDP did not come up" }
  $page = $targets | Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl } | Select-Object -First 1
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $ws.ConnectAsync([uri]$page.webSocketDebuggerUrl, [Threading.CancellationToken]::None).Wait(10000) | Out-Null

  $script:nextId = 0
  function Send-Cdp([string]$method, $params) {
    $script:nextId++
    $id = $script:nextId
    $payload = @{ id = $id; method = $method; params = $params } | ConvertTo-Json -Depth 12 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $ws.SendAsync((New-Object ArraySegment[byte] -ArgumentList @(,$bytes)), [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait(10000) | Out-Null
    $buf = New-Object byte[] 4194304
    $sb = New-Object Text.StringBuilder
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
      $sb.Clear() | Out-Null
      do {
        $r = $ws.ReceiveAsync((New-Object ArraySegment[byte] -ArgumentList @(,$buf)), [Threading.CancellationToken]::None)
        $r.Wait(30000) | Out-Null
        [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $r.Result.Count))
      } while (-not $r.Result.EndOfMessage)
      $msg = $sb.ToString() | ConvertFrom-Json
      if ($msg.PSObject.Properties.Name -contains 'id' -and $msg.id -eq $id) { return $msg }
    }
    throw "timeout waiting for $method"
  }
  function Js([string]$expr) {
    $res = Send-Cdp 'Runtime.evaluate' @{ expression = $expr; returnByValue = $true }
    return $res.result.result.value
  }
  function Shot([string]$name) {
    $res = Send-Cdp 'Page.captureScreenshot' @{ format = 'png' }
    $path = Join-Path $OutDir $name
    [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($res.result.data))
    Write-Host "wrote $path ($((Get-Item $path).Length) bytes)"
  }

  Send-Cdp 'Page.enable' @{} | Out-Null
  Send-Cdp 'Runtime.enable' @{} | Out-Null
  Start-Sleep -Milliseconds 800

  $rect = Js 'JSON.stringify((()=>{const r=document.getElementById("board").getBoundingClientRect();return {l:r.left,t:r.top};})())' | ConvertFrom-Json
  $ox = [double]$rect.l; $oy = [double]$rect.top
  function Scr([double]$wx, [double]$wy) { @{ x = [int]($ox + 90 + $wx); y = [int]($oy + 70 + $wy) } }

  # 1. plain board
  Shot 'board.png'

  # 2. select all -> blue outlines everywhere
  Send-Cdp 'Input.dispatchKeyEvent' @{ type = 'keyDown'; key = 'a'; code = 'KeyA'; windowsVirtualKeyCode = 65; modifiers = 2 } | Out-Null
  Send-Cdp 'Input.dispatchKeyEvent' @{ type = 'keyUp'; key = 'a'; code = 'KeyA'; windowsVirtualKeyCode = 65; modifiers = 2 } | Out-Null
  Start-Sleep -Milliseconds 400
  Shot 'multi-select.png'

  # 3. rubber band mid-drag
  $a = Scr 60 60; $b = Scr 700 430
  Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mousePressed'; x = $a.x; y = $a.y; button = 'left'; buttons = 1; clickCount = 1 } | Out-Null
  for ($i = 1; $i -le 5; $i++) {
    $p = @{ x = [int]($a.x + ($b.x - $a.x) * $i / 5); y = [int]($a.y + ($b.y - $a.y) * $i / 5) }
    Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = $p.x; y = $p.y; button = 'left'; buttons = 1; clickCount = 0 } | Out-Null
    Start-Sleep -Milliseconds 40
  }
  Start-Sleep -Milliseconds 200
  Shot 'band-select.png'
  Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = $b.x; y = $b.y; button = 'left'; buttons = 0; clickCount = 1 } | Out-Null

  # 4. Mermaid import
  Js 'document.querySelector("[data-action=mermaid]").click()' | Out-Null
  Start-Sleep -Milliseconds 700
  Shot 'mermaid-import.png'

  $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).Wait(5000) | Out-Null
}
finally {
  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 300
  Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue
}
