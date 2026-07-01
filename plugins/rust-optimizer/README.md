# rust-optimizer (plugin)

Audit-and-report optimizer for Rust GitHub Actions CI, release workflows, and Docker images. It never
edits your code — it detects, reports, emits an autopilot-ready spec, and measures impact.

## What's inside

```
plugins/rust-optimizer/
├── commands/
│   ├── rust-optimize-audit.md      # audit → report + OPTIMIZATION_SPEC.md + baseline
│   ├── rust-optimize-baseline.md   # capture .optimizer/baseline.json
│   └── rust-optimize-measure.md    # after-snapshot → scorecard
├── skills/optimize/
│   ├── SKILL.md                    # the discipline (progressive disclosure)
│   ├── references/
│   │   ├── rule-catalog.md         # rules A–G, each with a machine-checkable DoD
│   │   ├── detection-patterns.md   # stack / CI / Docker / visibility detection
│   │   ├── account-awareness.md    # runner availability by account × visibility
│   │   ├── spec-template.md        # the OPTIMIZATION_SPEC.md handoff contract
│   │   └── metrics.md              # deterministic vs empirical, warm/cold, scorecard
│   └── scripts/
│       ├── audit.sh                # detect → findings.json (+ est_impact)
│       ├── baseline.sh             # → .optimizer/baseline.json
│       └── measure.sh              # → impact.json + scorecard.md
└── docs/WORKFLOW.md                # design rationale
```

## The flow

`optimize` (audit → report → `OPTIMIZATION_SPEC.md` + baseline) → **you curate** → `autopilot:plan` →
**you approve** → `autopilot:detect` + `autopilot:orchestrate` (apply behind a gate) →
`rust-optimize-measure` (before/after scorecard).

## Invariants

- Never edits a target repo's source/CI/Docker (scripts write only under `.optimizer/`).
- Every rule has a Definition of Done in autopilot vocabulary (`cmd:`/`grep:`/`grep:absent:`).
- Findings are verified empirically — the compiler/runtime is the arbiter.
- Runner/arch recommendations are account- and visibility-aware; inapplicable findings are marked N/A.
- Metrics separate deterministic from empirical and report warm-vs-warm.

See the [repo README](../../README.md) for install + commands, and [WORKFLOW.md](docs/WORKFLOW.md) for
the design rationale.
