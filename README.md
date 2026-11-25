# MoonDraw

用 MoonBit 写的流程图 / 白板编辑器。

**在线试用：<https://pingguomiaomiao.github.io/MoonDraw/>**（纯静态，GitHub Pages 托管，无需服务器；也支持离线双击本地文件）

**安装（mooncakes）：** `moon add PingGuoMiaoMiao/moondraw@0.1.0` — 可直接消费 `moondraw/kernel`（纯逻辑，js / wasm / native 均可运行）

UI 逻辑、文档模型、命中测试、正交连线路由、撤销栈、SVG 导出、Mermaid 解析与自动布局全部是纯 MoonBit；只通过一层很薄的 `extern "js"` 绑定调用 Canvas 2D 与 DOM。

当前进度：**M0（技术验证）+ M1（内核）+ M2（多选/吸附/连线）+ M3（文件与互操作）+ M4（便携 exe 壳）完成**。

## 快速开始 / Quickstart

三种形态，同一份前端代码：

```bash
moon build --target js --release     # 开发：直接打开 index.html
pwsh tools/build-exe.ps1             # 单文件 + 便携 exe（dist/）
```

| 形态 | 命令 | 产物 |
| --- | --- | --- |
| 网页 | `moon build --target js --release` → 打开 `index.html` | 无（`file://` 可用） |
| 单文件 | `tools/build-exe.ps1` | `dist/moondraw.html` · 9.1 MB（内联 ELK） |
| 便携 exe | 双击 `dist/MoonDraw.exe` | `dist/MoonDraw.exe` · 9.1 MB |
| **兜底入口** | 双击 `dist/MoonDraw.cmd` | 同一份前端，shell 拉起浏览器 app 窗口 |

> 两种入口的差别：`MoonDraw.exe` 自己 spawn 浏览器，在部分受限环境会被拦（本机就是）；`MoonDraw.cmd` 走 shell 的 `start`，已验证能出窗口。详见 [shell/README.md](shell/README.md)。

详见 [shell/README.md](shell/README.md)（Tauri 脚手架与踩过的坑都在那里）。

命令行演示（不需要浏览器，证明内核与 DOM 无关）：

```bash
moon run src/cmd_mermaid_preview --target js
```

输出 5 个节点、5 条连线以及一份 2.7 KB 的 SVG。

```bash
pwsh tools/verify.ps1                 # 一条命令：check + 单测 + 构建 + 产物新鲜度 + 端到端
pwsh tools/publish-pages.ps1          # 生成 docs/index.html（Pages 用的单文件，已提交）
moon test --target js                 # 51 个用例（内核 18 + 应用 33）
moon test --target native             # 18 个纯内核用例（内核与 DOM 无关的证明）
moon build --target native            # 内核 + 命令行示例，不需要浏览器
pwsh tools/cdp-e2e.ps1                # 59 项端到端断言（需要本机 Chrome）
pwsh tools/cdp-shot.ps1               # 生成 docs/*.png 截图
```

## 操作

| 操作 | 方式 |
| --- | --- |
| 选择 / 移动 | 选择工具下拖拽图形；移动时自动吸附网格并对齐邻近图形（红色对齐线） |
| 多选 | Shift + 点击切换；空白处拖拽框选（只选中完全框住的图形） |
| 全选 / 删除 | Ctrl+A / Delete |
| 多文档 | 标签栏 `+` 新建（Ctrl+T）、点击切换、`×` 关闭（Ctrl+W）、双击标签重命名 |
| 等间距分布 | 选中 3+ 图形后点「⇹ 横分布 / ⇕ 纵分布」，两端不动、中间等间距（不吸附，保证严格相等） |
| 缩放图形 | 拖拽四角控制点（仅单选时出现） |
| 新建图形 | 选矩形/圆角/菱形/椭圆后拖拽；单击给默认尺寸，落点吸附 8px 网格 |
| 连线 | 连线工具：从 A 拖到 B；单击连线可选中（高亮），Delete 删除 |
| 改文字 / 连线标签 | 双击图形改文字，双击连线改标签，双击空白处插入文本 |
| 平移 / 缩放画布 | H 或中键拖拽 / 滚轮（以指针为锚点） |
| 撤销 / 重做 | Ctrl+Z / Ctrl+Shift+Z |
| 适配视图 | F |
| 打开 / 保存 | 打开 `.moondraw` / `.json` / `.mmd`；保存为 `.moondraw` |
| 导入 Mermaid | 工具栏「Mermaid」按钮导入示例；`打开` 也支持 `.mmd` 文件 |
| 导出 | 先选范围（整图 / 选区 / 视口），再点 SVG 或 PNG；PNG 固定 2x，Ctrl+S 存本地 |
| 自动布局 | 顶栏选算法（分层/力导向/应力/树形/辐射/装箱）→「自动布局」；Mermaid 导入也走 ELK |

