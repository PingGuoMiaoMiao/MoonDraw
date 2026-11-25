# AI 使用说明

摘要（English）：This project was built with an **AI coding assistant** (an agent that can read
files, run commands, and run tests). Every claim in the docs is reproducible with the scripts in
`tools/`; measurements that could not be taken are marked "未验证" instead of being estimated.

完整的边界与决策记录见 [adr/0001-ai-assisted-development.md](adr/0001-ai-assisted-development.md)。

## 谁做了什么

| 工作 | AI | 人 |
|---|---|---|
| 代码骨架、重构、测试编写、调试定位、文档整理 | 主要承担 | 审核 |
| 产品方向、范围取舍、验收口径 | 提供选项与代价 | 决定 |
| 「已验证」的判定 | 只能提供证据 | 以脚本结果为准 |

## 关键取舍（人决定，非 AI 自选）

1. 吸附优先级：网格 → 对齐线，且对齐线优先（与主流设计工具一致）。
2. Mermaid 导入只取图不取样式，`classDef` / `style` / `click` 一律丢弃。
3. 布局只做按深度分层，不引入完整 dagre。
4. 交付形态优先零依赖便携壳，Tauri 作为增强路径。
5. 无法测量的指标（Canvas 帧时间、输入法候选框）显式标注为未验证。

## 可复核性

```bash
pwsh tools/verify.ps1    # 类型检查 + 单测 + 构建 + 产物新鲜度 + 端到端
moon test --target js    # 内核白盒单测
pwsh tools/cdp-e2e.ps1   # 真实浏览器端到端断言
```

## AI 引入并被测试捕获的缺陷

1. 删除选中图形时漏记快照，Delete 后无法撤销 —— 端到端 D3 捕获。
2. Mermaid `|标签|` 的竖线被当作连接符，`B -->|是| C` 解析出节点 `是C` —— 单测与端到端 G 组捕获。
3. 等间距分布先改坐标再记快照，撤销失效 —— 端到端 O5 捕获。
4. 视口导出按世界尺寸缩放，结果并非"所见即所得" —— 端到端 N2 捕获。
5. 裸节点引用覆盖已定义标签（`B --> C` 把 `B{判断}` 刷成 `B`）—— 新增命令行示例运行时捕获。

这些都记在 ADR 里，作为"验证体系有效"的证据，而不是隐藏。
