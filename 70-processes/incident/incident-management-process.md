# Incident Management Process — CSDM v5 Aligned

**Scope**: Generic incident management process built on CSDM v5 relationships and OOTB ServiceNow capabilities.
**Date**: 4 April 2026
**Version**: 1.0 — 25 May 2026
**Sources**: CSDM 5 specification (Figure 16), CSDM Data Model Examples (May 2025), CSDM Workshop — Getting Started (Zurich, December 2025), How to configure incident management to align with CSDM leading practice v3 (2023)
**Supersedes**: How to configure incident management to align with CSDM leading practice v3 (ServiceNow, 2023) — extends v3 to CSDM v5 (BSO/TSO split, TMS layer, Service Instance terminology, Parent/Child escalation).

---

## Design Note: TSO Tracking on the Incident

OOTB ServiceNow does not provide a separate field for Technical Service Offering on the incident table. The `service_offering` field holds whichever offering the incident is recorded against — BSO or TSO. There is no native mechanism to hold both simultaneously on a single incident.

This creates a design choice when escalating from a BSO (business service level) to a TSO (technical level):

### Approach 1 — Custom field (e.g., `u_technical_service_offering`)

Add a custom field to the incident table to track the current TSO while preserving the BSO in `service_offering`.

| Advantage | Disadvantage |
|---|---|
| Single incident throughout — simple | Custom field — not OOTB |
| BSO preserved for business accountability | One SLA on one ticket — BSO and TSO share measurement |
| Familiar to operators | Custom code needed for escalation logic (Script Include) |
| | Cannot scale to multi-user TSO failures without additional mechanism |

This approach works but requires custom development. It is the reason Script Includes like escalation handlers exist — the platform doesn't natively support tracking two Service Offerings on one incident.

### Approach 2 — Parent/Child incidents (OOTB, CSDM v5 best practice)

When escalation from BSO to TSO is needed, create a new incident against the TSO. The TSO incident becomes the Parent (root cause), the BSO incident becomes the Child (symptom).

| Advantage | Disadvantage |
|---|---|
| Fully OOTB — no custom fields or code | Two incidents per escalation — more records |
| Separate SLA tracking: BSO SLA (customer experience) vs TSO SLA (technical resolution) | Requires operator discipline to create Parent rather than reassign |
| Scales to multi-user TSO failures (50 BSO children → 1 TSO Parent hub) | State synchronisation needed (OOTB Business Rule) |
| TSO Parent acts as Major Incident hub | |
| Aligns with ServiceNow leading practice guide (scenario 3, page 9) | |
| No Script Include needed for escalation | |

### Platform verification required for Approach 2

The Parent/Child model is referenced in ServiceNow's leading practice guide (scenario 3, page 9: *"Child incident can be raised for the Technical Service Offering"*) and aligns with the CSDM v5 Consumer/Provider separation. However, the following platform behaviours should be verified before committing to this approach:

| Question | What we assume | Needs confirmation |
|---|---|---|
| Does OOTB have an "Awaiting Parent" hold reason? | Yes — listed in OOTB hold reasons | Verify in instance |
| Does Parent resolution cascade state to Children? | Yes — via OOTB Business Rule | Verify if this is OOTB or requires configuration |
| How does an agent create the TSO Parent from a BSO incident? | UI Action or manual creation + link | Verify if OOTB provides a mechanism or if a UI Action is needed |
| Does `parent_incident` drive any OOTB state synchronisation? | Partial — some OOTB, some may need Business Rules | Verify scope of OOTB behaviour |

Until these are verified, Approach 2 should be treated as the **target direction** based on CSDM v5 best practice, not as a confirmed OOTB capability. The process described in this document assumes Approach 2 works as expected — if verification reveals gaps, those gaps should be addressed with minimal, targeted configuration rather than a full Script Include.

### This document follows Approach 2 as the target.

The Parent/Child model maintains the Consumer (BSO) / Provider (TSO) separation that CSDM v5 defines. Each incident has one `service_offering` — the offering it is recorded against. Business accountability and technical accountability are tracked on separate records with separate SLAs.

