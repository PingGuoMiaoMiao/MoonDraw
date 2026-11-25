# 第三方组件与许可证

本仓库自身的代码（`src/`、`shell/`、`tools/`）采用 **MIT**（见 `LICENSE`）。

## 运行时依赖

| 组件 | 版本 | 许可证 | 用途 |
|---|---|---|---|
| [moonbit-community/elk](https://github.com/moonbit-community/moon_elk) | 0.4.2 | **Eclipse Public License 2.0** | 自动布局引擎（`src/elk_layout` 调用） |

ELK 是 Eclipse Layout Kernel 的 MoonBit 移植，EPL-2.0 属于 OSI 认可的许可证。

## 分发时的义务

构建产物（`dist/moondraw.html`、`dist/MoonDraw.exe`、GitHub Pages 上的单文件）会把 ELK 的编译结果**内联**进同一份文件。这意味着分发物中包含 EPL-2.0 覆盖的代码，需要满足：

1. **保留声明**：分发物或同目录文档中保留本文件与 ELK 的许可证与版权声明（本仓库已随附本文件，构建脚本保留 `LICENSE`）。
2. **源代码可得**：EPL-2.0 要求在分发目标代码时能够获取对应源码。ELK 的源码在
   <https://github.com/moonbit-community/moon_elk>（发布版本 0.4.2，标签/提交可查）；
   本项目对 ELK 的使用是**未修改**的直接依赖，没有本地补丁。
3. **修改说明**：若将来对 ELK 打了本地补丁，必须在该处注明修改内容与日期。

## 不在本项目内的第三方内容

- 参考实现的界面、图标与文件格式（ioDraw / draw.io）**未**被复制进本仓库；仅参考交互范式。
- Rust 便携壳（`shell/launcher`）只使用标准库与 Win32 API，无第三方 crate。

## 如果要把整个项目改成 EPL-2.0

当前选择「MIT + 依赖 EPL」是刻意的最小摩擦方案：本仓库代码可自由复用，只有 ELK 部分受 EPL 约束。
如果使用方希望单一许可证，可把 `moon.mod` 的 `license` 改为 `EPL-2.0`——EPL 允许这样做，只是会把 EPL 的互惠范围扩大到本项目自身。
