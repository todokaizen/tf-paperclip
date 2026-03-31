# Paperclip + UAW v3 Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pipeline routing, role maps, phase classification, and kickoff prompt templating to Paperclip so it can orchestrate UAW v3 agent workflows across projects.

**Architecture:** New `pipelineConfig` jsonb field on projects stores phase rules and role assignments. New `phase` column on issues tracks task phase. A new `pipeline` service creates sub-tasks per pipeline stage, chains stages on completion, and builds kickoff prompts injected into the heartbeat context. UAW v3 templates are amended with three multi-agent clauses.

**Tech Stack:** TypeScript, Drizzle ORM (PostgreSQL), Zod validators, Vitest, Express routes

---

## File Structure

```
New files:
  packages/shared/src/validators/pipeline.ts          — Zod schemas for pipeline config and phase
  server/src/services/pipeline.ts                      — Pipeline routing, stage chaining, kickoff prompt builder
  server/src/__tests__/pipeline-service.test.ts         — Tests for pipeline service
  UAW-v3/amendments.md                                 — UAW v3 amendments for multi-agent support

Modified files:
  packages/shared/src/constants.ts                     — Add ISSUE_PHASES constant
  packages/db/src/schema/projects.ts                   — Add pipelineConfig jsonb column
  packages/db/src/schema/issues.ts                     — Add phase and pipelineRole columns
  packages/shared/src/validators/project.ts            — Add pipelineConfig to project validators
  packages/shared/src/validators/issue.ts              — Add phase and pipelineRole to issue validators
  server/src/services/issues.ts                        — Hook stage chaining into status updates
  server/src/services/heartbeat.ts                     — Inject kickoff prompt into context
```

---

### Task 1: UAW v3 Amendments

**Files:**
- Create: `UAW-v3/amendments.md`

- [ ] **Step 1: Create the amendments file**

```markdown
# UAW v3 Amendments for Multi-Agent Orchestration

Date: 2026-03-30
Status: accepted

These amendments extend the UAW v3 spec to support orchestrated multi-agent
pipelines where different agents handle different stages of a task (spec writing,
validation, execution, review).

---

## Amendment 1: Multi-Agent Session Handoff

**Add to Section 10 (Session Protocol):**

> When multiple agents work a task sequentially, each agent completes the full
> shutdown protocol before the next agent starts. The incoming agent reads
> `resume.md` written by the previous agent as its starting context.

---

## Amendment 2: Role Scoping

**Add to Section 12 (Operating Rules):**

> When an agent receives a scoped role assignment, it operates only within that
> role's boundaries. A spec_writer produces the spec and completes shutdown. An
> executor implements. A reviewer validates. No role exceeds its boundary.

---

## Amendment 3: Externally Assigned Phase

**Add to Section 4 (Phase Classification):**

> Phase is assigned by the task creator, not derived by the agent. The agent
> receives phase in the kickoff context and applies the corresponding
> verification depth.
```

- [ ] **Step 2: Commit**

```bash
git add UAW-v3/amendments.md
git commit -m "docs: add UAW v3 amendments for multi-agent orchestration"
```

---

### Task 2: Add Phase Constants and Pipeline Validators

**Files:**
- Modify: `packages/shared/src/constants.ts`
- Create: `packages/shared/src/validators/pipeline.ts`

- [ ] **Step 1: Write the failing test**

Create `packages/shared/src/__tests__/pipeline-validators.test.ts`:

