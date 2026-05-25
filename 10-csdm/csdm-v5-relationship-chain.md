---
status: Approved
intent: Normative
---

# CSDM v5 Relationship Chain — The Reference

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Normative](https://img.shields.io/badge/intent-Normative-EF4444)

The chain that everything else depends on. Get the relationship **types** and **directions** wrong and queries return zero results, incidents route to the wrong group, and BIA chains break silently.

This page is the canonical reference for the **chain that runs from BSO down to infrastructure CI**, with the parallel design-side chain through Business Application.

## The canonical chain — top to bottom

```
                      ┌─────────────────────────────────────────┐
SERVICE CONSUMPTION   │  Business Service  ─publishes→  BSO     │
                      │       (cmdb_ci_service_business)        │
                      └────────────────────┬────────────────────┘
                                           │  Depends on :: Used by
                                           │  (BSO is parent)
                                           ▼
                      ┌─────────────────────────────────────────┐
SERVICE DELIVERY      │            Service Instance             │
                      │            (cmdb_ci_service_auto)       │
                      └─────────────┬───────────────────────────┘
                                    ▲
                                    │  Contains :: Contained by
                                    │  (TSO is parent)
                      ┌─────────────┴───────────────────────────┐
SERVICE DELIVERY      │  Tech Mgmt Service  ─publishes→  TSO    │
                      │       (cmdb_ci_service_technical)       │
                      └─────────────────────────────────────────┘

  (CSDM 5 model is **flat siblings**: one TMS → many TSOs, each TSO
   stratified by location/environment/SLA/support group. TSO→TSO
   chaining is not part of canon — see "Non-canonical CCH patterns"
   below.)

  ── parallel design-side chain ───────────────────────────────────
                      ┌─────────────────────────────────────────┐
DESIGN & PLANNING     │           Business Application          │
                      │           (cmdb_ci_business_app)        │
                      └────────────────────┬────────────────────┘
                                           │  Uses :: Used by
                                           │  (BA is parent)
                                           ▼
                                  Service Instance

  ── infrastructure layer ────────────────────────────────────────
                                   Service Instance
                                           │  Depends on :: Used by
                                           ▼
                              Infrastructure CIs
                              (server, DB, network, container)
```

## Relationship type guidance

Two relationship types matter most. **Choose deliberately:**

| Type | When to use | What it implies |
|---|---|---|
| **`Depends on :: Used by`** | Availability is binary; outage propagates; SLA / impact must travel | Removing the provider **guarantees** failure of the dependent |
| **`Contains :: Contained by`** | Grouping / membership; the parent governs the child's metadata | The child is one of many the parent manages |
| **`Uses :: Used by`** | Capability consumption; shared services; partial failure scenarios | The user can survive degraded provider performance |
| **`Provided by`** | Capability ↔ service / application | Design-time, not run-time |

CSDM 4 used `Consumes / Consumed by` between Business Application and Service Instance. **CSDM 5 changed this to `Uses / Used by`** per the [White Paper](source/csdm-5-white-paper.pdf) (Figure 16, page 48). Note that ServiceNow's own [CSDM Data Model Examples](source/csdm-data-model-examples.pdf) deck (Asset 0003134, May 2025) still uses `Consumes` in every implementation diagram — known documentation drift within the same release. The White Paper is authoritative.

## The full relationship table (CSDM 5 spec)

From the [CSDM 5 White Paper](source/csdm-5-white-paper.pdf) (Lemm, Koeten — Figure 16 "CSDM 5 Configuration Item relationships", page 48), reconciled with [CSDM Data Model Examples](source/csdm-data-model-examples.pdf) (May 2025, Asset 0003134) where the two agree. Where they disagree, the **White Paper wins** (it is prescriptive; Examples is illustrative and contains CSDM 4 carryover — notably the BA→SI relationship verb, which Examples still labels `Consumes`).

| From (parent) | Relationship | To (child) |
|---|---|---|
| Business Capability | Provided by | Business Application |
| Business Capability | Provided by | Business Service |
| Business Application | Uses | Information Object |
| Business Application | uses reference | Business Application *(self-ref)* |
| Business Application | Contains | SDLC Component |
| Business Application | **Uses** | Service Instance (Application Service) |
| SDLC Component | Consumes | Service Instance |
| Service Instance | Depends on / sends Data to | Service Instance |
| Service Instance | Depends on | Service Instance |
| Application | Runs on | Infrastructure CIs |
| Technology Mgmt Service | uses reference attribute | Technology Mgmt Service Offering (TSO) |
| **TSO** | **Contains** | **Service Instance** |
| **TSO** | **Contains** | **Dynamic CI Group** *(also exposed in Service Builder UI as the "Application services I contain" reference field on `service_offering` — same semantic, two surface representations)* |
| Dynamic CI Group | Uses related list | Infrastructure CIs |
| Service Portfolio | uses reference attribute | Business Service |
| Business Service | uses reference attribute | Business Service Offering (BSO) |
| **BSO** | **Depends on** | **Service Instance** |

> The bolded rows are the **incident-routing chain**. Get these wrong and the incident management process fails.

## The two traps

### Trap 1: BSO → SI vs TSO → SI

Both end with Service Instance as the child. **Different relationship types:**

- BSO → SI: `Depends on :: Used by` (BSO is parent)
- TSO → SI: `Contains :: Contained by` (TSO is parent)

A query that filters on "child = Service Instance, relationship = Depends on" gets only the BSO side. CCHIncidentUtils originally queried the wrong direction (Service Instance → TSO instead of TSO → Service Instance) and returned zero results in prod. Name-matching was the workaround. **Validate every chain query against `cmdb_rel_ci` directly before trusting the spec.**

### Trap 2: Service Instance never parents Service Offering

CCH verification (April 2026) queried all 497 records where Service Instance is the parent. **Zero of those children were Service Offerings.** This confirms both:
- TSO → SI direction (`Contains :: Contained by`, TSO is parent — not SI → TSO)
- BSO → SI direction (`Depends on :: Used by`, BSO is parent — not SI → BSO)

If your data shows otherwise, the relationships were inverted at creation time.

## Relationship type differentiations (practical)

**Prefer `Uses :: Used by` when:**
- Modelling capability consumption
- Linking applications to services
- Showing shared services or platforms
- Uncertain or partial failure scenarios

**Use `Depends on :: Used by` when:**
- Availability is binary
- SLA / outage / incident impact must propagate
- Removing the provider guarantees failure

## CCH maturity (April 2026 verification)

| Layer | Relationship | Records | Status |
|---|---|---|---|
| BSO → SI | `Depends on :: Used by` | 870 | ✅ Run maturity |
| TSO → SI | `Contains :: Contained by` | 395 | ✅ Walk maturity, growing |
| TSO → TSO | `Depends on :: Used by` (L2→L3→L4) | 647 | ⚠️ **CCH-specific pattern, not in CSDM 5 canon** — see "Non-canonical CCH patterns" below; full detail to move to `20-cch/csdm-evidence/` in Phase 3 |
| TSO → DCG | `Contains :: Contained by` | 7 | ❌ CI-first path largely untapped |
| Calculated App Service → PG | `Contains :: Contained by` | 456 | ✅ Dynatrace discovery output |

## When the chain is broken

The most common chain failures and what they break:

| Missing | What breaks |
|---|---|
| BSO → SI | BSO incident path can't resolve dependent CI; default routing fails |
| TSO → SI | Incident escalation can't identify which TSO to escalate to |
| TSO → TSO (L2→L3→L4) *(CCH-specific, not CSDM 5 canon)* | Multi-level escalation can't progress; everything hits L2 forever |
| TSO → DCG | CI-first path doesn't work; agent-selected CIs orphan from any TSO |
| CI → SI (`svc_ci_assoc`) | CI selection on incident form doesn't auto-suggest BSO/TSO |
| BSO has no `support_group` | Default incident assignment goes to "Service Desk" fallback |
| BSO has no `business_criticality` | Urgency derivation fails; Priority is incorrect |

## Non-canonical CCH patterns

These appear in CCH's `cmdb_rel_ci` but are **not prescribed by CSDM 5**. They are pragmatic implementation choices, not framework deviations to be defended as if canonical. Full detail (record counts, dated observations, rationale) moves to `20-cch/csdm-evidence/` in Phase 3 of the migration.

### TSO → TSO chain via `Depends on :: Used by` (L2 → L3 → L4)

- **CCH evidence**: 647 records (April 2026 verification)
- **What CCH does**: chains TSOs to model multi-level technical-support escalation (L2 front-line → L3 backend → L4 vendor).
- **What CSDM 5 says**: nothing. The [White Paper](source/csdm-5-white-paper.pdf) Walk stage (page 54) describes TSOs as **siblings** under one TMS, stratified by location/environment/SLA/support group — not as a hierarchy. No TSO→TSO relationship appears in Figure 16 or in any of the implementation diagrams in the [Examples deck](source/csdm-data-model-examples.pdf) (SAP, EPIC, O365, Dynamics, Salesforce all show flat TSOs).
- **Canonical alternatives** for multi-level escalation:
  - Multiple **TMS** entities at different tiers (front-line TMS, backend TMS, vendor TMS), each with their own TSOs
  - **Underlying Service Instance dependencies** (`SI → Depends on → SI`) carrying the technical impact chain
  - Escalation logic in the **incident process**, not in the CMDB topology
- **Should CCH refactor?** Open question. The 647 records work today; refactoring is non-trivial. Worth flagging for the next CSDM maturity review rather than acting on reflex.

## Related notes

- [README](README.md)
- [service-consumption](service-consumption.md) — BSO domain
- [service-delivery](service-delivery.md) — SI/TSO domain
- [classes/cmdb_ci_service_auto.md](classes/cmdb_ci_service_auto.md) — Service Instance (the bridge)
- [classes/service_offering.md](classes/service_offering.md) — BSO and TSO container
- [incident-assignment-bso-tso](incident-assignment-bso-tso.md)
- [service-mapping-bottom-up](service-mapping-bottom-up.md)
- [business-impact-analysis](business-impact-analysis.md)
