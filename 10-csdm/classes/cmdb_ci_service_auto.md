# `cmdb_ci_service_auto` — Service Instance

**Domain**: Service Delivery
**Extends**: `cmdb_ci_service`
**Status**: OOTB
**Previous label (CSDM v4)**: Application Service

## What it represents

The **bridge class** of CSDM v5. The single most important table in the model — the only class allowed to connect **upward** to the business consumption domain (BSO) and **downward** to the technical / operational domain (TSO and infrastructure CIs).

CSDM v5 relabeled this from "Application Service" to "Service Instance" and gave it new siblings (Data, Connection, Network, Facility, Operational Process Service Instances). The **underlying table is unchanged** — any v4-era HLD that says "Application Service" maps directly to `cmdb_ci_service_auto` or to one of its child tables.

## Service Instance siblings (extensions of `cmdb_ci_service_auto`)

| Sibling | Table | Service Classification | Notes |
|---|---|---|---|
| Application Service — Discovered/Manual | `cmdb_ci_service_discovered` | Application Service | Service Mapping top-down or manual creation |
| Application Service — Tag-based | `cmdb_ci_service_by_tags` | Application Service | Tag-driven population |
| Application Service — Calculated | `cmdb_ci_service_calculated` | Application Service | Calculated method; **SGO/Dynatrace landing class** — see [cmdb_ci_service_calculated](cmdb_ci_service_calculated.md) |
| Application Service — Query-Based / Dynamic CI Group | `cmdb_ci_query_based_service` | Application Service OR Technical Service | The **bridging primitive** — see [cmdb_ci_query_based_service](cmdb_ci_query_based_service.md) |
| Data Service Instance | `cmdb_ci_data_service_instance` | Technical Service | New in v5; DB/storage/AI pipelines |
| Connection Service Instance | `cmdb_ci_connection_service_instance` | Technical Service | New in v5; VLAN/LAN/WLAN |
| Network Service Instance | `cmdb_ci_network_service_instance` | Technical Service | New in v5 |
| Facility Service Instance | `cmdb_ci_facility_service_instance` | Technical Service | New in v5; building services |
| Operational Process Service Instance | `cmdb_ci_operational_process_service_instance` | Technical Service | New in v5; manufacturing/utility |

> **No UI for Service Instances in v5**. The pre-existing Application Service Wizard remains the default for creating Application Services. The new siblings (Data, Connection, etc.) require **manual creation and maintenance** and are **not part of Event Impact Analysis**.

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB |
| `service_classification` | choice | "Application Service" or "Technical Service" depending on sibling |
| `operational_status` / `life_cycle_stage` / `life_cycle_stage_status` | choice | Filters eligibility for ITSM use |

## Key relationships

| From | Relationship | To | Direction & meaning |
|---|---|---|---|
| **BSO** | **Depends on :: Used by** | Service Instance | BSO is **parent** — the consumer view depends on this SI |
| **TSO** | **Contains :: Contained by** | Service Instance | TSO is **parent** — the provider groups this SI under its offering |
| Business Application | Uses :: Used by | Service Instance | BA → SI (design-to-operations linkage) |
| Service Instance | Depends on :: Used by | Service Instance | Inter-SI dependencies |
| Service Instance | Depends on :: Used by | Infrastructure CI | "Runs on" |
| CI | associated with (`svc_ci_assoc`) | Service Instance | Member CIs of the SI |

> **Trap**: BSO → SI uses `Depends on :: Used by` (BSO is parent). TSO → SI uses `Contains :: Contained by` (TSO is parent). Different relationship types, both with TSO/BSO at the parent end. The CCH HLD originally had TSO → SI reversed and that query returned zero results in prod.

## CCH evidence (April 2026)

- **10,194** Service Instance records — by far the largest of the three core service classes.
- Queried all 497 `cmdb_rel_ci` records where Service Instance is the **parent**. Child class breakdown:
  - Server: 243 / Service Instance (self-ref): 155 / Windows Server: 81 / Linux Server: 7 / Tag-Based App Service: 6 / MS SQL Instance: 4 / Configuration Item: 1
  - **Service Offering: 0** — Service Instance never parents Service Offering. This confirms the `Contains` direction (TSO is parent, SI is child) and `Depends on` direction (BSO is parent, SI is child).
- 870 `BSO → SI (Depends on :: Used by)` relationships
- 395 `TSO → SI (Contains :: Contained by)` relationships
- Calculated App Service → Process Group `Contains :: Contained by` — 456 records (Dynatrace discovery output)

## Notes / decisions

- The Service Instance is **the** load-bearing class in CSDM v5 — the only object spanning business ↔ technical.
- INC HLD §7.2.2 uses `cmdb_ci_service_auto` (or `cmdb_ci_service_by_tags`) as the child class in the BSO incident path: BSO → `Depends on :: Used by` → Service Instance, then SI's support group as a fallback for incident assignment.
- Population method matters for governance — manual/tagged SIs need owner curation; calculated SIs are SGO output; query-based SIs are auto-maintained via CMDB Group queries.

## Encountered in

- [CSDM v5 Reference Model](../../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md) — the bridge concept; v4↔v5 terminology mapping; record counts
- [Incident Management Process — CSDM v5](../../../blueprints/incident-management/incident-management-process-csdm-v5.md) — BSO incident registration path; CMDB prerequisites
- [Calculated Service → BSO Bridge](../../../projects/dt-sn-integration/references/calculated-service-to-bso-bridge.md) — bottom-up service mapping pattern using calculated services
- [service-delivery](../service-delivery.md) — domain index
- [csdm-v5-relationship-chain](../csdm-v5-relationship-chain.md) — relationship reference
