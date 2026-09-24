import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, mkdtempSync, writeFileSync, rmSync, mkdirSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { process_request } from '../_build/js/release/build/bridge/bridge.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const album = readFileSync(new URL('../examples/album.cue', import.meta.url), 'utf8');
const cli = (...args) => spawnSync(process.execPath, ['cli/mooncue.mjs', ...args], { cwd: root, encoding: 'utf8', timeout: 10000 });

test('unbuilt checkout can show help and gives actionable build instructions', () => {
  const dir = mkdtempSync(join(tmpdir(), 'mooncue 未构建 '));
  try {
    mkdirSync(join(dir, 'cli'));
    const entry = join(dir, 'cli/mooncue.mjs');
    copyFileSync(join(root, 'cli/mooncue.mjs'), entry);
    const help = spawnSync(process.execPath, [entry, '--help'], { cwd: dir, encoding: 'utf8', timeout: 10000 });
    assert.equal(help.status, 0, help.stderr);
    assert.match(help.stdout, /Usage:/);
    for (const command of ['check', 'batch-check']) {
      const run = spawnSync(process.execPath, [entry, 'check', 'album.cue'].map((v, i) => i === 1 ? command : v), { cwd: dir, encoding: 'utf8', timeout: 10000 });
      assert.equal(run.status, 2);
      assert.match(run.stderr, /moon build --target js --release/);
      assert.doesNotMatch(run.stderr, /at ModuleLoader|node:internal/);
      assert.equal(run.stdout, '');
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('CLI resolves compiled core independently of caller directory and preserves Unicode paths', () => {
  const dir = mkdtempSync(join(tmpdir(), 'mooncue 路径 '));
  try {
    writeFileSync(join(dir, '专辑 空格.cue'), album, 'utf8');
    const run = spawnSync(process.execPath, [join(root, 'cli/mooncue.mjs'), 'check', '专辑 空格.cue'], { cwd: dir, encoding: 'utf8', timeout: 10000 });
    assert.equal(run.status, 0, run.stderr);
    assert.equal(JSON.parse(run.stdout).output.metadata.TITLE, '月下录音');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('CLI help succeeds', () => {
  const r = cli('--help');
  assert.equal(r.status, 0); assert.match(r.stdout, /Usage:/);
});
test('catalog exposes player-ready tracks and inherited performers', () => {
  const r = cli('catalog','examples/album.cue');
  assert.equal(r.status,0,r.stderr);
  const data = JSON.parse(r.stdout);
  assert.equal(data.output[0].performer,'MoonCue Demo');
  assert.equal(data.output[1].start_frame,18000);
  assert.equal(cli('catalog','examples/invalid.cue').status,1);
});
test('check good fixture reports valid structured data', () => {
  const r = cli('check', 'examples/album.cue');
  assert.equal(r.status, 0, r.stderr);
  const data = JSON.parse(r.stdout);
  assert.equal(data.ok, true); assert.equal(data.output.files[0].tracks.length, 2);
  assert.equal(data.output.metadata.TITLE, '月下录音');
});
test('bad fixture reports multiple errors and exits 1', () => {
  const r = cli('check', 'examples/invalid.cue');
  assert.equal(r.status, 1);
  const data = JSON.parse(r.stdout);
  assert.equal(data.ok, false);
  assert.ok(data.diagnostics.some(d => d.code === 'E_TIME' && d.line === 4));
  assert.ok(data.diagnostics.some(d => d.code === 'E_TIME_ORDER'));
});
test('normalization round trip through actual CLI', () => {
  const r = cli('normalize', 'examples/album.cue');
  assert.equal(r.status, 0, r.stderr);
  const data = JSON.parse(process_request('check', r.stdout, '', '{}'));
  assert.equal(data.ok, true); assert.equal(data.output.files[0].tracks.length, 2);
  assert.equal(JSON.parse(process_request('normalize', r.stdout, '', '{}')).output, r.stdout);
});
test('normalization refuses broken input', () => {
  const r = cli('normalize', 'examples/invalid.cue');
  assert.equal(r.status, 1); assert.equal(JSON.parse(r.stdout).ok, false);
});
for (const [policy, end, start] of [['exclude',17850,18000],['append',18000,18000],['prepend',17850,17850]]) {
  test(`plan ${policy} exact boundary and known end`, () => {
    const r = cli('plan','examples/album.cue','--gap',policy,'--durations','examples/durations.json');
    assert.equal(r.status,0,r.stderr);
    const data = JSON.parse(r.stdout);
    assert.equal(data.timebase,'1/75');
    assert.equal(data.output[0].end_frame,end);
    assert.equal(data.output[1].start_frame,start);
    assert.equal(data.output[1].end_frame,30000);
  });
}
test('unknown end stays null in JSON', () => {
  const r = cli('plan','examples/album.cue');
  assert.equal(r.status,0);
  assert.equal(JSON.parse(r.stdout).output[1].end_frame,null);
});
test('audit reports omitted audio and explicit incomplete coverage', () => {
  const known = JSON.parse(cli('audit','examples/album.cue','--durations','examples/durations.json').stdout);
  assert.equal(known.output.complete,true);
  assert.equal(known.output.sources[0].selected_frames,29850);
  assert.equal(known.output.sources[0].known_omitted_frames,150);
  const unknown = JSON.parse(cli('audit','examples/album.cue').stdout);
  assert.equal(unknown.output.complete,false);
  assert.equal(unknown.output.sources[0].selected_frames,null);
});
test('multifile fixture retains file-local ranges and generated silence', () => {
  const r = cli('plan','examples/multifile.cue');
  assert.equal(r.status,0);
  const data = JSON.parse(r.stdout);
  assert.equal(data.output[0].end_frame,null);
  assert.equal(data.output[1].start_frame,0);
  assert.equal(data.output[1].generated_pregap_frames,150);
  assert.equal(data.output[1].generated_postgap_frames,75);
});
test('invalid command, missing file, unknown or duplicate flags exit 2', () => {
  for (const args of [['missing'],['check','does-not-exist.cue'],['check','examples/album.cue','--gap','exclude'],['plan','examples/album.cue','--gap'],['plan','examples/album.cue','--gap','append','--gap','prepend']]) {
    assert.equal(cli(...args).status,2,JSON.stringify(args));
  }
});
test('unknown gap is rejected by MoonBit', () => {
  assert.equal(cli('plan','examples/album.cue','--gap','bogus').status,1);
});
test('duration schema rejects wrong shapes and noninteger numbers', () => {
  for (const durations of ['null','[]','42','{"album.wav":1.25}','{"album.wav":"30000"}','{"album.wav":2147483648}','{invalid']) {
    assert.equal(JSON.parse(process_request('plan',album,'exclude',durations)).ok,false,durations);
  }
});
test('unknown API command returns a failure envelope', () => {
  assert.equal(JSON.parse(process_request('oops',album,'','{}')).ok,false);
});
test('invalid UTF-8 is rejected without replacement and input remains unchanged', () => {
  const dir = mkdtempSync(join(tmpdir(),'mooncue-test-'));
  try {
    const input = join(dir,'invalid.cue'); const bytes = Buffer.from([0xff,0xfe,0x00]);
    writeFileSync(input,bytes);
    const r = cli('check',input);
    assert.equal(r.status,2); assert.deepEqual(readFileSync(input),bytes);
  } finally { rmSync(dir,{recursive:true,force:true}); }
});
test('all valid operations preserve source bytes', () => {
  const input = join(root,'examples/album.cue'); const before = readFileSync(input);
  for (const command of ['check','normalize','plan']) assert.equal(cli(command,input).status,0);
  assert.deepEqual(readFileSync(input),before);
});
test('stdin accepts exact UTF-8 content for every single-document command', () => {
  for (const command of ['check','normalize','plan','catalog','audit']) {
    const r = spawnSync(process.execPath,['cli/mooncue.mjs',command,'-'],{cwd:root,input:Buffer.from(album),encoding:'utf8'});
    assert.equal(r.status,0,r.stderr);
    if (command === 'normalize') assert.match(r.stdout,/月下录音/);
    else assert.equal(JSON.parse(r.stdout).ok,true);
  }
});
test('stdin rejects malformed UTF-8 and reports empty input as invalid CUE', () => {
  const invalid = spawnSync(process.execPath,['cli/mooncue.mjs','check','-'],{cwd:root,input:Buffer.from([0xc3,0x28]),encoding:'utf8'});
  assert.equal(invalid.status,2);
  const empty = spawnSync(process.execPath,['cli/mooncue.mjs','check','-'],{cwd:root,input:'',encoding:'utf8'});
  assert.equal(empty.status,1);
  assert.equal(JSON.parse(empty.stdout).ok,false);
});
test('batch-check handles all-valid files in input order', () => {
  const r = cli('batch-check','examples/album.cue','examples/multifile.cue');
  assert.equal(r.status,0,r.stderr);
  const data = JSON.parse(r.stdout);
  assert.deepEqual(data.summary,{files:2,valid:2,invalid:0,unreadable:0});
  assert.deepEqual(data.results.map(r => r.input),['examples/album.cue','examples/multifile.cue']);
});
test('batch-check continues after content errors and returns aggregate failure', () => {
  const r = cli('batch-check','examples/invalid.cue','examples/album.cue');
  assert.equal(r.status,1);
  const data = JSON.parse(r.stdout);
  assert.equal(data.ok,false);
  assert.deepEqual(data.summary,{files:2,valid:1,invalid:1,unreadable:0});
  assert.equal(data.results[1].ok,true);
});
test('batch-check continues after I/O errors with exit code 2 taking precedence', () => {
  const r = cli('batch-check','missing.cue','examples/invalid.cue','examples/album.cue');
  assert.equal(r.status,2);
  const data = JSON.parse(r.stdout);
  assert.deepEqual(data.summary,{files:3,valid:1,invalid:1,unreadable:1});
  assert.equal(typeof data.results[0].io_error,'string');
  assert.equal(data.results[2].ok,true);
});
test('batch-check rejects ambiguous stdin and empty invocation', () => {
  for (const args of [[],['-'],['--gap','exclude']]) assert.equal(cli('batch-check',...args).status,2);
});
