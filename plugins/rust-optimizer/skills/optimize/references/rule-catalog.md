# Rule Catalog

The full rule set the audit runs. Groups **A–G**. Only run rules that apply to what
`references/detection-patterns.md` found, and gate every runner/arch recommendation through
`references/account-awareness.md`.

Each rule follows the same shape so it drops straight into `OPTIMIZATION_SPEC.md`:

- **Smell** — what you observe (the symptom).
- **Root cause** — the deeper thing the smell points at.
- **Evidence** — how to find it, captured as `file:line`.
- **Deliverable** — what the fix produces (autopilot applies this; you only describe it).
- **Definition of Done** — machine-checkable, in autopilot vocabulary (`cmd:` / `grep:` / `grep:absent:`).
- **Est. impact / severity** — see `references/metrics.md` for how to size these.

A finding is only real once verified empirically. Grep gets you a candidate; the compiler, the test
run, or a `push: false` smoke build is the arbiter.

## Table of contents

- [A. Build architecture & caching](#a-build-architecture--caching)
- [B. Disk exhaustion](#b-disk-exhaustion)
- [C. Concurrency & feedback latency](#c-concurrency--feedback-latency)
- [D. Multi-arch / Docker](#d-multi-arch--docker)
- [E. Quality-gate theater](#e-quality-gate-theater)
- [F. Dependency hygiene](#f-dependency-hygiene)
- [G. Test/coverage correctness (often exposed by the CI fixes)](#g-testcoverage-correctness-often-exposed-by-the-ci-fixes)

---

## A. Build architecture & caching

### A1 — Same workspace compiled in >2 jobs

- **Smell:** `cargo build`/`cargo test` compile the whole workspace independently in lint, test, and
  coverage jobs.
- **Root cause:** No shared build artifact — each job pays full compile cost.
- **Fix:** Build once with `cargo nextest archive --archive-file nextest.tar.zst`; downstream test
  jobs consume the archive with `cargo nextest run --archive-file …`.
- **Deliverable:** An archive-producing job + consumers.
- **DoD:** `grep: nextest archive in .github/workflows/**` and `grep: archive-file in .github/workflows/**`.
- **Impact:** High — removes N−1 full compiles per PR.

### A2 — Both `sccache-action` and `Swatinem/rust-cache` present

- **Smell:** Two caching layers configured at once.
- **Root cause:** Redundant/competing caches; sccache adds overhead that Swatinem's `target/` cache
  already covers for most workspaces.
- **Fix:** Keep `Swatinem/rust-cache`; remove `sccache-action` (unless a measured sccache win exists).
- **DoD:** `grep:absent: sccache-action in .github/workflows/**` and `grep: Swatinem/rust-cache in .github/workflows/**`.
- **Impact:** Medium.

### A3 — Missing `CARGO_INCREMENTAL=0` and `CARGO_PROFILE_TEST_DEBUG=0`

- **Smell:** CI has neither env var set.
- **Root cause:** Incremental artifacts and test debuginfo bloat `target/` — a frequent driver of the
  "CI out of disk" symptom (see B1).
- **Fix:** Set both in the workflow env.
- **DoD:** `grep: CARGO_INCREMENTAL: ?0 in .github/workflows/**` and `grep: CARGO_PROFILE_TEST_DEBUG: ?0 in .github/workflows/**`.
- **Impact:** Medium — shrinks `target/`, speeds cache save/restore, relieves disk.

### A4 — No fast linker

- **Smell:** Default linker; link time dominates incremental rebuilds.
- **Fix:** Install `lld` and add `-Clink-arg=-fuse-ld=lld` (via `RUSTFLAGS` or `.cargo/config.toml`).
- **DoD:** `grep: fuse-ld=lld in .github/workflows/** .cargo/config.toml` and `grep: lld in .github/workflows/**`.
- **Impact:** Medium.

### A5 — Test suite run twice (second run only to emit JSON)

- **Smell:** Tests run once for pass/fail, then again to produce machine-readable output.
- **Root cause:** Reporting bolted on as a second execution.
- **Fix:** Single run with nextest's JUnit profile (`--profile ci`, `[profile.ci.junit]` in
  `.config/nextest.toml`).
- **DoD:** exactly one test invocation in the job; `grep: junit in .config/nextest.toml`.
- **Impact:** High — halves test wall-clock.

### A6 — `cargo install cargo-*` from source

- **Smell:** CI compiles tools (`cargo-nextest`, `cargo-audit`, …) from source each run.
- **Fix:** `taiki-e/install-action` (prebuilt binaries).
- **DoD:** `grep: taiki-e/install-action in .github/workflows/**` and `grep:absent: cargo install cargo- in .github/workflows/**`.
- **Impact:** Medium.

### A7 — Toolchain pinned in both `rust-toolchain.toml` and workflow

- **Smell:** Rust version declared in two places; they drift.
- **Fix:** Single source of truth — keep `rust-toolchain.toml`, drop the workflow's `toolchain:` pin.
- **DoD:** `grep: rust-toolchain.toml in .` present and no explicit version in `dtolnay/rust-toolchain@<ver>` across workflows.
- **Impact:** Low (correctness/maintenance).

---

## B. Disk exhaustion

### B1 — Inline `rm -rf /usr/share/dotnet` (and friends)

- **Smell:** Steps that delete `/usr/share/dotnet`, `/opt/ghc`, Android SDK, etc. to free disk.
- **Root cause:** **A symptom, not a fix.** The real causes are redundant builds (A1) and fat
  artifacts (A3). The disk hack masks them.
- **Fix:** Address A1 + A3; remove the hack once disk headroom is real.
- **DoD:** `grep:absent: rm -rf /usr/share/dotnet in .github/workflows/**` (only after A1/A3 land).
- **Impact:** Medium — but always report it as _evidence of_ A1/A3, never as its own root cause.

### B2 — `cargo llvm-cov` = separate full instrumented build

- **Smell:** Coverage job does a full, separately-instrumented compile.
- **Root cause:** Instrumented builds are large and slow — a frequent OOM/disk culprit.
- **Fix:** Set `CARGO_PROFILE_TEST_DEBUG=0` for the job; consider moving coverage off the per-PR path
  to a nightly/merge cadence.
- **DoD:** `grep: CARGO_PROFILE_TEST_DEBUG: ?0 in .github/workflows/**` (coverage job) and, if moved,
  the coverage job is not triggered on `pull_request`.
- **Impact:** Medium/High.

---

## C. Concurrency & feedback latency

### C1 — No `concurrency:` group

- **Smell:** Pushes to the same PR pile up instead of cancelling stale runs.
- **Fix:** Add a `concurrency:` group with `cancel-in-progress: true` for PRs.
- **DoD:** `grep: cancel-in-progress: ?true in .github/workflows/**`.
- **Impact:** Medium (runner minutes + faster feedback).

### C2 — `build`/`test` `needs: [lint]` (serial)

- **Smell:** Heavy jobs wait on lint before starting.
- **Fix:** Parallelize build/test with lint; keep a `ci-success` aggregation job that still requires
  lint to pass.
- **DoD:** build/test jobs have no `needs: [lint]`; a `ci-success` job `needs:` all of them.
- **Impact:** Medium (time-to-green).

### C3 — Heavy jobs hardcode `ubuntu-latest`

- **Smell:** No way to point heavy jobs at a bigger runner.
- **Root cause:** Runner choice baked in — and a nonexistent label queues forever (see account-awareness).
- **Fix:** `runs-on: ${{ vars.HEAVY_RUNNER || 'ubuntu-latest' }}`.
- **DoD:** `grep: vars.HEAVY_RUNNER in .github/workflows/**`.
- **Impact:** Low/Medium (opt-in speed, safe default).

### C4 — Expensive job (docker) on every PR

- **Smell:** Docker build runs on PRs that don't touch Docker-relevant paths.
- **Fix:** Gate on a native git-diff (not a third-party paths-filter action) so it only runs when
  relevant files change.
- **DoD:** `grep: git diff in .github/workflows/**` gating the docker job; job is conditional.
- **Impact:** Medium.

---

## D. Multi-arch / Docker

### D1 — QEMU-emulated arm64 build

- **Smell:** `setup-qemu-action` + `platforms: linux/amd64,linux/arm64` + `push:` in the release
  workflow.
- **Root cause:** QEMU-emulated arm64 Rust builds are **~10–12× slower** than native (measured 59 min+
  vs ~5 min native).
- **Fix:** Native split — build arm64 on `ubuntu-24.04-arm`, amd64 on `ubuntu-latest`, push by digest,
  then merge with `docker buildx imagetools create` into one manifest. **Gate on account-awareness:
  the `-arm` runner is free only for public repos.**
- **DoD:** `grep:absent: setup-qemu-action in .github/workflows/release*.yml`,
  `grep: ubuntu-24.04-arm in .github/workflows/**`, `grep: buildx imagetools create in .github/workflows/**`.
- **Impact:** High — but mark **N/A** if the account/visibility can't use `-arm` runners.

### D2 — `upload-artifact` + `always()` + maybe-missing path

- **Smell:** Artifact upload that fails the job when the path doesn't exist.
- **Fix:** `if-no-files-found: ignore`.
- **DoD:** `grep: if-no-files-found: ignore in .github/workflows/**`.
- **Impact:** Low (flakiness).

---

## E. Quality-gate theater

### E1 — `|| echo` / `continue-on-error: true` on audit/deny/lint

- **Smell:** A gate that reports green while swallowing failures.
- **Root cause:** Gate theater — looks enforced, catches nothing.
- **Fix:** Enforce or remove. Make the step block on non-zero.
- **DoD:** `grep:absent: continue-on-error: ?true in .github/workflows/**` (on the gate step),
  `grep:absent: || echo in .github/workflows/**`, and `cmd: cargo audit` exits 0.
- **Impact:** High (security/quality correctness).

### E2 — Known-unfixable transitive advisory

- **Smell:** `cargo audit`/`cargo deny` flags a transitive advisory with no upstream fix.
- **Root cause:** Requires judgment, not a blanket ignore. **First analyze reachability.** Example:
  the `rsa` "Marvin" timing advisory reached via `jsonwebtoken`'s `rust_crypto` feature is **dead
  code** if the app only uses HS256/PATs (not RSA) — the vulnerable path is never executed.
- **Fix:** Right-size the response:
  - Not reachable → a **documented allowlist entry** with rationale (`[advisories.ignore]` +
    reachability note), not a silent ignore.
  - Reachable → a real remediation (dependency swap or, e.g., a runtime `CryptoProvider` change).
- **DoD:** `cmd: cargo audit` exits 0 (via justified ignore or fix); `grep: <advisory-id> in deny.toml`
  with an adjacent rationale comment when allowlisted.
- **Impact:** High — wrong call here is either a real vuln shipped or a false alarm blocking CI.

---

## F. Dependency hygiene

### F1 — `cargo machete --with-metadata` hits

- **Smell:** Declared dependencies that appear unused.
- **Root cause:** Candidate only — machete has false positives (macro-only use, feature-enabling deps,
  build-script use, re-exports). **The compiler is the arbiter:** remove, then `cargo build` +
  test.
- **Fix:** Verify each hit, remove the truly-unused, keep the rest.
- **DoD:** `cmd: cargo machete` exits 0.
- **Impact:** Medium (compile time, `Cargo.lock` size, supply-chain surface).

### F2 — Feature stub `feature = ["dep:X"]` where X is unused

- **Smell:** A Cargo feature enables an optional dependency nothing uses.
- **Fix:** Remove the dependency and fix the feature definition.
- **DoD:** `grep:absent: dep:X in Cargo.toml` (for the specific `X`); `cmd: cargo build` exits 0.
- **Impact:** Low/Medium.

### F3 — Orphaned `[workspace.dependencies]` entries

- **Smell:** Workspace-level dependency entries no member crate references.
- **Fix:** Drop them.
- **DoD:** `cmd: cargo machete` exits 0 and `cmd: cargo build --workspace` exits 0.
- **Impact:** Low (hygiene, lock size).

---

## G. Test/coverage correctness (often exposed by the CI fixes)

These usually surface **because** the CI fixes remove the masking (retries, never-run coverage). Frame
them as **exposed, not caused**.

### G1 — Random test data + UNIQUE constraint, masked by retries/never-run coverage

- **Smell:** A test uses random values against a UNIQUE column; it passes only because nextest retries
  hide the occasional collision, or because coverage (which would run it) never ran.
- **Root cause:** Non-deterministic fixtures — a latent bug, exposed once retries/coverage change.
- **Fix:** Deterministic data (e.g. an atomic counter for unique values).
- **DoD:** `cmd: cargo nextest run <test>` exits 0 with retries disabled; `grep:absent: rand in <test file>`
  for the fixture (or equivalent).
- **Impact:** Medium (correctness/flakiness).

### G2 — `pnpm test -- --run --coverage` (leading `--` turns flags into positionals)

- **Smell:** In a polyglot repo, a JS test script passes `--` such that `--run`/`--coverage` become
  positional args and are silently ignored.
- **Root cause:** Argument-forwarding mistake — coverage never actually ran.
- **Fix:** A dedicated `test:coverage` script with the flags applied correctly.
- **DoD:** `grep: "test:coverage" in package.json`; `cmd: pnpm run test:coverage` produces a coverage
  report.
- **Impact:** Medium — only applies if the repo is polyglot (Rust + JS/TS).
