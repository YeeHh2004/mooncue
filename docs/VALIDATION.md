# Validation record

Date: 2026-09-24. Local OS: Windows.

Toolchain: `moon 0.1.20260920`, `moonc v0.10.14+7d59c7ec9`, `moonrun 0.1.20260920`.

| Check | Result |
|---|---|
| `moon check --target js` | Passed without warnings after cleanup |
| `moon test --target js` | 47 passed, 0 failed |
| `moon test --target wasm-gc` | 47 passed, 0 failed |
| `moon build --target js --release` | Passed |
| `node --test tests/cli.test.mjs tests/conformance.test.mjs` | 31 passed (26 CLI/API + 5 conformance/property), 0 failed |
| `moon info` and `moon fmt` | Completed; public API file generated |

The 47 tests run against two backends are the same cases, not 94 independent test designs. Additional loops sample the timestamp range and process 600 reproducible malformed documents.

Tests cover exact 75-frame arithmetic, boundary ranges, Unicode, BOM/CRLF, quoting, Windows paths, scope recovery, duplicate metadata, source-local timelines, invalid tracks/indexes, all three gap policies, explicit null EOF, generated silence, malformed duration JSON, invalid UTF-8, exit codes and preserving input bytes.

The CLI tests caught a serialization issue: an unknown optional field was omitted, and an initial custom serializer encoded known values as singleton arrays. The final explicit encoder emits an integer or JSON null, with both cases asserted by tests.

CI runs fresh checkouts on Linux / Node 20, Linux / Node 22 and Windows / Node 22 using pinned MoonBit compiler and core 0.10.14+7d59c7ec9. Formatting and generated API drift are checked alongside the full tests. Local Node version is v24.19.0. Its live result is available on the repository Actions page. Local results do not imply a remote CI pass unless that run is shown as successful.

No real audio decoder/splitter interoperability or CD burning conformance is claimed. Inputs include synthetic cases and two MIT-licensed external CUE text fixtures with provenance in tests/fixtures/cue-parser/README.md; the project processes CUE text only.

New regression coverage checks malformed FILE/TRACK scope recovery, preservation of FILE-level REM, inherited track metadata, source coverage audit, stdin, batch continuation after I/O errors and invalid input, missing-build guidance and launching outside the checkout with Unicode paths.

Property tests generate 120 two-file, six-track albums. They verify full semantic preservation across normalization and compare all three gap policies against an independent integer interval model. Selected and omitted ranges must cover every source frame exactly once. The upstream sample has a backwards fourth-track timestamp, rejected at line 27; its explicitly truncated first-three-track subset validates known offsets and synthetic silence. This is not differential testing against an upstream implementation.

During CI setup, checks detected formatter differences and a trailing blank-line difference in generated interfaces between local MoonBit 0.10.4 and CI 0.10.14. Compiler and core versions are now pinned together; generated formatting and interface files must match that toolchain. Failed setup runs remain visible in Actions history.

Final local rerun uses the same pinned 0.10.14 compiler and core as CI. Public trait methods are explicitly exposed using `pub extend`, preserving method-call behavior while removing all implicit-promotion deprecation warnings. The final local check/build has no warnings, with 47/47 core cases on each target and 31/31 integration cases passing.
