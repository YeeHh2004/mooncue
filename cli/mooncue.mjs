#!/usr/bin/env node
// I/O adapter only: all parsing, validation, normalization and planning are MoonBit.
import { readFile } from 'node:fs/promises';
import { process_request } from '../_build/js/release/build/bridge/bridge.js';

const help = `MoonCue — CUE sheet checker and audio split planner
Usage:
  node cli/mooncue.mjs check <file.cue>
  node cli/mooncue.mjs normalize <file.cue>
  node cli/mooncue.mjs catalog <file.cue>
  node cli/mooncue.mjs plan <file.cue> [--gap exclude|append|prepend] [--durations file.json]

All file input must be UTF-8. Output goes to stdout; input is never overwritten.
Durations: JSON object mapping exact FILE names to integer lengths in CD frames (1/75 s).
Unknown final lengths remain null. No audio is read, decoded, split or modified.
Exit codes: 0 success; 1 validation error; 2 invocation or I/O error.
`;
const args = process.argv.slice(2);
if (!args.length || args[0] === '--help') {
  console.log(help);
} else {
  try {
    const [command, input, ...options] = args;
    if (!['check', 'normalize', 'plan', 'catalog'].includes(command) || !input || input.startsWith('--')) {
      throw new Error('Expected a command and input file. Run with --help.');
    }
    let gap = 'exclude';
    let durations = '{}';
    const seen = new Set();
    for (let i = 0; i < options.length; i += 2) {
      const key = options[i];
      const value = options[i + 1];
      if (command !== 'plan' || !['--gap', '--durations'].includes(key) || !value || seen.has(key)) {
        throw new Error(`Invalid or duplicate option: ${key}`);
      }
      seen.add(key);
      if (key === '--gap') gap = value;
      else durations = new TextDecoder('utf-8', { fatal: true }).decode(await readFile(value));
    }
    const text = new TextDecoder('utf-8', { fatal: true }).decode(await readFile(input));
    const result = JSON.parse(process_request(command, text, gap, durations));
    if (command === 'normalize' && result.ok) {
      process.stdout.write(result.output);
      if (result.diagnostics.length) console.error(JSON.stringify(result.diagnostics, null, 2));
    } else console.log(JSON.stringify(result, null, 2));
    if (!result.ok) process.exitCode = 1;
  } catch (error) {
    console.error(`mooncue: ${error.message}`);
    process.exitCode = 2;
  }
}