Organisations that choose Approach 1 should understand that it introduces custom development and a single-SLA limitation by design. It is a valid trade-off if separate BSO/TSO SLA measurement is not required.

---

## 1. Principles

1. **Incident Management is a consumer of CSDM data, not a definer of it.** The data model must be correct first — the incident process follows from it.
2. **Service Offering is the anchor.** Every incident is recorded against a single Service Offering. Routing, assignment, priority, and SLA derive from it.
3. **OOTB first.** Use platform-native relationship traversal, assignment group resolution, and escalation. Custom code only where platform capability genuinely does not exist.
4. **Relationships, not naming conventions.** Routing decisions are derived from `cmdb_rel_ci` relationships, not string matching or hardcoded filters.
5. **Separate consumer and provider accountability.** BSO represents the customer-facing service (consumer). TSO represents the technical delivery (provider). Each gets its own incident and its own SLA.
6. **One incident, one Service Offering.** An incident is recorded against either a BSO or a TSO — never both simultaneously. The Parent/Child relationship connects them.

---

## 2. CSDM v5 Relationship Foundation

The incident process depends on these relationships being correctly populated in `cmdb_rel_ci`:

| From (Parent) | Relationship | To (Child) | Purpose |
|---|---|---|---|
| Business Service | offers (reference) | BSO | Business Service publishes its offerings |
| BSO | Depends on :: Used by | Service Instance | BSO is delivered through a Service Instance |
| TSO | Contains :: Contained by | Service Instance | TSO contains the Service Instance it supports |
| TSO | Contains :: Contained by | Dynamic CI Group | TSO contains the CI group for CI-first path |
| TSO (L2) | Depends on :: Used by | TSO (L3) | Escalation chain between technical levels |
| TSO (L3) | Depends on :: Used by | TSO (L4) | Escalation chain continues |
| Technology Management Service | offers (reference) | TSO | TMS publishes its technical offerings |
| CI | associated with (`svc_ci_assoc`) | Service Instance | CI is part of a Service Instance |

**If these relationships are missing, the process breaks.** No custom code can sustainably compensate for missing data.

### Terminology vs v3 (2023)

CSDM v5 renames "Application Service" → **Service Instance** (`cmdb_ci_service_auto` class is unchanged — name change only). v5 also introduces the **Technology Management Service (TMS)** layer between Service Instance and TSO; v3 did not represent TMS. The canonical v5 picture is **Figure 16 — CSDM 5 Configuration Item relationships** (page 49) in the CSDM 5 white paper (see [10-csdm/source/csdm-5-white-paper.pdf](../../10-csdm/source/csdm-5-white-paper.pdf)).

---

## 3. Incident Form — CSDM Fields

Three CSDM fields on the incident form, with a defined population order:

| Field | Table Field | Role | Population |
|---|---|---|---|
| **Service Offering** | `service_offering` | Primary anchor — the offering impacted (BSO or TSO) | Agent selects (or AI predicts) |
| **Service** | `business_service` | Business Service or Technology Management Service parent | Auto-populated from Service Offering (read-only) |
| **Configuration Item** | `cmdb_ci` | The specific CI affected | Agent selects (optional for SaaS) |

### Population flow (Service Offering first)

1. Agent fills out **Service Offering**
2. **Service** auto-populated from SO parent (read-only)
3. Agent fills **CI** to fullest extent possible
4. **Assignment Group** auto-populated from `service_offering.support_group` on the resulting incident. CI support group is only consulted on Path 2/3 (CI-first or system-generated) where no Service Offering exists yet — see §4.

### OOTB configuration required

