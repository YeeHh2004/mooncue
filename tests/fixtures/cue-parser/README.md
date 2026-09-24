# External text fixtures

Source: [MaxMEllon/cue-parser](https://github.com/MaxMEllon/cue-parser/tree/99fc7f17293a1a29afc766ca12e68076aa6377c5/examples), commit `99fc7f17293a1a29afc766ca12e68076aa6377c5`, retrieved 2026-09-24. `sample.cue`, `invalid.cue` and the accompanying MIT `LICENSE` are unmodified upstream files. Copyright (c) 2025 MaxMEllon.

Only test data is reused, not parser code or an implementation dependency. The original sample has a fourth track returning to `00:00:00` in the same FILE after `07:23:45`; MoonCue intentionally rejects this backwards timeline. A separate positive test takes its first three tracks, explicitly removing the fourth declaration in memory. This is compatibility evidence for that supported subset, not a claim of conformance to the upstream parser or every CUE dialect. No audio is distributed.
