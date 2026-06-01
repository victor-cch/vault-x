---
status: Approved
intent: Normative
---

# Badge convention (vault-x)

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Normative](https://img.shields.io/badge/intent-Normative-EF4444)

Documents across this vault carry **shields.io badges** along two dimensions:

- **Status** → maturity of the document (how stable it is)
- **Intent** → purpose of the document (what role it plays)

This convention is shared with the prior `platform-z` repo, where it originated. Vault-x is the canonical home going forward; eventually `platform-z`'s README links forward to this page.

In a Dataview-driven vault the same status/intent values also live in **YAML frontmatter**, so notes can be queried by maturity (e.g. *"show me every Draft note in 10-csdm I haven't verified yet"*). The badges are the human-readable visual layer; the frontmatter is the queryable layer.

## Status (maturity)

| Status | Meaning | Badge |
|---|---|---|
| Draft | Early-stage; incomplete and not yet reviewed | ![Status: Draft](https://img.shields.io/badge/status-Draft-F59E0B) |
| In Progress | Actively being developed; subject to change | ![Status: In Progress](https://img.shields.io/badge/status-In%20Progress-3B82F6) |
| Approved | Reviewed and aligned; authoritative and ready for use | ![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) |

## Intent (purpose)

| Intent | Meaning | Badge |
|---|---|---|
| Normative | Defines target state; must be followed (source of truth) | ![Intent: Normative](https://img.shields.io/badge/intent-Normative-EF4444) |
| Procedural | Defines how to implement or execute | ![Intent: Procedural](https://img.shields.io/badge/intent-Procedural-EAB308) |
| Analytical | Investigation, comparison, or deep-dive analysis | ![Intent: Analytical](https://img.shields.io/badge/intent-Analytical-8B5CF6) |
| Conceptual | Explains models, architecture, design thinking | ![Intent: Conceptual](https://img.shields.io/badge/intent-Conceptual-8B5CF6) |
| Informational | Reference or supporting material; not normative | ![Intent: Informational](https://img.shields.io/badge/intent-Informational-64748B) |

## Colour semantics

| Colour | Hex | Meaning |
|---|---|---|
| Orange | `#F59E0B` | Draft — early-stage, unstable |
| Blue | `#3B82F6` | In Progress — active work |
| Green | `#10B981` | Approved — validated and agreed |
| Red | `#EF4444` | Normative — authoritative design |
| Yellow | `#EAB308` | Procedural — execution guidance |
| Violet | `#8B5CF6` | Analytical / Conceptual — investigation, comparison, modelling |
| Slate | `#64748B` | Informational — neutral reference |

## Application pattern

Each substantive document (i.e. not READMEs or indexes) carries:

1. A **YAML frontmatter block** at the very top of the file, with `status:` and `intent:` keys
2. The matching **two badges** directly under the H1 — Status first, then Intent

### Example

````markdown
---
status: Approved
intent: Normative
---

# `cmdb_ci_service_technical` — Technology Management Service (TMS)

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Normative](https://img.shields.io/badge/intent-Normative-EF4444)

…document body…
````

**Why both?** Badges render in Obsidian preview, GitHub, and any markdown viewer — instant visual signal. Frontmatter is invisible in render but queryable by Dataview — programmatic signal. Same values, two surfaces.

## Per-pillar guidance

| Pillar | Typical default |
|---|---|
| `10-csdm/` — canonical material | Status: `Approved` once verified against the CSDM 5 White Paper; `Draft` while being written. Intent: `Normative` (vendor canon) or `Conceptual` (synthesis MOCs). |
| `20-servicenow-cch/` — CCH current state | Intent: `Informational` (state snapshot) or `Analytical` (gaps, observations). |
| `30-dynatrace-ref/` | Same shape as 10-csdm. Intent: `Normative` (vendor reference). |
| `40-dynatrace-cch/` | Same shape as 20-servicenow-cch. Intent: `Informational` / `Analytical`. |
| `50-mappings/` | Intent: `Conceptual` (the web) for mapping notes; `Normative` for decisions (ADR-style). |
| `60-projects/` | Status varies by deliverable; Intent often `Procedural` (HLDs) or `Conceptual`. |
| `70-processes/` | Process designs: `Normative` once approved; `Conceptual` while being designed. |
| `90-meta/` — this folder | Conventions: `Approved` + `Normative`. |
| READMEs and indexes | **No badges** — index rows drift from stale state; badges live on the documents themselves. |

## Querying by status/intent (Dataview)

Example queries enabled by the frontmatter:

````markdown
```dataview
TABLE status, intent
FROM "10-csdm"
WHERE status = "Draft"
```
````

````markdown
```dataview
TABLE file.folder AS Pillar, intent
FROM ""
WHERE status = "Approved" AND intent = "Normative"
```
````

````markdown
```dataview
LIST
FROM "20-servicenow-cch"
WHERE intent = "Analytical" AND status != "Approved"
```
````

---

*Adopted from the badge convention originally defined in `platform-z` — refined here with YAML frontmatter for Dataview queryability.*
