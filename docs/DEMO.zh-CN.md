# 3 分钟验收演示与理解要点

## 讲述顺序

**0:00–0:30，问题。** 一整张音频文件有多个曲目，CUE 负责描述每首歌的索引。索引写错，播放器或分轨工具就会切错。MoonCue 提供可嵌入 MoonBit 应用的解析、校验和分轨规划。

**0:30–1:00，正确样例。**

```sh
moon build --target js --release
node cli/mooncue.mjs check examples/album.cue
```

展示专辑名、源文件、两首曲目和 `ok: true`。说明真正的业务逻辑在 MoonBit，Node.js 只负责读文件。

**1:00–1:30，错误样例。**

```sh
node cli/mooncue.mjs check examples/invalid.cue
```

解释：第 4 行帧号 75 不合法，因为每秒帧编号是 00–74；还有时间倒退和未知命令。不会输出假成功，而是返回诊断和退出码 1。

**1:30–2:15，三种间隙策略。**

```sh
node cli/mooncue.mjs plan examples/album.cue --gap exclude --durations examples/durations.json
node cli/mooncue.mjs plan examples/album.cue --gap append --durations examples/durations.json
node cli/mooncue.mjs plan examples/album.cue --gap prepend --durations examples/durations.json
```

对比 17850/18000 帧：分别对应 03:58:00 和 04:00:00。解释半开区间及 150 帧文件内间隙。去掉 durations 参数，末轨结束为 `null`，而不是猜测音频长度。

**2:15–3:00，验证和边界。**

```sh
moon test --target js
moon test --target wasm-gc
node --test tests/cli.test.mjs
```

展示 35 个核心测试在两个目标运行，以及 16 个接口/CLI 测试。说明暂不做音频切割、刻录或 GUI，输入不被覆盖。

## 需要能解释的五个问题

1. **为什么不用浮点秒？** CUE 本来就是 1/75 秒为单位；整数避免边界舍入问题。
2. **INDEX 00 和 PREGAP 一样吗？** 不一样。INDEX 00 指源文件里已存在的音频；PREGAP 表示需要额外生成的静音，不能挪动源文件偏移。
3. **多文件如何处理？** 每个 FILE 有自己的时间原点；曲目编号仍按整张 CUE 递增。
4. **不知道文件多长怎么办？** 保留未知结束 `null`；允许外部调用者传入以 CD 帧计的真实总长。
5. **为什么不自动修复？** 一些修改会改变分轨语义；只规范化已验证输入，错误由调用者决定如何处理。

## AI 辅助说明

可以如实表述：“我使用 AI 辅助完成了 MoonBit 实现、测试与文档，并通过可复现样例理解和验证了核心行为。”在实际能够解释之前，不应声称已经掌握全部细节。
