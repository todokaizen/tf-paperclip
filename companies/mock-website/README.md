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
