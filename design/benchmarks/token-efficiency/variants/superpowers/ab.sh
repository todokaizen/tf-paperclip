#!/usr/bin/env bash
# Superpowers patch ON vs OFF — Phase 2 A/B driver.
#
# Runs the token-efficiency benchmark N times with the patched
# session-start hook (variant tag: superpowers-on), then N times with
# the unpatched hook (variant tag: superpowers-off), then calls
# compare.sh to emit a markdown delta report.
#
# Always restores the patched hook at the end, even on interrupt.
#
#   ab.sh            # default N=3
#   ab.sh 5          # N=5
#
# Expects the same env vars as run.sh (MOCK_COMPANY_ID, MOCK_VL_AGENT_ID,
# MOCK_PROJECT_ID, optionally PAPERCLIP_API_BASE / PAPERCLIP_API_KEY).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bench_dir="$(cd "$here/../.." && pwd)"
n="${1:-3}"

: "${MOCK_VL_AGENT_ID:?inherit from shell; see ../../README.md}"
: "${MOCK_COMPANY_ID:?inherit from shell; see ../../README.md}"
: "${MOCK_PROJECT_ID:?inherit from shell; see ../../README.md}"

# Always restore the patched hook on exit (the "normal" state for Paperclip).
restore_patched() {
  echo "🔧 restoring patched hook..."
  "$here/apply.sh" patched >/dev/null
}
trap restore_patched EXIT

run_variant() {
  local label="$1" file="$2"
  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  running $n trial(s) with variant: $label"
  echo "════════════════════════════════════════════════════════════════"
  "$here/apply.sh" "$file"
  for i in $(seq 1 "$n"); do
    echo ""
    echo "── trial $i / $n ($label) ──────────────────────────────────────"
    BENCH_VARIANT="$label" "$bench_dir/run.sh" || {
      echo "⚠️  trial $i of $label failed; continuing"
    }
  done
}

run_variant "superpowers-on"  patched
run_variant "superpowers-off" unpatched

# Trap restores patched before compare runs.
restore_patched
trap - EXIT

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  A/B summary"
echo "════════════════════════════════════════════════════════════════"
"$bench_dir/compare.sh" superpowers-on superpowers-off "$n"
