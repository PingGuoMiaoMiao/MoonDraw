# 定位修订：从「画布编辑器」到「结构化图表引擎」

## 为什么要改

2026-11-26 的初审意见指出：本项目与同期维护的 Moonlight 在主要编辑器内核上实质重合。

复核后我认为这条判断有其依据，但依据的是**前一版定位**。前一版把 MoonDraw 描述为
「流程图与白板编辑器」，读者自然把它与 Excalidraw 类项目并列。而在那个框架下对比，
重合的是选择、拖拽、撤销、缩放手柄——**任何编辑器都会重合的部分**。

真正不重合的部分，此前没有被摆到台面上：**图模型与布局派生**。

## 修订后的定位

> MoonDraw 是 MoonBit 的结构化图表引擎。
> 输入是文本图（Mermaid）或程序化构造的图模型，输出是经过布局计算的 SVG，
> 并提供可嵌入的编辑器前端作为参考实现。

三条交付面：

| 面 | 形态 | 与 Moonlight 的关系 |
|---|---|---|
| 图内核 | moondraw/kernel 包 | 无对应物：对方无 Edge 实体 |
| 布局 | moondraw/elk_layout | 无对应物：对方无布局阶段 |
| 命令行 | moondraw render/layout/check | 无对应物：对方只有浏览器应用 |

## 可核验的差异（不是描述，是能跑的东西）

### 1. 命令行是主入口，不是附属品

`ash
$ moondraw check examples/flow/cycle.mmd
节点 3 · 边 3 · ⚠ 存在环

$ moondraw layout examples/flow/ticket.mmd
节点 7 · 边 7 · 无环
  收到工单  @(65,12)
  是否 P1  @(45,96)
  ...
`

这段输出需要**有向图**才能产生：环检测要走边集做 DFS。一个只存几何图元、
连线是 Line 元素的数据模型，写不出 ⚠ 存在环。

### 2. 换算法，坐标真的会变

同一个 	icket.mmd：

| 算法 | 第一个节点坐标 | 第三个节点坐标 |
|---|---|---|
| layered / DOWN | (65, 12) | (222, 228) |
| mrtree / RIGHT | (40, 103) | (380, 40) |

坐标是**派生**的。Moonlight 的坐标来自用户拖拽，不存在"换算法重排"这个动作，
因为它的模型里没有布局阶段。

### 3. 内核可在无浏览器环境运行

moon build src/cli --target native 通过，产物 3.4 MB，
ender 一次耗时 26–582 ms
（随算法变化）。Moonlight 的 preferred_target = js 且依赖 luna / js_browser 全栈绑定，
无法生成 native 可执行文件。

## 与 Moonlight 的关系：不是竞争，是在不同层

- Moonlight 做**画布**：自由摆放、手绘、贝塞尔拟合、Embed 组件。这些它做得比我好。
- MoonDraw 做**引擎**：文本→图→坐标→矢量。这一层它没有。

若要类比：Moonlight 像 Excalidraw，MoonDraw 更像 Graphviz / ELK 的使用者与封装者。

## 这次修订动了什么

| 项 | 修订前 | 修订后 |
|---|---|---|
| 项目描述 | Flowchart / whiteboard editor | Structured diagram engine |
| 主入口 | 网页 | 命令行 |
| 关键词 | flowchart, whiteboard, editor | diagram, graph, layout, mermaid, elk |
| 包文档首页 | 功能列表 | 交付面表格 + 三段 Quickstart |
| 版本 | 0.1.2 | 0.2.0（破坏性的定位变更） |

编辑器前端保留，但降级为"参考实现"，用于证明内核在真实交互下可用。

## 仍然存在的重合，我不否认

选择框、拖拽、撤销栈、缩放手柄、网格吸附——这些在任何编辑器里都会有。
如果评审认为"任何编辑器都会重合的部分"也算实质重合，那这条我无法反驳；
但如果标准是"核心职责与扩展方向是否相同"，则两项目的重心分别在
**画布交互**与**图布局**，且这一差异已经体现在数据模型、导出链路与分发形态上。
