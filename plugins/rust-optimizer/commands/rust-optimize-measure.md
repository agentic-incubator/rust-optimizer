---
description: Recompute Rust CI metrics after fixes ship and render a before/after scorecard (impact.json + scorecard.md).
argument-hint: "[path to repo, defaults to current]"
---

Measure the impact of the optimizations now that fixes have shipped, using the `rust-optimizer:optimize`
skill's metrics subsystem. This is the final autopilot phase, `measure-impact`.

Target: ${ARGUMENTS:-the current repository}

Run `scripts/measure.sh`, which recomputes the current snapshot and diffs it against
`.optimizer/baseline.json`, writing `.optimizer/impact.json` and `.optimizer/scorecard.md`. Then:

- Present the **scorecard** (before | after | Δ | class).
- Lead with **deterministic** rows — they're exact and are the honest headline.
- Report **empirical** rows only with enough warm runs on both sides; otherwise say so.
- Call out anything the CI fixes **exposed** (e.g. a newly-failing flaky test) as _exposed, not caused_.

If there's no baseline yet, tell me to run `/rust-optimize-baseline` first — you can't diff without a
"before".
