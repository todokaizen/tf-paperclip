# Proposal: Flexible Pipeline Modes

Date: 2026-04-04
Status: draft
Version: 1.0
Supersedes: none

> **Note (2026-04-27):** The orchestrator-agnostic mode concept (supervised / automated / spec_provided / quick) was extracted into [tf-devflow/pipeline-modes.md](https://github.com/todokaizen/tf-devflow/blob/main/pipeline-modes.md). This file remains as the **Paperclip-specific implementation** — concrete YAML schema, VentureLead dispatch logic, migration steps. See `design/decisions.md` (2026-04-27 entry) for the split rationale.

## Problem

The current pipeline config is static — one set of phase rules, one set of approval gates. In practice, the operator needs different behaviors for different situations:

- **A/B tests** need fully automated runs with no human gates
- **Production work** needs human review at key checkpoints
- **Some tasks** already have a spec written by the operator — skip spec_writer
- **Quick fixes** need minimal pipeline — just executor, no spec or validation

Switching between these modes currently requires editing `~/.paperclip/pipelines/{project}.yaml` before each run. That's high friction and error-prone.

## Proposed Solution: Pipeline Modes

Add a `modes` section to the pipeline config. Each mode defines its own phase rules, approval gates, and stage overrides. The operator selects a mode when creating the task.

### Pipeline Config with Modes

```yaml
# ~/.paperclip/pipelines/galileos-circle.yaml

# Default mode — used when no mode is specified
default_mode: supervised

modes:
  # Full human oversight — approval gates at key checkpoints
  supervised:
    phase_rules:
      exploratory:
        - executor
      structural:
        - spec_writer
        - executor
      production:
        - spec_writer
        - spec_validator
        - executor
        - reviewer
    approval_gates:
      - after: spec_writer
      - after: reviewer

  # Fully automated — validator replaces human review, no gates
  automated:
    phase_rules:
      exploratory:
        - executor
      structural:
        - spec_writer
        - spec_validator
        - executor
        - reviewer
      production:
        - spec_writer
        - spec_validator
        - executor
        - reviewer
    approval_gates: []

  # Operator wrote the spec — skip spec_writer, go straight to execution
  spec_provided:
    phase_rules:
      exploratory:
        - executor
      structural:
        - executor
      production:
        - spec_validator
        - executor
        - reviewer
    approval_gates:
      - after: reviewer

  # Quick fix — just executor, no spec or validation
  quick:
    phase_rules:
      exploratory:
        - executor
      structural:
        - executor
      production:
        - executor
    approval_gates: []

# Role assignments — shared across all modes
role_assignments:
  spec_writer: "SpecWriter"
  spec_validator: "Validator"
  executor: "Implementor"
  reviewer: "Validator"
  debugger: "Debugger"

# Failure escalation — shared across all modes
failure_escalation:
  executor_retries_before_debugger: 3
```

### How the Operator Selects a Mode

The mode is specified in the task description using a simple tag. The VentureLead parses it.

**Option 1: Tag in task title**
```
Build landing page [mode:automated]
Build landing page [mode:spec_provided]
Build landing page [mode:quick]
```

**Option 2: Tag in task description**
```
Build the landing page per specs/landing-page-copy.md.

mode: automated
phase: structural
```

**Option 3: Default from config**
If no mode is specified, VentureLead uses `default_mode` from the pipeline config. For normal work, this is `supervised`. For test runs, change the default temporarily.

**Recommendation:** Option 2 — tag in the description. It's explicit, visible in the issue, and doesn't clutter the title. The VentureLead reads the description for the mode tag, falls back to `default_mode` if not found.

## Mode Definitions

### supervised (default)

The current behavior. Human reviews spec before implementation, human reviews result after validation.

**Use when:** Normal production work. You want to catch spec errors before they propagate.

### automated

Validator replaces human at both checkpoints. No approval gates — the pipeline runs end-to-end. The Validator's structured output (`spec_fulfilled`, `spec_violations`, `extra_behavior_detected`) determines pass/fail. Failures loop back to the implementor automatically.

**Use when:** A/B tests, batch processing, tasks where you trust the spec and want speed. You review the final result on the board afterward.

### spec_provided

The operator wrote the spec manually and placed it in `specs/`. The spec_writer stage is skipped entirely. Pipeline starts at spec_validator (production) or executor (structural).

**Use when:** You brainstormed and wrote the spec yourself (or in a Claude session). You want agents to implement your spec, not write their own.

**Task description format:**
```
Implement per specs/my-feature.md

mode: spec_provided
phase: production
```

### quick

Just the executor. No spec writing, no validation, no review gates. The implementor reads the task description and does the work.

**Use when:** Small fixes, trivial changes, things not worth a full pipeline. You review the commit directly.

## VentureLead Changes

The VentureLead startup protocol adds one step: parse mode from task description.

```
1. Read task title, description, and phase
2. Parse mode tag from description (default: from pipeline config)
3. Read pipeline config → look up modes[mode].phase_rules[phase]
4. Execute stages in order
```

The rest of the VentureLead logic stays identical — it's still a state machine, it just reads from a different rule set based on the mode.

## What This Doesn't Change

- **Governance classification** — agents still classify decisions regardless of mode
- **UAW protocol** — agents still follow CLAUDE.md, update resume.md, etc.
- **System invariant** — no stage introduces unauthorized behavior regardless of mode
- **Portability** — modes are config, not code
- **Layer separation** — modes are Layer 1 (orchestration), not Layer 2 (workflow)

## Migration

1. Update `pipelines/template.yaml` with the modes structure
2. Update VentureLead AGENTS.md with mode parsing instructions
3. Existing pipeline configs without a `modes` section continue to work — VentureLead treats the top-level `phase_rules` as the only mode (backward compatible)

## Examples

### A/B Test (fully automated)
```
Title: Build Galileo's Circle landing page - Run 2A
Description: |
  Build the landing page per specs/landing-page-copy.md.
  mode: automated
  phase: structural
```
Pipeline runs: spec_writer → spec_validator → executor → reviewer. No human gates. Compare token counts after.

### Operator-written spec
```
Title: Add contact form to landing page
Description: |
  Implement per specs/contact-form.md. I wrote the spec.
  mode: spec_provided
  phase: production
```
Pipeline runs: spec_validator → executor → reviewer. Spec_writer skipped.

### Quick fix
```
Title: Fix typo in hero headline
Description: |
  Change "hwo" to "how" in the hero section of index.html.
  mode: quick
  phase: exploratory
```
Pipeline runs: executor only. No spec, no validation.

### Normal production work (default)
```
Title: Add user authentication
Description: |
  Build JWT-based auth system per the requirements in the project goal.
  phase: production
```
No mode tag → uses `default_mode: supervised`. Full pipeline with human review gates.