```typescript
import { describe, expect, it } from "vitest";
import { pipelineConfigSchema, ISSUE_PHASES, PIPELINE_ROLES } from "../validators/pipeline.js";

describe("pipelineConfigSchema", () => {
  it("accepts a valid pipeline config", () => {
    const config = {
      phaseRules: {
        exploratory: ["executor"],
        structural: ["spec_writer", "executor"],
        production: ["spec_writer", "spec_validator", "executor", "reviewer"],
        durable_knowledge: ["spec_writer", "spec_validator", "executor", "reviewer"],
      },
      roleAssignments: {
        spec_writer: "agent-uuid-1",
        spec_validator: "agent-uuid-2",
        executor: "agent-uuid-2",
        reviewer: "agent-uuid-3",
      },
    };
    const result = pipelineConfigSchema.safeParse(config);
    expect(result.success).toBe(true);
  });

  it("accepts fan-out role assignments (array of agent IDs)", () => {
    const config = {
      phaseRules: {
        exploratory: ["executor"],
      },
      roleAssignments: {
        executor: "agent-uuid-1",
        spec_writer: ["agent-uuid-1", "agent-uuid-2", "agent-uuid-3"],
      },
    };
    const result = pipelineConfigSchema.safeParse(config);
    expect(result.success).toBe(true);
  });

  it("rejects empty phaseRules", () => {
    const config = {
      phaseRules: {},
      roleAssignments: { executor: "agent-uuid-1" },
    };
    const result = pipelineConfigSchema.safeParse(config);
    expect(result.success).toBe(false);
  });

  it("rejects invalid pipeline role names in phaseRules", () => {
    const config = {
      phaseRules: {
        exploratory: ["invalid_role"],
      },
      roleAssignments: {},
    };
    const result = pipelineConfigSchema.safeParse(config);
    expect(result.success).toBe(false);
  });
});

describe("ISSUE_PHASES", () => {
  it("contains the four UAW phases", () => {
    expect(ISSUE_PHASES).toEqual([
      "exploratory",
      "structural",
      "production",
      "durable_knowledge",
    ]);
  });
});

describe("PIPELINE_ROLES", () => {
  it("contains the four pipeline roles", () => {
    expect(PIPELINE_ROLES).toEqual([
      "spec_writer",
      "spec_validator",
      "executor",
      "reviewer",
    ]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/shared && npx vitest run src/__tests__/pipeline-validators.test.ts`
Expected: FAIL — modules not found

- [ ] **Step 3: Add ISSUE_PHASES and PIPELINE_ROLES to constants**

In `packages/shared/src/constants.ts`, add after the `ISSUE_PRIORITIES` block:

```typescript
export const ISSUE_PHASES = [
  "exploratory",
  "structural",
  "production",
  "durable_knowledge",
] as const;
export type IssuePhase = (typeof ISSUE_PHASES)[number];

export const PIPELINE_ROLES = [
  "spec_writer",
  "spec_validator",
  "executor",
  "reviewer",
] as const;
export type PipelineRole = (typeof PIPELINE_ROLES)[number];
```

- [ ] **Step 4: Create the pipeline validators**

Create `packages/shared/src/validators/pipeline.ts`:

```typescript
import { z } from "zod";
import { ISSUE_PHASES, PIPELINE_ROLES } from "../constants.js";

export { ISSUE_PHASES, PIPELINE_ROLES };

const pipelineRoleSchema = z.enum(PIPELINE_ROLES);

const phaseRulesSchema = z
  .record(z.enum(ISSUE_PHASES), z.array(pipelineRoleSchema).min(1))
  .refine((rules) => Object.keys(rules).length > 0, {
    message: "phaseRules must define at least one phase",
  });

const roleAssignmentValueSchema = z.union([
  z.string().uuid(),
  z.array(z.string().uuid()).min(1),
]);

const roleAssignmentsSchema = z.record(pipelineRoleSchema, roleAssignmentValueSchema);

export const pipelineConfigSchema = z.object({
  phaseRules: phaseRulesSchema,
  roleAssignments: roleAssignmentsSchema,
});

export type PipelineConfig = z.infer<typeof pipelineConfigSchema>;
```

- [ ] **Step 5: Export from shared package index**

In `packages/shared/src/index.ts` (or wherever validators are re-exported), add:

```typescript
export {
  pipelineConfigSchema,
  type PipelineConfig,
} from "./validators/pipeline.js";
```

Also export the new constants from `constants.ts` (they should already be exported if the file uses named exports).

- [ ] **Step 6: Run test to verify it passes**

Run: `cd packages/shared && npx vitest run src/__tests__/pipeline-validators.test.ts`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add packages/shared/src/constants.ts packages/shared/src/validators/pipeline.ts packages/shared/src/__tests__/pipeline-validators.test.ts packages/shared/src/index.ts
git commit -m "feat: add pipeline config validators and phase/role constants"
```

---

### Task 3: Database Migration — Add Phase to Issues and PipelineConfig to Projects

**Files:**
- Modify: `packages/db/src/schema/issues.ts`
- Modify: `packages/db/src/schema/projects.ts`

- [ ] **Step 1: Add `phase` and `pipelineRole` columns to the issues schema**

In `packages/db/src/schema/issues.ts`, add after the `priority` field (line 33):

```typescript
    phase: text("phase"),
    pipelineRole: text("pipeline_role"),
    pipelineParentId: uuid("pipeline_parent_id").references((): AnyPgColumn => issues.id),
