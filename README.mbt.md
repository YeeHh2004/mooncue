# MoonCue

**MoonBit 原生音频 CUE 曲目表解析、校验与分轨规划库。**

[![Test MoonCue](https://github.com/YeeHh2004/mooncue/actions/workflows/ci.yml/badge.svg)](https://github.com/YeeHh2004/mooncue/actions/workflows/ci.yml)

一张整轨音频可能用 CUE 文件描述多首曲目。MoonCue 检查曲目和索引是否合法，并输出每首曲目在源文件中的精确帧区间，供播放器、音频归档或分轨工具使用。它只处理文本和规划数据，不读取或修改音频。

Core parsing, validation, normalization and split planning are written in MoonBit with no external library dependencies. The small Node.js CLI only handles arguments, UTF-8 file I/O and exit codes.

## 快速运行

环境：MoonBit 工具链、Node.js 20+。本地已验证 `moonc v0.10.4+2cc641edf`；CI 验证官方当前工具链。不要把 `.cue` 文件按 GBK 直接输入；先转换为 UTF-8。

```sh
git clone https://github.com/YeeHh2004/mooncue.git
cd mooncue
moon test --target js
moon test --target wasm-gc
moon build --target js --release
node --test tests/cli.test.mjs

node cli/mooncue.mjs check examples/album.cue
node cli/mooncue.mjs normalize examples/album.cue
node cli/mooncue.mjs plan examples/album.cue --gap exclude --durations examples/durations.json
```

仅看 MoonBit 内置演示：`moon run cmd/main --target js`。

上述单文档命令均可把文件名替换为 `-`，从标准输入读取 UTF-8 CUE。例：Unix shell 下 `cat examples/album.cue | node cli/mooncue.mjs check -`。程序会等待输入结束后解析，仍检查非法 UTF-8；Windows 管道须确保上游输出 UTF-8，直接传文件路径可避免 shell 编码差异。

CLI 输出到标准输出，不自动覆盖原文件。`check` 和 `plan` 输出 JSON；`normalize` 成功时输出 CUE 文本，错误时输出 JSON。退出码：0 成功、1 输入校验或规划失败、2 参数或文件读取失败。

## 已实现

归档批量检查可运行 `node cli/mooncue.mjs batch-check examples/album.cue examples/invalid.cue`。输出逐文件 JSON 报告和汇总，遇到一个损坏或读不到的文件也会继续检查剩余文件。存在 I/O 错误时退出码 2 优先，否则内容错误为 1、全通过为 0。只检查显式传入的路径，不递归扫描目录；批处理不接受 stdin。

- 解析 FILE、TRACK、INDEX、TITLE、PERFORMER、SONGWRITER、CATALOG、CDTEXTFILE、ISRC、FLAGS、PREGAP、POSTGAP、REM。
- 支持 UTF-8 中文、带空格及 Windows 反斜杠路径、BOM、CRLF、制表符、多源文件、命令大小写不敏感。
- 行号诊断：引号、参数、作用域、重复字段、时间范围、曲目/索引顺序、缺少 INDEX 01、未知命令和不支持的模式。
- 规范化合法输入；遇到错误拒绝输出“修复后的”文件，避免悄悄丢弃不认识的信息。
- 以整数 CD 帧为单位规划音频片段，单帧为 1/75 秒；未知源长度不会猜测。
- 显式区分文件内 INDEX 00 音频与 PREGAP/POSTGAP 生成静音。
- 35 个 MoonBit 测试（JS 与 Wasm 各运行一遍）及 16 个 CLI/API 测试，另有时间换算往返采样及 600 个确定性畸形输入样本。

## 三种间隙策略

样例中第二首的 `INDEX 00` 是 `03:58:00`，`INDEX 01` 是 `04:00:00`。这段 150 帧的文件内间隙有三种处理方式：

| `--gap` | 第一首结束帧（不包含） | 第二首开始帧（包含） | 含义 |
|---|---:|---:|---|
| `exclude`（默认） | 17850 | 18000 | 排除文件内间隙 |
| `append` | 18000 | 18000 | 间隙归前一首 |
| `prepend` | 17850 | 17850 | 间隙归后一首 |

分轨区间为半开区间 `[start_frame, end_frame)`，相对于各自 FILE 的开头。换到下一源文件时不会借用下一文件的时间戳。首轨 INDEX 01 之前的音频只在存在 INDEX 00 且选择 `prepend` 时纳入；其他情况不会隐式附加。

`--durations` 接受 JSON 文件，例如 `{"album.wav":30000}`，表示调用者提供的解码后总长度（CD 帧），不是文件字节数。没有提供长度时，最后一段的 `end_frame` 为 `null`。CUE 通常使用 `FILE "album.flac" WAVE` 来表示 FLAC 音源；MoonCue 不检查媒体编码或文件是否存在。

`generated_pregap_frames` / `generated_postgap_frames` 是后续消费者可选择执行的静音插入指令，不会被加到源文件偏移中。

如需检查是否遗漏音频，使用 `audit` 命令（参数同 `plan`），或 `audit_plan(text, policy, durations)`。报告列出每个 FILE 声明的已选帧数、已知排除区间及总帧数。没有音源长度时 `complete` 为 false，选中总帧数保持 `null`；有长度时可核对“选中帧数 + 排除帧数 = 总帧数”。合成静音不计入源音频覆盖量，`complete` 不表示已经读取媒体验证。

## MoonBit API

播放器集成可使用 `catalog(text)`，或运行 `node cli/mooncue.mjs catalog examples/album.cue`。输出按曲目排列的文件引用、INDEX 01 位置、标题及表演者/词曲作者。轨级元数据优先于专辑级；未指定的表演者和词曲作者为空字符串，缺少标题时使用 `Track NN`。返回结果是导航数据，不包含播放功能。

本项目尚未发布至 Mooncakes；当前请克隆源码运行，或将模块作为本地开发依赖使用。主要 API 可查阅 [pkg.generated.mbti](pkg.generated.mbti)：

| API | 返回值 |
|---|---|
| `parse(text)` | `Report`，包含结构化 sheet 和 diagnostics |
| `report.is_valid()` | 是否没有 error；warning 不使输入无效 |
| `parse_time("04:00:00")` | `Ok(18000)` |
| `format_time(18000)` | `Ok("04:00:00")` |
| `normalize(text)` | `Result[String, Array[Diagnostic]]` |
| `plan(text, policy, durations)` | `Result[Array[Segment], Array[Diagnostic]]` |
| `process_request(command, text, policy, durations_json)` | 稳定 JSON 信封，供 JS 或 CLI 使用 |

数据模型：Sheet → CueFile → Track → CueIndex。解析结果保留原始行号；规范化会重新排版，所以不保证字节或行号保持不变。REM 内容保留，可能移动到所属作用域的规范位置。

## 支持边界

- 这是实用的 AUDIO CUE 子集，不是完整 CDRWIN/Red Book 合规认证器。只检查这里列出的规则，不保证所有播放器/刻录软件都接受。
- 时间格式固定为两位 `mm:ss:ff`，最大 `99:59:74`。曲目编号 1–99，索引 0–99。
- 非 AUDIO 曲目显式拒绝。BINARY/MOTOROLA 可解析音频布局，但不允许生成解码音频分轨计划。
- 不支持将一个 TRACK 分散在多个 FILE 中的扩展写法、不支持转义引号、不猜测 GBK 编码。
- 不解码、切割、转码、播放音频，不执行生成的命令，不验证源文件存在、音频总长度真实性或 CDTEXTFILE 内容。
- 无网络请求、无模型 API、无密钥和付费服务依赖。

## 参赛材料

- [项目申报说明](docs/PROPOSAL.zh-CN.md)
- [查重记录](docs/ECOSYSTEM-SEARCH.zh-CN.md)
- [验收演示与理解要点](docs/DEMO.zh-CN.md)
- [测试记录](docs/VALIDATION.md)

## 来源、许可证与 AI 使用

Apache-2.0。独立实现；格式语义参考 [GNU ccd2cue 文档](https://www.gnu.org/software/ccd2cue/manual/html_node/CUE-sheet-format.html)及 [GNU libcdio](https://www.gnu.org/software/libcdio/)，未复制它们的源码或整段文档。除自行编写的合成样例外，测试另引用 MaxMEllon/cue-parser 的两份 MIT 许可 CUE 文本，来源和原始许可证见 [测试数据说明](tests/fixtures/cue-parser/README.md)。未移植其解析器代码，不含第三方音频。

项目使用 AI 辅助设计、编码、测试和文档。参赛者仍需理解数据模型、间隙处理、测试结果和支持边界；不能将测试通过等同于主办方已验收或奖金已获批。
