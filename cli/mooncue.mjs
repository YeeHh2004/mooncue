#!/usr/bin/env node
// I/O adapter only: all parsing, validation, normalization and planning are MoonBit.
import { readFile } from 'node:fs/promises';
let process_request;

async function loadCore() {
  try {
    ({ process_request } = await import('../_build/js/release/build/bridge/bridge.js'));
  } catch (error) {
    if (error.code === 'ERR_MODULE_NOT_FOUND') {
      throw new Error('Compiled MoonBit core is unavailable. From the project directory run: moon build --target js --release');
    }
    throw error;
  }
}

async function readCue(input) {
  if (input !== '-') return readFile(input);
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function batchCheck(inputs) {
  if (!inputs.length || inputs.some(p => p === '-' || p.startsWith('--'))) {
    throw new Error('batch-check requires one or more CUE paths; stdin and options are not supported.');
  }
  const results = [];
  const summary = { files: inputs.length, valid: 0, invalid: 0, unreadable: 0 };
  for (const input of inputs) {
    try {
      const text = new TextDecoder('utf-8', { fatal: true }).decode(await readFile(input));
      const report = JSON.parse(process_request('check', text, '', '{}'));
      summary[report.ok ? 'valid' : 'invalid']++;
      results.push({ input, ...report });
    } catch (error) {
      summary.unreadable++;
      results.push({ input, ok: false, io_error: error.message });
    }
  }
  console.log(JSON.stringify({ ok: !summary.invalid && !summary.unreadable, summary, results }, null, 2));
  process.exitCode = summary.unreadable ? 2 : summary.invalid ? 1 : 0;
}

const help = `MoonCue — CUE sheet checker and audio split planner
Usage:
  node cli/mooncue.mjs batch-check <first.cue> <second.cue> [...]
  node cli/mooncue.mjs check <file.cue>
  node cli/mooncue.mjs normalize <file.cue>
  node cli/mooncue.mjs catalog <file.cue>
  node cli/mooncue.mjs plan <file.cue> [--gap exclude|append|prepend] [--durations file.json]
  node cli/mooncue.mjs audit <file.cue> [--gap exclude|append|prepend] [--durations file.json]

All file input must be UTF-8. Output goes to stdout; input is never overwritten.
Use - as the CUE filename to read UTF-8 bytes from stdin (durations still use a file).
Durations: JSON object mapping exact FILE names to integer lengths in CD frames (1/75 s).
Unknown final lengths remain null. No audio is read, decoded, split or modified.
Exit codes: 0 success; 1 validation error; 2 invocation or I/O error.
`;
const args = process.argv.slice(2);
if (!args.length || args[0] === '--help') {
  console.log(help);
} else {
  try {
    await loadCore();
    if (args[0] === 'batch-check') {
      await batchCheck(args.slice(1));
    } else {
      const [command, input, ...options] = args;
      if (!['check', 'normalize', 'plan', 'catalog', 'audit'].includes(command) || !input || input.startsWith('--')) {
        throw new Error('Expected a command and input file. Run with --help.');
      }
      let gap = 'exclude';
      let durations = '{}';
      const seen = new Set();
      for (let i = 0; i < options.length; i += 2) {
        const key = options[i];
        const value = options[i + 1];
        if (!['plan','audit'].includes(command) || !['--gap', '--durations'].includes(key) || !value || seen.has(key)) {
          throw new Error(`Invalid or duplicate option: ${key}`);
        }
        seen.add(key);
        if (key === '--gap') gap = value;
        else durations = new TextDecoder('utf-8', { fatal: true }).decode(await readFile(value));
      }
      const text = new TextDecoder('utf-8', { fatal: true }).decode(await readCue(input));
      const result = JSON.parse(process_request(command, text, gap, durations));
      if (command === 'normalize' && result.ok) {
        process.stdout.write(result.output);
        if (result.diagnostics.length) console.error(JSON.stringify(result.diagnostics, null, 2));
      } else console.log(JSON.stringify(result, null, 2));
      if (!result.ok) process.exitCode = 1;
    }
  } catch (error) {
    console.error(`mooncue: ${error.message}`);
    process.exitCode = 2;
  }
}
