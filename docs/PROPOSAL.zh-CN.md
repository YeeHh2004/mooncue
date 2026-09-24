# MoonCue 项目申报说明

项目名称：MoonCue — MoonBit 原生 CUE 曲目表解析、校验与分轨规划库

公开仓库：https://github.com/YeeHh2004/mooncue

参赛方向：月度新项目 / 数据处理与内容处理工具

## 真实问题

整轨音频的 CUE 文件记录曲目、标题、源文件和 1/75 秒精度的索引。错误的索引、缺失的 INDEX 01、混淆文件内间隙与合成静音，会导致播放器显示和分轨边界错误。需要一个可以嵌入 MoonBit 应用、输出可解释诊断的轻量工具。

## 本期已实现范围

1. 原创 MoonBit 解析器：引号路径、中英文元数据、BOM/CRLF、多文件与多曲目、标准命令。
2. 语义检查：命令作用域、曲目与索引顺序、时间范围、必需索引、重复字段、支持范围。
3. 规范化输出及 JSON 报告。
4. 音频分轨计划：区分 INDEX 00 与 PREGAP，提供间隙排除/归前轨/归后轨策略；支持调用者提供源文件总帧数，未知结尾保持未知。
5. 命令行入口、测试、示例、参考来源和使用文档。

核心算法由 MoonBit 实现；Node.js 仅处理文件读写、命令行参数及退出码。不解码音频、不执行 FFmpeg、不声称是完整的光盘刻录或镜像工具。只支持 AUDIO 曲目的规划，其他模式显式诊断。

## 验收方式

从公开仓库克隆后运行 MoonBit 测试、构建 CLI，再对正常/错误/多文件/间隙样例进行检查和规划。错误输入应返回带行号的稳定诊断，CLI 返回非零状态；有效输入规范化后重新解析，语义保持一致。用独立预期值验证 75 帧换算和分轨边界。

## 查重与差异

2026-09-24 获取 Mooncakes API 的 2,637 条模块元数据，对 cue sheet、cuesheet、音频 CUE 等关键词检索，未发现专门的 CUE sheet 库；GitHub 对 MoonBit + cuesheet / cue-sheet 的仓库搜索无结果。搜索结果不能证明绝对不存在同类项目，最终以主办方审核为准。

已发现并避开：angela/srt 字幕库、MaoDingA/moonpost 字幕及时间码质检工具、多个 iCalendar 和 JSON Patch 项目。MoonCue 处理专辑/音频的 CUE 曲目表、文件内索引及分轨计划，与字幕 cue 是不同数据格式和用途。

## 参考与许可证

- Mooncakes 模块目录：https://mooncakes.io/api/v0/modules
- GNU ccd2cue CUE 格式说明：https://www.gnu.org/software/ccd2cue/manual/html_node/CUE-sheet-format.html
- GNU libcdio：https://www.gnu.org/software/libcdio/
- 比较项目：https://github.com/MaoDingA/moonbitpostqc

项目采用 Apache-2.0；独立实现，不复制上述项目源代码。开发使用 AI 辅助，参赛者需理解接口、间隙策略、测试及已知限制。首版已实现上列能力，本地 35 项核心测试在 JS/Wasm 两个目标各通过一次，16 项接口/CLI 测试通过；尚未报名或取得主办方审核结论。
