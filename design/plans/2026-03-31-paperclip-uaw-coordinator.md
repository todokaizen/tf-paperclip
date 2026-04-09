# Paperclip + UAW v3 Coordinator Setup Plan

Date: 2026-03-31
Status: current
Version: 1.0
Supersedes: 2026-03-30-paperclip-uaw-integration.md

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a coordinator agent to the company package, create pipeline config templates, remove pipeline-config.yaml from UAW templates (wrong layer), and update all docs to reflect the coordinator-driven workflow.

**Architecture:** Per-project coordinator agents (claude_local) read pipeline config from `~/.paperclip/pipelines/{project}.yaml` and orchestrate the task pipeline as a state machine. Pipeline config is Paperclip-layer (Layer 1), not repo content (Layer 2). No Paperclip core code changes.

**Tech Stack:** Markdown, YAML

---

## File Structure

```
Create:
  company-package/agents/coordinator/AGENTS.md   — Coordinator agent with state machine instructions
  company-package/pipelines/template.yaml         — Pipeline config template for new projects

Modify:
  company-package/.paperclip.yaml                 — Add coordinator adapter entry
  company-package/README.md                       — Replace manual workflow with coordinator-driven flow
  company-package/COMPANY.md                      — Add coordinator to agent list
  UAW-v3/uaw-templates/README.md                  — Remove pipeline-config.yaml reference

Remove:
  UAW-v3/uaw-templates/pipeline-config.yaml       — Wrong layer; moves to Paperclip config
```

---

### Task 1: Remove pipeline-config.yaml from UAW Templates

**Files:**
- Remove: `UAW-v3/uaw-templates/pipeline-config.yaml`
- Modify: `UAW-v3/uaw-templates/README.md`

Pipeline config is orchestration (Layer 1), not workflow contract (Layer 2). It should not be in project repos.

- [ ] **Step 1: Delete the file**

```bash
rm UAW-v3/uaw-templates/pipeline-config.yaml
```

- [ ] **Step 2: Update the UAW templates README**

Replace the contents of `UAW-v3/uaw-templates/README.md` with:

```markdown
# UAW-os Project Templates

## Setup

To initialize a new project under the Universal Agentic Workflow:

1. Copy this folder into your project root:
   ```
   cp -r UAW-v3/uaw-templates/ your-project/
   ```

2. Your project will have:
   ```
   your-project/
     CLAUDE.md            <- UAW operating contract (agents read this first)
     resume.md            <- current state - the one file to read on return
     decisions.md         <- append-only architectural decisions
     specs/               <- spec files for non-exploratory work
       spec-template.md   <- copy and rename per spec
     archive/             <- dated resume.md copies from prior sessions
   ```

3. Fill in `resume.md` - project name, phase, objective.

## Paperclip Integration

This project uses Paperclip as the orchestration layer. Paperclip assigns agents
to tasks; agents follow the UAW contract in CLAUDE.md autonomously.

**Separation of concerns:**
- Paperclip manages: who runs, when, budget, approvals, audit trail
- UAW manages: what files to read, authority order, status transitions, proof, shutdown

**If Paperclip is removed,** nothing changes except who kicks off the job.

## Agent Read Order

On every session start, the agent reads:
1. `CLAUDE.md` (this contract)
2. `resume.md`
3. `decisions.md`
4. Active spec (if referenced in resume)

## Session End

On every session end, the agent:
1. Copies `resume.md` to `archive/resume-YYYY-MM-DD.md`
2. Writes fresh `resume.md` with current state
3. Updates `decisions.md` if any decisions were made
```

- [ ] **Step 3: Commit**

```bash
git rm UAW-v3/uaw-templates/pipeline-config.yaml
git add UAW-v3/uaw-templates/README.md
git commit -m "docs: remove pipeline-config.yaml from UAW templates (wrong layer)"
```

---

### Task 2: Create Pipeline Config Template

