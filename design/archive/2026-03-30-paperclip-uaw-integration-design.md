# Design: Paperclip + UAW v3 Integration

Date: 2026-03-30 (revised 2026-03-31)
Status: archived
Version: 1.0
Supersedes: none

## Objective

Set up Paperclip as the orchestration layer for managing AI agent workflows across multiple projects, using UAW v3 (Unambiguous Agentic Workflow) as the in-repo contract that agents follow. Paperclip is replaceable — removing it changes only who kicks off a job, not how the job runs.

---

## Design Philosophy

### Layered Architecture

The system has five layers. Each layer has one job. Layers do not reach into each other's responsibilities.

```
Layer 1: Paperclip (orchestration)
  Task routing, scheduling, approvals, audit logs.
  The coordinator agent lives here.

Layer 2: UAW (workflow manifest, in each repo)
  Roles, allowed actions, required steps, constraints, escalation paths.
  Agents read this on startup and follow it autonomously.

Layer 3: Execution agents
  Claude, Codex, AntiGravity, Gemini, others.
  They do the work. They follow UAW. They write state back to the repo.

Layer 4: Validation (outside Paperclip)
  Tests, evaluators, rubrics, policy checks.
  Correctness is decided here — never in Paperclip.

Layer 5: Output sinks
  GitHub (code), CMS (NHN), datasets (TFLabs), Open Brain.
```

### Critical Design Rule

**Paperclip never decides correctness.**

Paperclip coordinates, records, and enforces workflow. It does not evaluate quality, judge completeness, or determine whether work is good enough. Correctness comes from validation systems, evaluation pipelines, and policy rules — all outside Paperclip.

This means:
- The coordinator is a **state machine**, not a decision maker
- The coordinator does not skip stages, retry on its own, or work around failures
- If something goes wrong, the coordinator reports it and waits for the human
- Approval gates are where the human exercises judgment

### Separation of Concerns

**Paperclip owns the _who_, _when_, and _how much_:**
- When a workflow starts
- Which agent runs it
- Budget and time
- Approvals
- Job audit trail

**UAW owns the _what_ and _how_:**
- What files to read
- What order of authority to use
- What status transitions mean
- What proof is required
- What shutdown must write

They touch at exactly one point: Paperclip launches an agent on a task in a workspace, and the agent picks up UAW from there.

---

## Architecture

### Company Structure

Each business entity is a **separate Paperclip company** — fully isolated agents, budgets, and projects. A master template defines all agent types; it's imported once per company, activating only the agents that company needs.

```
Company: TFLabs
  ├── Project: TFLabs-poc     → workspace: /path/to/tflabs-poc
  ├── Project: TFLabs-FE      → workspace: /path/to/tflabs-fe
  └── Project: TFLabs-Evals   → workspace: /path/to/tflabs-evals

Company: TFEdu
  ├── Project: TFChem          → workspace: /path/to/tfchem
  ├── Project: TFBio           → workspace: /path/to/tfbio
  ├── Project: Galileo-Circle  → workspace: /path/to/galileo-circle
  └── Project: Galileo-Curie   → workspace: /path/to/galileo-curie

Company: NHN
Company: TFTrading
Company: TFOpenBrain
```

UAW v3 files live in each repo and are self-sufficient:
```
project-root/
  CLAUDE.md        ← UAW operating contract
  resume.md        ← current state (read first on every session)
  decisions.md     ← append-only architectural decisions
  specs/           ← spec files for non-exploratory work
  archive/         ← dated resume.md copies from prior sessions
```

### Agent Model

Agents are **stack-specialized** (defined by capability, not AI tool) and **role-agnostic** (any agent can fill any pipeline role). Role assignment is per-project orchestration config.

Agents are named **stack-first with company suffix**: `python-tflabs`, `fe-tflabs`, `coordinator-tfedu`.

A master template defines all agent types. Each company imports it and activates the relevant agents:

| Agent | Expertise | Paperclip Role |
|-------|-----------|----------------|
| coordinator | Pipeline state machine | pm |
| python | Python, LangGraph, FastAPI, data pipelines | engineer |
| fe | Next.js, React, TypeScript, Tailwind | engineer |
| devops | Docker, CI/CD, GitHub Actions, infra | devops |
| content | Technical writing, docs, educational content | general |
| research | Literature review, analysis, evaluation | researcher |
| crypto | Cryptocurrency markets, trading, blockchain | engineer |

