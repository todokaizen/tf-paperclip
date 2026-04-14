# Token-efficiency benchmark

Measures how many tokens a TF-Devflow configuration burns on an assignment-triggered heartbeat. Phase 1 scope is deliberately small: **prove the pipe works, get a reproducible number, do not try to compare variants yet.**

## What gets measured

For each run the script:

1. Creates a fresh issue assigned to the mock-website VentureLead. **Paperclip auto-fires an assignment-triggered heartbeat on that agent** — this is the run we measure.
2. Polls `GET /api/companies/:id/heartbeat-runs` (active only) for the new run, captures its id.
3. Polls `GET /api/heartbeat-runs/:id` until `status` is terminal.
4. Reads `usageJson` off the run record. That's the canonical source — it has `inputTokens`, `cachedInputTokens`, `outputTokens`, `costUsd`, `model`, `biller`.

We do **not** fire our own `paperclipai heartbeat run`. Doing so lands a second wake that dedup-skips the already-blocked issue and pollutes the measurement with ~$0.12 of irrelevant "there's nothing new" chatter.

Result lives in `results/<timestamp>-<sha>-<variant>.json` alongside a `.log` of the run's server-side stdout.

## One-time setup

```sh
# 1. Start the server in a separate terminal
cd <repo-root>
pnpm paperclipai run

# 2. Import the mock-website company
pnpm paperclipai company import ./companies/mock-website \
    --new-company-name "Mock Website"

# 3. Look up the IDs the runner needs (slug is null on the records —
#    filter by name instead)
curl -sS http://localhost:3100/api/companies \
    | jq '.[] | select(.name=="Mock Website") | {id, name}'

# Given <mock-website-id> from above:
curl -sS "http://localhost:3100/api/companies/<mock-website-id>/agents" \
    | jq '.[] | select(.name=="VentureLead") | {id, name}'
curl -sS "http://localhost:3100/api/companies/<mock-website-id>/projects" \
    | jq '.[] | select(.name=="demo") | {id, name}'
```

## Running once

```sh
export MOCK_COMPANY_ID=<company uuid>
export MOCK_VL_AGENT_ID=<venture-lead uuid>
export MOCK_PROJECT_ID=<demo project uuid>
# Optional:
# export PAPERCLIP_API_BASE=http://localhost:3100
# export PAPERCLIP_API_KEY=<bearer token; otherwise local_trusted header is used>
# export BENCH_VARIANT=baseline
# export BENCH_TIMEOUT_SECS=300
./design/benchmarks/token-efficiency/run.sh
```

Each run writes two files under `results/`:

- `<ts>-<sha>-<variant>.json` — the structured measurement (usage + run metadata + fixture diff preview)
- `<ts>-<sha>-<variant>.log`  — mirror of the heartbeat's server-side log for debugging

Each run leaves its bench issue in the Paperclip DB. The runner sweeps any prior `[bench:...]` issues to `done` before creating the new one, so the VL's inbox only ever has the current run's issue when the measurement starts. Without the sweep the per-run token count creeps upward as prior blocked bench issues accumulate and the VL re-evaluates each one every wake.

## Running independently with `/loop`

Dynamic-mode `/loop` lets Claude Code pace repeated runs for variance sampling:

```
/loop ./design/benchmarks/token-efficiency/run.sh
```

**Before trusting any single number, run at least 3–5 times back-to-back.** LLM runs are stochastic; one run is not the variant's token cost. Phase 1 success = same config produces the same answer within ~10 % across several runs. That variance is the floor for any A/B claim we make in Phase 2.

## What the baseline currently measures

Because `~/.paperclip/pipelines/demo.yaml` does not exist, the VentureLead can't dispatch workflow stages. It picks up the issue, reads the missing pipeline config, posts a blocked comment, and exits. First-run numbers observed (subscription billing, so `costUsd` is informational, not a real charge):

- input: ~11 tokens
- cached: ~200 k tokens (cold cache; most of this is the system prompt + skill bundle)
- output: ~2.6 k tokens (the blocked comment + reasoning)
- costUsd: ~$0.18