**Files:**
- Create: `company-package/pipelines/template.yaml`

This is a template operators copy and customize per project. The actual configs live at `~/.paperclip/pipelines/` at runtime — this template lives in the company package for reference.

- [ ] **Step 1: Create the template file**

Create `company-package/pipelines/template.yaml`:

```yaml
# Pipeline Configuration Template
#
# Copy this file to ~/.paperclip/pipelines/{project-name}.yaml
# and fill in the agent names for your project.
#
# This file is Layer 1 (Paperclip orchestration config).
# It is NOT part of the project repo.
# The coordinator agent reads it to route tasks through the pipeline.

# Phase rules: which pipeline stages run for each phase.
# Stages execute in order. Each stage maps to a role.
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
  durable_knowledge:
    - spec_writer
    - spec_validator
    - executor
    - reviewer

# Role assignments: which Paperclip agent fills each role.
# Use the agent name as registered in Paperclip (e.g., "Claude-TFLabs").
# Any agent can fill any role.
# For fan-out (competing outputs), use a list of agent names.
role_assignments:
  spec_writer: "Codex-PROJECTNAME"
  spec_validator: "Claude-PROJECTNAME"
  executor: "Claude-PROJECTNAME"
  reviewer: "AntiGrav-PROJECTNAME"

# Approval gates: stages after which the coordinator pauses for operator review.
# The coordinator creates a Paperclip approval request and waits.
approval_gates:
  - after: spec_writer
  - after: reviewer
```

- [ ] **Step 2: Commit**

```bash
git add company-package/pipelines/template.yaml
git commit -m "docs: add pipeline config template for coordinator agent"
```

---

### Task 3: Create Coordinator Agent Definition

**Files:**
- Create: `company-package/agents/coordinator/AGENTS.md`

This is the core of the coordinator — its instructions define the state machine behavior.

- [ ] **Step 1: Create the coordinator AGENTS.md**

Create `company-package/agents/coordinator/AGENTS.md`:

```markdown
---
name: Coordinator
role: pm
title: "Pipeline Coordinator"
icon: target
capabilities: >
  Per-project pipeline coordinator. Reads pipeline config, creates sub-tasks
  for each stage, assigns agents, and pauses at approval gates. State machine
  only — never judges correctness or quality of work.
---

# Coordinator

Pipeline orchestration agent. One instance per project (e.g., Coordinator-TFLabs).
Powered by Claude Code (claude_local adapter).

## Critical Rule

You are a state machine. You coordinate, record, and enforce workflow.
You NEVER decide correctness. You NEVER judge quality. You NEVER skip stages.
If something fails or seems wrong, you report it and wait for the operator.

## Startup Protocol

When you receive a task:

1. Read the task title, description, and phase from the Paperclip issue.
2. Read the pipeline config from `~/.paperclip/pipelines/{project}.yaml`.
3. Look up `phase_rules[phase]` to get the ordered list of stages.
4. Execute each stage in order (see Pipeline Execution below).

If the pipeline config file is missing or the phase has no rules, report
this as BLOCKED and wait.

## Pipeline Execution

For each stage in the pipeline:

1. **Create a sub-task** in Paperclip:
   - Title: `[{role}] {parent_task_title}`
   - Description: Same as parent task description
   - Assign to: The agent named in `role_assignments[role]`
   - Set as child of the parent task
   - Status: `todo` (triggers Paperclip auto-wakeup of the assigned agent)

2. **Wait for completion.** Monitor the sub-task status.
   - If status becomes `done` → proceed to step 3
   - If status becomes `blocked` → report to operator and wait
   - If the agent fails → report to operator and wait
   - Do NOT retry, work around, or make judgment calls

3. **Check for approval gate.** If `approval_gates` includes `after: {role}`:
   - Create a Paperclip approval request on the parent task
   - Post a comment: "Stage [{role}] complete. Awaiting operator approval to proceed."
   - Wait for approval
   - If rejected → stop the pipeline, report to operator

4. **Advance to next stage.** Repeat from step 1 for the next role in the list.

## Fan-Out

If `role_assignments[role]` is a list of agents (not a single agent):
- Create one sub-task per agent, all with the same role
- Wait for ALL sub-tasks to complete
- The operator picks the best output at the approval gate
- Proceed with the next stage

## Pipeline Completion

When all stages are complete:
1. Move the parent task to `in_review`
2. Post a comment: "All pipeline stages complete. Ready for final review."
3. Wait for the operator to approve and close the task

## What You Do NOT Do

- Judge whether a spec is good enough
- Evaluate code quality
- Decide to skip or reorder stages
- Retry failed stages without operator approval
- Make any correctness decisions
- Modify files in the project repo
- Run tests or validation (that is Layer 4, not your job)

## Per-Project Configuration

When registering this agent for a project, configure:
- `cwd`: Path to the project repo (for workspace context)
- Budget: Minimal — the coordinator creates tasks, it doesn't do heavy work

## Naming Convention

Register as `Coordinator-{ProjectName}` (e.g., `Coordinator-TFLabs`).
```

