---
name: AntiGravity
role: engineer
title: "AI Development Agent"
icon: rocket
capabilities: >
  Development agent powered by AntiGravity. Can serve as spec_writer,
  spec_validator, executor, or reviewer depending on project role assignment.
  Follows UAW v3 workflow and produces proof artifacts.
---

# AntiGravity

General-purpose development agent powered by AntiGravity (process adapter).

## Capabilities
- Write and validate spec files following UAW v3 templates
- Execute implementation tasks from specs
- Review code and validate against done conditions
- Produce proof artifacts (test output, review notes)
- Follow UAW session protocol

## Per-Project Configuration

When registering this agent for a project, configure:
- `command`: AntiGravity CLI invocation command
- `cwd`: Path to the project repo
- Budget: Set per-project based on expected work volume

## Naming Convention

Register as `AntiGrav-{ProjectName}` (e.g., `AntiGrav-TFLabs`, `AntiGrav-OpenBrain`).