That's the cost of "spin up a fresh VentureLead session, read the inbox, discover missing pipeline config, block". A stable unit, and a realistic subset of what every real assignment pays. Phase 2 can extend this by putting `demo.yaml` in place so the VL actually dispatches sub-tasks, and by measuring sub-agent runs too.

## Known caveats

- **Preconditions are not auto-fulfilled.** If the server is down or the IDs are unset the script fails loud with a hint; it does not attempt to start the server or import the company itself.
- **`costUsd` is subscription-aware, not a real bill.** `billingType: "subscription_included"` means `costCents` on `cost_events` is 0; the dollar figure in `usageJson.costUsd` is a list-price estimate, not a charge. Treat raw tokens as the stable signal.
- **Cold-cache vs warm-cache runs differ.** The assignment-triggered run always opens a fresh session (`freshSession: true`) — that is intentionally cold so different variants are compared on equal footing. Dedup-skip runs (which we don't measure) would reuse the session and look cheaper.
- **Codex adapter.** `spec-writer` and `validator` use `codex_local` in this fixture (inherited from master-template). They don't run in the baseline above because the VL blocks before dispatch, but if you wire up the pipeline config they'll need Codex CLI installed.
- **Pipeline config drift.** `~/.paperclip/pipelines/*.yaml` is per-project state outside this repo. If you want a reproducible full-pipeline benchmark, pin `demo.yaml` — or copy it from `companies/mock-website/pipelines/template.yaml` and substitute the agent names. Left out of Phase 1 on purpose.

## Phase 2 — first A/B: superpowers patch ON vs OFF

The superpowers plugin's `SessionStart` hook (at `~/.claude/plugins/cache/claude-plugins-official/superpowers/<version>/hooks/session-start`) injects the `using-superpowers` skill into every Claude Code session. Paperclip agent heartbeats are Claude Code sessions, so this injection lands in every wake. Our local patch short-circuits the hook when `PAPERCLIP_RUN_ID` is present. Issue 6 claims the delta is ~200 k tokens per heartbeat — this A/B measures it for real.

Files:

- `variants/superpowers/session-start.patched` — our patched hook (current state)
- `variants/superpowers/session-start.unpatched` — the vanilla superpowers hook (patched minus the 6-line skip block; verified byte-identical otherwise)
- `variants/superpowers/apply.sh patched|unpatched` — installs the selected variant into the live plugin dir (discovers the active version dynamically)
- `variants/superpowers/ab.sh [N]` — runs N trials on each variant, tags results with `BENCH_VARIANT=superpowers-on` (unpatched hook, skill injected — as if the feature were live) or `BENCH_VARIANT=superpowers-off` (patched hook, skill skipped — our normal prod state). Calls `compare.sh superpowers-off superpowers-on N` so the printed delta is (skill-off) − (skill-on), i.e. "how much does having the patch save us." Always restores the patched hook on exit via a `trap`, so even an interrupted run leaves Paperclip in the normal state.
- `compare.sh <A> <B> [N]` — reads the most recent N result JSONs per variant and prints mean / min / max for cached-input, output, and cost, plus a B−A delta.

Run it:

```sh
export MOCK_COMPANY_ID=…
export MOCK_VL_AGENT_ID=…
export MOCK_PROJECT_ID=…
./variants/superpowers/ab.sh 3    # 3 trials each = 6 heartbeats total
```

At 3 trials × 2 variants and ~90 s per run, expect ~9 minutes wall-clock. Larger N tightens the confidence band against the ~2× LLM-path variance documented above.

## Phase 2+ (later)

- Wire `~/.paperclip/pipelines/demo.yaml` into the fixture setup so the VentureLead can actually dispatch sub-tasks (spec-writer → implementor → validator). Unlocks full-pipeline measurements instead of the VL-only "block on missing config" path.
- Pipeline-mode matrix from `design/proposals/pipeline-flexibility-proposal.md`: `supervised` / `automated` / `spec_provided` / `quick`. Each mode is a different pipeline config variant; the runner swaps `~/.paperclip/pipelines/demo.yaml` between each.
- Combined matrix: `{patch on, off} × {4 modes} × N trials`. Expensive, but the scaffolding above composes.

See `../../issues/paperclip-issues-log.md` for the underlying issue write-ups, and `../../proposals/pipeline-flexibility-proposal.md` for the mode matrix spec.
