---
description: Capture the pre-optimization metrics snapshot (.optimizer/baseline.json) for a Rust repo.
argument-hint: "[path to repo, defaults to current]"
---

Capture the optimization baseline for this repo using the `rust-optimizer:optimize` skill's metrics
subsystem.

Target: ${ARGUMENTS:-the current repository}

Run `scripts/baseline.sh` to write `.optimizer/baseline.json`, then summarize what it captured:

- **Deterministic metrics** (exact): `Cargo.lock` lines, direct deps, full-workspace-compiles-per-PR,
  enforced-gates count, `setup-qemu` present, unused-dep count.
- **Empirical metrics** (only if enough warm runs): median time-to-green. If there aren't enough
  samples, say "insufficient data — deterministic only" rather than reporting a noisy number.

Report warm-vs-warm; never headline a one-time cold-cache cost. See the skill's `references/metrics.md`
for the rules. This is the "before" half — run `/rust-optimize-measure` after fixes ship to get the Δ.
