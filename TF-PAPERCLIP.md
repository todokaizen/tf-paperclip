# TF-Paperclip

This repository is **not stock Paperclip**. It is a fork of [`paperclipai/paperclip`](https://github.com/paperclipai/paperclip) with the TF-Paperclip overlay — configuration, company packages, pipeline configs, and runtime tooling that bind [tf-devflow](https://github.com/todokaizen/tf-devflow) (governance methodology) to the Paperclip orchestrator.

See `README.md` for the underlying Paperclip project.

## Layering

```
uaw          ← foundation: file-authoritative agent operating contract (UAW v3)
  ↑
tf-devflow   ← extension: governance methodology, decision rubrics, three-check
                          spec review, solo-operator discipline
  ↑
tf-paperclip ← this repo: Paperclip-specific implementation of tf-devflow
```

- [uaw](https://github.com/todokaizen/uaw) — Unambiguous Agentic Workflow v3. The per-project operating contract: authority order, session protocol, phase classification, spec template.
- [tf-devflow](https://github.com/todokaizen/tf-devflow) — Operator manifesto, decision rubrics, governance framework, three-check spec review, pipeline-mode concepts, role abstractions. Orchestrator-agnostic.
- **tf-paperclip** (this repo) — Paperclip-specific implementation: company packages, pipeline configs, agent definitions, runtime scripts, ARCHITECTURE/RUNBOOK, benchmarks.

A different orchestrator binding could host the same tf-devflow methodology; only this repo's contents would be replaced.

## What the overlay adds

These top-level directories are TF-Paperclip-specific. Everything else is upstream Paperclip.

| Path | Purpose |
|------|---------|
| `companies/` | Company packages (`nhn`, `tflabs`, `todofoco`, `websites`) that run on this Paperclip instance |
| `master-template/` | Reference template used to scaffold new companies and agents |
| `pipelines/` | Pipeline configs (version-controlled) with sync and recovery tooling |
| `paperclip-uaw/` | UAW workflow scripts: `install.sh`, `sync-pipelines.sh`, `healthcheck.sh`, `recover.sh` |
| `design/` | Architecture, runbooks, decision logs, issue tracking, Paperclip-specific design proposals |

## Upstream relationship

- `origin` → `git@github.com:todokaizen/tf-paperclip.git` (this fork)
- `upstream` → `git@github.com:paperclipai/paperclip.git` (Paperclip core)

Pull upstream updates with:

```sh
git fetch upstream
git merge upstream/master
```

## Rename discipline

TF-Paperclip is a **configuration layer**, not a rebrand. The Paperclip system keeps its identity inside the repo so that upstream merges stay conflict-free.

**Stays `paperclip` / `@paperclipai` / `PAPERCLIP_*`:**
- All upstream files (`server/`, `ui/`, `cli/`, `packages/`, `doc/`, `releases/`, root `README.md`, `package.json`, etc.)
- Env vars (`PAPERCLIP_*`) — runtime contract
- Schema IDs (`schema: paperclip/v1`) — validated by `server/src/services/company-portability.ts`
- The `@paperclipai/*` monorepo scope
- The `paperclip-uaw/` directory name (stable path for scripts)

**TF-Paperclip-named:**
- This file and `CLAUDE.md`
- Overlay-specific documents whose names already include `tf-paperclip`

When adding new overlay content, name it after TF-Paperclip; when editing upstream code, leave Paperclip references alone. Methodology documents (manifesto, rubrics, governance principles) belong in the **tf-devflow** repo, not here.