## 架构

```
src/kernel/         纯 MoonBit 内核：不引用 FFI，js / native / wasm 都能构建
  types.mbt      Shape / Edge / Scene / View / Drag / App 数据结构
  geom.mbt       命中测试、正交路由、点到线段距离
  scene.mbt      增删改查、示例文档、JSON 序列化（含转义）、包围盒
  select.mbt     选择集、框选、连线命中、删除、网格吸附、对齐辅助线
  mermaid.mbt    Mermaid flowchart 子集解析（节点/连线/标签/方向）
  layout.mbt     分层自动布局（BFS 定层 → 按层排布）
  svg.mbt        SVG 导出（与画布同一套坐标与样式）
  render.mbt     Canvas 绘制：网格、边、图形、选中框、框选框、对齐线、HUD、离屏导出
  app.mbt        交互状态机、撤销栈、文本编辑、文件读写、对外 API
  ffi.mbt        唯一的 JS 边界（canvas / 事件 / 文件 / 下载 / 存储 / JSON）
  bench.mbt      内核基准（时钟由调用方注入，保持纯函数）
  view.mbt       相机变换
  shape_ops.mbt  字段变更的具名操作
  kernel_wbtest.mbt   内核单测
  import_wbtest.mbt   Mermaid 解析与布局单测
src/app/            JS 后端：交互状态机 + Canvas 渲染 + 文件 IO
  app.mbt render.mbt ffi.mbt docs.mbt scene_json.mbt types_app.mbt
  select.mbt arrange.mbt
  *_wbtest.mbt
tools/
  build-exe.ps1  内联前端 + 编译便携壳 → dist/moondraw.html、dist/MoonDraw.exe
  cdp-e2e.ps1    59 项端到端断言：真实鼠标/键盘事件 → 状态 → 持久化 → 磁盘文件
  cdp-shot.ps1   抓取 board / multi-select / band-select / mermaid-import 截图
shell/
  launcher/      零依赖 Rust 便携壳（9.1 MB，内嵌前端 + ELK，Edge/Chrome app 模式）
  tauri/         Tauri v2 脚手架（需联网构建，本机未构建，原因见 shell/README.md）
```

设计要点：

- **布局交给 ELK**：src/elk_layout 把 Scene 转成 ElkGraph JSON，调用 moonbit-community/elk 的引擎，再把坐标写回；自带的分层实现保留为后备。
- **内核不碰 DOM**。`geom` / `scene` / `select` / `svg` / `mermaid` / `layout` 可在任何后端跑，可单测。
- **渲染与视口解耦**：`draw_scene(ctx, view, scene, w, h, grid)` 既画交互画布，也画离屏导出画布——PNG 导出复用同一套绘制代码，不会出现“截图像素和 SVG 不一致”。
- **文本编辑走 DOM textarea 覆盖层**，不在 canvas 里自绘光标。canvas 没有 IME 支持，中文输入必须借宿主输入框。
- **高 DPI**：后备存储 = CSS 尺寸 × `devicePixelRatio`，几何一律用 CSS 像素。
- **吸附优先级**：先对齐网格，再叠加对齐辅助线（对齐线优先，和 Figma 一致），所以最终坐标不一定落在 8 的倍数上——这是有意的。
- **撤销**用序列化快照（JSON），简单、可预测；代价是每步 O(文档大小)。
- **Mermaid 导入只取值、不取样式**：样式/子图/点击事件直接丢弃——编辑器要的是图，不是一张画。

## 验证结果（可复现）

内核单测：`moon test --target js` → **50 passed / 0 failed**。
端到端：`tools/cdp-e2e.ps1` → **59/59 PASS**（真实 CDP 事件，断言落在 localStorage、DOM 与磁盘文件上）。

