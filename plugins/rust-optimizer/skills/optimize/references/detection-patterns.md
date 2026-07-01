# Detection Patterns

Step 1 of the operating model. Establish the ground truth before running any rule — a rule that
doesn't apply to this repo is noise, and a runner recommendation that ignores account/visibility can
make jobs queue forever. `scripts/audit.sh` automates the first pass; this file explains what it looks
for and how to confirm by hand.

## 1. Stack shape

| Question                         | How to detect                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------ |
| Cargo workspace or single crate? | `[workspace]` in root `Cargo.toml`; enumerate `members`.                             |
| Which crates?                    | `cargo metadata --no-deps --format-version 1 \| jq '.packages[].name'`.              |
| Edition / MSRV?                  | `edition` and `rust-version` in `Cargo.toml`; `rust-toolchain.toml`.                 |
| Test runner?                     | `.config/nextest.toml` or `cargo-nextest` in workflows → nextest; else `cargo test`. |
| Polyglot?                        | `package.json` / `pnpm-lock.yaml` alongside `Cargo.toml` → rule G2 may apply.        |

## 2. CI / release workflows

- Enumerate `.github/workflows/*.yml`. Classify each: lint, test, coverage, build, release, docker.
- Build the **job DAG** — read every `needs:` to see what is serial (C2) and how many jobs compile the
  full workspace (A1). "Full-workspace-compiles-per-PR" is a headline metric (see metrics.md).
- Note env vars (`CARGO_INCREMENTAL`, `CARGO_PROFILE_TEST_DEBUG`, `RUSTFLAGS`), caching actions
  (`Swatinem/rust-cache`, `sccache-action`), and tool-install patterns (`cargo install` vs
  `taiki-e/install-action`).
- Record every finding as `file:line` so it drops straight into the spec.

## 3. Docker / multi-arch

| Signal                                       | Meaning                                                    |
| -------------------------------------------- | ---------------------------------------------------------- |
| `Dockerfile`, `docker/**`, `compose*.yml`    | Docker is in play.                                         |
| `docker/setup-qemu-action`                   | Emulated cross-build — the arm64 slowness smell (D1).      |
| `platforms:` listing `linux/arm64`           | Multi-arch target.                                         |
| `docker/build-push-action` with `push: true` | Real publish path — arm64 changes are risky (risk_phases). |
| `buildx imagetools create`                   | Manifest-merge already present (native split partly done). |

## 4. Account type + repo visibility (critical)

Recommendations depend on this — run it early:

```bash
gh repo view --json visibility,isInOrganization,owner
```

- `visibility`: `PUBLIC` vs `PRIVATE`.
- `isInOrganization`: personal account vs org.
- `owner.login`: who owns it.

Feed the result into `references/account-awareness.md` to decide which runners/features apply. Any
finding the account/visibility can't use is marked **N/A** in the report with the reason — do not
recommend a runner label the repo can't schedule (it will queue forever, not fall back).

## 5. Baseline run history (for empirical metrics)

```bash
gh run list --limit 50 --json databaseId,workflowName,conclusion,createdAt,updatedAt,event
```

Use this to compute median time-to-green over recent runs (warm-vs-warm) and to judge whether there
are enough samples for empirical metrics at all (see metrics.md). If there is no recent release to
measure an arm64 build from, plan an active probe (a `push: false` smoke build) rather than reporting
"unknown."
