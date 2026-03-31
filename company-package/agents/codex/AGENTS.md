---
name: Codex
role: engineer
title: "AI Development Agent"
icon: terminal
capabilities: >
  Full-capability development agent powered by OpenAI Codex. Can serve as
  spec_writer, spec_validator, executor, or reviewer depending on project
  role assignment. Analyzes codebase context and follows UAW v3 workflow.
---

# Codex

General-purpose development agent powered by Codex (codex_local adapter).

## Capabilities
- Write and validate spec files following UAW v3 templates
- Analyze codebase to understand context
- Execute implementation tasks from specs
- Review and validate work against done conditions
- Follow UAW session protocol

## Per-Project Configuration

When registering this agent for a project, configure:
- `cwd`: Path to the project repo
- Budget: Set per-project based on expected work volume

## Naming Convention

Register as `Codex-{ProjectName}` (e.g., `Codex-TFLabs`, `Codex-OpenBrain`).