- [ ] **Step 2: Commit**

```bash
git add company-package/agents/coordinator/AGENTS.md
git commit -m "docs: add coordinator agent with state machine instructions"
```

---

### Task 4: Update .paperclip.yaml with Coordinator Adapter

**Files:**
- Modify: `company-package/.paperclip.yaml`

- [ ] **Step 1: Add coordinator entry**

Replace the contents of `company-package/.paperclip.yaml` with:

```yaml
schema: paperclip/v1

# Agent adapter configurations.
# These are TEMPLATES — when importing for a specific project, update:
#   - cwd paths to point to the actual project repo
#   - budget values for the project
#   - model choices if needed
#
# Agents are role-agnostic. Any agent can fill any pipeline role
# (spec_writer, spec_validator, executor, reviewer). Role assignment
# is configured per-project in ~/.paperclip/pipelines/{project}.yaml.

agents:
  coordinator:
    adapter:
      type: claude_local
      config:
        cwd: "{{PROJECT_REPO_PATH}}"
        model: claude-sonnet-4-6
        maxTurnsPerRun: 100
        dangerouslySkipPermissions: false

  claude:
    adapter:
      type: claude_local
      config:
        cwd: "{{PROJECT_REPO_PATH}}"
        model: claude-sonnet-4-6
        maxTurnsPerRun: 300
        dangerouslySkipPermissions: false

  codex:
    adapter:
      type: codex_local
      config:
        cwd: "{{PROJECT_REPO_PATH}}"
        dangerouslyBypassApprovalsAndSandbox: false

  antigravity:
    adapter:
      type: process
      config:
        command: "antigravity"
        cwd: "{{PROJECT_REPO_PATH}}"
        timeoutSec: 300

  gemini:
    adapter:
      type: gemini_local
      config:
        cwd: "{{PROJECT_REPO_PATH}}"
```

- [ ] **Step 2: Commit**

```bash
git add company-package/.paperclip.yaml
git commit -m "docs: add coordinator to .paperclip.yaml adapter configs"
```

---

### Task 5: Update COMPANY.md with Coordinator

**Files:**
- Modify: `company-package/COMPANY.md`

- [ ] **Step 1: Update COMPANY.md**

Replace the contents of `company-package/COMPANY.md` with:

