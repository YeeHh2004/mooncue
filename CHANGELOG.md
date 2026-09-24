# Changelog

## 0.2.0 — 2026-09-24

- Recover safely after malformed FILE/TRACK declarations; retain file-level REM scope.
- Add `catalog` for player-facing metadata inheritance and `audit_plan` for source coverage and omitted ranges.
- Add UTF-8 stdin, batch archive checks and actionable missing-build guidance to the CLI.
- Verify 47 core cases on JS/Wasm and 31 integration/property cases, including external licensed fixtures and an independent interval model.
- Add Linux/Windows and Node 20/22 CI with API drift checking, pinned compiler/core 0.10.14+7d59c7ec9 and explicit public trait-method exposure.

`CueFile` now exposes `remarks`; `TrackEntry`, `PlanAudit`, `SourceCoverage` and `OmittedRange` are new public models. Existing check/normalize/plan commands retain their output conventions. The project remains a text parser and planner, not an audio decoder or splitter.

## 0.1.0 — 2026-09-24

Initial audio CUE parser, validator, normalizer and three-policy split planner with MoonBit API and Node CLI.
