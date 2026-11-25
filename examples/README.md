# Examples

## mermaid_preview（命令行，无需浏览器）

把一段 Mermaid flowchart 解析成可编辑图形，再导出 SVG。用来证明内核
（解析 → 布局 → 导出）不依赖 DOM。

```bash
moon run src/cmd_mermaid_preview --target js
```

输出：

```
节点: 5  连线: 5
  收到工单  @(0,0)
  是否 P1  @(0,180)
  ...
SVG: 2731 字节
<svg xmlns="http://www.w3.org/2000/svg" width="426" height="778" ...>
```

## 图形化界面

`index.html` 本身就是示例：双击打开即见示例文档，工具栏有「Mermaid」按钮
可直接导入一段流程图。

```bash
moon build --target js --release
# 浏览器打开 index.html
```
