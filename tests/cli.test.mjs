import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { process_request } from '../_build/js/release/build/bridge/bridge.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const album = readFileSync(new URL('../examples/album.cue', import.meta.url), 'utf8');
const cli = (...args) => spawnSync(process.execPath, ['cli/mooncue.mjs', ...args], { cwd: root, encoding: 'utf8' });

test('CLI help succeeds', () => {
  const r = cli('--help');
  assert.equal(r.status, 0); assert.match(r.stdout, /Usage:/);
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