```markdown
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

## Design Philosophy

### Layered Architecture

1. **Paperclip (orchestration)** — task routing, scheduling, approvals, audit logs
2. **UAW (workflow manifest)** — roles, allowed actions, required steps, constraints
3. **Execution agents** — Claude, Codex, AntiGravity, Gemini, others
4. **Validation (outside Paperclip)** — tests, evaluators, rubrics, policy checks
5. **Output sinks** — GitHub, CMS, datasets, Open Brain

### Critical Rule

Paperclip never decides correctness. It coordinates, records, and enforces
workflow. Correctness comes from validation systems, evaluation pipelines,
and policy rules — all outside Paperclip.

## How It Works

1. Each project repo contains UAW v3 files (CLAUDE.md, resume.md, decisions.md, specs/)
2. You create a task in Paperclip and assign it to the project's coordinator
3. The coordinator reads the pipeline config and creates sub-tasks per stage
4. Paperclip auto-wakes each assigned agent via heartbeat
5. Agents follow the UAW contract autonomously — Paperclip tracks status and budget
6. The coordinator pauses at approval gates for your review
7. You approve or intervene — the coordinator never makes judgment calls

## Agents

### Coordinator (per project)
Pipeline state machine. Routes tasks, creates sub-tasks, pauses at gates.
Never judges correctness.

### Execution Agents (role-agnostic)
Any agent can fill any role. Role assignment is per-project config.
- **Claude** — claude_local adapter
- **Codex** — codex_local adapter
- **AntiGravity** — process adapter
- **Gemini** — gemini_local adapter

## Pipeline Roles

Assigned per-project in `~/.paperclip/pipelines/{project}.yaml`:
- **spec_writer** — writes spec files from task descriptions
- **spec_validator** — reviews specs for ambiguity, consistency, feasibility
- **executor** — implements the work following the spec
- **reviewer** — validates the result against the spec and done condition
```

- [ ] **Step 2: Commit**

```bash
git add company-package/COMPANY.md
git commit -m "docs: update COMPANY.md with layered architecture and coordinator"
```

---

### Task 6: Update Company Package README

**Files:**
- Modify: `company-package/README.md`

- [ ] **Step 1: Replace README with coordinator-driven workflow**

Replace the contents of `company-package/README.md` with:

```markdown
# Ker's Lab — Paperclip Company Package

## Design Philosophy

### Layered Architecture

```
Layer 1: Paperclip        — coordinates, records, enforces workflow
Layer 2: UAW v3           — defines roles, steps, constraints (in each repo)
Layer 3: Execution agents — do the work, follow UAW
Layer 4: Validation       — tests, evaluators, rubrics (outside Paperclip)
Layer 5: Output sinks     — GitHub, CMS, datasets
```

**Critical rule:** Paperclip never decides correctness. The coordinator is a
state machine — it routes tasks, it does not judge them.

## Prerequisites

1. Paperclip server running (`paperclipai run`)
2. UAW v3 templates copied into each project repo (see `UAW-v3/uaw-templates/`)

## Quick Setup

### 1. Import the company

```bash
paperclipai company import ./company-package --new-company-name "Ker's Lab"
```

This creates the company with template agents.

### 2. For each project, create per-project agents

Agents are registered per-project. Example for TFLabs:

```bash
# Create project with workspace
# POST /api/companies/{companyId}/projects
# {
#   "name": "TFLabs",
#   "workspace": {
#     "sourceType": "local_path",
#     "cwd": "/path/to/tflabs",
#     "isPrimary": true
#   }
# }

# Create coordinator
# POST /api/companies/{companyId}/agents
# { "name": "Coordinator-TFLabs", "role": "pm", "adapterType": "claude_local",
#   "adapterConfig": { "cwd": "/path/to/tflabs", "model": "claude-sonnet-4-6" },
#   "budgetMonthlyCents": 1000 }

# Create execution agents
# { "name": "Claude-TFLabs", "role": "engineer", "adapterType": "claude_local",
#   "adapterConfig": { "cwd": "/path/to/tflabs", "model": "claude-sonnet-4-6" },
#   "budgetMonthlyCents": 5000 }

# { "name": "Codex-TFLabs", "role": "engineer", "adapterType": "codex_local",
#   "adapterConfig": { "cwd": "/path/to/tflabs" },
#   "budgetMonthlyCents": 3000 }

