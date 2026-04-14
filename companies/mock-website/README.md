# Mock Website (benchmark fixture)

Not a real company. A **frozen-config Paperclip package** used by the TF-Devflow token-efficiency benchmark (see `design/benchmarks/token-efficiency/`).

## Import

```bash
pnpm paperclipai company import ./companies/mock-website --new-company-name "Mock Website"
```

## Contents

- `.paperclip.yaml` — agent + adapter config. Snapshot of `master-template/.paperclip.yaml` plus a single `projects.demo` entry. Editing this file changes the benchmark baseline.
- `agents/*/AGENTS.md` — copies of master-template's agent instructions.
- `pipelines/template.yaml` — copy of master-template's pipeline.
- `projects/demo/PROJECT.md` — single project.
- `fixture-repo/` — the actual product. A tiny static website with a trivial bug the agent is expected to fix.

## How the benchmark uses it

1. `rsync -a --delete fixture-repo/ /tmp/mock-website-run-<id>/` — staged copy per run, so the checked-in fixture stays pristine.
2. `.paperclip.yaml` `projects.demo.workspaces.demo.cwd` points at that scratch path.
3. Runner invokes `paperclipai heartbeat-run --agentId <venture-lead-id>`.
4. Runner reads `cost_events` for the resulting heartbeat_run_id and writes a JSON result.

## The fixture bug

`fixture-repo/index.html` + `fixture-repo/styles.css` style the Submit button with `background: #888` (placeholder grey). The task in `projects/demo/` asks the implementor to change it to `#007BFF` and update `fixture-repo/tests/button.test.js` accordingly. Deterministic enough for repeatable measurement, wide enough to exercise spec-writer → implementor → validator.

## Billing split (API vs subscription)

Anthropic no longer supports Claude subscriptions over oauth for programmatic tools like OpenClaw. The practical TF-Devflow pattern is: orchestration agents pay per-token via the Anthropic API, the implementor consumes the subscription (where Claude Code / Max credits live).

This fixture encodes that split via per-agent env in `.paperclip.yaml`:

| Agent | Adapter | `env.ANTHROPIC_API_KEY` | Auth used |
|---|---|---|---|
| venture-lead | claude_local | (inherited from host) | API, if host has the key |
| debugger | claude_local | (inherited from host) | API, if host has the key |
| implementor | claude_local | `""` (empty — shadows host) | Subscription (Claude Code login) |
| spec-writer | codex_local | n/a | Codex auth (separate) |
| validator | codex_local | n/a | Codex auth (separate) |

`claude_local` treats an empty `ANTHROPIC_API_KEY` the same as unset and falls back to the CLI's logged-in subscription (`packages/adapters/claude-local/src/server/execute.ts:98-105`). That's why `""` on the implementor is safe — it's explicitly "ignore the inherited key."

To run with this split, the host shell (the one launching `paperclipai run`) needs both:

1. `ANTHROPIC_API_KEY` exported — consumed by venture-lead / debugger.
2. Claude Code logged in to the subscription — consumed by the implementor.

If the host has no `ANTHROPIC_API_KEY`, every `claude_local` agent falls back to the subscription (no billing split). If Claude Code isn't logged in, the implementor fails at run time.

**Don't commit the API key.** `ANTHROPIC_API_KEY` lives in the host shell (`.envrc`, launchd plist, keychain-backed export, whatever), not in `.paperclip.yaml`. The only env value in this config is `""` on the implementor, which is public by intent.
