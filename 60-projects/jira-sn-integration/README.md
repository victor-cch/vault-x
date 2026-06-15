# ServiceNow ITSM ↔ Jira Integration

![GitHub Repo](https://img.shields.io/badge/github-repository-red?logo=github)

**Status**: In Review — bidirectional integration between CCH ServiceNow (Incidents / RITMs) and the XTEL Jira instance via IntegrationHub + Jira Spoke.

This is, structurally, a **bidirectional e-bond** across an organizational boundary (CCH ↔ XTEL) — so the same race-condition discipline as the broader incident e-bond work applies (loop prevention, conflict resolution, ordering).

---

## What's here

| File | Contains |
|---|---|
| [hld-snow-jira-integration.md](hld-snow-jira-integration.md) | The HLD (v1.0, author Ahmed Badr) — faithful Markdown transcription of the source document; field/status/priority mappings, conflict-ownership model, auth, implementation steps |
| [hld-assessment.md](hld-assessment.md) | Independent assessment — blockers, must-fix-before-prod, cross-document reconciliation with the CCH IM HLD, open questions, recommendation |

---

## Read in this order

1. [hld-snow-jira-integration.md](hld-snow-jira-integration.md) — what is being built
2. [hld-assessment.md](hld-assessment.md) — what to fix before it ships

> **Self-containment**: references to material outside this folder (e.g. the CCH IM HLD) are given as descriptive path text, not links, so the folder stays packageable.

---

## Badge convention

Mirrors the repo-wide convention — **Status** (Draft `#F59E0B` · In Progress `#3B82F6` · Approved `#10B981`) then **Intent** (Normative `#EF4444` · Procedural `#EAB308` · Analytical/Conceptual `#8B5CF6` · Informational `#64748B`), applied under each document's H1.