```

Add an index in the table's index block:

```typescript
    pipelineParentIdx: index("issues_pipeline_parent_idx").on(table.companyId, table.pipelineParentId),
```

- [ ] **Step 2: Add `pipelineConfig` column to the projects schema**

In `packages/db/src/schema/projects.ts`, add after the `executionWorkspacePolicy` field (line 20):

```typescript
    pipelineConfig: jsonb("pipeline_config").$type<Record<string, unknown>>(),
```

- [ ] **Step 3: Generate the migration**

Run: `cd packages/db && npx drizzle-kit generate`

This will create a new migration SQL file in `packages/db/src/migrations/`. Verify it contains:

```sql
ALTER TABLE "issues" ADD COLUMN "phase" text;
ALTER TABLE "issues" ADD COLUMN "pipeline_role" text;
ALTER TABLE "issues" ADD COLUMN "pipeline_parent_id" uuid;
ALTER TABLE "projects" ADD COLUMN "pipeline_config" jsonb;
ALTER TABLE "issues" ADD CONSTRAINT "..." FOREIGN KEY ("pipeline_parent_id") REFERENCES "issues"("id");
CREATE INDEX "issues_pipeline_parent_idx" ON "issues" USING btree ("company_id","pipeline_parent_id");
```

- [ ] **Step 4: Run the migration**

Run: `cd packages/db && npx drizzle-kit migrate`

- [ ] **Step 5: Commit**

```bash
git add packages/db/src/schema/issues.ts packages/db/src/schema/projects.ts packages/db/src/migrations/
git commit -m "feat: add phase/pipelineRole to issues and pipelineConfig to projects"
```

---

### Task 4: Update Issue and Project Validators

**Files:**
- Modify: `packages/shared/src/validators/issue.ts`
- Modify: `packages/shared/src/validators/project.ts`

- [ ] **Step 1: Add phase and pipelineRole to issue validators**

In `packages/shared/src/validators/issue.ts`, add imports:

```typescript
import { ISSUE_PHASES, PIPELINE_ROLES } from "../constants.js";
```

In `createIssueSchema`, add after the `priority` field:

```typescript
  phase: z.enum(ISSUE_PHASES).optional().nullable(),
  pipelineRole: z.enum(PIPELINE_ROLES).optional().nullable(),
  pipelineParentId: z.string().uuid().optional().nullable(),
```

The `updateIssueSchema` already extends `createIssueSchema.partial()`, so it will inherit these fields.

- [ ] **Step 2: Add pipelineConfig to project validators**

In `packages/shared/src/validators/project.ts`, add import:

```typescript
import { pipelineConfigSchema } from "./pipeline.js";
```

In the `projectFields` object, add after `executionWorkspacePolicy`:

```typescript
  pipelineConfig: pipelineConfigSchema.optional().nullable(),
```

- [ ] **Step 3: Run the typecheck to verify**

Run: `cd packages/shared && npx tsc --noEmit`
Expected: PASS (no type errors)

- [ ] **Step 4: Commit**

```bash
git add packages/shared/src/validators/issue.ts packages/shared/src/validators/project.ts
git commit -m "feat: add phase and pipelineConfig to issue/project validators"
```

---

### Task 5: Pipeline Service — Stage Creation

**Files:**
- Create: `server/src/services/pipeline.ts`
- Create: `server/src/__tests__/pipeline-service.test.ts`

- [ ] **Step 1: Write the failing test for stage creation**

Create `server/src/__tests__/pipeline-service.test.ts`:

```typescript
import { describe, expect, it, beforeAll, afterAll, afterEach } from "vitest";
import { randomUUID } from "node:crypto";
import { getEmbeddedPostgresTestSupport } from "./helpers/embedded-postgres.js";
import { createDb } from "./helpers/embedded-postgres.js";
import { startEmbeddedPostgresTestDatabase } from "./helpers/embedded-postgres.js";
import { companies } from "@paperclipai/db/schema";
import { agents } from "@paperclipai/db/schema";
import { projects } from "@paperclipai/db/schema";
import { issues } from "@paperclipai/db/schema";
import { goals } from "@paperclipai/db/schema";
import { pipelineService } from "../services/pipeline.js";
import type { PipelineConfig } from "@paperclipai/shared/validators/pipeline";

const embeddedPostgresSupport = await getEmbeddedPostgresTestSupport();
const describeDb = embeddedPostgresSupport.supported ? describe : describe.skip;

