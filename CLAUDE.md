# CLAUDE.md — TF-Paperclip overlay

This repo is a fork of [`paperclipai/paperclip`](https://github.com/paperclipai/paperclip) with the **TF-Paperclip overlay** — the Paperclip-specific binding of [tf-devflow](https://github.com/todokaizen/tf-devflow) (governance methodology) on top of [uaw](https://github.com/todokaizen/uaw) (the file-authoritative operating contract). See `TF-PAPERCLIP.md` for the full description. `AGENTS.md` is upstream Paperclip guidance — read it for engine-level context.

## Layering — where to read what

- **uaw** — per-project operating contract, session protocol, spec template, authority order. Lives at https://github.com/todokaizen/uaw.
- **tf-devflow** — methodology: manifesto, decision rubrics, three-check spec review, governance framework, pipeline-mode concepts, role abstractions. Lives at https://github.com/todokaizen/tf-devflow. **Methodology docs are NOT in this repo** — read them there.
- **tf-paperclip** (here) — Paperclip implementation of the above: companies/, pipelines/, agent definitions, runtime scripts, ARCHITECTURE/RUNBOOK, benchmarks.

## Overlay boundary

TF-Paperclip-specific (safe to edit without upstream concerns):

- `companies/` — company packages
- `master-template/` — scaffolding template
- `pipelines/` — pipeline configs + tooling
- `paperclip-uaw/` — UAW workflow scripts (install, sync, healthcheck, recover)
- `design/` — architecture, runbooks, decisions, issues, Paperclip-specific design proposals
- `TF-PAPERCLIP.md`, `CLAUDE.md` — this overlay's identity files

Everything else is upstream Paperclip. Touching it invites merge conflicts on every `upstream/master` pull.

## Rename discipline (hard rules)

Do **not** rename any of these — they are the merge boundary:

- `PAPERCLIP_*` env vars (runtime contract)
- `schema: paperclip/v1` schema IDs (validated by `server/src/services/company-portability.ts`)
- `@paperclipai/*` package scope (`package.json`, workspaces)
- `paperclip-uaw/` directory name
- Any occurrence of `paperclip` inside upstream-tracked files (`server/`, `ui/`, `cli/`, `packages/`, `doc/`, `releases/`, root `README.md`, `package.json`, etc.)

Do rename / name freshly:

- New overlay files and docs — prefer `tf-paperclip` in the name
- Overlay-internal identifiers that have no upstream counterpart

## What goes where

When adding a new doc, decide first which repo it belongs to:

- If it would be useful to a *different orchestrator binding* (Symphony, Cline, custom), it's methodology — put it in **tf-devflow**.
- If it's a per-project operating contract change (session protocol, spec template structure, authority order), it's foundational — put it in **uaw**.
- If it's about *this Paperclip implementation* (companies, pipelines, agents, runtime, benchmarks, Paperclip-specific decisions), it goes here in **tf-paperclip**.

## Remotes

```
origin    git@github.com:todokaizen/tf-paperclip.git
upstream  git@github.com:paperclipai/paperclip.git
```

Pull upstream updates with `git fetch upstream && git merge upstream/master`.
