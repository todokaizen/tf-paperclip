# WebSites — Paperclip Company Package

Website projects across all business entities.

## Import

```bash
pnpm paperclipai company import ./companies/websites --new-company-name "WebSites"
```

## Agents

| Agent | Expertise |
|-------|-----------|
| coordinator | Pipeline state machine |
| fe | Next.js, React, TypeScript, Tailwind |
| content | Technical writing, docs, educational content |

## Projects

| Project | Path |
|---------|------|
| todofoco | /Users/ker/_Projects/Active/MentorMesh/websites/TodoFoco |
| galileo-curie | /Users/ker/_Projects/Active/MentorMesh/websites/GalileoCurie |
| galileos-circle | /Users/ker/_Projects/Active/MentorMesh/websites/GalileosCircle |
| tfeval-ui | /Users/ker/_Projects/Active/MentorMesh/websites/TFEval-UI |
| todofoco-edu | /Users/ker/_Projects/Active/MentorMesh/websites/TodoFocoEdu |
| tflabs-web | /Users/ker/_Projects/Active/MentorMesh/websites/TFLabs |

## Post-Import

1. Rename agents: `fe` → `fe-websites`, `content` → `content-websites`, `coordinator` → `coordinator-websites`
2. Create pipeline configs at `~/.paperclip/pipelines/{project}.yaml` for each project
3. Copy UAW templates into each project repo
