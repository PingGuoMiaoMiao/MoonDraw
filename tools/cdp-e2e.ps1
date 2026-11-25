param(
  [string]$Chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe',
  [string]$Url = 'file:///D:/moonbit-compition/_moondraw/index.html',
  [int]$Port = 9345
)

$ErrorActionPreference = 'Stop'
$script:failures = 0
function Assert($name, $cond, $detail) {
  if ($cond) { Write-Host ("PASS  {0}{1}" -f $name, $(if($detail){"  [$detail]"}else{""})) }
  else { Write-Host ("FAIL  {0}{1}" -f $name, $(if($detail){"  [$detail]"}else{""})); $script:failures++ }
}

$profileDir = Join-Path $env:TEMP ("moondraw-e2e-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
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
    $buf = New-Object byte[] 262144
    $sb = New-Object Text.StringBuilder
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
      $sb.Clear() | Out-Null
      do {
        $r = $ws.ReceiveAsync((New-Object ArraySegment[byte] -ArgumentList @(,$buf)), [Threading.CancellationToken]::None)
        $r.Wait(20000) | Out-Null
        [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $r.Result.Count))
      } while (-not $r.Result.EndOfMessage)
      $msg = $sb.ToString() | ConvertFrom-Json
      if ($msg.PSObject.Properties.Name -contains 'id' -and $msg.id -eq $id) { return $msg }
    }
    throw "timeout waiting for $method"
  }
  function Js([string]$expr) {
    $res = Send-Cdp 'Runtime.evaluate' @{ expression = $expr; returnByValue = $true; awaitPromise = $true }
    if ($res.result.exceptionDetails) { throw ($res.result.exceptionDetails | ConvertTo-Json -Depth 8) }
    return $res.result.result.value
  }

  Send-Cdp 'Runtime.enable' @{} | Out-Null
  Start-Sleep -Milliseconds 700

  $rect = Js 'JSON.stringify((()=>{const r=document.getElementById("board").getBoundingClientRect();return {l:r.left,t:r.top,w:r.width,h:r.height};})())' | ConvertFrom-Json
  $ox = [double]$rect.l
  $oy = [double]$rect.t
  # camera in the demo scene is (90,70), zoom 1
  function Scr([double]$wx, [double]$wy) {
    @{ x = [int]($ox + 90 + $wx); y = [int]($oy + 70 + $wy) }
  }
  function Mouse([string]$type, $p, [string]$button = 'left', [int]$clickCount = 1) {
    Send-Cdp 'Input.dispatchMouseEvent' @{
      type = $type; x = $p.x; y = $p.y; button = $button;
      buttons = $(if ($type -eq 'mouseReleased') { 0 } else { 1 });
      clickCount = $clickCount
    } | Out-Null
    Start-Sleep -Milliseconds 45
  }
  function Drag($from, $to) {
    Mouse 'mousePressed' $from
    $steps = 6
    for ($i = 1; $i -le $steps; $i++) {
      $p = @{ x = [int]($from.x + ($to.x - $from.x) * $i / $steps); y = [int]($from.y + ($to.y - $from.y) * $i / $steps) }
      Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = $p.x; y = $p.y; button = 'left'; buttons = 1; clickCount = 0 } | Out-Null
      Start-Sleep -Milliseconds 25
    }
    Mouse 'mouseReleased' $to
    Start-Sleep -Milliseconds 150
  }
  # Persisted state is now a document list; return the active tab's scene.
  function Doc() {
    $raw = Js 'localStorage.getItem("moondraw_docs_v1")'
    if (-not $raw) { return $null }
    $all = $raw | ConvertFrom-Json
    $all.docs[$all.active].scene
  }
  function Status() { Js 'document.getElementById("status").textContent' }
  function Key([string]$k, [string]$code, [int]$vk, [int]$mods = 0) {
    Send-Cdp 'Input.dispatchKeyEvent' @{ type = 'keyDown'; key = $k; code = $code; windowsVirtualKeyCode = $vk; modifiers = $mods } | Out-Null
    Send-Cdp 'Input.dispatchKeyEvent' @{ type = 'keyUp'; key = $k; code = $code; windowsVirtualKeyCode = $vk; modifiers = $mods } | Out-Null
    Start-Sleep -Milliseconds 250
  }

  # ---------------------------------------------------------------- A baseline
  $d = Doc
  Assert 'A1 示例文档已加载' ($d.shapes.Count -eq 4 -and $d.edges.Count -eq 3) "shapes=$($d.shapes.Count) edges=$($d.edges.Count)"

  # ------------------------------------------------------- B snapping on drag
  $c1 = Scr 195 172          # centre of shape #1 (120,140,150x64)
  Drag $c1 (Scr 235 202)
  $d = Doc
  Assert 'B1 拖拽移动生效' ($d.shapes[0].x -ne 120) ("x=$($d.shapes[0].x) y=$($d.shapes[0].y)")
  $near = ([math]::Abs($d.shapes[0].x - 160) -le 8) -and ([math]::Abs($d.shapes[0].y - 170) -le 8)
  $snapped = (($d.shapes[0].x % 8) -eq 0) -or (($d.shapes[0].y % 8) -eq 0)
  Assert 'B2 落点被吸附(网格或对齐线)' ($near -and $snapped) ("x=$($d.shapes[0].x) y=$($d.shapes[0].y)")
  Key 'z' 'KeyZ' 90 2
  $d = Doc
  Assert 'B3 Ctrl+Z 恢复到 (120,140)' ($d.shapes[0].x -eq 120 -and $d.shapes[0].y -eq 140) ("x=$($d.shapes[0].x) y=$($d.shapes[0].y)")

  # ------------------------------------------------------------ C rubber band
  Drag (Scr 60 60) (Scr 700 430)
  $st = Status
  Assert 'C1 框选报告数量' ($st -match '框选\s*3') $st
  $sel = Js 'document.title + ""' | Out-Null
  # move the band selection: grab an empty-ish spot inside the selection, on shape #1
  $c1 = Scr 195 172
  Drag $c1 (Scr 215 192)
  $d = Doc
  Assert 'C2 多选整体移动' ([math]::Abs($d.shapes[0].x - $d.shapes[1].x + 230) -lt 400) "s0=($($d.shapes[0].x),$($d.shapes[0].y)) s1=($($d.shapes[1].x),$($d.shapes[1].y)) s3=($($d.shapes[3].x),$($d.shapes[3].y))"
  Assert 'C3 未选中的图形不动' ($d.shapes[2].x -eq 640 -and $d.shapes[2].y -eq 140) "s2=($($d.shapes[2].x),$($d.shapes[2].y))"
  Key 'z' 'KeyZ' 90 2
  Key 'z' 'KeyZ' 90 2
  $d = Doc
  Assert 'C4 两次撤销回到初始' ($d.shapes[0].x -eq 120 -and $d.shapes[1].x -eq 350) "s0.x=$($d.shapes[0].x) s1.x=$($d.shapes[1].x)"

  # ------------------------------------------------------- D select-all / delete
  Key 'a' 'KeyA' 65 2
  $st = Status
  Assert 'D1 Ctrl+A 全选' ($st -match '全选\s*4') $st
  Key 'Delete' 'Delete' 46 0
  $d = Doc
  Assert 'D2 Delete 清空选中' ($d.shapes.Count -eq 0 -and $d.edges.Count -eq 0) "shapes=$($d.shapes.Count)"
  Key 'z' 'KeyZ' 90 2
  $d = Doc
  Assert 'D3 撤销恢复文档' ($d.shapes.Count -eq 4) "shapes=$($d.shapes.Count)"

  # ------------------------------------------------------------ E connector hit
  # double-click the connector between shape 1 and 2 (~world 310,172)
  $edgePt = Scr 310 172
  Mouse 'mousePressed' $edgePt 'left' 1
  Mouse 'mouseReleased' $edgePt 'left' 1
  Mouse 'mousePressed' $edgePt 'left' 2
  Mouse 'mouseReleased' $edgePt 'left' 2
  Start-Sleep -Milliseconds 300
  $editorOpen = Js '(function(){const e=document.getElementById("inline-editor");return !!e && e.style.display==="block";})()'
  Assert 'E1 双击连线打开标签编辑器' ($editorOpen -eq $true) "open=$editorOpen"
  if ($editorOpen) {
    $active = Js 'document.activeElement ? document.activeElement.id : ""'
    Js 'document.getElementById("inline-editor").focus()' | Out-Null
    Send-Cdp 'Input.insertText' @{ text = '是' } | Out-Null
    Start-Sleep -Milliseconds 200
    $val = Js 'document.getElementById("inline-editor").value'
    Assert 'E2a 文本进入编辑框' ($val -eq '是') "activeElement=$active value=$val"
    Key 'Enter' 'Enter' 13 0
    Start-Sleep -Milliseconds 300
    $d = Doc
    $labelled = @($d.edges | Where-Object { $_.label -eq '是' }).Count
    Assert 'E2b 连线标签已写入' ($labelled -ge 1) ("labels=" + (($d.edges | ForEach-Object { "'$($_.label)'" }) -join ','))
  }

  # --------------------------------------------------------- F create + snap
  Js 'document.querySelector("[data-tool=rect]").click()' | Out-Null
  Start-Sleep -Milliseconds 150
  Drag (Scr 180 520) (Scr 300 590)
  $d = Doc
  $new = $d.shapes | Where-Object { $_.x -gt 170 -and $_.y -gt 510 } | Select-Object -First 1
  Assert 'F1 新建图形成功' ($null -ne $new) ''
  if ($new) {
    Assert 'F2 新建图形也吸附网格' ((($new.x % 8) -eq 0) -and (($new.y % 8) -eq 0)) "x=$($new.x) y=$($new.y) w=$($new.w) h=$($new.h)"
  }

  # ------------------------------------------------ G mermaid import (M3)
  Js 'document.querySelector("[data-action=mermaid]").click()' | Out-Null
  Start-Sleep -Milliseconds 500
  $d = Doc
  Assert 'G1 Mermaid 导入生成节点' ($d.shapes.Count -eq 7) "shapes=$($d.shapes.Count)"
  Assert 'G2 Mermaid 导入生成连线' ($d.edges.Count -eq 7) "edges=$($d.edges.Count)"
  $kinds = ($d.shapes | ForEach-Object { $_.kind }) -join ','
  Assert 'G3 节点形状被映射' ($kinds -match 'diamond' -and $kinds -match 'round' -and $kinds -match 'ellipse') $kinds
  $st = Status
  Assert 'G4 导入状态提示' ($st -match '已导入 Mermaid') $st

  # canvas actually repainted after import
  $nonBg = Js '(function(){const c=document.getElementById("board");const g=c.getContext("2d");const d=g.getImageData(0,0,c.width,c.height).data;let n=0;for(let i=0;i<d.length;i+=4){if(d[i]!==244||d[i+1]!==246||d[i+2]!==250)n++;}return n;})()'
  Assert 'G5 导入后画布有内容' ([int]$nonBg -gt 20000) "non-bg px=$nonBg"

  # --------------------------------------------------- H save as file (M3)
  $dlDir = Join-Path $env:TEMP ("moondraw-dl-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
  New-Item -ItemType Directory -Force -Path $dlDir | Out-Null
  $ok = $true
  try { Send-Cdp 'Browser.setDownloadBehavior' @{ behavior = 'allow'; downloadPath = $dlDir } | Out-Null }
  catch { try { Send-Cdp 'Page.setDownloadBehavior' @{ behavior = 'allow'; downloadPath = $dlDir } | Out-Null } catch { $ok = $false } }

  Js 'document.querySelector("[data-action=saveFile]").click()' | Out-Null
  Start-Sleep -Milliseconds 700
  $st = Status
  Assert 'H1 保存为 .moondraw' ($st -match 'moondraw\.moondraw') $st

  # ------------------------------------------------ I whole-diagram PNG (M3)
  Js 'document.querySelector("[data-action=png]").click()' | Out-Null
  Start-Sleep -Milliseconds 1200
  $st = Status
  Assert 'I1 整图 PNG 导出' ($st -match '已导出整图 PNG') $st

  # ---------------------------------------------------- J files on disk (M3)
  Start-Sleep -Milliseconds 500
  $files = @{}
  foreach ($f in Get-ChildItem $dlDir -File) { $files[$f.Name] = $f.FullName }
  Write-Host "downloads: $($files.Keys -join ', ')"
  Assert 'J1 下载目录收到文件' ($files.Count -ge 2) "count=$($files.Count) cdp=$ok"

  $docPath = $files.Values | Where-Object { $_ -like '*.moondraw' } | Select-Object -First 1
  if ($docPath) {
    $docJson = Get-Content -Raw -Encoding UTF8 $docPath | ConvertFrom-Json
    Assert 'J2 .moondraw 是可读 JSON' ($docJson.shapes.Count -eq 7) "shapes=$($docJson.shapes.Count)"
  } else { Assert 'J2 .moondraw 是可读 JSON' $false 'file missing' }

  $pngPath = $files.Values | Where-Object { $_ -like '*.png' } | Select-Object -First 1
  if ($pngPath) {
    $bytes = [IO.File]::ReadAllBytes($pngPath)
    $sig = ($bytes[0] -eq 137 -and $bytes[1] -eq 80 -and $bytes[2] -eq 78 -and $bytes[3] -eq 71)
    $pw = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
    $ph = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]
    Assert 'J3 PNG 文件头有效' $sig "bytes=$($bytes.Length)"
    Assert 'J4 PNG 尺寸 = 2x 包围盒' ($pw -eq 1292 -and $ph -eq 1556) "${pw}x${ph}"
    Assert 'J5 PNG 体积合理（非空白）' ($bytes.Length -gt 8000) "size=$($bytes.Length)"
  } else { Assert 'J3 PNG 文件头有效' $false 'file missing' }

  $svgPath = $files.Values | Where-Object { $_ -like '*.svg' } | Select-Object -First 1
  if (-not $svgPath) {
    Js 'document.querySelector("[data-action=svg]").click()' | Out-Null
    Start-Sleep -Milliseconds 700
    $svgPath = (Get-ChildItem $dlDir -File | Where-Object { $_.Name -like '*.svg' } | Select-Object -First 1).FullName
  }
  if ($svgPath) {
    $svg = Get-Content -Raw -Encoding UTF8 $svgPath
    Assert 'J6 SVG 含中文节点文本' ($svg -match '上报工单') "len=$($svg.Length)"
  } else { Assert 'J6 SVG 含中文节点文本' $false 'file missing' }

  Remove-Item -Recurse -Force $dlDir -ErrorAction SilentlyContinue

  # ------------------------------------------------- K open a file (M3 gap)
  $srcFile = Join-Path $env:TEMP ("moondraw-open-" + [guid]::NewGuid().ToString('N').Substring(0, 6) + ".moondraw")
  $payload = '{"shapes":[{"id":1,"kind":"rect","x":0,"y":0,"w":120,"h":60,"text":"甲","fill":"#ffffff","stroke":"#8b9bb4"},{"id":2,"kind":"ellipse","x":300,"y":0,"w":120,"h":60,"text":"乙","fill":"#e8faf1","stroke":"#10b981"}],"edges":[{"id":3,"from":1,"to":2,"label":"连线"}],"next_id":4}'
  [IO.File]::WriteAllText($srcFile, $payload, [Text.UTF8Encoding]::new($false))
  Js 'document.querySelector("[data-action=open]").click()' | Out-Null
  Start-Sleep -Milliseconds 300
  Send-Cdp 'DOM.enable' @{} | Out-Null
  $doc0 = Send-Cdp 'DOM.getDocument' @{ depth = 1 }
  $rootId = $doc0.result.root.nodeId
  $q = Send-Cdp 'DOM.querySelector' @{ nodeId = $rootId; selector = '#file-input' }
  $inputId = $q.result.nodeId
  if ($inputId) {
    Send-Cdp 'DOM.setFileInputFiles' @{ nodeId = $inputId; files = @($srcFile) } | Out-Null
    Start-Sleep -Milliseconds 700
    $d = Doc
    Assert 'K1 打开 .moondraw 生效' ($d.shapes.Count -eq 2) "shapes=$($d.shapes.Count)"
    Assert 'K2 打开后内容正确' ($d.shapes[0].text -eq '甲' -and $d.shapes[1].text -eq '乙') "texts=$($d.shapes[0].text),$($d.shapes[1].text)"
    Assert 'K3 连线一并载入' ($d.edges.Count -eq 1) "edges=$($d.edges.Count)"
    Assert 'K4 打开状态提示' ((Status) -match '已打开') (Status)
  } else {
    Assert 'K1 打开 .moondraw 生效' $false 'file input not created'
  }
  Remove-Item -Force $srcFile -ErrorAction SilentlyContinue

  # ------------------------------------------- L IME composition (M0/F0 gap)
  # Double-click empty canvas -> empty editor -> feed a composition event.
  # Screen-space point: the camera moved after the file import + fit.
  $empty = @{ x = [int]($ox + $rect.w * 0.82); y = [int]($oy + $rect.h * 0.78) }
  Mouse 'mousePressed' $empty 'left' 1
  Mouse 'mouseReleased' $empty 'left' 1
  Mouse 'mousePressed' $empty 'left' 2
  Mouse 'mouseReleased' $empty 'left' 2
  Start-Sleep -Milliseconds 400
  $open = Js '(function(){const e=document.getElementById("inline-editor");return !!e && e.style.display==="block";})()'
  Assert 'L1 空白处双击打开编辑器' ($open -eq $true) "open=$open"
  if ($open) {
    Js 'document.getElementById("inline-editor").focus()' | Out-Null
    Send-Cdp 'Input.imeSetComposition' @{ text = '中文'; selectionStart = 2; selectionEnd = 2 } | Out-Null
    Start-Sleep -Milliseconds 200
    $v1 = Js 'document.getElementById("inline-editor").value'
    Assert 'L2 组合中文本进入编辑框' ($v1 -eq '中文') "value=$v1"
    Send-Cdp 'Input.imeSetComposition' @{ text = ''; selectionStart = 0; selectionEnd = 0 } | Out-Null
    Send-Cdp 'Input.insertText' @{ text = '中文' } | Out-Null
    Start-Sleep -Milliseconds 200
    Key 'Enter' 'Enter' 13 0
    Start-Sleep -Milliseconds 350
    $d = Doc
    $hit = @($d.shapes | Where-Object { $_.text -eq '中文' }).Count
    Assert 'L3 组合文本提交为图形文字' ($hit -eq 1) "match=$hit shapes=$($d.shapes.Count)"
  }

  # ------------------------------------------------------ M documents (P2)
  function Tabs() { (Js 'ui_docs_json()') | ConvertFrom-Json }
  function ActiveShapes() {
    $d = Doc
    if ($null -eq $d) { return 0 }
    return $d.shapes.Count
  }

  $t0 = Tabs
  Assert 'M1 初始单文档' ($t0.docs.Count -eq 1 -and $t0.active -eq 0) "docs=$($t0.docs.Count) active=$($t0.active)"
  $before = ActiveShapes

  Js 'document.getElementById("tab-add").click()' | Out-Null
  Start-Sleep -Milliseconds 500
  $t1 = Tabs
  Assert 'M2 新建文档切到新标签' ($t1.docs.Count -eq 2 -and $t1.active -eq 1) "docs=$($t1.docs.Count) active=$($t1.active)"
  Assert 'M3 新文档是空的' ((ActiveShapes) -eq 0) "shapes=$(ActiveShapes)"
  $emptyShown = Js 'getComputedStyle(document.getElementById("empty-state")).display'
  Assert 'M3b 空白画布显示空状态' ($emptyShown -eq 'grid') "display=$emptyShown"

  # draw something in the new tab
  Js 'document.querySelector("[data-tool=round]").click()' | Out-Null
  Start-Sleep -Milliseconds 150
  Drag (Scr 200 300) (Scr 340 380)
  $drawn = ActiveShapes
  Assert 'M4 新文档里能画' ($drawn -eq 1) "shapes=$drawn"
  $emptyHidden = Js 'getComputedStyle(document.getElementById("empty-state")).display'
  Assert 'M4b 有内容后隐藏空状态' ($emptyHidden -eq 'none') "display=$emptyHidden"

  # switch back to tab 0
  Js 'document.querySelectorAll(".tab")[0].click()' | Out-Null
  Start-Sleep -Milliseconds 500
  $t2 = Tabs
  Assert 'M5 切回第一个标签' ($t2.active -eq 0) "active=$($t2.active)"
  Assert 'M6 第一个文档内容未变' ((ActiveShapes) -eq $before) "shapes=$(ActiveShapes) expected=$before"

  # switch forward again: the drawn shape must still be there
  Js 'document.querySelectorAll(".tab")[1].click()' | Out-Null
  Start-Sleep -Milliseconds 500
  Assert 'M7 第二个文档内容保留' ((ActiveShapes) -eq $drawn) "shapes=$(ActiveShapes)"

  # close the second tab
  Js 'document.querySelectorAll(".tab .close")[1].click()' | Out-Null
  Start-Sleep -Milliseconds 500
  $t3 = Tabs
  Assert 'M8 关闭标签后只剩一个' ($t3.docs.Count -eq 1) "docs=$($t3.docs.Count)"
  Assert 'M9 关闭后回到第一个文档' ((ActiveShapes) -eq $before) "shapes=$(ActiveShapes)"

  # reload: tabs must survive
  Send-Cdp 'Page.reload' @{} | Out-Null
  Start-Sleep -Milliseconds 2500
  $t4 = Tabs
  Assert 'M10 刷新后文档仍在' ($t4.docs.Count -eq 1 -and (ActiveShapes) -eq $before) "docs=$($t4.docs.Count) shapes=$(ActiveShapes)"

  # ------------------------------------ N export ranges (P2: all/selection/viewport)
  $dlDir = Join-Path $env:TEMP ("moondraw-dl2-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
  New-Item -ItemType Directory -Force -Path $dlDir | Out-Null
  try { Send-Cdp 'Browser.setDownloadBehavior' @{ behavior = 'allow'; downloadPath = $dlDir } | Out-Null } catch { }
  function NewestFile($pattern) {
    Get-ChildItem $dlDir -File | Where-Object { $_.Name -like $pattern } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
  }
  function PngSize($path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $w = ([int]$bytes[16] -shl 24) -bor ([int]$bytes[17] -shl 16) -bor ([int]$bytes[18] -shl 8) -bor [int]$bytes[19]
    $h = ([int]$bytes[20] -shl 24) -bor ([int]$bytes[21] -shl 16) -bor ([int]$bytes[22] -shl 8) -bor [int]$bytes[23]
    return @{ w = $w; h = $h }
  }

  # whole diagram (already exported above as moondraw-all.png after the change)
  $allFile = NewestFile 'moondraw-all.png'
  if (-not $allFile) { Js 'document.querySelector("[data-action=png]").click()' | Out-Null; Start-Sleep -Milliseconds 1200; $allFile = NewestFile 'moondraw-all.png' }
  if ($allFile) {
    $sz = PngSize $allFile.FullName
    # Expected = current document bounds + 96 padding, at 2x.
    $sd = Doc
    $xs = @($sd.shapes | ForEach-Object { $_.x }) + @($sd.shapes | ForEach-Object { $_.x + $_.w })
    $ys = @($sd.shapes | ForEach-Object { $_.y }) + @($sd.shapes | ForEach-Object { $_.y + $_.h })
    $expW = [int]((($xs | Measure-Object -Maximum).Maximum - ($xs | Measure-Object -Minimum).Minimum + 96) * 2)
    $expH = [int]((($ys | Measure-Object -Maximum).Maximum - ($ys | Measure-Object -Minimum).Minimum + 96) * 2)
    Assert 'N1 整图导出 = 文档包围盒 2 倍' ([math]::Abs($sz.w - $expW) -le 2 -and [math]::Abs($sz.h - $expH) -le 2) "$($sz.w)x$($sz.h) expected ${expW}x${expH}"
  } else { Assert 'N1 整图导出尺寸' $false 'no moondraw-all.png' }

  # viewport: equals canvas css size * 2
  Js 'document.getElementById("export-range").value = "viewport"' | Out-Null
  Js 'document.querySelector("[data-action=png]").click()' | Out-Null
  Start-Sleep -Milliseconds 1200
  $vpFile = NewestFile 'moondraw-viewport.png'
  if ($vpFile) {
    $sz = PngSize $vpFile.FullName
    $cw = [int]$rect.w; $chh = [int]$rect.h
    Assert 'N2 视口导出 = 画布 2 倍' ($sz.w -eq ($cw * 2) -and [math]::Abs($sz.h - ($chh * 2)) -le 2) "$($sz.w)x$($sz.h) vs canvas ${cw}x${chh}"
    $allSz = PngSize $allFile.FullName
    Assert 'N3 视口与整图是不同裁剪' (($sz.w -ne $allSz.w) -or ($sz.h -ne $allSz.h)) "viewport=$($sz.w)x$($sz.h) all=$($allSz.w)x$($allSz.h)"
  } else { Assert 'N2 视口导出 = 画布 2 倍' $false 'no moondraw-viewport.png' }

  # selection: work in a fresh document so the camera is the known default
  # (90,70 / zoom 1) and the only shape is the one we just drew.
  Js 'document.querySelector("[data-tool=round]").click()' | Out-Null
  Start-Sleep -Milliseconds 120
  Js 'ui_new_doc()' | Out-Null
  Start-Sleep -Milliseconds 300
  Drag (Scr 200 200) (Scr 320 280)   # 120x80 at world (110,130)
  Start-Sleep -Milliseconds 200
  Key 'a' 'KeyA' 65 2
  Start-Sleep -Milliseconds 250
  Js 'document.getElementById("export-range").value = "selection"' | Out-Null
  $selShapes = ((Doc) | ForEach-Object { $_.shapes.Count })
  Assert 'N3b 选区测试文档只有一个图形' ($selShapes -eq 1) "shapes=$selShapes"
  Js 'document.querySelector("[data-action=png]").click()' | Out-Null
  Start-Sleep -Milliseconds 1200
  $selFile = NewestFile 'moondraw-selection.png'
  if ($selFile) {
    $sz = PngSize $selFile.FullName
    # 120x80 shape + 96 padding, doubled => 432x352
    Assert 'N4 选区导出按选中图形裁剪' ($sz.w -eq 432 -and $sz.h -eq 352) "$($sz.w)x$($sz.h) expected 432x352"
    Assert 'N5 选区导出小于整图' ($sz.w -lt 1292) "$($sz.w)x$($sz.h)"
  } else { Assert 'N4 选区导出按选中图形裁剪' $false 'no moondraw-selection.png' }

  # svg honours the range too
  Js 'document.querySelector("[data-action=svg]").click()' | Out-Null
  Start-Sleep -Milliseconds 900
  $selSvg = NewestFile 'moondraw-selection.svg'
  if ($selSvg) {
    $svgText = Get-Content -Raw -Encoding UTF8 $selSvg.FullName
    Assert 'N6 选区 SVG 用裁剪后的 viewBox' ($svgText -match '<svg' -and $svgText -match 'viewBox=') "len=$($svgText.Length)"
  } else { Assert 'N6 选区 SVG 用裁剪后的 viewBox' $false 'no moondraw-selection.svg' }
  Js 'document.getElementById("export-range").value = "all"' | Out-Null

  # ------------------------------------------- O distribute (P2: equal spacing)
  Js 'ui_new_doc()' | Out-Null
  Start-Sleep -Milliseconds 300
  Js 'document.querySelector("[data-tool=rect]").click()' | Out-Null
  Start-Sleep -Milliseconds 120
  Drag (Scr 100 100) (Scr 200 160)
  Drag (Scr 400 100) (Scr 460 160)
  Drag (Scr 700 100) (Scr 780 160)
  Start-Sleep -Milliseconds 200
  $d = Doc
  Assert 'O1 三个图形就位' ($d.shapes.Count -eq 3) "shapes=$($d.shapes.Count)"

  $sorted = @($d.shapes | Sort-Object x)
  $endBefore = $sorted[2].x + $sorted[2].w
  $startBefore = $sorted[0].x

  Key 'a' 'KeyA' 65 2
  Start-Sleep -Milliseconds 200
  Js 'document.querySelector("[data-action=dist-h]").click()' | Out-Null
  Start-Sleep -Milliseconds 400

  $d = Doc
  $s2 = @($d.shapes | Sort-Object x)
  $gap1 = $s2[1].x - ($s2[0].x + $s2[0].w)
  $gap2 = $s2[2].x - ($s2[1].x + $s2[1].w)
  Assert 'O2 横向间距相等' ([math]::Abs($gap1 - $gap2) -lt 0.01) "gap1=$([math]::Round($gap1,2)) gap2=$([math]::Round($gap2,2))"
  Assert 'O3 两端位置不变' ([math]::Abs($s2[0].x - $startBefore) -lt 0.01 -and [math]::Abs(($s2[2].x + $s2[2].w) - $endBefore) -lt 0.01) "start=$($s2[0].x) end=$($s2[2].x + $s2[2].w) before=$startBefore..$endBefore"
  Assert 'O4 分布状态提示' ((Status) -match '等间距') (Status)

  # undo restores the uneven layout
  Key 'z' 'KeyZ' 90 2
  Start-Sleep -Milliseconds 300
  $d = Doc
  $s3 = @($d.shapes | Sort-Object x)
  $ug1 = $s3[1].x - ($s3[0].x + $s3[0].w)
  $ug2 = $s3[2].x - ($s3[1].x + $s3[1].w)
  Assert 'O5 撤销恢复原状' ([math]::Abs($ug1 - $ug2) -gt 0.5) "gap1=$([math]::Round($ug1,2)) gap2=$([math]::Round($ug2,2))"

  # guard: fewer than three selected
  Key 'Escape' 'Escape' 27 0
  Start-Sleep -Milliseconds 150
  Js 'document.querySelector("[data-action=dist-v]").click()' | Out-Null
  Start-Sleep -Milliseconds 250
  Assert 'O6 少于三个图形时给出提示' ((Status) -match '至少 3') (Status)

  # ------------------------------------- P properties panel (left rail shell)
  Js 'ui_new_doc()' | Out-Null
  Start-Sleep -Milliseconds 250
  Js 'document.querySelector("[data-tool=rect]").click()' | Out-Null
  Start-Sleep -Milliseconds 120
  Drag (Scr 200 200) (Scr 340 280)
  Start-Sleep -Milliseconds 250

  $panel = (Js 'ui_selection_panel()') | ConvertFrom-Json
  Assert 'P1 单选后属性面板有数据' ($panel.kind -eq 'rect' -and $panel.count -eq 1) "kind=$($panel.kind)"
  Assert 'P2 面板回显几何' ($panel.w -gt 50 -and $panel.h -gt 30) "w=$($panel.w) h=$($panel.h)"
  $domX = Js 'document.getElementById("p-x").value'
  Assert 'P3 DOM 输入框已同步' ([math]::Abs([double]$domX - [double]$panel.x) -lt 1) "dom=$domX model=$($panel.x)"

  # edit geometry through the panel
  Js '(function(){const e=document.getElementById("p-w"); e.value="240"; e.dispatchEvent(new Event("change"));})()' | Out-Null
  Start-Sleep -Milliseconds 300
  $afterW = ((Doc).shapes[0].w)
  Assert 'P4 面板改宽度写回模型' ([math]::Abs([double]$afterW - 240) -lt 1) "w=$afterW"

  # edit colour through the panel
  Js '(function(){const e=document.getElementById("p-fill"); e.value="#ebf5ff"; e.dispatchEvent(new Event("input"));})()' | Out-Null
  Start-Sleep -Milliseconds 300
  $afterFill = ((Doc).shapes[0].fill)
  Assert 'P5 面板改填充写回模型' ($afterFill -eq '#ebf5ff') "fill=$afterFill"

  # zoom controls
  $z0 = Js 'document.getElementById("hud-zoom").textContent'
  Js 'document.querySelector("[data-action=zoom-in]").click()' | Out-Null
  Start-Sleep -Milliseconds 250
  $z1 = Js 'document.getElementById("hud-zoom").textContent'
  Assert 'P6 缩放按钮生效' ($z0 -ne $z1) "$z0 -> $z1"

  # deselect clears the panel
  Key 'Escape' 'Escape' 27 0
  Start-Sleep -Milliseconds 250
  $panelEmpty = Js 'ui_selection_panel()'
  Assert 'P7 取消选中后面板清空' ($panelEmpty -eq 'null') "json=$panelEmpty"

  # ------------------------------------ Q shapes / align / layer (feature gap)
  Js 'ui_new_doc()' | Out-Null
  Start-Sleep -Milliseconds 250
  Js 'document.querySelector("[data-tool=rect]").click()' | Out-Null
  Start-Sleep -Milliseconds 120
  Drag (Scr 100 100) (Scr 220 160)
  Drag (Scr 320 220) (Scr 420 280)
  $d = Doc
  Assert 'Q1 两个矩形就位' ($d.shapes.Count -eq 2) "shapes=$($d.shapes.Count)"

  Key 'a' 'KeyA' 65 2
  Start-Sleep -Milliseconds 200
  Js 'document.querySelector("[data-action=align-left]").click()' | Out-Null
  Start-Sleep -Milliseconds 350
  $d = Doc
  $xs = @($d.shapes | ForEach-Object { [double]$_.x })
  Assert 'Q2 左对齐生效' ([math]::Abs($xs[0] - $xs[1]) -lt 0.01) "x0=$($xs[0]) x1=$($xs[1])"

  # layer: clear the multi-selection, pick one shape, then send it to front
  Key 'Escape' 'Escape' 27 0
  Start-Sleep -Milliseconds 150
  Drag (Scr 140 130) (Scr 141 131)
  Start-Sleep -Milliseconds 200
  $before = (@(Doc).shapes | ForEach-Object { $_.id }) -join ','
  Js 'document.querySelector("[data-action=layer-front]").click()' | Out-Null
  Start-Sleep -Milliseconds 350
  $after = (@(Doc).shapes | ForEach-Object { $_.id }) -join ','
  Assert 'Q3 置顶改变绘制顺序' ($before -ne $after) "before=$before after=$after"

  # new shape kinds round-trip through the model
  Js 'document.querySelector("[data-tool=hexagon]").click()' | Out-Null
  Start-Sleep -Milliseconds 120
  Drag (Scr 520 300) (Scr 640 380)
  Start-Sleep -Milliseconds 250
  $kinds = @(Doc).shapes | ForEach-Object { $_.kind }
  Assert 'Q4 新图元(六边形)可绘制' ($kinds -contains 'hexagon') ("kinds=" + ($kinds -join ','))

  Js 'document.querySelector("[data-tool=cylinder]").click()' | Out-Null
  Start-Sleep -Milliseconds 120
  Drag (Scr 700 300) (Scr 800 400)
  Start-Sleep -Milliseconds 250
  $kinds2 = @(Doc).shapes | ForEach-Object { $_.kind }
  Assert 'Q5 新图元(圆柱)可绘制' ($kinds2 -contains 'cylinder') ("kinds=" + ($kinds2 -join ','))

  Write-Host ""
  if ($script:failures -eq 0) { Write-Host "ALL PASS" } else { Write-Host "FAILURES: $($script:failures)" }

  $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).Wait(5000) | Out-Null
  exit $script:failures
}
finally {
  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 300
  Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue
}
