# TFLabs — Paperclip Company Package

AI/LangGraph platform company.

## Import

```bash
paperclipai company import ./companies/tflabs --new-company-name "TFLabs"
```

## Agents

| Agent | Expertise |
|-------|-----------|
| coordinator | Pipeline state machine |
| python | Python, LangGraph, FastAPI, data pipelines |
| fe | Next.js, React, TypeScript, Tailwind |
| devops | Docker, CI/CD, GitHub Actions |
| research | Literature review, analysis, evaluation |

## Projects

| Project | Path | Stack |
|---------|------|-------|
| tflabs-poc | /Users/ker/_Projects/Active/MentorMesh/tflabs-poc | Python/LangGraph |
| tflabs-edu-fe | /Users/ker/_Projects/Active/MentorMesh/tflabs-edu-fe | Next.js |

## Post-Import

1. Rename agents: `python` → `python-tflabs`, `fe` → `fe-tflabs`, etc.
2. Create pipeline configs at `~/.paperclip/pipelines/tflabs-poc.yaml` and `~/.paperclip/pipelines/tflabs-edu-fe.yaml`
3. Copy UAW templates into each project repo
