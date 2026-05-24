# `cmdb_ci_query_based_service` — Dynamic CI Group (Query-Based Service)

**Domain**: Service Delivery
**Extends**: `cmdb_ci_service_auto` (Service Instance)
**Status**: OOTB
**Service Classification**: Application Service OR Technical Service (use case-dependent)

## What it represents

A **dynamic grouping of CIs** based on the results of CMDB Group queries. Its membership is defined not by manual relationships but by a query that ServiceNow evaluates on a schedule and populates automatically.

This is the **bridging primitive** in the bottom-up CI-to-BSO chain — the layer that absorbs the granularity, churn, and ownership mismatch between fast-moving calculated services and slow-moving Business Applications.

> **Naming history**: Older documentation calls this a "Query-Based Service" (the table name still reflects that). Paris release relabeled it to **Dynamic CI Group** in the UI. CSDM-specific framing uses both names. The CMDB Group → Dynamic CI Group hierarchy: a Dynamic CI Group references one or more `cmdb_group` records, and the CIs returned by those CMDB Group queries become the DCG members.

## Service Classification — two use cases

Setting `service_classification` changes the semantics:

| Classification | Behaviour | Use case |
|---|---|---|
| **Application Service** | DCG acts like a query-based Application Service | The DCG IS the Service Instance ("MyAppServiceProd" without Service Mapping) |
| **Technical Service** | DCG acts like a grouping of CIs managed by TMS Offerings | DCG IS a managed group of infra (e.g. "Detroit web servers", "200 Linux patch group") |

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB |
| `service_classification` | choice | Application Service or Technical Service — drives the use case |
| `query` | reference / encoded | The CMDB Group query that resolves membership |
| `parent` | reference | When this is a child of a TSO: the parent TSO that contains it |

## Key relationships

| From | Relationship | To | Notes |
|---|---|---|---|
| Dynamic CI Group | uses | CMDB Group | The CMDB Group carries the actual query |
| **TSO** | **Contains :: Contained by** | Dynamic CI Group | TSO is parent — the CI-first incident path uses this |
| Dynamic CI Group | Uses related list | Infrastructure CIs | The CIs identified by the query |
| Business Application | Depends on / Used by (bridge pattern) | Dynamic CI Group | When DCG bridges from calculated services to a BA — see bridge guide |

## Constraints

- A Dynamic CI Group contains **CIs only**, not other groups.
- A CI may exist in multiple Dynamic CI Groups so long as **only one** of those DCGs is related to a TMS. If a CI is in multiple DCGs each related to a different TMS Offering, data copy from TSO (Managed By, Support, Change groups) will overwrite — ServiceNow's recommendation is one TSO per CI per DCG.

## CCH evidence (April 2026)

- **7** `TSO → Dynamic CI Group (Contains :: Contained by)` relationships in production. Very low — the CI-first incident path is largely untapped at CCH.
- This is **far below** what the OOTB CSDM v5 incident process requires for the CI-first path to work reliably.

## Use case examples (from CSDM 5 white paper)

1. **As a Query-Based Application Service** — "You don't have Service Mapping yet, but you know these 12 servers and 3 database instances are part of `MyAppServiceProd`. Eliminate the spreadsheet, use a DCG as the Application Service."
2. **As a Managed Group of Infrastructure** — "The web servers in Detroit are managed by the `DetroitRockCity` TSO. Use a DCG for `Detroit web servers`, link the TSO via `Contains`, all the infra ownership data cascades automatically."
3. **Patch Management** — "Time to patch our 200 Linux servers. Select the DCG in the Change, business rule auto-populates Affected CIs. Or break into Americas/EMEA/APAC DCGs all related to the same TMS."

## The bridging pattern (CCH-specific, in design)

For the CI-upward chain:

```
calculated services (cmdb_ci_service_calculated)
    ↓ member of (via DCG query, tag-driven)
Dynamic CI Group (cmdb_ci_query_based_service, classification = Application Service)
    ↓ Depends on / Used by
Business Application (cmdb_ci_business_app)
    ↓ Supports / Supported by
Business Service (cmdb_ci_service_business)
    ↓ Offering of / Offered by
Business Service Offering (service_offering, classification = Business Service)
```

**Sizing for CCH**: ~400 Business Applications → ~400 Dynamic CI Groups, one per BA. ~840 hours (~5 person-months concentrated, 10 elapsed months distributed) for the tag governance work alone.

## Notes / decisions

- The DCG **is the load-bearing element** of bottom-up CI-to-BSO mapping. Without it, the granularity/churn/ownership mismatch makes direct mapping structurally impossible.
- Query performance matters at scale — keep queries indexable (exact-match on tags, not regex on names). 200+ DCGs each running scheduled queries against 50k+ rows = real CPU load.
- DCG retirement is often forgotten when a BA is decommissioned — flag DCGs with empty membership for >7 days as part of audit cadence.

## Encountered in

- [Calculated Service → BSO Bridge](../../../projects/dt-sn-integration/references/calculated-service-to-bso-bridge.md) — the DCG as the bridging primitive (sections 4-7)
- [CSDM v5 Reference Model](../../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md) — TSO → DCG record count
- [Incident Management Process — CSDM v5](../../../blueprints/incident-management/incident-management-process-csdm-v5.md) — CI-first incident path uses DCG → TSO derivation
- [service-delivery](../service-delivery.md) — domain index
- [service-mapping-bottom-up](../service-mapping-bottom-up.md) — DCG in the bottom-up chain
