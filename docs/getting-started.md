# 🚀 Getting started

This walks you from "my Rust CI is slow/expensive" to shipped, measured fixes — with two human
checkpoints along the way. rust-optimizer finds and reports; [autopilot](https://github.com/agentic-incubator/claude-autopilot)
applies. They're separate on purpose: an audit you can review is more trustworthy than a bot silently
rewriting your pipeline.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) with the plugin installed (see the [README](../README.md#-install)).
- `gh` (authenticated), `jq`, and `cargo` on your PATH. `cargo-machete` too if you want dependency findings.
- The `autopilot` plugin, to apply the fixes.

## Step 1 — Audit

From inside your Rust repo:

```
/rust-optimize-audit
```

The `optimize` skill will:

1. **Detect** your stack and, critically, your **account type + repo visibility**
   (`gh repo view --json visibility,isInOrganization,owner`) — because a native-arm64 runner that's
   free on a public repo will make a private-repo job queue forever.
2. **Scan** with `scripts/audit.sh`, then **verify each candidate** empirically (a grep hit is a
   hypothesis; the compiler settles it).
3. Present a **prioritized report**: findings ranked by severity × impact, plus a sequenced plan —
   quick wins first, then the tradeoff calls that need your judgment. Anything your account can't use
   is marked **N/A** with the reason.

## Checkpoint 1 — Curate the audit

**This is your first human checkpoint.** Read the findings. Confirm which to pursue, drop any you
don't want, and sanity-check the N/A calls. An audit is a proposal, not a mandate — nothing is applied
yet.

Once you approve, the skill writes:

- **`OPTIMIZATION_SPEC.md`** — one section per finding, each with a machine-checkable Definition of
  Done in autopilot's own vocabulary.
- **`.optimizer/baseline.json`** — your "before" metrics.

## Step 2 — Hand off to autopilot

```
/autopilot-plan OPTIMIZATION_SPEC.md
```

Because the spec is already written in DoD vocabulary, autopilot ingests it with a high readiness
score and no enrichment. Recommended first run: **`autonomy: reviewed`** (autopilot stops after each
phase for you to look). Risky findings (release/arm64 changes, security-gate enforcement) are flagged
for `risk_phases:` so they always get a checkpoint.

## Checkpoint 2 — Approve the plan

**Your second human checkpoint.** Review the phase plan autopilot produced, then:

```
/autopilot-detect
/autopilot-run
```

autopilot implements each phase test-first behind a quality gate that verifies your spec's DoD — a
phase can't be marked done unless its `cmd:`/`grep:` checks actually pass.

## Step 3 — Measure

After the fixes merge:

```
/rust-optimize-measure
```

You get a **before | after | Δ** scorecard. Deterministic rows (lock-file size, compiles-per-PR,
enforced gates) are exact; empirical rows (time-to-green) appear only with enough warm runs. If the CI
fixes **exposed** a latent bug — a flaky test that retries used to hide — that's reported as _exposed,
not caused_.

That's the loop: **audit → curate → hand off → approve → ship → measure.**
