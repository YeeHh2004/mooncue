import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { process_request } from '../_build/js/release/build/bridge/bridge.js';

const request = (command, text, policy = 'exclude', durations = {}) =>
  JSON.parse(process_request(command, text, policy, JSON.stringify(durations)));
const fixture = name => readFileSync(new URL(`fixtures/cue-parser/${name}`, import.meta.url), 'utf8');
const semantics = value => JSON.parse(JSON.stringify(value, (key, val) => key === 'line' ? undefined : val));

test('unmodified external sample rejects its backwards fourth-track timestamp', () => {
  const source = fixture('sample.cue');
  const result = request('check', source);
  assert.equal(result.ok, false);
  assert.ok(result.diagnostics.some(d => d.code === 'E_TIME_ORDER' && d.line === 27));
  for (const command of ['normalize', 'plan', 'catalog', 'audit']) {
    const failed = request(command, source);
    assert.equal(failed.ok, false);
    assert.equal(failed.output, undefined, 'failed transformation must not return partial output');
  }
});

test('external sample first three tracks preserve metadata, frames, flags and synthetic gaps', () => {
  // Documented subset: retain original bytes up to the fourth TRACK declaration.
  const source = fixture('sample.cue').split('\t\tTRACK 04 AUDIO')[0];
  const checked = request('check', source);
  assert.equal(checked.ok, true, JSON.stringify(checked.diagnostics));
  assert.equal(checked.output.metadata.CATALOG, '1234567890123');
  const tracks = request('catalog', source).output;
  assert.deepEqual(tracks.map(t => t.start_frame), [183, 16887, 33270]);
  assert.deepEqual(tracks.map(t => t.title), ['First Track', 'Second Track', 'Third Track']);
  assert.equal(tracks[1].performer, 'Sample Artist');
  assert.equal(checked.output.files[0].tracks[2].metadata.FLAGS, 'PRE');
  const plan = request('plan', source, 'prepend', { 'audio.wav': 36000 }).output;
  assert.equal(plan[0].start_frame, 0);
  assert.equal(plan[1].generated_pregap_frames, 150);
  assert.equal(plan[2].generated_postgap_frames, 105);
  assert.equal(plan[2].end_frame, 36000);
  const normalized = request('normalize', source).output;
  assert.deepEqual(semantics(request('check', normalized).output), semantics(checked.output));
});

test('external invalid fixture reports source-scoped failures without crashing', () => {
  const result = request('check', fixture('invalid.cue'));
  assert.equal(result.ok, false);
  assert.ok(result.diagnostics.some(d => d.code === 'E_SCOPE' && d.line === 2));
  assert.ok(result.diagnostics.some(d => d.code === 'E_CATALOG' && d.line === 4));
});

// Model is generated as integers before formatting any CUE. Expectations never
// call MoonCue's parser/formatter or derive boundaries from its parsed output.
const stamp = frames => [Math.floor(frames / 4500), Math.floor(frames / 75) % 60, frames % 75]
  .map(n => String(n).padStart(2, '0')).join(':');
function generatedAlbum(seed) {
  let state = seed;
  const next = limit => { state = (Math.imul(state, 1664525) + 1013904223) >>> 0; return state % limit; };
  const lines = ['TITLE "生成测试 🎵"', 'PERFORMER "全局"', 'REM album "freeform'];
  const sources = [];
  let number = 1;
  for (let f = 0; f < 2; f++) {
    const name = `源 ${f}.wav`;
    const tracks = [];
    let cursor = next(20);
    lines.push(`FILE "${name}" WAVE`, 'REM file scope');
    for (let t = 0; t < 3; t++) {
      const zero = cursor;
      const one = zero + next(50);
      const gap = next(2) === 0;
      tracks.push({ number, zero: gap ? zero : one, one });
      lines.push(`TRACK ${number++} AUDIO`, `TITLE "曲目 ${t}"`, 'REM track scope');
      if (gap) lines.push(`INDEX 00 ${stamp(zero)}`);
      lines.push(`INDEX 01 ${stamp(one)}`);
      cursor = one + 30 + next(100);
    }
    sources.push({ name, tracks, length: cursor });
  }
  const text = '\uFEFF' + lines.join(seed % 2 ? '\r\n' : '\n') + '\n';
  return { text, sources, durations: Object.fromEntries(sources.map(f => [f.name, f.length])) };
}

test('120 generated multi-file albums retain every semantic field through normalization', () => {
  for (let seed = 1; seed <= 120; seed++) {
    const { text } = generatedAlbum(seed);
    const original = request('check', text);
    assert.equal(original.ok, true, `seed ${seed}`);
    const normalized = request('normalize', text);
    assert.equal(normalized.ok, true);
    assert.deepEqual(semantics(request('check', normalized.output).output), semantics(original.output));
    assert.equal(request('normalize', normalized.output).output, normalized.output);
    assert.deepEqual(semantics(request('catalog', normalized.output).output), semantics(request('catalog', text).output));
  }
});

test('all gap policies match generated interval model and partition each source exactly once', () => {
  for (let seed = 1; seed <= 120; seed++) {
    const { text, sources, durations } = generatedAlbum(seed);
    for (const policy of ['exclude', 'append', 'prepend']) {
      const result = request('audit', text, policy, durations);
      assert.equal(result.ok, true, `seed ${seed} ${policy}`);
      const report = result.output;
      assert.equal(report.complete, true);
      for (const [f, source] of sources.entries()) {
        const segments = report.segments.filter(s => s.file === source.name);
        const expected = source.tracks.map((t, i, tracks) => [
          policy === 'prepend' ? t.zero : t.one,
          i + 1 === tracks.length ? source.length : policy === 'append' ? tracks[i + 1].one : tracks[i + 1].zero,
        ]);
        assert.deepEqual(segments.map(s => [s.start_frame, s.end_frame]), expected);
        // Per-frame independent coverage check detects overlap as well as loss.
        const coverage = new Uint8Array(source.length);
        for (const s of [...segments, ...report.sources[f].omitted]) {
          assert.ok(s.start_frame >= 0 && s.end_frame <= source.length);
          for (let n = s.start_frame; n < s.end_frame; n++) coverage[n]++;
        }
        assert.ok(coverage.every(n => n === 1), `seed ${seed} ${policy} source ${f}`);
        assert.equal(report.sources[f].selected_frames + report.sources[f].known_omitted_frames, source.length);
      }
    }
  }
});
