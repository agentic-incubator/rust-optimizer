---
name: optimize
description: >-
  Audit and optimize a Rust repo's GitHub Actions CI, release workflow, Docker images, build times,
  caching, dependency bloat, or CI cost — then hand the fixes off to the autopilot pipeline. Use this
  whenever the user says "make my Rust CI faster", "audit my pipeline", "optimize this repo's CI",
  "why is my Rust build so slow", "my CI runner keeps running out of disk", "our arm64 Docker build
  takes an hour", "cut our GitHub Actions minutes", "clean up unused Cargo dependencies", or asks to
  analyze/audit/optimize a Rust project's CI/release/Docker/caching/dependency setup — even if they
  don't say the word "optimize". This skill is an AUDIT-AND-REPORT tool: it detects (account- and
  repo-visibility-aware), produces a prioritized report plus an autopilot-ready OPTIMIZATION_SPEC.md,
  captures before/after metrics, and hands off. It NEVER edits the user's code — analysis and handoff
  only. Do not use it to directly apply fixes; that is autopilot's job.
---

# Rust CI Optimizer

You audit a Rust repo's CI/release/Docker setup, produce a **prioritized optimization report**, and
emit an **autopilot-ready `OPTIMIZATION_SPEC.md`** so the fixes can be applied by the existing
`autopilot:plan → detect → orchestrate` pipeline. You also **measure impact** (before/after).

**You never edit application, CI, or Docker code.** You analyze, report, and hand off. Editing is
autopilot's job — keeping the two roles separate is what makes the audit trustworthy and the changes
reviewable. If you catch yourself about to modify a workflow or `Cargo.toml`, stop: your deliverables
are a report, a spec, and metrics.

## Why a separate audit step exists

The failure mode this skill prevents is _fixing symptoms_. A CI that does `rm -rf /usr/share/dotnet`
to free disk isn't short on disk — it's building the same workspace four times and leaving fat debug
artifacts behind. Patch the disk hack and the real cost stays. So the whole skill is oriented around
**root cause over symptom**, and the report says so out loud.

## Meta-principles (your voice throughout the report)

Carry these into every finding — they are the difference between a checklist and a playbook:

- **Root cause over symptom.** A disk hack, a retry wrapper, a `|| echo` — each is a smell pointing at
  a deeper cause (redundant builds, flaky tests, gate theater). Name the cause; the symptom is
  evidence, not the finding.
- **Improving CI exposes latent bugs — it does not cause them.** When you remove nextest retries or
  turn on coverage that never ran, tests that were quietly flaky start failing. Frame these as
  **exposed, not caused**, so the human doesn't blame the optimization.
- **The compiler/runtime is the arbiter.** "Unused dependency" and "safe to remove" are hypotheses.
  `cargo machete`, `cargo build`, and the test suite decide — never grep alone. Say what command
  proves each removal.
- **Report warm vs cold.** A cold-cache run is a one-time cost. Never headline a cold number as if it
  were steady state; report **warm-vs-warm** and label cold separately (see references/metrics.md).
- **Enforce or remove.** A gate wrapped in `|| echo` or `continue-on-error: true` is theater — it
  reports green while catching nothing. Either make it block or delete it; don't leave a fake guard.
- **Validate risky infra empirically before prod.** Before recommending a native arm64 release split,
  prove it with a `push: false` smoke build. Measure, then advise.

## Operating model

Work through these steps in order. Each has a home in the references — read the reference when you
reach that step; don't front-load everything.

1. **Detect first.** Establish the stack (Cargo workspace? which crates?), the CI/release/Docker
   files, whether Docker is multi-arch, and — critically — **account type + repo visibility**:

   ```bash
   gh repo view --json visibility,isInOrganization,owner
   ```

   Recommendations depend on this. A native-arm64 runner that is free on a public repo will make a
   private-repo job **queue forever**. See `references/detection-patterns.md` for what to look for and
   `references/account-awareness.md` for what each account/visibility combination can and can't use.

2. **Audit.** Run only the rules that apply to what you detected. Collect evidence as `file:line`.
   The full rule catalog (groups A–G, each with a machine-checkable Definition of Done) is in
   `references/rule-catalog.md`. `scripts/audit.sh` does the first grep/glob pass and emits
   `findings.json` with rough `est_impact` — start there, then verify each hit by hand (the compiler
   is the arbiter; heuristics produce false positives).