| Field | Change | Outcome |
|---|---|---|
| Service (`business_service`) | Client Script: auto-populate from SO parent | Agent doesn't need to fill it |
| Service (`business_service`) | UI Policy: make read-only | Forces SO as primary field |
| Service Offering (`service_offering`) | Dictionary Override: allow independent selection | SO not filtered by Service |
| Service Offering (`service_offering`) | Client Script: clear Service on change | Keeps SO and Service consistent |
| Configuration Item (`cmdb_ci`) | Reference Specification: filter to principal CI classes | Relevant CIs only |

**Note on `business_service`**: The field name predates CSDM v5. Under v5, `service_offering.parent` resolves to a **Business Service** when the offering is a BSO, or to a **Technology Management Service** when the offering is a TSO. Both are valid parents of `business_service` in CSDM v5. The v3 client script (`g_form.setValue('business_service', set_service_offering.parent)`) remains correct — no script change required, only an updated mental model.

---

## 4. Three Incident Creation Paths

### Path 1 — Service Offering first (user/agent perspective)

The primary path. End users and agents select the business service they're experiencing issues with.

```
User describes issue
  → Service Offering selected (BSO)
    → Service auto-populated (read-only)
      → Assignment Group from BSO support group
        → CI optionally populated
```

**CMDB traversal:** BSO → `Depends on :: Used by` → Service Instance → populates `cmdb_ci`

### Path 2 — Configuration Item first (IT staff perspective)

Technical staff know the affected component. The system derives the service context.

```
Agent selects CI
  → System checks Dynamic CI Group membership
    → If match: TSO derived from Dynamic CI Group relationship
      → New incident created against TSO (or agent selects TSO)
        → Assignment Group from TSO support group
    → BSO derived separately: CI → Service Instance (via svc_ci_assoc) → BSO (via cmdb_rel_ci)
      → BSO incident linked as Child if TSO incident exists
```

**CMDB traversal:** CI → `svc_ci_assoc` → Service Instance → BSO (via `Depends on :: Used by`)
**TSO traversal:** Dynamic CI Group → TSO (via `Contains :: Contained by`, TSO is parent)

### Path 3 — System-generated (monitoring/integration perspective)

Automated systems create incidents from alerts, events, or monitoring data.

```
Monitoring system detects issue
  → CI resolved from alert payload
    → TSO derived from CMDB relationships (same as Path 2)
      → Incident created against TSO
        → Priority derived from Service Offering business_criticality + event severity
          → Assignment Group from TSO support group
    → BSO derived and linked as Child if business impact confirmed
```

---

## 5. Escalation Model — Parent/Child

### How it works

When a BSO incident (customer-reported issue) requires technical investigation by a different service team:

1. **TSO incident created** — recorded against the appropriate TSO, assigned to the TSO support group. This becomes the **Parent** (root cause).
2. **BSO incident linked as Child** — the original BSO incident is linked via `parent_incident`. It goes **On Hold — Awaiting Parent**.
3. **TSO team resolves the Parent** — technical investigation and fix on the TSO incident.
4. **Resolution cascades** — when the Parent is resolved, the Child (BSO) state is updated. The BSO team verifies with the user and closes.

```
BSO Incident (Child — symptom)              TSO Incident (Parent — root cause)
├── service_offering = BSO                  ├── service_offering = TSO
├── assignment_group = BSO support          ├── assignment_group = TSO support
├── state = On Hold (Awaiting Parent)       ├── state = In Progress
├── BSO SLA running (E2E customer)          ├── TSO SLA running (technical resolution)
└── parent_incident = TSO incident          └── resolves → cascades to Child
```

### Multi-level technical escalation (L2 → L3 → L4)

If the TSO incident requires further escalation within the technical domain:

**CMDB traversal:** TSO (L2) → `Depends on :: Used by` → TSO (L3) → `Depends on :: Used by` → TSO (L4)

Two options:
- **Reassign the TSO incident** — change `service_offering` to the L3 TSO, update `assignment_group`. Simple, but loses L2 SLA measurement.
- **Create another Parent** — L3 TSO incident becomes Parent of the L2 TSO incident. Preserves SLA at each level. Use when vendor OLA tracking per level is required.

### Multi-user TSO failures

