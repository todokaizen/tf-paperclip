---
schema: agentcompanies/v1
name: "Ker's Lab"
description: >
  Solo developer operation managing multiple AI agent workflows across projects.
  Uses UAW v3 as the in-repo contract and Paperclip as the replaceable orchestrator.
---

# Ker's Lab

A one-person AI-augmented development operation. Each project gets its own set of
agent instances configured for that project's stack, budget, and workflow needs.

## How It Works

1. Each project repo contains UAW v3 files (CLAUDE.md, resume.md, decisions.md, specs/)
2. Agents are registered per-project in Paperclip with stack-specific configs
3. The operator creates tasks in Paperclip, sets the phase, and assigns agents
4. Agents follow the UAW contract autonomously — Paperclip tracks status and budget
5. The operator reviews at approval gates (after spec, after review)

## Agent Roles

Any agent can fill any role. Roles are assigned per-project in pipeline-config.yaml:

- **spec_writer** — Writes spec files from task descriptions
- **spec_validator** — Reviews specs for ambiguity, consistency, feasibility
- **executor** — Implements the work following the spec
- **reviewer** — Validates the result against the spec and done condition
