# 与 Moonlight 的能力对比（驳回意见答复）

本文件回应组委会 2026-11-26 的驳回意见：「主要编辑器内核与近期维护的 Moonlight 实质重合」。

## 一、先把对象确认清楚

Mooncakes 与 GitHub 上存在**两个**同名 `moonlight`，二者完全不同：

| 候选 | 仓库 | 性质 | 规模 |
|---|---|---|---|
| A | `mizchi/moonlight` | **MoonBit 写的 SVG / 白板编辑器**（自称 "like Excalidraw"） | 82 个 `.mbt` / 29,194 行 / 486 个测试 |
| B | `Milky2018/moonlight` | MoonBit 写的**分布式任务编排框架**（Dataset / Cluster / Manager / Worker，依赖 moonchor） | 9 个 `.mbt` / 272 行 / 0 个测试 |

据驳回意见中"使用场景、编辑机制"的措辞，评审所指应为 **A：mizchi/moonlight**。以下对比均针对 A。若评审指的是 B，则二者连领域都不重叠（分布式计算 vs 图形编辑），对比表可直接忽略。

## 二、双方定位的真实差异

mizchi/moonlight 的自我定义是 **"SVG editor, like Excalidraw"**：自由画布 + 自由摆放 + 手绘风格。它的数据模型是 `Element { x, y, shape: ShapeType, style, parent_id, connections }`，`ShapeType` 为几何图元（Rect / Circle / Ellipse / Line / Polyline / Path）。导入器只解析 **SVG**（`import_svg_validated`）。

MoonDraw 的定位是 **"结构化图表编辑器"**：图是节点与边的有向图，坐标可以被派生而非手工摆放。数据模型是 `Shape { id, kind, x, y, w, h, text }` + `Edge { from, to, label }`，导入器解析 **Mermaid flowchart**，布局调用 **Eclipse Layout Kernel**。

一句话：**Moonlight 编辑的是"图形"，MoonDraw 编辑的是"图（graph）"。** 前者回答"这个矩形放在哪"，后者回答"这几个节点应该排成几层"。

## 三、同场景能力对比

表格只列可核验的事实，不写推测。Moonlight 数据来自其仓库 HEAD（`62276b9`）实测；MoonDraw 数据来自本仓库。

| 能力 | mizchi/moonlight | MoonDraw | 差异性质 |
|---|---|---|---|
| 编辑对象 | 几何图元（Rect/Circle/Ellipse/Line/Polyline/Path） | 语义节点（10 种：矩形/圆角/菱形/椭圆/文本/平行四边形/六边形/圆柱/文档/圆形）+ 有向边 | 图元 vs 图结构 |
| 连接图抽象 | ✅ 有 `ConnectionGraph`（`src/model/topology.mbt`，638 行）：邻接表、最短路、连通分量、`has_cycle`、hub/leaf 判定 | ✅ `Edge { from, to, label }` 一等实体，删除节点级联删边 | **此前的判断有误，详见下方更正** |
| 自动布局 | ❌ 仓库内无布局模块（无 dagre/elk/layered/rank 相关代码） | ✅ 接入 Eclipse Layout Kernel，顶栏可选 6 种（layered/force/stress/mrtree/radial/rectpacking），引擎注册 11 种 | **结构性差异** |
| 文本图导入 | ❌ 只解析 SVG | ✅ Mermaid flowchart 子集解析（节点形状、连线、`\|标签\|`、`-- 标签 -->`、方向） | **结构性差异** |
| 边的路由 | 直线 / 折线（手绘） | 正交自动路由（按节点相对位置计算出入口） | 手绘 vs 派生 |
| 导出 | SVG（原生） | SVG + PNG（三种范围：整图/选区/视口，2×） | 各有取舍 |
| 撤销 | ✅ 命令历史 | ✅ JSON 快照 | 同级 |
| 吸附 | ✅ 网格吸附 | ✅ 网格 + 对齐辅助线（对齐线优先于网格） | MoonDraw 多一层对齐 |
| 层级 | `parent_id` 分组 | `group` 编组 + 4 种层级顺序（置顶/上移/下移/置底） | 同级，实现不同 |
| 暗色主题 | ✅ 有 | ❌ 无 | Moonlight 领先 |
| 手绘 / 贝塞尔拟合 | ✅ `bezier_fit` 模块 | ❌ 无 | **Moonlight 明显领先** |
| Embed / Web Component | ✅ 多种 entry（viewer / embed / widget） | ❌ 无 | **Moonlight 明显领先** |
| 可嵌入 API | ✅ `src/api`、`embed` | ⚠️ 仅发布 MoonBit 包（`moondraw/kernel`），无 JS API | Moonlight 领先 |
| 依赖形态 | 依赖 luna / js / js_browser / signals（重度 JS 绑定） | 仅依赖 `moonbit-community/elk`；内核无 FFI 依赖 | 取舍不同 |
| native 可构建 | ❌（preferred_target = js，全栈依赖 luna） | ✅ `moon build --target native` 通过，25 项内核测试在 native 下运行 | **结构性差异** |
| 测试规模 | 486 个测试 | 76 单测 + 90 条端到端断言 | Moonlight 单测规模更大 |

## 四、MoonBit 承担的职责对比

这是驳回意见的核心：「MoonBit 主体职责」是否重合。

| | mizchi/moonlight | MoonDraw |
|---|---|---|
| 界面框架 | **Luna（MoonBit 的响应式 UI 库）** 提供组件、信号与渲染 | 自建：Canvas 2D + 一层 `extern "js"` FFI（`src/app/ffi.mbt`） |
| 界面渲染 | Luna 生成 DOM / SVG 元素 | MoonBit 自行发出 Canvas 2D 绘制指令 |
| 布局计算 | 无 | **MoonBit 实现** + ELK（MoonBit 移植） |
| 图算法 | 无 | 命中测试、正交路由、分层结构、吸附对齐、编组、分布 |
| 可移植性 | 绑定浏览器与 Luna，native 不可构建 | 内核零 FFI，native 可构建并跑测试 |

