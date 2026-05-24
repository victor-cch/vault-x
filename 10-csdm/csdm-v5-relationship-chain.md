# CSDM v5 Relationship Chain — The Reference

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
                      └──────────┬──────────────────────────────┘
                                 │  Depends on :: Used by
                                 │  (parent TSO → child TSO; L2→L3→L4)
                                 ▼
                              TSO (next level)

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

CSDM 4 used `Consumes / Consumed by` between Business Application and Service Instance. **CSDM 5 changed this to `Uses / Used by`**.

## The full relationship table (CSDM 5 spec)

From **CSDM Data Model Examples** (May 2025, Asset 0003134):

| From (parent) | Relationship | To (child) |
|---|---|---|
| Business Capability | Provided by | Business Application |
| Business Capability | Provided by | Business Service |
| Business Application | Uses | Information Object |
| Business Application | uses reference | Business Application *(self-ref)* |
| Business Application | Contains | SDLC Component |
| Business Application | Contains | Service Instance |
| SDLC Component | Consumes | Service Instance |
| Service Instance | Depends on / sends Data to | Service Instance |
| Service Instance | Depends on | Service Instance |
| Application | Runs on | Infrastructure CIs |
| Technology Mgmt Service | uses reference attribute | Technology Mgmt Service Offering (TSO) |
| **TSO** | **Contains** | **Service Instance** |
| **TSO** | **Contains** | **Dynamic CI Group** |
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
| TSO → TSO | `Depends on :: Used by` (L2→L3→L4) | 647 | ⚠️ Mixed quality — includes OT BS→SO and orphans |
| TSO → DCG | `Contains :: Contained by` | 7 | ❌ CI-first path largely untapped |
| Calculated App Service → PG | `Contains :: Contained by` | 456 | ✅ Dynatrace discovery output |

## When the chain is broken

The most common chain failures and what they break:

| Missing | What breaks |
|---|---|
| BSO → SI | BSO incident path can't resolve dependent CI; default routing fails |
| TSO → SI | Incident escalation can't identify which TSO to escalate to |
| TSO → TSO (L2→L3→L4) | Multi-level escalation can't progress; everything hits L2 forever |
| TSO → DCG | CI-first path doesn't work; agent-selected CIs orphan from any TSO |
| CI → SI (`svc_ci_assoc`) | CI selection on incident form doesn't auto-suggest BSO/TSO |
| BSO has no `support_group` | Default incident assignment goes to "Service Desk" fallback |
| BSO has no `business_criticality` | Urgency derivation fails; Priority is incorrect |

## Related notes

- [README](README.md)
- [service-consumption](service-consumption.md) — BSO domain
- [service-delivery](service-delivery.md) — SI/TSO domain
- [classes/cmdb_ci_service_auto.md](classes/cmdb_ci_service_auto.md) — Service Instance (the bridge)
- [classes/service_offering.md](classes/service_offering.md) — BSO and TSO container
- [incident-assignment-bso-tso](incident-assignment-bso-tso.md)
- [service-mapping-bottom-up](service-mapping-bottom-up.md)
- [business-impact-analysis](business-impact-analysis.md)
