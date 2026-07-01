# 🦀 rust-optimizer

[![CI](https://github.com/agentic-incubator/rust-optimizer/actions/workflows/ci.yml/badge.svg)](https://github.com/agentic-incubator/rust-optimizer/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/agentic-incubator/rust-optimizer)](https://github.com/agentic-incubator/rust-optimizer/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Point Claude Code at your slow, expensive Rust CI. Get a prioritized fix list — and a spec autopilot can ship.**

rust-optimizer is an **audit-and-report** plugin for [Claude Code](https://claude.com/claude-code). It
inspects a Rust repo's GitHub Actions CI, release workflow, Docker images, caching, and dependency
graph; produces a prioritized optimization report; and emits an `OPTIMIZATION_SPEC.md` written in
[autopilot](https://github.com/agentic-incubator/claude-autopilot)'s Definition-of-Done vocabulary — so
the fixes ship through the autopilot pipeline instead of by hand. 🔁

It **never edits your code.** It detects (aware of your account type and repo visibility), reports,
hands off, and measures before/after impact. The two things it optimizes for are **root cause over
symptom** and **honest metrics** — no cold-cache scare numbers, no gates that only pretend to enforce.

New to Rust CI internals — nextest archives, native arm64 runners, `cargo machete`? That's fine; every
finding explains the "why," and the [glossary](docs/concepts.md#glossary) spells out the terms.

---

## ⚡ The 60-second version

```
cd your-rust-repo
/rust-optimizer:optimize            # or: /rust-optimize-audit

# 👀 review the prioritized findings + confirm which ones to pursue (checkpoint 1)
# → the skill writes OPTIMIZATION_SPEC.md + .optimizer/baseline.json

/autopilot-plan OPTIMIZATION_SPEC.md   # hand off; approve the plan (checkpoint 2)
/autopilot-detect
/autopilot-run                          # ship the fixes, one phase at a time

# after fixes merge:
/rust-optimize-measure               # before | after | Δ scorecard
```

---

## 📚 Guides

| Guide                                                          | Read it when                                                                          |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| 🚀 [**Getting started**](docs/getting-started.md)              | You want your first audit → spec → shipped fixes, step by step.                       |
| 🧠 [**How it works + glossary**](docs/concepts.md)             | You want to understand the audit → handoff model — and what nextest, QEMU, etc. mean. |
| 💡 [**Use cases**](docs/use-cases.md)                          | You want real examples: a slow arm64 release, disk exhaustion, dependency bloat.      |
| 🔍 [**Design notes**](plugins/rust-optimizer/docs/WORKFLOW.md) | You want the deep rationale: why audit-and-report, why the DoD vocabulary.            |

---

## 🤔 Why it exists

Most Rust CI slowness is a **symptom**. A job does `rm -rf /usr/share/dotnet` to free disk — but the
disk is full because the workspace compiles four times per PR and leaves fat debug artifacts behind.
Patch the disk hack and the real cost stays. rust-optimizer is built to find and name the **cause**,
then hand a machine-checkable fix to autopilot so it actually ships.

Three principles hold the whole thing together:

- **Root cause over symptom.** Every finding names the underlying cause; the smell is evidence, not the fix.
- **The compiler is the arbiter.** "Unused dependency" is a hypothesis until `cargo machete` + a build proves it.
- **Enforce or remove.** A gate wrapped in `|| echo` is theater — it reports green and catches nothing.

---

## 📦 Install

```
/plugin marketplace add agentic-incubator/rust-optimizer
/plugin install rust-optimizer@rust-optimizer
```

Update or remove later:

```
/plugin marketplace update rust-optimizer
/plugin uninstall rust-optimizer@rust-optimizer
```

---

## 🧰 Commands

| Command                          | What it does                                                          |
| -------------------------------- | --------------------------------------------------------------------- |
| `/rust-optimize-audit [path]`    | Audit CI/release/Docker → report + `OPTIMIZATION_SPEC.md` + baseline. |
| `/rust-optimize-baseline [path]` | Capture the pre-optimization metrics snapshot only.                   |
| `/rust-optimize-measure [path]`  | After fixes ship, render the before/after scorecard.                  |

You can also just ask in natural language — "audit my Rust CI", "why is my arm64 Docker build so
slow", "clean up unused Cargo deps" — and the `optimize` skill triggers on its own.

---

## ✅ Prerequisites

- **[Claude Code](https://claude.com/claude-code)** with plugin support.
- **`gh`** (GitHub CLI, authenticated) — for account/visibility detection and CI run history.
- **`jq`** — the scripts build their JSON with it.
- **`cargo`** (and `cargo-machete` for dependency findings) — the compiler is the arbiter.
- **[autopilot](https://github.com/agentic-incubator/claude-autopilot)** — to _apply_ the fixes the spec describes (rust-optimizer only writes the spec).

---

## 🗂️ Layout

```
rust-optimizer/
├── .claude-plugin/marketplace.json     # marketplace manifest
├── plugins/rust-optimizer/             # the plugin
│   ├── .claude-plugin/plugin.json
│   ├── commands/                       # 3 thin slash-command wrappers
│   ├── skills/optimize/                # SKILL.md + references/ + scripts/
│   ├── docs/WORKFLOW.md                # design rationale
│   └── README.md
├── docs/                               # user guides
├── scripts/validate-manifests.mjs      # runs in CI
└── .github/workflows/                  # ci, release (release-please), link-check
```

---

## 📜 License

[MIT](LICENSE) © Chris Phillipson
