# TodoFoco AI Governance Framework (Phase 1 - Simplified)

## Overview

This document defines a **minimal, operational governance framework** for orchestrating AI agents across multiple ventures under TodoFoco.

Guiding principle:

> **Only add complexity when it is needed**

This Phase 1 system is intentionally constrained to ensure:
- daily usability
- low cognitive overhead
- strong safety boundaries
- fast iteration

---

## Active System (Phase 1)

### Agents

- **todofoco-CEO**
  - Primary decision-maker
  - Oversees all ventures
  - Sole gate for human escalation

- **ventureLead (per venture)**
  - e.g. `tflabs-ventureLead`, `nhn-ventureLead`
  - Executes and manages work within a venture
  - Operates within TodoFoco constraints

---

## Core Framework

### 1. Decision Classification (3 Types Only)

#### Routine
- Reversible
- Low cost
- Single venture
- High confidence

#### Significant
- Affects direction within a venture
- Moderate cost/time
- Some uncertainty

#### Critical
- Irreversible OR
- Cross-venture OR
- External-facing OR
- Low confidence + high impact

---

### 2. Routing Rules

| Classification | Action |
|----------------|--------|
| Routine        | Log only |
| Significant    | Notify (non-blocking) |
| Critical       | Require human review (blocking) |

---

### 3. Self-Check Requirement (No Validator in Phase 1)

Each decision must include:

```json
{
  "classification": "...",
  "confidence": 0.0,
  "why_not_critical": "..."
}
```

Rule:
- If justification is weak or missing → treat as **Critical**

---

### 4. Decision Record (Logging)

Every decision must produce:

```json
{
  "decision": "...",
  "classification": "routine | significant | critical",
  "confidence": 0.0,
  "scope": "venture | portfolio",
  "timestamp": "...",
  "escalated": true/false
}
```

- 100% logging required
- No filtering

---

## Control Flow

```
todofoco-CEO
    ↓
classification + self-check
    ↓
routing:
    routine → log
    significant → notify
    critical → block + notify human
```

---

## Notification System

### Significant (Non-blocking)

```
[Decision - Significant]
TFLabs: Adjust eval pipeline priority
Confidence: 0.78
```

---

### Critical (Blocking)

```
[HUMAN REVIEW REQUIRED]
Portfolio-level decision
Reason: cross-venture / irreversible / low confidence
```

---

## Escalation Rules

Only Critical decisions trigger human involvement.

Triggers:
- irreversible actions
- cross-venture impact
- external exposure
- low confidence + high impact

---

## Design Constraints (Deliberate)

This phase intentionally excludes:

- validator agents
- opsLead / taskOrchestrator layers
- complex ACL systems
- multi-agent debate
- advanced memory systems

These are added **only when failure justifies them**

---

## When to Add Complexity (Phase 2 Triggers)

Add components only when these failures occur:

| Failure | Add |
|--------|-----|
| Misclassification / silent errors | Validator agent |
| Task coordination breakdown | opsLead |
| High task concurrency chaos | taskOrchestrator |
| Cross-venture interference | stricter ACLs |

---

## Operating Principle

At all times:

> **Complexity must be earned by failure, not anticipated by design**

---

## Summary

Phase 1 provides:

- Minimal agent set
- 3-type decision model
- deterministic routing
- full logging
- human safety gate

It is designed to:
- work immediately
- scale gradually
- remain understandable

---

**End of Document**
