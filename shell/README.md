# MoonDraw shell (M4)

前端始终是 `dist/index.html`（由 `tools/build-exe.ps1` 把 JS/CSS 内联成的单文件）。这里提供两种“双击即用”的壳，共用同一份前端。

| 方案 | 产物 | 体积 | 前提 | 本机验证 |
| --- | --- | --- | --- | --- |
| `launcher/`（已交付） | `MoonDraw.exe` | 460 KiB（内含 218 KB 前端） | 目标机有 Edge 或 Chrome（Win10/11 默认有） | 构建、内嵌、解包、浏览器解析全部验证；窗口弹出受沙箱限制，见下 |
| `tauri/`（脚手架） | `MoonDraw.exe` + 安装包 | 约 5–15 MB | 需要 crates.io 拉 `tauri` 依赖 | **未构建**：本机 crates.io 的 TLS 连接被拦 |

## launcher：零依赖便携壳

```powershell
pwsh -NoProfile -File ..\..\tools\build-exe.ps1
dist\MoonDraw.cmd             # 双击运行（已验证出窗口）
dist\MoonDraw.exe             # 直接跑；若本机策略不允许 exe 拉起浏览器则无窗口
dist\MoonDraw.exe --where     # 把解析结果写到同目录 where.txt
dist\MoonDraw.exe --dump-html # 把内嵌前端释放到同目录
```

`MoonDraw.cmd` 与 `MoonDraw.exe` 是同一份前端的两个入口：

| 入口 | 机制 | 本机验证 |
| --- | --- | --- |
| `MoonDraw.cmd` | shell 里 `start <browser> --app=...` | ✅ 窗口出现，渲染像素已核对 |
| `MoonDraw.exe` | 内嵌前端 → 解包 → 自己 spawn 浏览器 | ⚠️ 解包与解析正确，**拉起浏览器这一步在本机被拦** |

**为什么两个都要**：`MoonDraw.exe` 是真正的单文件（460 KB，拷走就能跑），但某些环境（这台就属于）不允许一个 GUI 子进程再拉起浏览器——Chrome 以 `0x80000003` 直接退出，Edge 报 `%TEMP% is not writable` 后停白页。同一条命令从 shell 执行则一切正常。所以 `MoonDraw.cmd` 作为兜底入口，代价是闪一下控制台。

行为（exe 路径）：

1. 把内嵌的 `moondraw.html` 释放到 **exe 同目录**（便携语义）；该目录只读时依次回退到 `%LOCALAPPDATA%\MoonDraw`、`%TEMP%\MoonDraw`。
2. 在 html 旁边建 `profile\` 作为浏览器用户目录，并写入 Chromium 约定的 `First Run` 标记，避免全新 profile 卡在首启白页。
3. 找浏览器：Chrome 优先，其次 Edge（Win10/11 必然存在）。
4. 以 `--app=` 模式启动，得到无地址栏、无标签页的应用窗口——渲染引擎和 WebView2 是同一个 Chromium。

零 crate 依赖（本机无 crates.io），只用 `std` + 两个 Win32 调用（`MessageBoxW`、`CommandExt::creation_flags`）。

### 踩过的四个坑（都写进代码注释了）

1. **直接 `CreateProcess` 拉起浏览器会让 Chrome 以 `0x80000003` 退出**；经由 `cmd /C start` 才稳定。
2. **`CREATE_NO_WINDOW` 会让 `start` 用 `SW_HIDE` 创建子窗口**——进程起来了但永不可见；改 `DETACHED_PROCESS`。
3. **`FreeConsole` 之后的继承句柄是死的**，子进程会误判；改为 GUI 子系统 + 给子进程空 stdio。
4. **全新 profile 的 Edge 会停在白页**（标题一直是 URL）；写 `First Run` 标记 + `--disable-features=msEdgeFirstRunExperience,msEdgeWelcomePage` 解决。

## tauri：正式壳（需联网构建）

```powershell
cd shell/tauri
npm install          # 需要网络
npm run build        # = 重建前端 + tauri build
```

产物在 `shell/tauri/src-tauri/target/release/bundle/`。前端零改动——Tauri 只是把 `dist/index.html` 塞进 WebView2。

**为什么这里没构建**：`cargo` 与 MSVC 都在，WebView2 运行时 157.0.4341.60 也已安装，但 crates.io 的 TLS 握手被环境拦截（`SSL connection could not be established`），拉不到 `tauri` 及其数百个传递依赖。