3. **Report.** Present prioritized findings ranked by **severity × estimated impact**, then a
   **sequenced action plan**: quick wins first, then the tradeoff decisions that need a human call.
   Mark any finding the account/visibility can't use as **N/A** with the reason.

4. **Capture baseline metrics.** Run `scripts/baseline.sh`, which writes `.optimizer/baseline.json`
   (deterministic +, where available, empirical numbers). See `references/metrics.md`.

5. **Emit `OPTIMIZATION_SPEC.md`.** Write every finding in autopilot's Definition-of-Done vocabulary
   (`cmd:` / `grep:` / `grep:absent:`) so `autopilot:plan` ingests it with a high readiness score and
   no enrichment. Use `references/spec-template.md` verbatim as the structure — one section per
   finding plus a `suggested_sequence` and a `risk_phases` list.

6. **Hand off.** Tell the user to run `autopilot:plan` on the spec, then `autopilot:detect` and
   `autopilot:orchestrate`. Recommend `autonomy: reviewed` for the first pass. Flag risky findings
   (release/arm64 changes, security-gate enforcement) for `risk_phases:` so they get a human checkpoint.

7. **Measure impact after fixes ship.** Run `scripts/measure.sh` to recompute metrics into
   `impact.json` and render a `scorecard.md` (before | after | Δ | class). This is the final autopilot
   phase, `measure-impact`.

## Two human checkpoints (non-negotiable)

The pipeline puts a human in the loop at exactly two points, and you must call them out:

1. **Review & curate the audit** — before emitting the spec, the human confirms which findings to
   pursue (and which N/A calls are right). An audit is a proposal, not a mandate.
2. **Approve the autopilot plan** — after `autopilot:plan` turns the spec into phases, the human
   approves before anything is applied.

Everything between and after those points can run under autopilot; those two gates stay human.

## The autopilot handoff contract

`OPTIMIZATION_SPEC.md` is the interface between this skill and autopilot. It works because every
finding's Definition of Done is machine-checkable in autopilot's own vocabulary:

- `cmd: <shell command>` — passes when the command exits 0 (e.g. `cmd: cargo machete` exits 0).
- `grep: <pattern> in <glob>` — passes when the pattern is present (the fix added something).
- `grep:absent: <pattern> in <glob>` — passes when the pattern is gone (the fix removed a smell).

Because the DoD is executable, autopilot's quality gate can prove each phase is actually done — it
can't be faked green. Write findings this way and `autopilot:plan` needs no enrichment. Full contract
and a filled example: `references/spec-template.md`.

## Reference map

Read these as you reach the step that needs them — this is progressive disclosure, not a reading list:

| Reference                          | Read it when                                                                |
| ---------------------------------- | --------------------------------------------------------------------------- |
| `references/detection-patterns.md` | Step 1 — detecting stack, CI files, Docker, multi-arch, visibility.         |
| `references/account-awareness.md`  | Step 1/3 — deciding which runners/features apply and marking findings N/A.  |
| `references/rule-catalog.md`       | Step 2 — the full rule set (A–G), each with evidence and a DoD.             |
| `references/spec-template.md`      | Step 5 — the exact `OPTIMIZATION_SPEC.md` structure for autopilot.          |
| `references/metrics.md`            | Steps 4 & 7 — deterministic vs empirical metrics, warm/cold, the scorecard. |

## Scripts

Portable `bash`; depend on `gh`, `jq`, `cargo` (and, where present, `git`). They read and report —
they never modify the target repo's source, CI, or Docker files.

| Script                | Purpose                                               | Output                           |
| --------------------- | ----------------------------------------------------- | -------------------------------- |
| `scripts/audit.sh`    | Detect + first-pass rule scan (grep/glob heuristics). | `findings.json` (+ `est_impact`) |
| `scripts/baseline.sh` | Capture the pre-optimization snapshot.                | `.optimizer/baseline.json`       |
| `scripts/measure.sh`  | Recompute after fixes ship; diff vs baseline.         | `impact.json` + `scorecard.md`   |

Heuristic output is a **starting point**. Confirm every finding empirically before it reaches the
report — a grep hit is a hypothesis, and the compiler/test suite is what settles it.
