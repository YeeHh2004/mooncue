# 选题查重记录

检查时间：2026-09-24。结论：本次公开检索未发现专门处理音频 CUE sheet 的 MoonBit 库。**这不是“全网没有同类项目”的证明，也不能替代主办方资格审核。**

## 范围与方法

1. 获取 https://mooncakes.io/api/v0/modules ，本次返回 2,637 条模块元数据。
2. 对模块名、描述、关键词检索 `cue sheet`、`cuesheet`、`cue`、音频/专辑相关关键词。未命中明确的音频 CUE sheet 解析/校验/分轨规划实现。
3. GitHub 仓库搜索 `cuesheet language:MoonBit`、`cue-sheet moonbit`；返回空列表。
4. Web 交叉搜索 `"MoonBit" "cue sheet"`、`"MoonBit" "cuesheet"`、`"MoonBit" "CUE" "audio"`；未发现直接同类实现。
5. 阅读相邻领域 MoonPost 的 README，确认其主要功能为字幕、时间码与后期 QC，不能据此宣称所有音频处理功能都不存在。

## 对照结果

| 方向/项目 | 已有能力 | 本次决策 |
|---|---|---|
| [angela/srt](https://mooncakes.io/docs/angela/srt) | SRT 字幕片段和输出 | 不做字幕基础库 |
| [MaoDingA/moonpost](https://github.com/MaoDingA/moonbitpostqc) | SRT/WebVTT/ASS、时间码、字幕 QC、部分 EDL 时间码辅助 | 不做字幕质检或通用时间码项目 |
| [Xu107-hhh/moonbit-jsonpatch](https://github.com/Xu107-hhh/moonbit-jsonpatch) | JSON Patch/Pointer/Merge Patch | 不做该方向 |
| [ciqingweiyang/MoonCal](https://github.com/ciqingweiyang/MoonCal) | iCalendar 与 RRULE | 不做该方向 |
| MoonCue 本次项目 | 音频 CUE 文本作用域、75 帧索引、间隙策略、多文件分轨规划 | 作为新项目候选，提交审核时如实说明边界 |

音频 CUE sheet 的 `INDEX 00/01`、`PREGAP`、多 FILE 局部时间，与字幕格式中的 cue 条目不同。MoonCue 不应被描述为“首个 MoonBit 音频工具”，也不应宣称与现有项目绝无重合。

## 限制

未逐一下载和阅读 2,637 个包的源代码；空描述包可能隐藏相关实现。GitHub 搜索存在索引遗漏；私有库、未发布仓库及主办方尚未公开的报名表不可见。本期完整参赛清单未取得，故不能声称已核对全部参赛项目。