When a single technical failure affects multiple users/services:

1. **One TSO Parent incident** — the root cause, assigned to the TSO team
2. **Multiple BSO Child incidents** — each user's reported issue, linked to the Parent
3. TSO resolution cascades to all children simultaneously
4. Each BSO Child retains its own SLA measurement

This scales naturally — the TSO Parent acts as the hub for Major Incident management.

### De-escalation

- **TSO resolves without BSO impact** — TSO incident resolved, BSO Child updated automatically
- **TSO determines BSO team should handle** — TSO incident closed, BSO Child returned to In Progress with the BSO support group
- BSO's `service_offering` never changes — business accountability is preserved

---

## 6. Identifying the TSO from a BSO Incident

When a BSO incident needs technical escalation, the system must identify which TSO to create the Parent against.

**CMDB traversal:** Given the Service Instance on the BSO incident (`cmdb_ci`):
- Find TSOs where: TSO (parent) → `Contains :: Contained by` → Service Instance (child)
- Filter to TSOs classified as Operations Support (L2)

If single match → auto-populate the new TSO incident. If multiple → present options to agent for selection.

No name matching. No hardcoded filters. Pure relationship traversal.

---

## 7. Priority Determination

### Impact

Scope of affected users or services, assessed by the reporter:

| Value | Label |
|---|---|
| 1 | Most users in many countries |
| 2 | Most users in single country or some users in many countries |
| 3 | Me or some users |

### Urgency

Automatically derived from `business_criticality` on the Service Offering:

| `business_criticality` | Urgency |
|---|---|
| 1 — Most critical | High |
| 2 — Somewhat critical | High |
| 3 — Less critical | Medium |
| 4 — Not critical | Low |
| 5 — Insignificant | Low |

Urgency is read-only for most users. Only authorised governance groups may override.

### Priority

Calculated from the standard OOTB 3x3 Impact x Urgency matrix. No custom priority values, no custom calculation rules.

Priority cannot be changed directly — adjust Impact or Urgency to change Priority.

### Priority on Parent vs Child

- **BSO Child** — priority derived from BSO `business_criticality` (customer impact)
- **TSO Parent** — priority derived from TSO `business_criticality` or inherited from the highest-priority Child

### Priority on system-generated incidents

For Path 3 (monitoring/event-driven) incidents, Urgency is derived from the event's `severity` rather than from `business_criticality` — the monitoring system has already assessed technical severity. Impact is derived from the affected TSO's scope. Standard 3×3 matrix applies thereafter.

---

## 8. SLA Model

### BSO Incident (Child) SLAs

| Timer | Starts | Measures |
|---|---|---|
| **E2E SLA** | Incident created | Total customer experience — creation to closure |
| **Business SLA** | On Hold — Awaiting Caller | Time waiting for customer input |

### TSO Incident (Parent) SLAs

| Timer | Starts | Measures |
|---|---|---|
| **Resolution SLA** | Incident created | Technical resolution time |
| **Vendor OLA** | Vendor/contract present on TSO | Vendor-specific resolution commitment |

- BSO SLA measures what the customer experiences
- TSO SLA measures what the technical team delivers
- Both run independently on separate incidents
- SLAs inherit vendor and contract from the Service Offering on each incident
- Priority drives SLA duration tiers
- Pause/resume based on state transitions

---

## 9. Incident Lifecycle — OOTB States

| State | Description |
|---|---|
| **New** | Incident created, pending triage |
| **In Progress** | Under active investigation/resolution |
| **On Hold** | Paused — awaiting caller, change, vendor, or parent |
| **Resolved** | Fix applied, pending confirmation |
| **Closed Complete** | Confirmed resolved |
| **Closed Incomplete** | Closed without full resolution |

- No custom states
- On Hold reasons: Awaiting Caller (mandatory comment, auto-returns to In Progress on caller response), Awaiting Change (mandatory change request link), Awaiting Vendor, Awaiting Parent (BSO waiting for TSO resolution)
- Parent/Child state synchronisation: Parent state changes cascade to Children via Business Rule

