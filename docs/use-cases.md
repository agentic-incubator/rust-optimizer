# 💡 Use cases

Three realistic scenarios, each showing how a symptom traces back to a root cause, what the finding
looks like in `OPTIMIZATION_SPEC.md`, and how the impact gets measured.

## 1. "Our CI keeps running out of disk"

**Symptom:** a `Free up disk space` step doing `rm -rf /usr/share/dotnet /opt/ghc …`.

**Root cause (what the audit reports):** the workspace compiles in four jobs (lint, test, coverage,
build) and `CARGO_INCREMENTAL`/`CARGO_PROFILE_TEST_DEBUG` are unset, so `target/` balloons. The disk
hack is a _symptom_ (rule B1) of the redundant builds (A1) and fat artifacts (A3).

**Spec findings:** A3 (`grep: CARGO_INCREMENTAL: ?0 …`), A1 (`grep: nextest archive …`), then B1
(`grep:absent: rm -rf /usr/share/dotnet …`) sequenced _after_ A1/A3 so the hack is only removed once
disk headroom is real.

**Impact:** `target/` size down, compiles-per-PR 4 → 2, disk hack gone.

## 2. "Our arm64 Docker release takes an hour"

**Symptom:** the release build takes 59+ minutes.

**Root cause:** `docker/setup-qemu-action` emulates arm64 — measured ~10–12× slower than native (rule
D1). But **account-awareness gates the fix:** the native `ubuntu-24.04-arm` runner is free (4 vCPU) on
**public** repos; on a **private** repo it's billed at 2 vCPU. On a private personal repo the finding
is marked **N/A / billed** rather than recommended outright.

**Spec finding (public repo):** D1 — native split, arm64 on `${{ vars.HEAVY_RUNNER || 'ubuntu-latest' }}`
mapped to `ubuntu-24.04-arm`, push-by-digest, `docker buildx imagetools create` manifest merge.
`grep:absent: setup-qemu-action in .github/workflows/release.yml`. Marked a `risk_phase` and validated
with a `push: false` smoke build before production.

**Impact (empirical, probe):** arm64 image build ~59m → ~5m.

## 3. "Clean up our dependency bloat"

**Symptom:** a huge `Cargo.lock`, slow cold builds, a broad supply-chain surface.

**Root cause:** unused direct deps, a feature stub enabling an optional dep nothing uses, and orphaned
`[workspace.dependencies]` entries (rules F1–F3). **The compiler is the arbiter** — `cargo machete`
produces candidates (with false positives: macro-only, feature-enabling, build-script, re-export uses),
and each removal is confirmed by `cargo build` + tests.

**Spec findings:** F1 (`cmd: cargo machete` exits 0), F2 (`grep:absent: dep:X in Cargo.toml`;
`cmd: cargo build`), F3 (`cmd: cargo build --workspace`).

**Impact (deterministic):** on one production repo — `Cargo.lock` −582 lines, direct deps −35.

## What often gets exposed

Fixing #1 and #3 frequently _exposes_ latent test bugs: removing nextest retries surfaces a test that
used random data against a UNIQUE constraint (rule G1); turning coverage back on surfaces a path that
never ran. rust-optimizer reports these as **exposed, not caused**, with a deterministic-data fix
(e.g. an atomic counter) and its own DoD.
