# Claude Operating Contract — UAW-os

You are operating inside the Unambiguous Agentic Workflow (UAW-os).

Written files are authoritative. Conversation is secondary.
If conflict exists, written files win.

---

## Authority Order

1. Spec file — authority of intent and scope
2. decisions.md — authority of durable architectural decisions
3. resume.md — authority of current project and session state
4. Linear — authority of task status and issue backlog
5. Conversation — lowest authority

---

## Session Start — Do This First

Before any implementation:

1. Read `resume.md`
2. Read `decisions.md`
3. Read the active spec referenced in resume.md (if any)
4. Check Linear for new issues or priority changes
5. Report current project state and active task
6. Begin at the Next Action stated in resume.md

If resume.md has no Resume Point yet, ask what to work on.

---

## During Execution

- Operate only on the stated task
- Update `resume.md` incrementally as you work
- Record decisions in `decisions.md` immediately when architecture changes
- Update Linear task status at each transition
- Do not broaden task scope beyond what is written
- Do not silently refactor unrelated files
- Do not change dependencies without recording a decision

---

## Session End — Do This Before Stopping

1. Ensure Linear is updated with current task state
2. Copy current `resume.md` to `archive/resume-YYYY-MM-DD.md`
3. Write fresh `resume.md` with current project state and resume point
4. Update `decisions.md` if any decisions were made during this session

---

## Task Statuses (Linear)

IDEA → SPEC → TODO → IN PROGRESS → BLOCKED → REVIEW → DONE

- Do not begin execution before a task is IN PROGRESS
- Do not mark REVIEW without proof (test output, screenshot, CLI result, or review pass)
- Do not mark DONE without completing the session end steps above
- If blocked, record why in resume.md and Linear, then stop

---

## Spec Rule

Every task that is not exploratory must have a spec in `specs/` before execution begins.
Exploratory tasks may skip the SPEC status.

---

## Phase Classification

| Phase | Spec Required | Verification Depth |
|-------|--------------|-------------------|
| Exploratory | No | Plausible enough to continue |
| Structural | Short spec | Internally coherent |
| Production | Full spec | Must survive real use |
| Durable Knowledge | Full spec | Source traceability |

---

## File Structure

```
project-root/
  CLAUDE.md            ← this file
  resume.md            ← current state — read first on every session
  decisions.md         ← append-only decisions — read second
  specs/               ← spec files for non-exploratory work
  archive/             ← dated resume.md copies from prior sessions
```

---

## When Uncertain

Stop and ask. Specify:
- which file
- which boundary
- which expected output

Never guess hidden intent.
Prefer narrower scope, explicit uncertainty, and reversible progress.

---

## Multi-Agent Pipeline Rules

When operating as part of a multi-agent pipeline orchestrated by Paperclip or
another coordinator:

### Session Handoff
When multiple agents work a task sequentially, each agent completes the full
shutdown protocol before the next agent starts. The incoming agent reads
`resume.md` written by the previous agent as its starting context.

### Role Scoping
When you receive a scoped role assignment, operate only within that role's
boundaries. A spec_writer produces the spec and completes shutdown. An executor
implements. A reviewer validates. No role exceeds its boundary.

### Externally Assigned Phase
Phase is assigned by the task creator, not derived by you. You receive phase
in the kickoff context and apply the corresponding verification depth from
the Phase Classification table above.
