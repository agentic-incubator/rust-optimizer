#!/usr/bin/env bash
#
# audit.sh — first-pass rule scan for a Rust repo's CI/release/Docker setup.
#
# Emits findings.json: an array of candidate findings (id, severity, evidence file:line,
# est_impact, note). These are HEURISTICS — grep/glob hits are hypotheses, not conclusions.
# Every hit must be verified empirically (compiler / test run / smoke build) before it reaches
# the report or OPTIMIZATION_SPEC.md. This script only reads; it never modifies the repo.
#
# Deps: bash, grep, jq. (gh/cargo used by baseline.sh, not here.)
# Usage: audit.sh [repo_root]   (defaults to git toplevel or CWD)

set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"

WF_GLOB=".github/workflows"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# add_finding <id> <severity> <est_impact> <note> [evidence]
add_finding() {
  jq -nc \
    --arg id "$1" \
    --arg severity "$2" \
    --arg est_impact "$3" \
    --arg note "$4" \
    --arg evidence "${5:-}" \
    '{id:$id, severity:$severity, est_impact:$est_impact, note:$note}
     + (if ($evidence | length) > 0 then {evidence: ($evidence | split("\n"))} else {} end)' \
    >>"$TMP"
}

# first_hits <pattern> — repo-wide file:line matches in workflows (empty if none)
wf_hits() {
  if [ -d "$WF_GLOB" ]; then
    grep -rniE "$1" "$WF_GLOB" 2>/dev/null | cut -d: -f1-2 | head -n 20 || true
  fi
}

has_wf() { [ -n "$(wf_hits "$1")" ]; }

# --- A. Build architecture & caching ---------------------------------------
if [ -d "$WF_GLOB" ]; then
  compile_jobs=$( { grep -rnE 'cargo (build|test)' "$WF_GLOB" 2>/dev/null || true; } | wc -l | tr -d ' ')
  if [ "${compile_jobs:-0}" -gt 2 ] && ! has_wf 'nextest archive'; then
    add_finding "A1" "high" "removes N-1 full workspace compiles per PR" \
      "Workspace appears compiled in >2 jobs; consider build-once via 'cargo nextest archive'." \
      "$(wf_hits 'cargo (build|test)')"
  fi
fi
if has_wf 'sccache-action' && has_wf 'Swatinem/rust-cache'; then
  add_finding "A2" "medium" "removes redundant cache layer" \
    "Both sccache-action and Swatinem/rust-cache present; keep Swatinem, drop sccache unless measured." \
    "$(wf_hits 'sccache-action')"
fi
if [ -d "$WF_GLOB" ] && ! has_wf 'CARGO_INCREMENTAL'; then
  add_finding "A3" "medium" "shrinks target/, relieves disk (root cause of B1)" \
    "CARGO_INCREMENTAL=0 / CARGO_PROFILE_TEST_DEBUG=0 not set." ""
fi
if [ -d "$WF_GLOB" ] && ! has_wf 'fuse-ld=lld'; then
  add_finding "A4" "medium" "faster link step on incremental builds" \
    "No fast linker (lld) configured." ""
fi
if has_wf 'cargo install cargo-'; then
  add_finding "A6" "medium" "avoids compiling tools from source each run" \
    "cargo install cargo-* from source; use taiki-e/install-action." \
    "$(wf_hits 'cargo install cargo-')"
fi

# --- B. Disk exhaustion -----------------------------------------------------
if has_wf 'rm -rf /usr/share/dotnet|rm -rf /opt/ghc|freeDiskSpace'; then
  add_finding "B1" "medium" "SYMPTOM of A1/A3 — fix the cause, then remove" \
    "Inline disk-freeing hack detected; treat as evidence of redundant builds / fat artifacts." \
    "$(wf_hits 'rm -rf /usr/share/dotnet|rm -rf /opt/ghc|freeDiskSpace')"
fi
if has_wf 'llvm-cov'; then
  add_finding "B2" "medium" "instrumented builds are an OOM/disk culprit" \
    "cargo llvm-cov present; set CARGO_PROFILE_TEST_DEBUG=0 and consider off-PR cadence." \
    "$(wf_hits 'llvm-cov')"
fi

# --- C. Concurrency & feedback latency -------------------------------------
if [ -d "$WF_GLOB" ] && ! has_wf 'cancel-in-progress'; then
  add_finding "C1" "medium" "cancels stale runs, saves runner minutes" \
    "No concurrency group with cancel-in-progress." ""
fi
if has_wf 'needs: *\[? *lint'; then
  add_finding "C2" "medium" "parallelizes build/test with lint" \
    "build/test appear to 'needs: [lint]' (serial); parallelize, keep ci-success requiring lint." \
    "$(wf_hits 'needs: *\[? *lint')"
fi
if has_wf 'runs-on: *ubuntu-latest' && ! has_wf 'vars\.'; then
  add_finding "C3" "low" "opt-in bigger runner with safe default" \
    "Heavy jobs hardcode ubuntu-latest; parameterize via \${{ vars.HEAVY_RUNNER || 'ubuntu-latest' }}." \
    "$(wf_hits 'runs-on: *ubuntu-latest')"
fi

# --- D. Multi-arch / Docker -------------------------------------------------
if has_wf 'setup-qemu-action'; then
  add_finding "D1" "high" "arm64 build ~10-12x faster native vs QEMU (GATE on account-awareness)" \
    "QEMU emulated cross-build; consider native split on ubuntu-24.04-arm (public repos: free)." \
    "$(wf_hits 'setup-qemu-action')"
fi
if has_wf 'upload-artifact' && ! has_wf 'if-no-files-found'; then
  add_finding "D2" "low" "avoids artifact-upload flakiness" \
    "upload-artifact without if-no-files-found: ignore." \
    "$(wf_hits 'upload-artifact')"
fi

# --- E. Quality-gate theater ------------------------------------------------
if has_wf 'continue-on-error: *true' || has_wf '\|\| *echo'; then
  add_finding "E1" "high" "turns fake gates into real ones" \
    "Gate theater: '|| echo' or 'continue-on-error: true' on audit/deny/lint — enforce or remove." \
    "$(wf_hits 'continue-on-error: *true|\|\| *echo')"
fi

# --- F. Dependency hygiene (heuristic pointer; cargo is the arbiter) --------
if [ -f "Cargo.toml" ]; then
  add_finding "F1" "medium" "verify with 'cargo machete'; compiler is arbiter" \
    "Run 'cargo machete --with-metadata' and verify each hit before removal (false positives exist)." \
    "Cargo.toml:1"
fi

# --- G. Polyglot coverage flag bug -----------------------------------------
if [ -f "package.json" ] && grep -qE 'test.*-- .*--(run|coverage)' package.json 2>/dev/null; then
  add_finding "G2" "medium" "coverage/run flags silently ignored" \
    "Leading '--' may turn --run/--coverage into positionals; add a dedicated test:coverage script." \
    "package.json:$(grep -nE 'test.*-- .*--(run|coverage)' package.json | head -n1 | cut -d: -f1)"
fi

# --- Emit -------------------------------------------------------------------
if [ -s "$TMP" ]; then
  jq -s '{generated_by:"rust-optimizer/audit.sh", root:"'"$ROOT"'", count:length, findings:.}' "$TMP"
else
  jq -n '{generated_by:"rust-optimizer/audit.sh", root:"'"$ROOT"'", count:0, findings:[]}'
fi
