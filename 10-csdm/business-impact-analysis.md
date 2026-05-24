# Business Impact Analysis (BIA) — The Chain

How CSDM v5 turns an external **severity signal** (from monitoring, ITSM workflow, or user-reported impact) into an **incident priority** through deterministic, model-driven derivation.

The BIA chain is **not abstract** — it is three concrete matrices and one stored field (`business_criticality`) on the Service Offering.

## The chain at a glance

```
External Signal (Dynatrace problem, user-reported issue, monitoring event)
   │
   ├── Severity (raw signal characteristic)
   │     ↓ Matrix 1
   │     Impact (1 / 2 / 3 — scope of users/services affected)
   │
   └── CI → CSDM → Service Offering → business_criticality (1-5)
         ↓ Matrix 2
         Urgency (1 / 2 / 3 — how time-pressured)

Impact + Urgency → Matrix 3 (3×3 OOTB) → Priority (P1-P5)
```

Two parallel inputs (signal severity + business criticality from the model) feed two matrices producing Impact and Urgency, then combine in the standard ServiceNow Priority matrix.

## Matrix 1: Severity → Impact

Reporter's assessment of *scope*:

| Impact | Label |
|---|---|
| 1 | Most users in many countries |
| 2 | Most users in single country or some users in many countries |
| 3 | Me or some users |

For Dynatrace-driven incidents:

| Dynatrace Severity | Impact |
|---|---|
| AVAILABILITY | 1 |
| ERROR | 2 |
| RESOURCE | 2 |
| PERFORMANCE | 3 |

Impact is **always** set; the reporter (human or system) determines scope.

## Matrix 2: business_criticality → Urgency

Urgency derives from the Service Offering's `business_criticality` field — **stored on the BSO or TSO that the incident is recorded against**.

| `business_criticality` | Label | Urgency |
|---|---|---|
| 1 | Most critical | High |
| 2 | Somewhat critical | High |
| 3 | Less critical | Medium |
| 4 | Not critical | Low |
| 5 | Insignificant | Low |

> **Urgency is read-only for most users** — it's a property of the model, not an agent assessment. Only authorised governance groups may override.

The `business_criticality` on the BSO is set by the **service architect / service owner** as part of catalogue maintenance. It is the **authoritative business judgment** about the offering's importance.

## Matrix 3: Impact × Urgency → Priority

The standard OOTB **3×3 priority matrix** — unchanged from base ServiceNow:

| | Urgency=1 (High) | Urgency=2 (Medium) | Urgency=3 (Low) |
|---|---|---|---|
| **Impact=1 (High)** | P1 — Critical | P2 — High | P3 — Moderate |
| **Impact=2 (Medium)** | P2 — High | P3 — Moderate | P4 — Low |
| **Impact=3 (Low)** | P3 — Moderate | P4 — Low | P5 — Planning |

- No custom priority values
- No custom calculation rules
- Priority cannot be changed directly — adjust Impact or Urgency to change Priority

## Why the BSO is the BIA anchor

The chain reduces to one decision: **on which BSO is the incident recorded?**

- Right BSO → correct `business_criticality` → correct Urgency → correct Priority → correct SLA tier → correct support_group
- Wrong BSO → wrong everything

This is why [incident-assignment-bso-tso](incident-assignment-bso-tso.md) puts so much weight on getting BSO selection right. The BIA chain is downstream of correct categorisation.

## Priority on Parent vs Child incidents

Under the Parent/Child model (Approach 2):

- **BSO Child** — priority derived from BSO `business_criticality` (customer impact)
- **TSO Parent** — priority derived from TSO `business_criticality` OR inherited from the highest-priority Child

> The Parent's priority is **the worst of**: its own TSO criticality, or any Child's BSO-derived priority. This ensures Major Incident escalation tracks the highest-impact user.

## What can break the BIA chain

| Failure | Effect |
|---|---|
| `business_criticality` unset on BSO | Urgency derivation fails; Priority falls back to default (usually P3 or P4) |
| Incident recorded on wrong BSO | Wrong `business_criticality` → wrong Urgency → wrong Priority |
| BIA cascade not configured (Parent doesn't inherit Child priority) | TSO Parent stays at TSO's own criticality even when Children are P1 |
| `business_criticality` set to "Insignificant" by default on new BSOs | All new BSOs produce P4/P5 incidents until manually reviewed |
| Impact set wrong by reporter | Reporter responsibility; AI prediction can help; needs Service Desk training |
| Custom Impact/Urgency choice values | Breaks OOTB 3×3 matrix; needs custom matrix; lost OOTB upgrades |

## Vendor severity → ServiceNow priority mapping (Dynatrace example)

CCH's DT-SN integration uses this mapping at the webhook:

```
Dynatrace Problem
  └─ severity from {AVAILABILITY, ERROR, RESOURCE, PERFORMANCE}
  └─ entity → tag (cmdb_business_app=...) → DCG → BA → BSO
                                                          └─ business_criticality (1-5)
  → Impact (from severity)
  → Urgency (from business_criticality on BSO)
  → Priority (OOTB 3×3 matrix)
  → SLA tier (priority-driven)
  → support_group (BSO.support_group; TSO.support_group on escalation)
```

If the CI doesn't have a tag, or the DCG doesn't exist, or the DCG → BA edge is missing, or `business_criticality` is unset — the chain fails silently at the failure point. The Dynatrace problem still creates an incident, but its priority is wrong.

## Audit cadence

Recommended queries to run periodically:

1. **BSOs without `business_criticality` set**:
   `service_offering WHERE service_classification=Business Service AND business_criticality IS EMPTY`
2. **BSOs with `business_criticality = 5` (Insignificant)** — flag for review; almost certainly wrong unless explicitly justified
3. **TSOs without `business_criticality`** — same risk as BSOs for incidents recorded directly against TSOs
4. **Incidents created with Priority = NULL** in the last 30 days — usually indicates a missing field in the BIA chain
5. **Incidents with manually-overridden Urgency** — Urgency should be model-driven; manual overrides indicate model gaps

## Related notes

- [README](README.md)
- [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md) — the relationship reference
- [incident-assignment-bso-tso](incident-assignment-bso-tso.md) — how BSO/TSO is selected
- [service-mapping-bottom-up](service-mapping-bottom-up.md) — how a CI maps to a BSO (the chain BIA depends on)
- [classes/service_offering.md](classes/service_offering.md) — where `business_criticality` lives
- [DT-SN BIA Chain](../../projects/dt-sn-integration/diagrams/incident-integration/hld-dt-incident-integration-bia-chain.md) — the diagram source
- [DT-SN Incident Integration HLD](../../projects/dt-sn-integration/incident-integration/hld-sn-dt-incident-integration.md) — the full integration design including BIA
