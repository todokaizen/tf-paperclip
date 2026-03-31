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
