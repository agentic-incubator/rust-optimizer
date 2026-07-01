# Metrics

The optimizer measures impact honestly. That means two things: separating metrics you can state
**exactly** from metrics you have to **measure**, and never letting a one-time cold-cache cost
masquerade as steady state. `scripts/baseline.sh` captures the "before"; `scripts/measure.sh`
captures the "after" and diffs them into a scorecard.

## Deterministic vs empirical

**Deterministic metrics** are exact — computed from files or the CI DAG, no timing involved. These are
the headline numbers because they don't move between runs:

| Metric                         | How                                                                     |
| ------------------------------ | ----------------------------------------------------------------------- |
| `Cargo.lock` line count        | `wc -l Cargo.lock`.                                                     |
| Direct dependency count        | `cargo tree --depth 1` (or parse `[dependencies]`).                     |
| Full-workspace-compiles-per-PR | Analyze the CI job DAG — how many jobs compile the whole workspace.     |
| Enforced-gates count           | Count gates that actually block (no `\|\| echo` / `continue-on-error`). |
| CI annotation count            | Warnings/annotations surfaced by a representative run.                  |
| `setup-qemu` present           | Boolean — is emulated cross-build still in the release workflow.        |
| Unused-dependency count        | `cargo machete` hit count (verified).                                   |

**Empirical metrics** are measured and vary run-to-run — report them only with enough samples and
always **warm-vs-warm**:

| Metric                 | How                                                                                         |
| ---------------------- | ------------------------------------------------------------------------------------------- |
| Median time-to-green   | Median over the last **N** `gh run` results, warm cache both sides; report the sample size. |
| Runner-minutes         | Sum of billable minutes across a PR's jobs.                                                 |
| arm64 image build time | From a real release or an **active probe** (a `push: false` smoke build).                   |

## Warm vs cold — never alarm on cold

The first run after a dependency or toolchain change rebuilds everything: a **cold** cache. That cost
is paid once. Reporting it as if it were the steady-state number is misleading and causes people to
"fix" a problem that doesn't exist.

- Headline **warm-vs-warm** numbers.
- Label cold numbers explicitly as one-time (cache seed, toolchain bump).
- When comparing before/after, compare warm-to-warm; note if either side is cold.

## Active probing (no recent release)

If there's no recent release to measure an arm64 build from, don't report "unknown" — **probe**. Run
the arm64 build with `push: false` as a measurement. This doubles as the empirical validation for the
D1 native-split finding: measure QEMU vs native before recommending the switch to production.

## The sufficiency rule

Report **deterministic metrics always** — they're exact. Report **empirical metrics only with ≥N runs
on both sides** (warm). With fewer, say so:

> Insufficient data for empirical timing (N runs available, need ≥K) — deterministic metrics only.

This keeps the scorecard trustworthy: exact where we can be, honest about uncertainty where we can't.

## The scorecard

`measure.sh` renders `scorecard.md` as a **before | after | Δ | class** table (`class` = deterministic
or empirical). A worked example using real results from a production Rust repo:

| Metric                     | Before     | After    | Δ               | Class               |
| -------------------------- | ---------- | -------- | --------------- | ------------------- |
| `Cargo.lock` lines         | (baseline) | −582     | −582            | deterministic       |
| Direct dependencies        | (baseline) | −35      | −35             | deterministic       |
| Full-workspace-compiles/PR | ~4         | ~2       | −2              | deterministic       |
| Enforced gates             | 0          | 2        | +2              | deterministic       |
| CI annotations             | 3          | 0        | −3              | deterministic       |
| `setup-qemu` present       | yes        | no       | removed         | deterministic       |
| arm64 image build time     | ~59 min    | ~5 min   | ~−54 min (~12×) | empirical (probe)   |
| Warm time-to-green         | (baseline) | improved | see run history | empirical (≥N runs) |

The deterministic rows are the honest headline; the empirical rows carry their sample basis (probe, or
≥N warm runs) so no single lucky run overstates the win.
