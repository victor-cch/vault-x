# Service Mapping — Bottom-Up (CI → BSO)

How a CI maps **upward** to the BSO it serves. This is the path used by:

- **CI-first incident creation** — agent selects a CI, the system derives the service context
- **Impact analysis** — given an outage on a host, what business services are affected
- **Discovery integration** — Dynatrace/SGO writes CIs; the chain walks upward to the offering

CSDM v5's relationship model **only walks cleanly bottom-up if the chain is populated**. Most enterprises have the bottom (infrastructure) and the top (BSO), with a missing middle. This MOC explains what fills the middle.

## The five-layer chain

```
INFRASTRUCTURE       ┌─────────────────────────────────────┐
   (discovered)      │  Server / DB / Network / Container  │
                     │  (cmdb_ci_* — discovered)           │
                     └─────────────────┬───────────────────┘
                                       │  associated with (svc_ci_assoc)
                                       │  or Depends on :: Used by
                                       ▼
DISCOVERY LANDING    ┌─────────────────────────────────────┐
                     │     Calculated App Service          │
                     │ (cmdb_ci_service_calculated)        │
                     │ SGO-owned, churns continuously      │
                     └─────────────────┬───────────────────┘
                                       │  (member of, via query)
                                       ▼
BRIDGING (curated)   ┌─────────────────────────────────────┐
                     │       Dynamic CI Group              │
                     │ (cmdb_ci_query_based_service)       │
                     │ Query-driven, auto-maintained       │
                     └─────────────────┬───────────────────┘
                                       │  Depends on :: Used by
                                       ▼
LOGICAL              ┌─────────────────────────────────────┐
                     │       Business Application          │
                     │ (cmdb_ci_business_app)              │
                     │ App-owner curated                   │
                     └─────────────────┬───────────────────┘
                                       │  Supports / Supported by
                                       │  (provided by, design-side)
                                       ▼
SERVICE              ┌─────────────────────────────────────┐
                     │       Business Service              │
                     │ (cmdb_ci_service_business)          │
                     │ Service-owner curated               │
                     └─────────────────┬───────────────────┘
                                       │  Offering of / Offered by
                                       │  (publishes)
                                       ▼
COMMERCIAL           ┌─────────────────────────────────────┐
                     │       Business Service Offering     │
                     │ (service_offering, BSO)             │
                     │ Service-architect curated           │
                     └─────────────────────────────────────┘
```

## Why direct calculated-service-to-BSO mapping fails

Three independent reasons:

### 1. Granularity mismatch

| Layer | Typical count (large enterprise) |
|---|---|
| BSOs | 30-80 |
| Business Applications | 200-500 |
| Calculated App Services | 5,000-50,000 |

You cannot manually create 50,000 `cmdb_rel_ci` records. Even if you could, they'd be wrong within a sprint as calculated services churn.

### 2. Churn mismatch

| Layer | Typical change frequency |
|---|---|
| BSOs | Single-digit changes per quarter |
| Business Applications | Tens of changes per quarter |
| Calculated Services | Hundreds of changes per **week** |

Direct manual links require manual maintenance at the calculated-service rate. Operationally untenable.

### 3. Ownership mismatch

| Layer | Owner |
|---|---|
| BSOs | Service architects / service owners |
| Business Applications | Application owners |
| Calculated Services | SGO sync (no human owner) |

Three different humans. A direct BSO ↔ calculated-service link forces the service architect to know about every microservice. Not how the organisation works.

## The Dynamic CI Group absorbs all three mismatches

| Gap | How DCG absorbs it |
|---|---|
| Granularity | One DCG per BA; the query selects all relevant calculated services. The 1:N collapse happens *inside* the query. |
| Churn | Query re-evaluates on schedule; membership auto-updates. No CMDB writes needed when a microservice changes. |
| Ownership | DCG is owned by the application owner (same as the BA above). Calculated services remain SGO-owned. Clean boundary. |

## The query

A typical Dynamic CI Group query for an application called "Salesforce Sales Cloud":

```
table: cmdb_ci_service_calculated
condition: tags CONTAINS 'cmdb_business_app=BA-SFDC-SALES'
```

Every calculated service tagged accordingly becomes a member of the DCG. The query runs on a schedule (hourly to daily). Membership is always current.

## The CCH-specific opportunity

CCH already maintains a `DTCSDM application name` tag on Dynatrace entities to drive **incident routing** via webhook. The tag exists *because* the CMDB-based path is broken (SGO sync misconfigured, no DCG bridge, no governance).

