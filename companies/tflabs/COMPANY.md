---
name: "TFLabs"
schema: "agentcompanies/v1"
slug: "tflabs"
---

AI/LangGraph platform company. Python backend, Next.js frontend, agent orchestration.

## Design Philosophy

### Layered Architecture

1. **Paperclip (orchestration)** — task routing, scheduling, approvals, audit logs
2. **UAW (workflow manifest)** — roles, allowed actions, required steps, constraints
3. **Execution agents** — do the work, follow UAW in each repo
4. **Validation (outside Paperclip)** — tests, evaluators, rubrics, policy checks
5. **Output sinks** — GitHub

### Critical Rule

Paperclip never decides correctness. It coordinates, records, and enforces
workflow. Correctness comes from validation systems and evaluation pipelines.
