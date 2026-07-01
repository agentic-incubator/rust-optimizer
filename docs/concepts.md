# 🧠 How it works + glossary

## The model: audit, hand off, measure

rust-optimizer does three things and deliberately does **not** do a fourth:

1. **Audit** — detect the stack + account/visibility, run the applicable rules, verify each finding
   empirically, and rank by severity × impact.
2. **Hand off** — emit `OPTIMIZATION_SPEC.md` in autopilot's Definition-of-Done vocabulary so the
   fixes can be applied and _verified_ by the autopilot pipeline.
3. **Measure** — capture before/after metrics and render a scorecard.

It does **not** edit your code. Keeping the auditor and the applier separate is what makes the whole
thing trustworthy: you review a proposal, then a gate that can't be faked proves each fix landed.

## Why not just auto-fix?

Because most CI slowness is a **symptom**, and auto-fixing symptoms entrenches the cause. The canonical
example: a job runs `rm -rf /usr/share/dotnet` to free disk. Auto-"fix" the disk error and you've
hidden that the workspace compiles four times per PR and leaves fat debug artifacts. rust-optimizer
instead names the cause (redundant builds; missing `CARGO_INCREMENTAL=0`) and only then retires the
hack. A human reviews that reasoning before anything changes.

## Definition-of-Done vocabulary

The handoff works because every finding's "done" condition is executable:

- `cmd: <command>` — passes when it exits 0 (e.g. `cmd: cargo machete`).
- `grep: <pattern> in <glob>` — passes when the pattern is present (the fix added it).
- `grep:absent: <pattern> in <glob>` — passes when the pattern is gone (the fix removed a smell).

autopilot's quality gate runs these, so a phase is green only when the fix is real.

## Honest metrics

Two rules keep the numbers from lying:

- **Deterministic vs empirical.** Deterministic metrics (lock-file lines, compiles-per-PR, enforced
  gates) are exact and are the headline. Empirical metrics (time-to-green, build minutes) are measured
  and reported only with enough warm samples.
- **Warm vs cold.** A cold cache rebuild is a one-time cost. We headline warm-vs-warm and label cold
  numbers separately, so nobody "fixes" a problem that only exists on the first run.

## Exposed, not caused

Improving CI often makes latent bugs _visible_ — removing nextest retries surfaces a flaky test;
turning on coverage that never ran surfaces an untested path. These bugs were always there; the
optimization just stopped hiding them. rust-optimizer frames them as **exposed, not caused** so the
improvement doesn't get blamed for the breakage.

## Glossary

- **nextest / `cargo nextest archive`** — a fast Rust test runner. `archive` compiles the workspace
  once into a portable bundle that downstream jobs run without recompiling.
- **Swatinem/rust-cache** — a GitHub Action that caches Cargo's `target/` and registry between runs.
- **sccache** — a compiler cache; can overlap with rust-cache and add overhead.
- **lld** — a fast linker; `-Clink-arg=-fuse-ld=lld` cuts link time on incremental builds.
- **`CARGO_INCREMENTAL=0` / `CARGO_PROFILE_TEST_DEBUG=0`** — env vars that shrink `target/`, easing
  disk pressure and cache save/restore.
- **QEMU** — CPU emulation. Emulated arm64 Rust builds run ~10–12× slower than native.
- **native arm64 runner (`ubuntu-24.04-arm`)** — a real arm64 GitHub runner; free (4 vCPU) on public
  repos, billed (2 vCPU) on private repos since Jan 2026.
- **push-by-digest + `buildx imagetools create`** — build each arch separately, push by digest, then
  merge into one multi-arch manifest — the native replacement for QEMU cross-builds.
- **`cargo machete`** — flags declared-but-unused dependencies (with false positives — verify before removing).
- **gate theater** — a check wrapped in `|| echo` / `continue-on-error: true` that reports green while
  catching nothing.
- **DoD (Definition of Done)** — the machine-checkable condition that proves a fix is complete.
- **autopilot** — the sibling plugin that applies the spec's fixes phase-by-phase behind a quality gate.
- **risk_phases** — findings that always get a human checkpoint even under autonomous runs.