---

## 10. Ownership and Assignment

| Stage | Incident | Owner | Derived from |
|---|---|---|---|
| BSO creation | BSO (Child) | BSO support group | `service_offering.support_group` |
| TSO escalation | TSO (Parent) | TSO support group | `service_offering.support_group` on TSO incident |
| Further technical escalation | TSO (Parent) | Next-level TSO support group | Relationship traversal (Depends on :: Used by) |
| De-escalation / resolution | BSO (Child) | Returns to BSO support group | Cascade from Parent resolution |
| CI-first creation | TSO directly | TSO support group from Dynamic CI Group | TSO derived from CI group membership |

- Assignment Group is **always** derived from the Service Offering's support group on that incident
- No manual reassignment outside the service model
- BSO incident remains the business accountability anchor — its `service_offering` never changes

---

## 11. CMDB Prerequisites

This process **cannot function** without the following CMDB data:

| Prerequisite | Table | Minimum coverage |
|---|---|---|
| Business Services defined | `cmdb_ci_service_business` | All operational business services |
| BSOs linked to Service Instances | `cmdb_rel_ci` (Depends on :: Used by) | All operational BSOs |
| TSOs linked to Service Instances | `cmdb_rel_ci` (Contains :: Contained by) | All operational TSOs |
| TSO escalation chains defined | `cmdb_rel_ci` (Depends on :: Used by, TSO→TSO) | All L2→L3→L4 chains |
| Dynamic CI Groups wired to TSOs | `cmdb_rel_ci` (Contains :: Contained by) | Major infrastructure areas |
| Support groups set on all offerings | `service_offering.support_group` | 100% of operational BSOs and TSOs |
| Business criticality set on BSOs | `service_offering.business_criticality` | All operational BSOs |
| CI-to-Service Instance associations | `svc_ci_assoc` | Principal CI classes |
| Principal CI classes for incident selection | Reference Specification on `cmdb_ci` | Service Instance, Server, Computer, Network Gear, Data Center, Database, PDU, UPS |

### Governance

- New Service Instances must have TSO relationships as part of onboarding
- Data Modeling Sessions (twice weekly) with service owners and architects to validate and maintain relationships
- CSDM Team with Standing members (Enterprise Architect, Service Owners, CMDB Managers) and Virtual members (Application SMEs, Portfolio Managers)

---

## 12. What this process does NOT cover

The following are organisation-specific and require separate design:

- Security incident classification and restricted visibility
- Data Privacy incident routing (location-based TSO selection)
- Major Incident Management (proposal/promotion governance)
- Swarming and collaboration model (Microsoft Teams integration)
- AI-assisted Service Offering prediction
- Integration-specific incident creation (Dynatrace, Chronicle, ADO, etc.)
- Reporting and KPI configuration
- SLA/OLA contract management
- Approach 1 implementation details (custom `u_technical_service_offering` field) — see Design Note at the top

These should be designed as extensions to this base process, not replacements for it.

---

## 13. Mapping v3 Scenarios to v5 Paths

For readers cross-walking from the 2023 v3 leading practice guide:

| v3 Scenario (2023) | v5 equivalent in this doc | Notes |
|---|---|---|
| Scenario 1 — End user device | §4 Path 1 (Service Offering first), BSO incident only | CI = end-user device; no TSO escalation typical |
| Scenario 2 — Cloud Native SaaS | §4 Path 1, BSO incident only | CI optional/empty; SO is the anchor as v3 states |
| Scenario 3 — Infra / Cloud Hosted App | §4 Path 1 escalating to §5 Parent/Child | v3's "Child incident can be raised for the TSO" is the seed of v5's Parent/Child pattern, now formalised |

---

*Based on: CSDM 5 specification, ServiceNow CSDM Data Model Examples (May 2025), CSDM Workshop — Getting Started (Zurich, December 2025), ServiceNow Incident Management CSDM Leading Practice Guide v3 (2023)*
