# High Level Design Document — SNOW ITSM ↔ Jira Integration — **REWORKED DRAFT (for review)**

![Status: Working Draft](https://img.shields.io/badge/status-Working%20Draft-F59E0B)
![Intent: Rebalancing edit](https://img.shields.io/badge/intent-Rebalancing%20edit-8B5CF6)

> **What this file is**: a reworked copy of `hld-snow-jira-integration.md` carrying the proposed additions from the assessment + the 2026-06-06 rebalancing strategy. **The original HLD is untouched** — this is a separate review artifact.
>
> **How to read the markup:**
> - **🟩 PROPOSED ADDITION** — net-new clause not in the original (no original text exists).
> - **Reworded:** proposed wording is in **bold**, with the original immediately after in *(original: "…")*.
> - Everything not marked is the author's original text, reproduced for context.
> - Nothing here is committed or agreed — it's for your read tomorrow.

---

## Document Control

| Attribute | Detail |
|---|---|
| Document Name | High Level Design Document for SNOW ITSM – JIRA Integration |
| Author | Ahmed Badr |
| Status | In Review |
| Date | June 1, 2026 |

> 🟩 **PROPOSED ADDITION — Change Log row**
> | 1.1 (proposed) | June 2026 | Review | Added cost-attribution reporting, sync-eligibility scoping, ownership/liability alignment for execution fields, and inbound webhook authentication. No change to the core Spoke architecture. |

---

## Glossary

*(original terms retained: ITSM, RITM, IntegrationHub, Spoke, Webhook, Correlation ID)*

> 🟩 **PROPOSED ADDITIONS — Glossary terms**
> | Term | Definition |
> |---|---|
> | Sync-eligibility filter | The agreed predicate (Jira-side event scope + JQL) determining which Jira issues are permitted to cross the integration. The default is restrictive; expansion is a governed, cost-reviewed change. |
> | Transaction attribution | Reporting of IntegrationHub transaction consumption broken down by the originating system, so platform cost is visible per source. |
> | System of record (execution) | Jira — authoritative for engineering/execution data and responsible for supplying it. Distinct from ServiceNow as system of engagement for ITSM. |

---

## Introduction

*(original text retained in full.)*

> 🟩 **PROPOSED ADDITION — closing sentence**
> This integration is bi-directional across an organisational boundary (CCH ServiceNow ↔ XTEL Jira). Accordingly, data ownership, platform cost, and service-level accountability are defined explicitly per direction so that each party owns the consequences of the data it originates.

---

## Scope

### In scope
*(original bullets retained.)*

> 🟩 **PROPOSED ADDITION — sync-eligibility (Lever 4)**
> - **Synchronisation is limited to engineering-actionable records** meeting the agreed sync-eligibility filter (Jira project key, issue type, and JQL predicate). Records outside the filter (e.g. how-to/training items, automated bot/build chatter, data/batch exceptions handled within Jira) **do not cross the bond**.
> - **Scope expansion beyond this baseline is a governed change**, subject to Jira BU request and an associated transaction-cost review (see Non-Functional Requirements → Cost Attribution).

### Out of scope
*(original bullets retained, including: "ServiceNow SLAs will natively pause/resume based on standard State changes triggered by Jira, but no SLA metrics or timers are passed between systems.")*

> **Reworded — SLA clause (Lever 3: privilege ↔ liability):**
> **Because Jira controls State transitions and ServiceNow SLAs pause/resume on those Jira-triggered State changes, the Jira BU consequently owns accountability for SLA outcomes driven by those transitions. No SLA metrics or timers are passed between systems.**
> *(original: "ServiceNow SLAs will natively pause/resume based on standard State changes triggered by Jira, but no SLA metrics or timers are passed between systems.")*

---

## Current State

*(original text + transaction volume/load figures retained.)*

> 🟩 **PROPOSED ADDITION — sizing note**
> The "600–900 tickets/day / 40–60 transactions/hour" figure reflects **ticket arrival**, not **integration transactions**. A bi-directional sync emits several transactions per ticket lifecycle (create + Jira echo-back + each State transition each way + comments + attachments). True IntegrationHub transaction volume is materially higher (estimated 5–10× the ticket count) and is metered. Volume must be re-derived from a per-ticket lifecycle model and sized against peak, not average. See Non-Functional Requirements → Cost Attribution.

---

## Future State

### Data Ownership & Conflict Resolution

*(original text retained:)*
- **Jira "Wins" (Execution)**: Jira acts as the source of truth for all engineering and execution-related fields…
- **ServiceNow "Wins" (ITSM)**: ServiceNow acts as the source of truth for ITSM related attributes…
- **Latest Timestamp Wins**: for shared, bi-directionally updated free-text fields…

> **Reworded — Jira "Wins" (execution) → couple ownership to responsibility (Lever 2 + 3):**
> **Jira "Owns" (Execution)**: **Jira is the system of record for all engineering/execution fields (Status/State, Components, Environment, resolution details) and is therefore responsible for supplying and maintaining their values. Ownership carries the corresponding accountability for the work progress and the service-level outcomes those fields drive.**
> *(original: 'Jira "Wins" (Execution): Jira acts as the source of truth for all engineering and execution-related fields. In a conflict, Jira's data will overwrite ServiceNow for fields like Status/State, Components, Environment, and resolution details. Jira dictates the progress of the work.')*

> 🟩 **PROPOSED ADDITION — "Latest Timestamp Wins" caveat**
> Latest-timestamp resolution is applied with a defined clock-skew tolerance and origin tracking, to prevent a stale cross-system write silently overwriting a human edit. (`sys_updated_on` and Jira `updated` are independent clocks.)

### Key improvements
*(original bullets retained, including the sync-loop safeguard bullet.)*

> 🟩 **PROPOSED ADDITION — loop safeguard specified (not just asserted)**
> The sync-loop safeguard is implemented via an integration-origin marker (e.g. an "updated-by-integration-user" / last-sync-source flag): an inbound update applied by the integration is tagged so it does not re-fire the outbound trigger. This origin suppression also governs reopen/ping-pong cases.

---

## Solution Design

*(original text + key design principles retained: Config over customization, Mapping-driven logic, Idempotent updates, Trigger/Routing/Execution separation, Sync-loop safeguard.)*

> 🟩 **PROPOSED ADDITION — duplicate-create guard**
> On SNOW→Jira creation, `correlation_id` is written synchronously from the Jira create response, and the inbound flow matches on **both** `correlation_id` and External Issue ID (`customfield_10061`), to close the race where Jira's "issue created" webhook returns before SNOW has stored the key.

### Work Type Mapping
*(original table retained.)*

> **Reworded — "Guidance and Training" routing:**
> **Guidance and Training (10009) → routed to a Request / how-to channel (not the Incident table).**
> *(original: "Guidance and Training | 10009 | Incident | incident")*
> 🟩 *Rationale: logging training/how-to as Incident inflates incident volume and MTTR and conflicts with the CSDM-aligned IM model. Such items are candidates for exclusion under the sync-eligibility filter.*

### Static Status Mapping Values / Dynamic Status Mapping
*(original tables retained.)*

> 🟩 **PROPOSED ADDITION — transition computation**
> Jira transitions are computed against the issue's **current** Jira status (a Jira issue accepts only transitions valid from its present state), not solely the SNOW old→new pair. Invalid-transition and missing-mapping cases raise a handled integration error rather than failing silently. Missing pairs in the current map (e.g. On Hold→Closed, WIP→Open) to be completed.

### Jira Field Values
*(original table retained — Division, Components, Environment, Hypercare marked Mandatory = Yes with SNOW Field Name = N/A.)*

> **Reworded — mandatory-field sourcing (Lever 2):**
> **Division, Components, Environment, and Hypercare are Jira-owned execution attributes with no ServiceNow ITSM equivalent. As system of record for execution, Jira is responsible for populating these values. SNOW→Jira creation for work types requiring them is therefore a Jira-side responsibility (Jira-originated), not a ServiceNow data-entry obligation.**
> *(original: these fields listed as "Mandatory = Yes", "SNOW Field Name = N/A", with Functional Requirements stating outbound flows abort if missing — which, unreworded, aborts every SNOW→Jira create.)*

### Priority Mapping
*(original tables retained.)*

> 🟩 **PROPOSED ADDITION — priority authority**
> ServiceNow `priority` is OOTB-derived from Impact × Urgency. To avoid desync (and to align with the CCH IM HLD, which forbids direct priority edits), Jira does not overwrite SNOW `priority` directly; priority is treated as ServiceNow-owned. Unmapped Jira priority values (e.g. `10004`, blank) are reconciled rather than silently flattened to Normal.

### Service Account & Authentication
*(original text retained — SNOW→Jira API token, Credentials module, alias-bound, XTEL-owned rotation.)*

> 🟩 **PROPOSED ADDITION — inbound webhook authentication (security)**
> The original covers SNOW→Jira (outbound) authentication only. The **inbound** Jira→SNOW webhook hitting the Flow Designer trigger URL must be authenticated/verified — shared secret or request signature, plus IP allow-listing of Jira Cloud egress ranges. Without this, the trigger URL is an unauthenticated write path into Incident/RITM. Securing the receiving endpoint is ServiceNow's responsibility (the receiver of a webhook owns its verification).

---

## Requirements

### Functional Requirements
*(original bullets retained, including "Mandatory Field Validation: outbound flows validate required fields … Missing data aborts.")*

> **Reworded — mandatory field validation:**
> **Outbound flows validate ServiceNow-owned required fields before sending. Jira-owned execution fields (Division, Components, Environment, Hypercare) are supplied by Jira and are not a ServiceNow-side abort condition** (see Jira Field Values, reworded).
> *(original: "Mandatory Field Validation: outbound flows validate required fields (Priority, Division, Components, Environment, Hypercare) before sending. Missing data aborts.")*

> 🟩 **PROPOSED ADDITION — resolution on inbound close**
> Jira→SNOW closures supply (or default) a `resolution_code` / close notes so the inbound transition satisfies OOTB ServiceNow mandatory resolution validation.

> 🟩 **PROPOSED ADDITION — comment visibility**
> Comment sync explicitly maps comment types across the org boundary: ServiceNow `work_notes` (internal) vs `comments` (customer-facing), and Jira internal vs public comments. Internal/private content is not propagated across the boundary by default.

### Non-Functional Requirements
*(original bullets retained, including Volume & Throughput.)*

> 🟩 **PROPOSED ADDITION — Cost Attribution (Lever 1 — the keystone)**
> **IntegrationHub transaction consumption shall be reported monthly, attributed by originating system (Jira-originated vs ServiceNow-originated).** Reporting includes transaction count, trend against the sized baseline, and the cost/quota implication. This makes platform-cost ownership transparent per source and provides the trigger for any sync-eligibility scope review.

> 🟩 **PROPOSED ADDITION — Error handling / operability**
> Define retry with backoff, dead-letter handling, failure alerting, and a reconciliation routine, with named ownership. At 600–900/day even a 1% failure ≈ 180–200 stuck records/month. Retry logic distinguishes idempotent field updates (safe to re-apply) from transitions (not safe to re-fire).

> 🟩 **PROPOSED ADDITION — Volume & rate limits**
> Jira Cloud REST is rate-limited (HTTP 429). Throughput is sized against peak with backoff/retry designed accordingly; the "within standard API rate limits" claim is validated against the re-derived per-ticket transaction model, not the ticket count.

---

## Implementation

### ServiceNow Implementation Steps
*(original steps retained.)*

> 🟩 **PROPOSED ADDITION — steps**
> - Implement inbound webhook verification (shared secret/signature + IP allow-list) on the Flow Designer trigger.
> - Implement the integration-origin marker for loop suppression.
> - Implement monthly transaction-attribution reporting.

### Jira Implementation Steps
*(original steps retained.)*

> 🟩 **PROPOSED ADDITION — steps (upstream filtering — cheapest cost control)**
> - **Scope the Jira webhook at source**: restrict events to the agreed minimum (e.g. Issue Created / Issue Updated / Comment Created) and apply the agreed JQL sync-eligibility predicate. Filtering upstream prevents IntegrationHub transactions being consumed for records that ServiceNow would only discard (the meter runs on receipt regardless of downstream filtering).
> - Configure Jira to supply the Jira-owned mandatory execution fields on issues that will sync.

---

## Planning and Risk Management

*(original: NA — not populated.)*

> 🟩 **PROPOSED ADDITION — this section cannot remain empty for go-live**
> Add: rollback plan, test strategy beyond REST validation, KPIs, cutover detail, and an explicit register of **business-accepted risks** (vendor-driven SLA clock; transaction-cost exposure; any agreed scope of synced ticket composition). These are governance decisions to be signed by the budget owner, not resolved in engineering.

---

## Appendix

### Plugins
*(original retained: IntegrationHub, Jira Spoke.)*

---

## Reviewer's note (not part of the HLD body)

The reworked clauses change **no part of the core architecture** — the Spoke-based, correlation-keyed, conflict-aware design stands. They (1) close the correctness blockers, (2) secure the inbound leg, and (3) realign ownership, cost, and liability so each party owns the data it originates. Levers 1, 3, and 4 are written as **agreed NFRs/governance clauses** (not advice) so the monthly cost-attribution report is inevitable rather than optional. Every clause is fair and standard governance practice; the rebalancing is achieved by *measuring honestly*, not by disadvantaging either party.
