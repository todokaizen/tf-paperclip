#!/usr/bin/env bash
# Superpowers ON vs OFF — Phase 2 A/B driver.
#
# Variant tags name the *superpowers feature*, not our patch:
#   superpowers-on   = vanilla hook, skill IS injected (our patch OFF)
#   superpowers-off  = patched hook, skill skipped     (our patch ON)
#
# So `on` is the "every agent wake gets the skill" world and `off` is
# the "patched/suppressed" world we ship in. Deltas printed by
# compare.sh are B minus A, so `compare.sh on off` reads as
# (skill-suppressed) − (skill-injected).
#
# Runs the token-efficiency benchmark N times on each variant and
# calls compare.sh to emit a markdown delta report.
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

run_variant "superpowers-on"  unpatched   # skill IS injected
run_variant "superpowers-off" patched     # skill SKIPPED (default prod state)

# Trap restores patched before compare runs.
restore_patched
trap - EXIT

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  A/B summary"
echo "════════════════════════════════════════════════════════════════"
"$bench_dir/compare.sh" superpowers-off superpowers-on "$n"
