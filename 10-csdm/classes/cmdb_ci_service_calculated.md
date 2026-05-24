# `cmdb_ci_service_calculated` — Calculated Application Service

**Domain**: Service Delivery
**Extends**: `cmdb_ci_service_auto` (Service Instance)
**Status**: OOTB
**Service Classification**: Application Service

## What it represents

A **Service Instance populated by the Calculated method** — typically the landing class for Dynatrace / SGO discovery output. Both Dynatrace `APPLICATION` and `SERVICE` entity types land here; differentiation is by source provenance (`sys_object_source`) and tags, **not** by class.

This is the **bottom of the bridging chain** for CI-upward service mapping. The pattern is:

```
Calculated Service → Dynamic CI Group → Business Application → Business Service → BSO
```

## Why it exists as a separate sibling

CSDM 5 lists four population methods for Application Services, each mapped to a distinct child table:

| Method | Table |
|---|---|
| Top-Down Discovery (Service Mapping) | `cmdb_ci_service_discovered` |
| Manual | `cmdb_ci_service_discovered` |
| Tags | `cmdb_ci_service_by_tags` |
| **Calculated** | **`cmdb_ci_service_calculated`** |
| Dynamic CI Group (Query Based) | `cmdb_ci_query_based_service` |

Calculated services are **auto-populated by discovery** (typically Dynatrace via SGC). Manual maintenance is not the intended model — the membership is driven upstream.

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB; typically Dynatrace-derived name |
| `sys_object_source` | string | Source provenance — distinguishes APPLICATION from SERVICE for Dynatrace landings |
| `tags` | string | Critical for tag-driven bridging — e.g. `cmdb_business_app=BA-SFDC-SALES` |

## Key relationships

| From | Relationship | To | Notes |
|---|---|---|---|
| Calculated Service | Depends on | Calculated Service | APPLICATION → SERVICE chain (Smartscape) |
| Calculated Service | (member of, via DCG query) | Dynamic CI Group | Implicit — driven by the DCG query, not a `cmdb_rel_ci` row |
| Calculated Service | Contains :: Contained by | Process Group / App Server | From Dynatrace topology |
| HOST → PGI → SERVICE → APPLICATION | Runs on / Depends on | (the chain) | Materialised by the Application Relationships job (separate phase from entity sync) |

## CCH evidence (April 2026)

- **456** `Calculated App Service → Process Group (Contains :: Contained by)` relationships (Dynatrace discovery output).
- Calculated service population is in flight — the broader CCH bridge (calculated → DCG → BA → BS → BSO) is **not yet built** in production; CCH is at Run maturity without the Calculated bridge.
- CCHBC has an existing `DTCSDM application name` tag maintained on the Dynatrace side that could be repurposed as the bridge tag (per the calculated-service-to-bso-bridge guide).

## Notes / decisions

- **APPLICATION and SERVICE share this table**. Any query that wants only one source type must filter by `sys_object_source`, not by class.
- A typical large enterprise has ~5,000-50,000 calculated services — orders of magnitude more than Business Applications (~200-500) or BSOs (~30-80).
- **Churn**: calculated services change constantly (hundreds per week) — direct manual linking is structurally impossible. The Dynamic CI Group is the absorption layer.
- **Tag-driven bridging** is the recommended pattern for the calculated→BA mapping. See [cmdb_ci_query_based_service](cmdb_ci_query_based_service.md) and the bridge guide.

## Risk notes (Dynatrace classic → Grail)

Tags in Grail use a different attribute model than classic Dynatrace. The bridge query syntax (`tags CONTAINS '...'`) must be re-validated against the Grail surface before any production cutover that depends on tag-driven bridging.

## Encountered in

- [Calculated Service → BSO Bridge](../../../projects/dt-sn-integration/references/calculated-service-to-bso-bridge.md) — the comprehensive bridge guide
- [DT-SN Integration README](../../../projects/dt-sn-integration/README.md) — DT integration overview
- [DT-SN Integration Patterns](../../../projects/dt-sn-integration/references/dt-sn-integration-patterns.md) — application-stack patterns
- [service-delivery](../service-delivery.md) — domain index
- [service-mapping-bottom-up](../service-mapping-bottom-up.md) — the bottom of the bottom-up chain
