---
description: Audit a Rust repo's CI/release/Docker setup and emit an autopilot-ready OPTIMIZATION_SPEC.md (never edits code).
argument-hint: "[path to repo, defaults to current]"
---

Use the `rust-optimizer:optimize` skill to audit this repo.

Target: ${ARGUMENTS:-the current repository}

Run the full operating model from the skill:

1. **Detect** the stack, CI/release/Docker files, and — critically — account type + repo visibility
   (`gh repo view --json visibility,isInOrganization,owner`).
2. **Audit** with `scripts/audit.sh` as the first pass, then verify each candidate finding empirically
   (the compiler / test run is the arbiter — grep hits are hypotheses).
3. **Report** prioritized findings (severity × impact) and a sequenced action plan; mark any finding
   the account/visibility can't use as **N/A** with the reason.
4. **Capture baseline** metrics with `scripts/baseline.sh` → `.optimizer/baseline.json`.
5. **Emit `OPTIMIZATION_SPEC.md`** in autopilot Definition-of-Done vocabulary (`cmd:`/`grep:`/`grep:absent:`).
6. **Hand off**: tell me to run `autopilot:plan` on the spec, then `autopilot:detect` + `autopilot:orchestrate`
   (recommend `autonomy: reviewed` first), and flag risky findings for `risk_phases:`.

Do not modify any source, CI, or Docker files — this is audit-and-report only. Pause for my review of
the audit before writing the spec (checkpoint 1).