# Repeat for AntiGrav-TFLabs, Gemini-TFLabs as needed
```

### 3. Create pipeline config

```bash
cp company-package/pipelines/template.yaml ~/.paperclip/pipelines/tflabs.yaml
```

Edit `~/.paperclip/pipelines/tflabs.yaml` — replace agent name placeholders
with the names you registered (e.g., `Claude-TFLabs`, `Codex-TFLabs`).

### 4. Copy UAW templates into the project repo

```bash
cp -r UAW-v3/uaw-templates/ /path/to/tflabs/
```

Edit `resume.md` with the project state.

### 5. Create your first task

Create a Paperclip issue:
- Title: "Implement feature X" (or reference a spec: "See specs/feature-x.md")
- Phase: production (or exploratory, structural, durable_knowledge)
- Assign to: Coordinator-TFLabs

The coordinator reads the pipeline config, creates sub-tasks for each stage,
assigns agents, and pauses at approval gates for your review.

## How the Pipeline Runs

```
You create task → assign to Coordinator-TFLabs → set phase

Coordinator reads ~/.paperclip/pipelines/tflabs.yaml
For production phase:

  [spec_writer] → Codex-TFLabs writes the spec
     ↓ approval gate — you review the spec
  [spec_validator] → Claude-TFLabs validates the spec
     ↓
  [executor] → Claude-TFLabs implements
     ↓
  [reviewer] → AntiGrav-TFLabs validates result
     ↓ approval gate — you review the result

  Parent task → in_review → you do final sign-off → done
```

For exploratory: coordinator assigns executor only, you review when done.
For structural: spec_writer → executor, you review when done.

## Role Map

Any agent can fill any role. The pipeline config decides:

| Role | What it does |
|------|-------------|
| spec_writer | Write specs from task descriptions |
| spec_validator | Review specs for quality and feasibility |
| executor | Implement the work |
| reviewer | Validate against done condition |

Change assignments anytime by editing `~/.paperclip/pipelines/{project}.yaml`.

## Onboarding a New Project

1. Copy UAW templates into the repo
2. Create the Paperclip project with workspace
3. Register per-project agents (coordinator + execution agents)
4. Create pipeline config at `~/.paperclip/pipelines/{project}.yaml`
5. Create first task and assign to coordinator
```

- [ ] **Step 2: Commit**

```bash
git add company-package/README.md
git commit -m "docs: update README with coordinator-driven workflow and layered architecture"
```

---

### Task 7: Verify Final Structure

**Files:** None — verification only

- [ ] **Step 1: Verify file structure**

```bash
find UAW-v3/uaw-templates company-package -type f ! -name '.DS_Store' ! -name '~*' | sort
```

Expected:
```
UAW-v3/uaw-templates/CLAUDE.md
UAW-v3/uaw-templates/README.md
UAW-v3/uaw-templates/decisions.md
UAW-v3/uaw-templates/resume.md
UAW-v3/uaw-templates/specs/spec-template.md
company-package/.paperclip.yaml
company-package/COMPANY.md
company-package/README.md
company-package/agents/antigravity/AGENTS.md
company-package/agents/claude/AGENTS.md
company-package/agents/codex/AGENTS.md
company-package/agents/coordinator/AGENTS.md
company-package/agents/gemini/AGENTS.md
company-package/pipelines/template.yaml
```

Note: `pipeline-config.yaml` is gone from UAW templates. `coordinator/AGENTS.md` and `pipelines/template.yaml` are new.

- [ ] **Step 2: Verify pipeline-config.yaml is gone from UAW templates**

```bash
ls UAW-v3/uaw-templates/pipeline-config.yaml 2>&1
```

Expected: `No such file or directory`

- [ ] **Step 3: Verify git log shows clean commit history**

```bash
git log --oneline -10
```

Verify 6 new commits from this plan on top of the previous work.
