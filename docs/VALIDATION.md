# Validation record

Date: 2026-09-24. Local OS: Windows.

Toolchain: `moon 0.1.20260713`, `moonc v0.10.4+2cc641edf`, `moonrun 0.1.20260713`.

| Check | Result |
|---|---|
| `moon check --target js` | Passed without warnings after cleanup |
| `moon test --target js` | 35 passed, 0 failed |
| `moon test --target wasm-gc` | 35 passed, 0 failed |
| `moon build --target js --release` | Passed |
| `node --test tests/cli.test.mjs` | 16 passed, 0 failed |
| `moon info` and `moon fmt` | Completed; public API file generated |

The 35 tests run against two backends are the same cases, not 70 independent test designs. Additional loops sample the timestamp range and process 600 reproducible malformed documents.

Tests cover exact 75-frame arithmetic, boundary ranges, Unicode, BOM/CRLF, quoting, Windows paths, scope recovery, duplicate metadata, source-local timelines, invalid tracks/indexes, all three gap policies, explicit null EOF, generated silence, malformed duration JSON, invalid UTF-8, exit codes and preserving input bytes.

The CLI tests caught a serialization issue: an unknown optional field was omitted, and an initial custom serializer encoded known values as singleton arrays. The final explicit encoder emits an integer or JSON null, with both cases asserted by tests.

CI runs on Linux using the current official MoonBit release. Its live result is available on the repository Actions page. Local results do not imply a remote CI pass unless that run is shown as successful.

No real audio decoder/splitter interoperability or CD burning conformance is claimed. Inputs are synthetic; the project processes CUE text only.
