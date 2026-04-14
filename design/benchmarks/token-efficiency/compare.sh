#!/usr/bin/env bash
# Compare the most recent N results of two variants and emit a markdown
# delta report. Intended to be called by variants/*/ab.sh at the end of
# a run pair, but safe to invoke standalone.
#
#   compare.sh <variantA> <variantB> [N=3]
#
# "Most recent N" is by filename timestamp, so compare.sh does not care
# whether the runs happened back-to-back or a week apart — which means
# stale results can slip in. Re-run ab.sh in a single session for a
# clean comparison.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
results="$here/results"

variant_a="${1:?variant A label (e.g. superpowers-on)}"
variant_b="${2:?variant B label (e.g. superpowers-off)}"
n="${3:-3}"

# Collect the N most recent result JSONs for a variant; print their usage
# summary as tab-separated: cached, output, costUsd, tool-call-count
# (placeholder: we don't currently capture tool calls in JSON).
collect() {
  local label="$1"
  ls -1t "$results"/*-"$label".json 2>/dev/null | head -n "$n"
}

stats() {
  local label="$1"
  local files
  files="$(collect "$label")"
  [[ -z "$files" ]] && { echo "no results for $label"; return 1; }
  # jq reads usage.{inputTokens, cachedInputTokens, outputTokens, costUsd}
  # off each file and aggregates.
  jq -s '
    (map(.usage.inputTokens       // 0) | add / length) as $avg_in |
    (map(.usage.cachedInputTokens // 0) | add / length) as $avg_cached |
    (map(.usage.outputTokens      // 0) | add / length) as $avg_out |
    (map(.usage.costUsd           // 0) | add / length) as $avg_cost |
    (map(.usage.cachedInputTokens // 0) | min) as $min_cached |
    (map(.usage.cachedInputTokens // 0) | max) as $max_cached |
    {
      samples:  length,
      input:    ($avg_in    | floor),
      cached:   ($avg_cached | floor),
      output:   ($avg_out   | floor),
      costUsd:  $avg_cost,
      cachedMin: $min_cached,
      cachedMax: $max_cached
    }' $files
}

sa_json="$(stats "$variant_a")"
sb_json="$(stats "$variant_b")"

# Deltas: B minus A.
delta() {
  local field="$1"
  python3 -c "
import json, sys
a = json.loads('''$sa_json''')
b = json.loads('''$sb_json''')
d = b['$field'] - a['$field']
pct = (100.0 * d / a['$field']) if a['$field'] else 0.0
print(f'{d:+.3f}  ({pct:+.1f}%)')
" 2>/dev/null || echo "n/a"
}

echo ""
echo "## Variant A: $variant_a"
echo ""
echo '```json'
echo "$sa_json" | jq .
echo '```'
echo ""
echo "## Variant B: $variant_b"
echo ""
echo '```json'
echo "$sb_json" | jq .
echo '```'
echo ""
echo "## Delta (B − A)"
echo ""
echo "| Metric  | Δ absolute (%) |"
echo "|---------|----------------|"
echo "| input   | $(delta input)  |"
echo "| cached  | $(delta cached) |"
echo "| output  | $(delta output) |"
echo "| costUsd | $(delta costUsd)|"
