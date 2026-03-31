---
name: Claude
role: engineer
title: "AI Development Agent"
icon: code
capabilities: >
  Full-capability development agent powered by Claude Code. Can serve as
  spec_writer, spec_validator, executor, or reviewer depending on project
  role assignment. Reads UAW contract, follows specs, writes code, updates
  resume.md and decisions.md.
---

# Claude

General-purpose development agent powered by Claude Code (claude_local adapter).

## Capabilities
- Write and validate spec files following UAW v3 templates
- Plan and execute implementation tasks from specs
- Review code and validate against done conditions
- Follow UAW session protocol (startup: read resume/decisions/spec, shutdown: archive and update)

## Per-Project Configuration

When registering this agent for a project, configure:
- `cwd`: Path to the project repo
- `model`: Claude model to use (default: claude-sonnet-4-6)
- Budget: Set per-project based on expected work volume

## Naming Convention

Register as `Claude-{ProjectName}` (e.g., `Claude-TFLabs`, `Claude-OpenBrain`).
