#!/usr/bin/env bash
#
# baseline.sh — capture the pre-optimization snapshot into .optimizer/baseline.json.
#
# Records deterministic metrics (exact, computed from files/CI DAG) plus, where enough data
# exists, empirical ones (warm CI run history). Deterministic metrics are always reported;
# empirical ones are reported only with enough samples (the sufficiency rule — see metrics.md).
# Read-only w.r.t. the repo source; the only file it writes is .optimizer/baseline.json.
#
# Deps: bash, jq; optional: cargo (dep counts), gh (run history), git.
# Usage: baseline.sh [repo_root]

set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"
OUT_DIR="$ROOT/.optimizer"
OUT="$OUT_DIR/baseline.json"
mkdir -p "$OUT_DIR"

WF_GLOB=".github/workflows"

# --- Deterministic metrics --------------------------------------------------
cargo_lock_lines=0
[ -f Cargo.lock ] && cargo_lock_lines=$(wc -l <Cargo.lock | tr -d ' ')

direct_deps="null"
if command -v cargo >/dev/null 2>&1 && [ -f Cargo.toml ]; then
  direct_deps=$(cargo tree --depth 1 2>/dev/null | grep -cE '^[[:alnum:]]' || echo 0)
fi

full_compiles=0
enforced_gates=0
qemu_present=false
if [ -d "$WF_GLOB" ]; then
  full_compiles=$( { grep -rnE 'cargo (build|test)' "$WF_GLOB" 2>/dev/null || true; } | wc -l | tr -d ' ')
  # A gate is "enforced" if it runs audit/deny/clippy WITHOUT '|| echo' or continue-on-error on that step.
  audit_steps=$( { grep -rlnE 'cargo (audit|deny)|clippy' "$WF_GLOB" 2>/dev/null || true; } | wc -l | tr -d ' ')
  theater=$( { grep -rnE 'continue-on-error: *true|\|\| *echo' "$WF_GLOB" 2>/dev/null || true; } | wc -l | tr -d ' ')
  enforced_gates=$(( audit_steps > theater ? audit_steps - theater : 0 ))
  if grep -rqiE 'setup-qemu-action' "$WF_GLOB" 2>/dev/null; then qemu_present=true; fi
fi

unused_deps="null"
if command -v cargo-machete >/dev/null 2>&1 && [ -f Cargo.toml ]; then
  unused_deps=$(cargo machete 2>/dev/null | grep -cE '^\s+[a-z]' || echo 0)
fi

# --- Empirical metrics (sufficiency rule) -----------------------------------
runs_sample=0
median_ttg_seconds="null"
empirical_note="gh unavailable or insufficient run history — deterministic metrics only"
MIN_RUNS=5
if command -v gh >/dev/null 2>&1; then
  runs_json=$(gh run list --limit 50 \
    --json conclusion,createdAt,updatedAt,event 2>/dev/null || echo '[]')
  # Warm-vs-warm: successful PR/push runs only; duration = updatedAt - createdAt.
  durations=$(echo "$runs_json" | jq '[ .[]
    | select(.conclusion=="success")
    | ((.updatedAt|fromdateiso8601) - (.createdAt|fromdateiso8601)) ]')
  runs_sample=$(echo "$durations" | jq 'length')
  if [ "${runs_sample:-0}" -ge "$MIN_RUNS" ]; then
    median_ttg_seconds=$(echo "$durations" | jq 'sort | .[ (length/2|floor) ]')
    empirical_note="warm-vs-warm median over last $runs_sample successful runs"
  fi
fi

jq -n \
  --arg root "$ROOT" \
  --argjson cargo_lock_lines "$cargo_lock_lines" \
  --argjson direct_deps "$direct_deps" \
  --argjson full_compiles "$full_compiles" \
  --argjson enforced_gates "$enforced_gates" \
  --argjson qemu_present "$qemu_present" \
  --argjson unused_deps "$unused_deps" \
  --argjson runs_sample "$runs_sample" \
  --argjson median_ttg_seconds "$median_ttg_seconds" \
  --arg empirical_note "$empirical_note" \
  '{
     generated_by: "rust-optimizer/baseline.sh",
     root: $root,
     deterministic: {
       cargo_lock_lines: $cargo_lock_lines,
       direct_deps: $direct_deps,
       full_workspace_compiles_per_pr: $full_compiles,
       enforced_gates: $enforced_gates,
       setup_qemu_present: $qemu_present,
       unused_deps: $unused_deps
     },
     empirical: {
       runs_sample: $runs_sample,
       median_time_to_green_seconds: $median_ttg_seconds,
       note: $empirical_note
     }
   }' | tee "$OUT"

echo "baseline written to $OUT" >&2