也就是说：**Moonlight 的 MoonBit 代码主要负责"状态 → Luna 组件树"；MoonDraw 的 MoonBit 代码负责"图 → 坐标 → 像素"**。前者把渲染委托给 UI 框架，后者自己做几何与光栅化指令。这不是同一份职责。

## 五、针对驳回意见的逐条回应

> 「主要编辑器内核……实质重合」

编辑器内核若指"选择/拖拽/撤销/缩放手柄"，确实重合——**任何编辑器都会重合**，这部分不是可差异化空间。真正的差异在**坐标的来源上**：Moonlight 有连接图，但**没有布局算法**（`elk`/`dagre`/`layered`/`arrange` 实测均为 0 处），坐标来自用户拖拽；MoonDraw 的坐标由布局引擎派生。详见「更正」一节。

> 「Mermaid 导入、ELK 接入和分发形态尚未建立核心职责的复用、扩展或充分的实质差异」

这条我接受一半，说明如下：

- **接受的部分**：如果只看"能导入 Mermaid、能自动布局"这两个功能名，确实像功能堆叠，没证明结构性差异。
- **不接受的部分**：这两项不是"附加功能"，而是**换了数据模型**。引入 `Edge` 与 ELK 后，文档不再是"一堆图元的坐标"，而是"一张图 + 一套可派生的布局"。这个区别会传导到每一处：删除节点要级联删边、导出要算正交路由、布局要能重排、导入要保留标签语义。Moonlight 要把这些加进来，需要改数据模型（引入 Edge、引入布局阶段），而不是加两个按钮。
- **尚未做够的部分**：我没有在仓库里提供"同场景对照"的可执行证据，只有各自的功能列表。这是我的疏漏。

> 「请补充同一编辑场景下的能力对比」

本文件即为此补充。若需要更强的证据，我可以再做一件更硬的事：**用同一张 Mermaid 源文件，分别喂给 Moonlight 与 MoonDraw，输出两者结果**（Moonlight 无法消费 Mermaid，只能手绘同等图形；MoonDraw 一键生成分层布局），把截图并排。这能把"结构性差异"从描述变成可复现的演示。


## 更正（2026-11-29 复核后）

本文件初版称「Moonlight 无 `Edge` 实体」，**该结论错误**，特此更正。

复核实测：`src/model/topology.mbt` 有 638 行的连接图实现，包含

```moonbit
pub(all) struct Edge {
  from_id : String
  to_id : String
  line_id : String
  from_anchor : Anchor
  to_anchor : Anchor
}
pub fn ConnectionGraph::has_cycle(self : ConnectionGraph) -> Bool
pub fn ConnectionGraph::find_shortest_path(...)
pub fn ConnectionGraph::get_all_components(...)
```

因此「结构校验能力只有一方有」的说法不成立——双方都能回答"图里有没有环"。

### 修正后的差异陈述

| 维度 | Moonlight | MoonDraw | 说明 |
|---|---|---|---|
| 连接图 | ✅ 有 | ✅ 有 | **确实重合** |
| 图结构分析 | ✅ `has_cycle`、连通分量、最短路 | ✅ `check` 子命令做环检测/孤立节点/悬空边 | **确实重合** |
| **布局算法** | ❌ 实测 0 处（`elk`/`dagre`/`layered`/`arrange` 均为 0） | ✅ ELK 11 种 | **不重合** |
| **坐标来源** | 用户拖拽 | 布局派生 | **不重合** |
| 图种（同一内核） | 1 种（无限画布） | 7 种输入 | 不重合 |
| 运行形态 | 浏览器 | native CLI + 浏览器 | 不重合 |

修正后的核心主张只剩一条，但这一条是可验证的：

> **两边都有连接图，但只有一方让坐标由算法产生。**

Moonlight 可以告诉你"这两个点连通"，但要移动它们，仍然是人拖。MoonDraw 可以告诉你"这两个点连通，并且我把它们排成了第 2 层、间距 96"。

## 六、我打算怎么补强（不是辩解，是工程）

若这次申诉被接受，后续会做以下三件事来坐实差异（按性价比排序）：

1. **结构性图操作**：ELK 支持复合节点（compound / 层级节点），MoonDraw 目前只有平铺节点。接入层级节点后，"子图折叠/展开 + 重新布局"会成为 Moonlight 难以低成本复制的能力。
2. **图语义校验**：对有向图做环检测、悬空边提示、入度/出度统计，并在画布上给出警示。这是"图编辑器"而非"图形编辑器"的标志。
3. **同源对照实验**：仓库内提供 `docs/compare/` —— 同一份 Mermaid 源、同一张图，Moonlight 与 MoonDraw 的处理结果与耗时，附可复现脚本。

## 七、我不主张的部分

- **不主张 MoonDraw 功能更多**：Moonlight 有手绘、贝塞尔拟合、暗色主题、Embed/Web Component、486 个测试，这些它都比我强。我不会拿"我用 MoonBit 写的"当挡箭牌。
- **不主张体积优势**：接入 ELK 后单文件 9.1 MB，比 Moonlight 大得多。
- **只主张一件事**：在"图（graph）"这个对象上，两边的内核职责不同，且 MoonDraw 的选择（边为一等实体 + 布局可派生 + 文本图导入）已经渗透进数据模型与导出链路，不是表层功能。
