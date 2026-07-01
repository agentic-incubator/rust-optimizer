# Design notes

Why rust-optimizer is shaped the way it is.

## Why audit-and-report, not auto-fix

An auditor that also applies its own findings has no independent check on itself — it grades its own
homework. By splitting **detection** (this plugin) from **application** ([autopilot](https://github.com/agentic-incubator/claude-autopilot)),
every fix passes through two things the auditor can't shortcut:

1. **A human curating the audit** — findings are a proposal, and the human decides what's real and
   what's N/A before anything is written to a spec.
2. **A machine-checkable gate** — autopilot only marks a phase done when the finding's Definition of
   Done (`cmd:` / `grep:` / `grep:absent:`) actually passes.

That separation is the whole trust model. It's also why the scripts are strictly read-only w.r.t. the
target repo: the only artifacts they produce live under `.optimizer/`.

## Why the DoD vocabulary

`OPTIMIZATION_SPEC.md` is the interface between the two plugins. If findings were prose, autopilot
would have to _interpret_ them (and could interpret them wrong). By writing each finding's "done"
condition as an executable check in autopilot's own vocabulary, the spec is ingested with a high
readiness score and **no enrichment** — and the fix can't be faked green, because a command either
exits 0 or it doesn't.

- `cmd:` for anything a tool can settle (`cargo machete`, `cargo audit`, `cargo build`).
- `grep:` / `grep:absent:` for structural changes a command can't easily assert.

## Why account- and visibility-awareness is load-bearing

GitHub does **not** gracefully fall back when a runner label doesn't resolve — the job queues forever.
So a well-meaning "use the native arm64 runner" recommendation can brick CI on a repo that can't
schedule that label. The audit therefore runs `gh repo view --json visibility,isInOrganization,owner`
_first_, gates every runner/arch finding through `references/account-awareness.md`, marks inapplicable
ones **N/A**, and always parameterizes runners as `${{ vars.X || 'ubuntu-latest' }}` so the spec is
portable.

## Why root-cause framing

Rust CI pain is usually downstream of a few root causes: redundant compiles, fat artifacts, gate
theater, emulated cross-builds. The disk hack, the retry wrapper, the `|| echo` — each is a _symptom_.
The rule catalog is deliberately written so the symptom is recorded as **evidence** and the finding
names the **cause**, with dependency ordering (`depends_on`, `suggested_sequence`) so symptoms are only
retired after their causes are fixed.

## Why metrics are split and warm-vs-warm

Two failure modes to avoid: overstating a win with a lucky run, and alarming on a one-time cold-cache
cost. So deterministic metrics (exact, file/DAG-derived) are the headline and always reported;
empirical metrics (timing) are reported only with enough warm samples and always warm-vs-warm. When
there's nothing recent to measure — e.g. no recent release for an arm64 build — the tooling _probes_
(a `push: false` smoke build) rather than guessing.

## Why "exposed, not caused"

Better CI removes the covers over latent bugs: retries that hid a flaky test, coverage that never ran.
Reporting those as _caused by_ the optimization would discourage the optimization. Framing them as
**exposed** keeps the incentive right — and each exposed bug gets its own finding with a real fix and DoD.