**The same tag can drive two outputs**, with no new operational labour:

```
Today (workaround):
   DTCSDM application name tag → webhook → incident routing
                                       ↘ CMDB ignored

Proposed (bridge):
   cmdb_business_app tag → webhook → incident routing (unchanged)
                        ↘ SGC syncs to CI ↘ DCG query → BA → BSO
```

Migration recommendation: **Option B — parallel run**. Add the new tag alongside the existing one, validate DCG membership, migrate the webhook last, retire the old tag.

## Implementation checklist (summarised from bridge guide)

In order, each gated on the previous:

1. **Tag governance** — define `cmdb_business_app=BA-<key>` format, auto-tag rules in Dynatrace
2. **SGC sync verification** — confirm tags reach `cmdb_ci_service_calculated.tags`
3. **DCG creation** — one per BA, query against `cmdb_ci_service_calculated` filtered by tag
4. **CSDM relationships** — DCG → BA → BS → BSO; audit chain walks
5. **Incident integration** — transform map uses the new chain; `business_criticality` and `support_group` read from BSO/TSO
6. **Validation queries** (audit cadence):
   - Calculated services without a tag
   - DCGs with empty membership >7 days
   - BAs without a DCG
   - "Dark BSOs" without a chain down to calculated services

## CCH sizing realism

For ~400 Business Applications:

| Phase | Effort |
|---|---|
| Platform engineering (DCG creation, transform map, validation) | 4-8 weeks one-time |
| Tag governance — auto-tag rules for 400 BAs | ~840 hours total (5 person-months concentrated, 10 elapsed months distributed) |
| CSDM relationships above DCG | 2-4 weeks (bulk-API-creatable) |
| Per-app adoption + validation | 8-12 weeks distributed |

**Total**: 1.5-2 person-years; 12-18 months elapsed if reasonably resourced. **Prerequisite**: BA catalogue in good shape — if not, budget 6-12 months for BA-catalogue cleanup as a separate programme.

## Risks worth surfacing upfront

| Risk | Mitigation |
|---|---|
| Dynatrace classic → Grail tag-model shift | Validate the tag model in Grail before committing; build queries against attributes that survive migration |
| Query performance at scale | Keep DCG queries indexable; exact-match on tag attribute, not regex on names; audit any DCG query >5s |
| Tag value drift | Registry of allowed tag values; monthly tag-value audit |
| Reconciliation collisions | Define IRE rules for SGC-sourced calculated services; audit duplicates pre-rollout |
| Stale DCG definitions | Flag DCGs with empty membership >7 days; BA decommission must include DCG retirement |
| Dark BSOs (no observable surface) | Audit BSOs whose chain returns zero members; accept but document for triage |

## What this gives you at incident time

Given a CPU saturation alert on a host:

```
HOST cchprdsap42 (cmdb_ci_linux_server)
   ↓ (associated with) ↓
Calculated Service "SAP-Finance-svc" (cmdb_ci_service_calculated)
   ↓ (member of DCG via tag query) ↓
DCG "SAP S/4HANA Finance — App Svc Group" (cmdb_ci_query_based_service)
   ↓ (Depends on / Used by) ↓
BA "SAP S/4HANA Finance" (cmdb_ci_business_app)
   ↓ (Supports / Supported by) ↓
BS "SAP Financial Services" (cmdb_ci_service_business)
   ↓ (Offering of / Offered by) ↓
BSO "SAP S/4HANA — EU Production" (service_offering)
   ↓ read business_criticality, support_group ↓
Incident created with:
   cmdb_ci = HOST
   service_offering = BSO
   support_group = SAP-Ops-EU
   priority = derived from business_criticality
```

The engineer sees the full chain. Routing is correct. Impact is visible. **None of this works without the DCG in the middle.**

## Related notes

- [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md) — the relationship reference this MOC depends on
- [classes/cmdb_ci_service_calculated.md](classes/cmdb_ci_service_calculated.md) — bottom of the chain
- [classes/cmdb_ci_query_based_service.md](classes/cmdb_ci_query_based_service.md) — the bridge
- [classes/cmdb_ci_business_app.md](classes/cmdb_ci_business_app.md) — middle layer
- [classes/cmdb_ci_service_business.md](classes/cmdb_ci_service_business.md) — service layer
- [classes/service_offering.md](classes/service_offering.md) — BSO
- [Calculated Service → BSO Bridge](../../projects/dt-sn-integration/references/calculated-service-to-bso-bridge.md) — the comprehensive bridge guide