describeDb("pipelineService", () => {
  let db: ReturnType<typeof createDb>;
  let svc: ReturnType<typeof pipelineService>;
  let tempDb: Awaited<ReturnType<typeof startEmbeddedPostgresTestDatabase>> | null = null;

  const companyId = randomUUID();
  const goalId = randomUUID();
  const projectId = randomUUID();
  const specWriterAgentId = randomUUID();
  const specValidatorAgentId = randomUUID();
  const executorAgentId = randomUUID();
  const reviewerAgentId = randomUUID();

  const pipelineConfig: PipelineConfig = {
    phaseRules: {
      exploratory: ["executor"],
      structural: ["spec_writer", "executor"],
      production: ["spec_writer", "spec_validator", "executor", "reviewer"],
    },
    roleAssignments: {
      spec_writer: specWriterAgentId,
      spec_validator: specValidatorAgentId,
      executor: executorAgentId,
      reviewer: reviewerAgentId,
    },
  };

  beforeAll(async () => {
    tempDb = await startEmbeddedPostgresTestDatabase("paperclip-pipeline-");
    db = createDb(tempDb.connectionString);
    svc = pipelineService(db);

    await db.insert(companies).values({
      id: companyId,
      name: "Test Co",
      issuePrefix: "TST",
      requireBoardApprovalForNewAgents: false,
    });
    await db.insert(goals).values({
      id: goalId,
      companyId,
      title: "Test Goal",
      level: "company",
      status: "active",
      ownerAgentId: executorAgentId,
    });
    await db.insert(projects).values({
      id: projectId,
      companyId,
      name: "Test Project",
      goalId,
      pipelineConfig: pipelineConfig as unknown as Record<string, unknown>,
    });
    for (const [id, name] of [
      [specWriterAgentId, "Codex"],
      [specValidatorAgentId, "Claude-Validator"],
      [executorAgentId, "Claude"],
      [reviewerAgentId, "AntiGrav"],
    ] as const) {
      await db.insert(agents).values({
        id,
        companyId,
        name,
        adapterType: "process",
      });
    }
  }, 20_000);

  afterEach(async () => {
    await db.delete(issues).where();
  });

  afterAll(async () => {
    await tempDb?.cleanup();
  });

  describe("createPipelineStages", () => {
    it("creates sub-tasks for a production-phase issue", async () => {
      const parentIssue = await db
        .insert(issues)
        .values({
          companyId,
          projectId,
          goalId,
          title: "Build feature X",
          phase: "production",
          issueNumber: 1,
          identifier: "TST-1",
        })
        .returning()
        .then((rows) => rows[0]!);

      const stages = await svc.createPipelineStages(parentIssue.id, pipelineConfig);

      expect(stages).toHaveLength(4);
      expect(stages[0]!.pipelineRole).toBe("spec_writer");
      expect(stages[0]!.assigneeAgentId).toBe(specWriterAgentId);
      expect(stages[1]!.pipelineRole).toBe("spec_validator");
      expect(stages[2]!.pipelineRole).toBe("executor");
      expect(stages[3]!.pipelineRole).toBe("reviewer");

      for (const stage of stages) {
        expect(stage.pipelineParentId).toBe(parentIssue.id);
        expect(stage.phase).toBe("production");
        expect(stage.projectId).toBe(projectId);
        expect(stage.companyId).toBe(companyId);
      }
    });

    it("creates only executor for exploratory phase", async () => {
      const parentIssue = await db
        .insert(issues)
        .values({
          companyId,
          projectId,
          goalId,
          title: "Explore idea Y",
          phase: "exploratory",
          issueNumber: 2,
          identifier: "TST-2",
        })
        .returning()
        .then((rows) => rows[0]!);

      const stages = await svc.createPipelineStages(parentIssue.id, pipelineConfig);

      expect(stages).toHaveLength(1);
      expect(stages[0]!.pipelineRole).toBe("executor");
      expect(stages[0]!.assigneeAgentId).toBe(executorAgentId);
    });

    it("creates fan-out sub-tasks when role maps to multiple agents", async () => {
      const fanOutConfig: PipelineConfig = {
        phaseRules: { structural: ["spec_writer", "executor"] },
        roleAssignments: {
          spec_writer: [specWriterAgentId, executorAgentId],
          executor: executorAgentId,
        },
      };

      const parentIssue = await db
        .insert(issues)
        .values({
          companyId,
          projectId,
          goalId,
          title: "Feature with competing specs",
          phase: "structural",
          issueNumber: 3,
          identifier: "TST-3",
        })
        .returning()
        .then((rows) => rows[0]!);

      const stages = await svc.createPipelineStages(parentIssue.id, fanOutConfig);

      // 2 spec_writer fan-out + 1 executor = 3 sub-tasks
      expect(stages).toHaveLength(3);
      const specWriters = stages.filter((s) => s.pipelineRole === "spec_writer");
      expect(specWriters).toHaveLength(2);
    });

    it("returns empty array when phase has no rules", async () => {
      const parentIssue = await db
        .insert(issues)
        .values({
          companyId,
          projectId,
          goalId,
          title: "No rules task",
          phase: "durable_knowledge",
          issueNumber: 4,
          identifier: "TST-4",
        })
        .returning()
        .then((rows) => rows[0]!);

      const stages = await svc.createPipelineStages(parentIssue.id, pipelineConfig);
      expect(stages).toHaveLength(0);
    });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/__tests__/pipeline-service.test.ts`
Expected: FAIL — module `../services/pipeline.js` not found

- [ ] **Step 3: Write the pipeline service — stage creation**

Create `server/src/services/pipeline.ts`:

```typescript
import { eq, and } from "drizzle-orm";
import { issues } from "@paperclipai/db/schema";
import type { PipelineConfig, PipelineRole } from "@paperclipai/shared/validators/pipeline";
import type { Db } from "../db.js";

export function pipelineService(db: Db) {
  return {
    /**
     * Create pipeline stage sub-tasks for a parent issue based on its phase
     * and the project's pipeline config.
     */
    createPipelineStages: async (
      parentIssueId: string,
      config: PipelineConfig,
    ) => {
      const parent = await db
        .select()
        .from(issues)
        .where(eq(issues.id, parentIssueId))
        .then((rows) => rows[0] ?? null);

      if (!parent || !parent.phase) return [];

      const phase = parent.phase as keyof PipelineConfig["phaseRules"];
      const roles = config.phaseRules[phase];
      if (!roles || roles.length === 0) return [];

      const stageInserts: (typeof issues.$inferInsert)[] = [];
      let stageNumber = 0;

      for (const role of roles) {
        const assignment = config.roleAssignments[role as PipelineRole];
        if (!assignment) continue;

        const agentIds = Array.isArray(assignment) ? assignment : [assignment];

        for (const agentId of agentIds) {
          stageNumber++;
          stageInserts.push({
            companyId: parent.companyId,
            projectId: parent.projectId,
            projectWorkspaceId: parent.projectWorkspaceId,
            goalId: parent.goalId,
            parentId: parent.parentId,
            pipelineParentId: parent.id,
            title: `[${role}] ${parent.title}`,
            description: parent.description,
            status: "backlog",
            priority: parent.priority,
            phase: parent.phase,
            pipelineRole: role,
            assigneeAgentId: agentId,
            issueNumber: (parent.issueNumber ?? 0) * 100 + stageNumber,
            identifier: `${parent.identifier}-S${stageNumber}`,
            originKind: "manual",
          });
        }
      }

      if (stageInserts.length === 0) return [];

      const created = await db
        .insert(issues)
        .values(stageInserts)
        .returning();

      return created;
    },

    /**
     * Get the next pending pipeline stage for a parent issue.
     * Returns null if all stages are complete or no stages exist.
     */
    getNextPendingStage: async (pipelineParentId: string, config: PipelineConfig) => {
      const parent = await db
        .select()
        .from(issues)
        .where(eq(issues.id, pipelineParentId))
        .then((rows) => rows[0] ?? null);

      if (!parent || !parent.phase) return null;

      const phase = parent.phase as keyof PipelineConfig["phaseRules"];
      const roles = config.phaseRules[phase];
      if (!roles) return null;

      const stages = await db
        .select()
        .from(issues)
        .where(eq(issues.pipelineParentId, pipelineParentId));

      // Walk roles in order; find the first role where not all sub-tasks are done
      for (const role of roles) {
        const roleStages = stages.filter((s) => s.pipelineRole === role);
        if (roleStages.length === 0) continue;

        const allDone = roleStages.every(
          (s) => s.status === "done" || s.status === "cancelled",
        );
        if (!allDone) {
          // Return the first backlog stage for this role
          const pending = roleStages.find((s) => s.status === "backlog");
          return pending ?? null;
        }
      }

      return null;
    },

    /**
     * Check if all pipeline stages for the current role group are complete.
     * If so, return the next role's stages that should be activated.
     * Returns null if there's nothing to advance.
     */
    advancePipeline: async (
      completedStageId: string,
      config: PipelineConfig,
    ): Promise<typeof issues.$inferSelect[] | null> => {
      const completedStage = await db
        .select()
        .from(issues)
        .where(eq(issues.id, completedStageId))
        .then((rows) => rows[0] ?? null);

      if (!completedStage?.pipelineParentId || !completedStage.pipelineRole) {
        return null;
      }

      const parent = await db
        .select()
        .from(issues)
        .where(eq(issues.id, completedStage.pipelineParentId))
        .then((rows) => rows[0] ?? null);

      if (!parent?.phase) return null;

      const phase = parent.phase as keyof PipelineConfig["phaseRules"];
      const roles = config.phaseRules[phase];
      if (!roles) return null;

      // Get all stages for this pipeline
      const allStages = await db
        .select()
        .from(issues)
        .where(eq(issues.pipelineParentId, completedStage.pipelineParentId));

      // Check if all stages for the completed role are done
      const completedRole = completedStage.pipelineRole;
      const sameRoleStages = allStages.filter((s) => s.pipelineRole === completedRole);
      const allRoleDone = sameRoleStages.every(
        (s) => s.status === "done" || s.status === "cancelled",
      );

      if (!allRoleDone) return null;

      // Find the next role in the pipeline
      const currentRoleIndex = roles.indexOf(completedRole as PipelineRole);
      if (currentRoleIndex === -1 || currentRoleIndex >= roles.length - 1) {
        // Last role — check if all stages are done, mark parent done
        const allDone = allStages.every(
          (s) => s.status === "done" || s.status === "cancelled",
        );
        if (allDone) {
          await db
            .update(issues)
            .set({ status: "in_review", updatedAt: new Date() })
            .where(eq(issues.id, completedStage.pipelineParentId));
        }
        return null;
      }

      const nextRole = roles[currentRoleIndex + 1]!;
      const nextStages = allStages.filter(
        (s) => s.pipelineRole === nextRole && s.status === "backlog",
      );

      // Move next stages to todo so they can be picked up
      if (nextStages.length > 0) {
        for (const stage of nextStages) {
          await db
            .update(issues)
            .set({ status: "todo", updatedAt: new Date() })
            .where(eq(issues.id, stage.id));
        }
      }

      return nextStages.length > 0 ? nextStages : null;
    },

    /**
     * Build the kickoff prompt that Paperclip injects into the heartbeat context.
     * This is the single integration point between Paperclip and UAW.
     */
    buildKickoffPrompt: (issue: {
      title: string;
      description: string | null;
      phase: string | null;
      pipelineRole: string | null;
    }, project: {
      name: string;
    }, workspace: {
      cwd: string | null;
    }): string => {
      const lines = [
        `Project: ${project.name}`,
        `Workspace: ${workspace.cwd ?? "unknown"}`,
        `Task: ${issue.title}`,
      ];
      if (issue.description) {
        lines.push(`Task Description: ${issue.description}`);
      }
      if (issue.phase) {
        lines.push(`Phase: ${issue.phase}`);
      }
      if (issue.pipelineRole) {
        lines.push(`Role: ${issue.pipelineRole}`);
      }
      return lines.join("\n");
    },
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npx vitest run src/__tests__/pipeline-service.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/src/services/pipeline.ts server/src/__tests__/pipeline-service.test.ts
git commit -m "feat: add pipeline service with stage creation, advancement, and kickoff builder"
```

---

### Task 6: Pipeline Advancement Tests

**Files:**
- Modify: `server/src/__tests__/pipeline-service.test.ts`

- [ ] **Step 1: Add tests for advancePipeline**

Append to the `describeDb("pipelineService")` block in the test file:

```typescript
  describe("advancePipeline", () => {
    it("advances to next role when all stages for current role are done", async () => {
      const parentIssue = await db
        .insert(issues)
        .values({
          companyId,
          projectId,
          goalId,
          title: "Pipeline test",
          phase: "structural",
          issueNumber: 10,
          identifier: "TST-10",
        })
        .returning()
        .then((rows) => rows[0]!);

      const stages = await svc.createPipelineStages(parentIssue.id, pipelineConfig);
      const specWriterStage = stages.find((s) => s.pipelineRole === "spec_writer")!;

      // Mark spec_writer as done
      await db
        .update(issues)
        .set({ status: "done" })
        .where(eq(issues.id, specWriterStage.id));

      const nextStages = await svc.advancePipeline(specWriterStage.id, pipelineConfig);

      expect(nextStages).not.toBeNull();
      expect(nextStages!).toHaveLength(1);
      expect(nextStages![0]!.pipelineRole).toBe("executor");
      expect(nextStages![0]!.status).toBe("todo");
    });

    it("does not advance when fan-out stages are still pending", async () => {
      const fanOutConfig: PipelineConfig = {
        phaseRules: { structural: ["spec_writer", "executor"] },
        roleAssignments: {
          spec_writer: [specWriterAgentId, executorAgentId],
          executor: executorAgentId,
        },
      };

      const parentIssue = await db
        .insert(issues)
        .values({
          companyId,
          projectId,
          goalId,
          title: "Fan-out pipeline test",
          phase: "structural",
          issueNumber: 11,
          identifier: "TST-11",
        })
        .returning()
        .then((rows) => rows[0]!);

      const stages = await svc.createPipelineStages(parentIssue.id, fanOutConfig);
      const specWriters = stages.filter((s) => s.pipelineRole === "spec_writer");

      // Only mark one spec_writer as done
      await db
        .update(issues)
        .set({ status: "done" })
        .where(eq(issues.id, specWriters[0]!.id));

      const nextStages = await svc.advancePipeline(specWriters[0]!.id, fanOutConfig);
      expect(nextStages).toBeNull();
    });

    it("moves parent to in_review when last stage completes", async () => {
      const parentIssue = await db
        .insert(issues)
        .values({
          companyId,
          projectId,
          goalId,
          title: "Final stage test",
          phase: "exploratory",
          issueNumber: 12,
          identifier: "TST-12",
        })
        .returning()
        .then((rows) => rows[0]!);

      const stages = await svc.createPipelineStages(parentIssue.id, pipelineConfig);
      const executorStage = stages.find((s) => s.pipelineRole === "executor")!;

      await db
        .update(issues)
        .set({ status: "done" })
        .where(eq(issues.id, executorStage.id));

      await svc.advancePipeline(executorStage.id, pipelineConfig);

      const updatedParent = await db
        .select()
        .from(issues)
        .where(eq(issues.id, parentIssue.id))
        .then((rows) => rows[0]!);

      expect(updatedParent.status).toBe("in_review");
    });
  });

  describe("buildKickoffPrompt", () => {
    it("builds the handoff prompt with all fields", () => {
      const prompt = svc.buildKickoffPrompt(
        {
          title: "Build auth system",
          description: "Add JWT-based authentication",
          phase: "production",
          pipelineRole: "executor",
        },
        { name: "TFLabs" },
        { cwd: "/home/user/tflabs" },
      );

      expect(prompt).toContain("Project: TFLabs");
      expect(prompt).toContain("Workspace: /home/user/tflabs");
      expect(prompt).toContain("Task: Build auth system");
      expect(prompt).toContain("Task Description: Add JWT-based authentication");
      expect(prompt).toContain("Phase: production");
      expect(prompt).toContain("Role: executor");
    });

    it("omits missing optional fields", () => {
      const prompt = svc.buildKickoffPrompt(
        { title: "Quick fix", description: null, phase: null, pipelineRole: null },
        { name: "OpenBrain" },
        { cwd: "/home/user/openbrain" },
      );

      expect(prompt).toContain("Task: Quick fix");
      expect(prompt).not.toContain("Phase:");
      expect(prompt).not.toContain("Role:");
      expect(prompt).not.toContain("Task Description:");
    });
  });
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd server && npx vitest run src/__tests__/pipeline-service.test.ts`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add server/src/__tests__/pipeline-service.test.ts
git commit -m "test: add pipeline advancement and kickoff prompt builder tests"
```

---

### Task 7: Hook Pipeline Advancement Into Issue Status Updates

**Files:**
- Modify: `server/src/services/issues.ts`

This is the integration point where Paperclip chains pipeline stages. When a pipeline stage issue transitions to `done`, we check if the pipeline should advance.

- [ ] **Step 1: Add pipeline service import to issues service**

At the top of `server/src/services/issues.ts`, add:

```typescript
import { pipelineService } from "./pipeline.js";
```

- [ ] **Step 2: Find the status update logic and add the pipeline hook**

In the `update()` method of the issues service, find where status is set to `"done"` (inside the `applyStatusSideEffects` call or the transaction block). After the status update completes and the transaction commits, add a post-commit hook.

Locate the section where the updated issue is returned (after the main update transaction). Add after it:

```typescript
    // Pipeline advancement: when a pipeline stage completes, advance the pipeline
    if (
      patch.status === "done" &&
      updated.pipelineParentId &&
      updated.pipelineRole
    ) {
      const pipeline = pipelineService(db);
      const parentIssue = await db
        .select()
        .from(issues)
        .where(eq(issues.id, updated.pipelineParentId))
        .then((rows) => rows[0] ?? null);

      if (parentIssue?.projectId) {
        const project = await db
          .select()
          .from(projects)
          .where(eq(projects.id, parentIssue.projectId))
          .then((rows) => rows[0] ?? null);

        if (project?.pipelineConfig) {
          const { pipelineConfigSchema } = await import("@paperclipai/shared/validators/pipeline");
          const parsed = pipelineConfigSchema.safeParse(project.pipelineConfig);
          if (parsed.success) {
            const advancedStages = await pipeline.advancePipeline(updated.id, parsed.data);
            // Stages moved to "todo" — assignment wakeup will be triggered
            // by the caller if assigneeAgentId is set on those stages.
          }
        }
      }
    }
```

Note: Import `projects` from the schema if not already imported.

- [ ] **Step 3: Run the existing issues service tests to verify no regressions**

Run: `cd server && npx vitest run src/__tests__/issues-service.test.ts`
Expected: PASS (all existing tests still pass)

- [ ] **Step 4: Commit**

```bash
git add server/src/services/issues.ts
git commit -m "feat: hook pipeline advancement into issue status transitions"
```

---

### Task 8: Inject Kickoff Prompt Into Heartbeat Context

**Files:**
- Modify: `server/src/services/heartbeat.ts`

- [ ] **Step 1: Add pipeline service import**

At the top of `server/src/services/heartbeat.ts`, add:

```typescript
import { pipelineService } from "./pipeline.js";
```

- [ ] **Step 2: Inject kickoff prompt into context**

In the `executeRun()` function, find the section where `context.paperclipWorkspace` is set (around line 2326). After the workspace context is built and before the adapter is invoked, add:

```typescript
    // Inject pipeline kickoff prompt if issue has phase/role metadata
    if (issueContext) {
      const issueRecord = await db
        .select({
          phase: issues.phase,
          pipelineRole: issues.pipelineRole,
          title: issues.title,
          description: issues.description,
        })
        .from(issues)
        .where(eq(issues.id, issueContext.id))
        .then((rows) => rows[0] ?? null);

      if (issueRecord?.phase || issueRecord?.pipelineRole) {
        const pipeline = pipelineService(db);
        const projectRecord = executionProjectId
          ? await db
              .select({ name: projects.name })
              .from(projects)
              .where(eq(projects.id, executionProjectId))
              .then((rows) => rows[0] ?? null)
          : null;

        context.paperclipKickoffPrompt = pipeline.buildKickoffPrompt(
          {
            title: issueRecord.title,
            description: issueRecord.description,
            phase: issueRecord.phase,
            pipelineRole: issueRecord.pipelineRole,
          },
          { name: projectRecord?.name ?? "Unknown" },
          { cwd: executionWorkspace.cwd },
        );
      }
    }
```

Note: Make sure `projects` is imported from the schema. Add the import if not present.

- [ ] **Step 3: Run the typecheck**

Run: `npx tsc --noEmit`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add server/src/services/heartbeat.ts
git commit -m "feat: inject pipeline kickoff prompt into heartbeat context"
```

---

### Task 9: Verify Full Build and Existing Tests

**Files:** None (verification only)

- [ ] **Step 1: Run the full typecheck across the monorepo**

Run: `pnpm typecheck` (or `pnpm -r exec tsc --noEmit`)
Expected: PASS — no type errors

- [ ] **Step 2: Run the full test suite**

Run: `pnpm test`
Expected: PASS — all existing tests pass, new pipeline tests pass

- [ ] **Step 3: Run the build**

Run: `pnpm build`
Expected: PASS — clean build

- [ ] **Step 4: Commit any fixups if needed, then tag completion**

If any issues were found and fixed:

```bash
git add -A
git commit -m "fix: resolve build/test issues from pipeline integration"
```