| 断言 | 结果 |
| --- | --- |
| 拖拽 + 吸附 | (120,140) → (160,171)，x 对齐网格、y 被对齐线拉走 |
| Ctrl+Z 恢复 | 回到 (120,140) |
| 框选 3 个并整体移动 | 三个都 +24/+20，未选中的不动 |
| Ctrl+A → Delete → 撤销 | 4 → 0 → 4 |
| 双击连线改标签 | `activeElement=inline-editor`，写入后标签为「是」 |
| 新建图形吸附 | (184,520)，w=120 h=72 |
| Mermaid 导入 | 7 节点 / 7 连线，形状映射为 rect/diamond/round/ellipse |
| 导入后画布重绘 | 非背景像素 220,423 |
| `.moondraw` 落盘 | JSON 可解析，shapes=7 |
| 打开 `.moondraw` | 通过 `DOM.setFileInputFiles` 注入文件 → 场景替换为 2 个图形 + 1 条连线 |
| 整图 PNG 落盘 | 文件头有效、尺寸 1292×1556（= 2× 包围盒）、84 KB 非空白 |
| SVG 落盘 | 含中文节点文本「上报工单」 |
| 中文组合输入 | `Input.imeSetComposition` 组合中文本进入 textarea，回车后落成图形文字「中文」 |
| **真实 app 窗口** | `MoonDraw.cmd` 双击 → Chromium app 窗口 2160×1350，canvas 背景 510,552 采样点、菱形节点色 5,695 点（`docs/app-window.png`） |
| 多文档 | 新建/切换/关闭后各文档内容与视口独立保留；刷新页面后标签从 `moondraw_docs_v1` 恢复 |
| 导出范围 | 整图 = 包围盒+48 padding 的 2 倍；视口 = 画布 CSS 尺寸的 2 倍（所见即所得）；选区 = 选中图形包围盒的 2 倍（实测 432×352） |
| 等间距分布 | 三图形拖拽后点横分布 → 间距 220/220，两端 104..784 不变；撤销能恢复 200/240 的不均匀原状 |
| 高 DPI 后备存储 | CSS 1230×612 → 后备 2460×1224（dpr=2） |
| 工具栏不溢出 | 1440/1180/980/760 四档 `scrollWidth == clientWidth` |
| 内核性能 | 1000 节点：JSON 1.9–10 ms / 152 KB，SVG 4–24 ms / 274 KB（Node，冷启） |
| 跨后端 | moon build --target native 成功，产物 cmd_mermaid_preview.exe；native 18 项内核测试通过 |

端到端抓到过两个单测漏掉的真 bug：`delete_selected` 忘了记快照（Delete 后无法撤销）、Mermaid 的 `|标签|` 被当成链接符吞掉。都已修复并被断言覆盖。

**未验证 / 已知限制**：

- 中文 IME 的**候选框与真实上屏**（自动化已覆盖 `compositionstart/update/end` 事件链路，但输入法候选窗只能人工看）。
- Canvas 帧时间：headless 虚拟时钟下 `performance.now()` 不推进，测不出可信帧率；需 DevTools 手测。
- 触摸 / 触控笔。
- 撤销栈随标签切换重置（每个标签的几何内容会保留，但切回来不能撤销切走前的操作）。
- Mermaid 只支持 flowchart 子集：`A[文本]`、`B(圆角)`、`C((椭圆))`、`D{菱形}`、`-->` / `---` / `-.->` / `==>`、`|标签|` 与 `-- 标签 -->`。`subgraph` 的分组语义、`style`/`classDef`、`click`、时序图/类图等其它图类型都不支持。
- 打开文件走浏览器文件选择框，端到端测试无法驱动（该路径只在单测层面覆盖）。
- **便携 exe 的窗口弹出**：`MoonDraw.cmd` 已验证出窗口（像素已核对）；`MoonDraw.exe` 自解包与浏览器解析正确，但**它自己拉起浏览器的那一步在本机被拦**——同一条命令行从 shell 执行正常，从 GUI 子进程执行时 Chrome 以 `0x80000003` 退出、Edge 报 `%TEMP% is not writable` 后停白页。这是环境限制，不是命令拼写问题。
- Tauri 壳未构建：本机 `cargo`、MSVC、WebView2 157 都在，但 crates.io 的 TLS 被拦，拉不到依赖。

## M4 产物体积对比

| | 体积 | 依赖 |
| --- | --- | --- |
| ioDraw（Electron 便携单文件） | 256.7 MiB | 自带 Chromium |
| MoonDraw（本方案，含 ELK 布局引擎） | **9.1 MB** | 复用系统 Edge/Chrome |
| MoonDraw + Tauri（未构建，估算） | 5–15 MiB | 复用系统 WebView2 |

## 后续

- P2 剩余：连线折点编辑、图形旋转。
- 想要真正的独立窗口而不依赖系统浏览器：在能联网的机器上跑 `shell/tauri`，产物约 5–15 MB。
- 想要零依赖且不依赖浏览器：需要自己实现 WebView2 COM 绑定或原生自绘渲染，代价见最初的风险表。

## 许可

MIT。
