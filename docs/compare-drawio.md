# 三方对照：ioDraw / draw.io / MoonDraw

对照对象说明：这不是「谁功能多」的比较，而是**同一类能力在不同工程路线下的实现方式**。
数据均取自各自仓库或可执行文件的实测，标注来源。

| 对象 | 性质 | 可否参考代码 |
|---|---|---|
| **ioDraw** `ixiaoyang8/iodraw` | 商业产品，GitHub 仓库**只放发布物**（README + Android APK），无源码、无 LICENSE | ❌ 不能。无许可即默认保留所有权利 |
| **draw.io** `jgraph/drawio` | Apache-2.0，9,634 星，JavaScript，1.87 GB | ✅ 可以，需保留声明 |
| **MoonDraw**（本项目） | MIT + 依赖 EPL-2.0 的 ELK | — |

---

## 一、ioDraw 仓库的真实内容

```
.github/
README.md
android.png
ioDraw-v1.0.2-android.apk
```

字段实测：`language: null`、`license: null`、`size: 6370 KB`。

结论：它是**分发渠道，不是开源项目**。你桌面那个 256 MB 的 exe，代码不在这里。

> 附带发现：GitHub 上还有一批 `xxx/iodraw-files` 仓库（描述都是「流程图, 思维导图, 甘特图, 在线白板, 代码绘图, 在线图表」）。那些是**用户自己的图文件仓库**——ioDraw 用 GitHub 当云存储，授权后会在用户账号下建同名仓库。不能当参考实现看。

---

## 二、draw.io 的相关模块（这是真正可参考的）

`src/main/webapp/js/` 下的目录实测：

| 模块 | 体积 | 作用 |
|---|---|---|
| `elk/drawio-elk.min.js` | 902 KB | ELK 布局（`org.eclipse.elk.layered` 出现 93 次、`elk.direction` 16 次） |
| `mermaid/drawio-mermaid.min.js` | 1.06 MB | Mermaid 解析 |
| `libavoid-js/` | — | 正交避障路由，说明原文：「Obstacle-avoiding orthogonal edge routing for the Arrange > Layout > Orthogonal Routing menu item」 |
| `freehand/perfect-freehand.js` | 4.8 KB | 手绘笔刷 |
| `app.min.js` | **12 MB** | 主程序 |
| `integrate.min.js` | **21.9 MB** | 集成包 |

关键事实：**这三个能力（ELK / Mermaid / 笔刷）在 draw.io 里都是「打包好的第三方产物」**，注意 `libavoid-js/README.md` 的原话：

> The bundle here is a prebuilt, committed artifact — the same pattern as the ELK and mermaid bundles.

---

## 三、同一能力的三种实现路线

| 能力 | ioDraw | draw.io | MoonDraw |
|---|---|---|---|
| 自动布局 | 私有实现（不可见） | **打包 ELK**（902 KB min.js，不可读） | **依赖 `moonbit-community/elk`**（ELK 的 MoonBit 移植，源码可读、可 `moon test`） |
| Mermaid | 支持 | **打包 mermaid 解析器**（1.06 MB） | 自写 flowchart 子集解析器（334 行，带 9 条单测） |
| 正交路由 | 私有 | **打包 libavoid**（预构建产物） | 自写正交路由（`geom.mbt` 165 行，纯函数、可单测） |
| 手绘笔刷 | 支持 | `perfect-freehand.js`（第三方） | 自写 Stroke 形状（折线，未做平滑） |
| 运行形态 | Electron 单文件 257 MB | Web + 桌面，JS 全栈 | **native CLI + 网页**，内核零 FFI |

---

## 四、这份对照最有价值的一条

draw.io 用 902 KB 的**压缩产物**接 ELK：能跑，但**改不了、测不了**——你无法对 `drawio-elk.min.js` 里的布局逻辑写单元测试。

MoonDraw 接的是 ELK 的 **MoonBit 移植**：

```bash
$ moon add PingGuoMiaoMiao/moondraw
$ moon test          # 108 项，其中 7 项直接测 ELK 桥接、9 项测 Mermaid 解析
$ moondraw layout examples/flow/ticket.mmd --algorithm force
```

这件事的意义不是「我更好」，而是：**在 MoonBit 生态里，布局引擎是源码级依赖，不是黑盒产物**。这决定了它能不能被下游项目测试和替换。

---

## 五、可以从 draw.io 学、但我还没做的

诚实列出（按价值排序）：

| 项 | draw.io 的做法 | 我的现状 |
|---|---|---|
| 避障路由 | libavoid（完整障碍求解） | **已实现简化版**：检测障碍并绕行（`route_avoiding`）；弱于 libavoid，但不再穿过节点 |
| 笔刷平滑 | perfect-freehand：可变宽度的平滑曲线 | 我的笔迹是折线，无平滑、无压感 |
| Mermaid 覆盖度 | 完整 mermaid 语法 | 只支持 flowchart 子集，且丢弃样式 |
| 交互细节 | 多年打磨：多选框、连接点吸附、智能引导线 | 有基础版，精度不如 |
| 文件格式 | `.drawio` XML 有公开 schema | `.moondraw` 是自定义 JSON，无 schema 文档 |

---

## 六、许可证上的注意事项

- **ioDraw 无 LICENSE**：默认「保留所有权利」。它的图标、文案、`.iodraw` 文件格式**不能复制**。本项目只借鉴交互范式（工具栏分区、属性面板布局），未复用任何资产。
- **draw.io 是 Apache-2.0**：如果将来复用它的代码，需保留 NOTICE 与声明。目前本项目**未复制** draw.io 的任何代码。
- **ELK 是 EPL-2.0**：本项目通过 mooncakes 依赖使用，义务见 `THIRD_PARTY.md`。

---

## 七、结论

1. **ioDraw 不可参考**（无源码、无许可），只能当产品形态的观察对象。
2. **draw.io 可参考**，但它对 ELK / mermaid / libavoid 的做法是「打包第三方产物」，这条路我走不了也不该走。
3. **本项目的差异点在于依赖形态**：布局引擎是 MoonBit 包（源码级、可测试），而不是压缩过的 JS 产物。这也解释了为什么同一个 ELK，在 draw.io 里是一个 902 KB 的黑盒，在这里是 7 条可运行的测试。

> 需要说明的边界：本对照比较的是**实现方式**，不比较功能完整度。draw.io 的成熟度远超本项目，这一点没有讨论余地。