All default to `claude_local` adapter. Operator changes adapter per company as needed. Agents can be renamed or new specialized variants created (e.g., `python-tflabs-langchain`).

### Coordinator Agent

The coordinator is a **Layer 1 state machine**. One per project. It reads the pipeline config, creates sub-tasks, assigns agents, and pauses at approval gates. It runs in parallel with coordinators from other projects.

**What the coordinator does:**
1. Receives a task (title, description, phase, project)
2. Reads `~/.paperclip/pipelines/{project}.yaml` for phase rules and role assignments
3. For each stage in the pipeline:
   - Creates a sub-task in Paperclip, assigns the designated agent
   - Paperclip auto-wakes the agent via heartbeat
   - Waits for the sub-task to complete
   - If an approval gate follows this stage, creates an approval request and pauses
   - When the operator approves, continues to the next stage
4. When all stages complete, moves the parent task to in_review for final sign-off

**What the coordinator does NOT do:**
- Judge output quality (Layer 4)
- Decide whether to skip stages (human decision)
- Evaluate specs or code (Layer 3/4)
- Retry or work around failures (reports and waits)
- Make correctness decisions of any kind

### Pipeline Config

Pipeline configuration lives in `~/.paperclip/pipelines/` — Paperclip-managed, outside of project repos. This is orchestration config (Layer 1), not workflow contract (Layer 2).

```yaml
# ~/.paperclip/pipelines/tflabs.yaml

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

role_assignments:
  spec_writer: "Codex-TFLabs"
  spec_validator: "Claude-TFLabs"
  executor: "Claude-TFLabs"
  reviewer: "AntiGrav-TFLabs"

approval_gates:
  - after: spec_writer
  - after: reviewer
```

Any agent can fill any role. Swap assignments at any time without touching UAW or the repo.

When a role maps to a list of agents, the coordinator creates parallel sub-tasks (fan-out). The operator compares outputs on the board and picks the best.

---

## Task Pipeline

### How a Task Flows

```
You create a task → assign to Coordinator-{Project} → set phase

Coordinator reads ~/.paperclip/pipelines/{project}.yaml
Coordinator creates sub-tasks per phase_rules[phase]:

  Stage: spec_writer
    └── Sub-task assigned to python-tflabs
        Paperclip auto-wakes python-tflabs
        Agent lands in workspace, reads CLAUDE.md, writes spec
        Agent completes → coordinator sees completion
        Approval gate → coordinator requests approval, pauses
        You review spec → approve

  Stage: executor
    └── Sub-task assigned to python-tflabs
        Paperclip auto-wakes python-tflabs
        Agent lands in workspace, reads CLAUDE.md + spec, implements
        Agent completes → coordinator sees completion

  Stage: reviewer
    └── Sub-task assigned to devops-tflabs
        Paperclip auto-wakes devops-tflabs
        Agent validates against done condition, produces proof
        Agent completes → coordinator sees completion
        Approval gate → coordinator requests approval, pauses
        You review result → approve

Coordinator moves parent task to in_review
You do final sign-off → done
```

### Status Mapping

| UAW v3 Status | Paperclip Status | Notes |
|---|---|---|
| IDEA | `backlog` | You create the issue |
| SPEC | `backlog` | Spec-writing sub-task assigned to spec_writer |
| TODO | `todo` | After you approve the spec |
| IN PROGRESS | `in_progress` | Agent checks out the issue |
| BLOCKED | `blocked` | Agent records reason in resume.md + issue comment |
| REVIEW | `in_review` | Agent finishes with proof |
| DONE | `done` | After you review and approve |

### Phase Classification

Phase is assigned by you when creating the task. It determines pipeline depth. The coordinator uses it to select the stage sequence. The agent receives it in the kickoff and applies UAW's corresponding verification rules.

| Phase | Spec Required | Pipeline |
|---|---|---|
| Exploratory | No | executor only |
| Structural | Short spec | spec_writer → executor |
| Production | Full spec | spec_writer → spec_validator → executor → reviewer |
| Durable Knowledge | Full spec | spec_writer → spec_validator → executor → reviewer |

---

## The Kickoff Handoff

