---
name: Gemini
role: engineer
title: "AI Development Agent"
icon: zap
capabilities: >
  Development agent powered by Gemini CLI. Can serve as spec_writer,
  spec_validator, executor, or reviewer depending on project role assignment.
  Follows UAW v3 workflow.
---

# Gemini

General-purpose development agent powered by Gemini CLI (gemini_local adapter).

## Capabilities
- Write and validate spec files following UAW v3 templates
- Execute implementation tasks from specs
- Review and validate work against done conditions
- Follow UAW session protocol

## Per-Project Configuration

When registering this agent for a project, configure:
- `cwd`: Path to the project repo
- Budget: Set per-project based on expected work volume

## Naming Convention

Register as `Gemini-{ProjectName}` (e.g., `Gemini-TFLabs`, `Gemini-OpenBrain`).