When the coordinator creates a sub-task and Paperclip wakes the assigned agent, the agent lands in the project workspace. The agent receives:
- The task title and description (from Paperclip)
- The workspace path (from the project workspace config)

The coordinator includes the role in the sub-task title (e.g., `[spec_writer] Implement auth system`) so the agent knows its scope per UAW Amendment 2.

The agent does NOT receive pipeline config, budget info, or other agents' work. It finds everything it needs in the repo via the UAW session protocol:
1. Read `CLAUDE.md` (the UAW contract)
2. Read `resume.md` (project state)
3. Read active spec (if referenced in resume)
4. Begin work per its role

---

## UAW v3 Amendments

Three amendments to support multi-agent orchestration:

### Amendment 1: Multi-Agent Session Handoff

Add to Section 10 (Session Protocol):

> When multiple agents work a task sequentially, each agent completes the full shutdown protocol before the next agent starts. The incoming agent reads `resume.md` written by the previous agent as its starting context.

### Amendment 2: Role Scoping

Add to Section 12 (Operating Rules):

> When an agent receives a scoped role assignment, it operates only within that role's boundaries. A spec_writer produces the spec and completes shutdown. An executor implements. A reviewer validates. No role exceeds its boundary.

### Amendment 3: Externally Assigned Phase

Add to Section 4 (Phase Classification):

> Phase is assigned by the task creator, not derived by the agent. The agent receives phase in the kickoff context and applies the corresponding verification depth.

---

## Project Onboarding Flow

Repeatable steps for bringing a new project into the setup:

**Step 1: Prepare the repo.** Copy UAW v3 templates into the project repo (`CLAUDE.md`, `resume.md`, `decisions.md`, `specs/`, `archive/`). Fill in the project state section of `resume.md`.

**Step 2: Create the Paperclip project.** Project name, workspace pointing to repo path, linked to a company goal.

**Step 3: Import agents.** Import the master template (`paperclipai company import ./master-template --new-company-name "CompanyName"`). Rename agents with company suffix (e.g., `python-tflabs`). Deactivate agents this company doesn't need.

**Step 4: Create pipeline config.** Write `~/.paperclip/pipelines/{project}.yaml` with phase rules, role assignments, and approval gates.

**Step 5: Create your first task.** Create a Paperclip issue with title, description, and phase. Assign to the project coordinator. The coordinator takes it from there.

---

## Key Design Decisions

1. **Layered architecture** — five layers, each with one job, no cross-layer responsibility leakage
2. **Paperclip never decides correctness** — it coordinates, records, enforces workflow; validation is external
3. **Coordinator is a state machine** — routes tasks, does not judge; reports failures, does not fix them
4. **Per-project coordinators** — run in parallel across projects, no shared state
5. **Stack-specialized, role-agnostic agents** — agents defined by capability (python, fe, devops), any can fill any pipeline role
6. **Separate companies per business entity** — TFLabs, TFEdu, NHN, TFTrading, TFOpenBrain — fully isolated
7. **Master template** — one template defines all agent types, imported per company
8. **Stack-first naming** — `python-tflabs`, `fe-tfedu`, `coordinator-nhn`
7. **Pipeline config outside repos** — lives at `~/.paperclip/pipelines/`, orchestration concern not workflow concern
8. **Paperclip is replaceable** — removing it changes only who kicks off jobs
9. **UAW in the repo is self-sufficient** — agents follow it autonomously regardless of orchestrator
10. **Fan-out supported** — multiple agents on same role creates parallel sub-tasks, operator picks best
11. **No Paperclip core code changes** — everything is config, company packages, and agent instructions

## Scope

### Included
- Paperclip company package (company, agents, coordinator, adapter configs)
- Pipeline config format and location (`~/.paperclip/pipelines/`)
- UAW v3 amendments for multi-agent support
- UAW v3 templates (ready to copy into repos)
- Project onboarding flow
- Coordinator agent instructions

### Excluded
- Paperclip core code changes — no DB migrations, no new services
- Execution workspace isolation (parallel agents on same project) — future enhancement
- Automatic fan-in notification — operator checks the board
- AntiGravity adapter implementation — depends on how AntiGravity runs
- Validation layer implementation (tests, evaluators, rubrics) — separate concern
- Output sink configuration — per-project, per-tool
