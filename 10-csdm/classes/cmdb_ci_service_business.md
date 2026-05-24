# `cmdb_ci_service_business` — Business Service

**Domain**: Service Consumption
**Extends**: `cmdb_ci_service`
**Status**: OOTB

## What it represents

The **business-facing service** in CSDM v5 — the consumer view. Represents a capability the business publishes to its users (e.g. "Order Management", "Field Sales", "Employee HR Portal"). v5's preferred class to model business consumption — it replaces the legacy `cmdb_ci_service` for v5 work.

Business Services are **single-level, not hierarchical**. They are operational CIs (`cmdb_ci_service_business`) used in Incident/Problem/Change impact analysis (IPC). Also used for Approvals for Change.

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB |
| `service_classification` | choice | Always "Business Service" — the differentiator from TMS |
| `operational_status` | choice | Determines whether the BS is in scope for operational reporting |
| `life_cycle_stage` / `life_cycle_stage_status` | choice | Filters eligibility for ITSM (only Operational → In Use is eligible) |
| `support_group` | reference | Defaults for derived BSO support groups |

## Key relationships

| From | Relationship | To | Notes |
|---|---|---|---|
| Business Service | Reference (`Published as`) | BSO (`service_offering`) | One BS publishes one or more BSOs |
| Business Service | Reference (`Is part of`) | Service Portfolio | Crosses into [manage-portfolios](../manage-portfolios.md) |
| Business Capability | Provided by | Business Service | From [design-planning](../design-planning.md) |

## CCH evidence (April 2026)

- **444** records in `cmdb_ci_service_business`, ~360 operational.
- Legacy `cmdb_ci_service` still holds **1,789** records — migration not complete.
- BSO count (Business Service Offerings) total: **2,029** offerings (1,293 business-facing). See [service_offering](service_offering.md).

## Notes / decisions

- BSO is the natural target class for **service-centric INC categorisation** in the CCH INC HLD.
- Migration from legacy `cmdb_ci_service` to `cmdb_ci_service_business` is **not automatic** — needs the 5-step migration process from the CSDM 5 white paper (backup → attribute mapping → dependency analysis → refactor → data migration).
- Common persona: Business Relationship Manager (BRM), Customer Service Manager (CSM).

## Encountered in

- [CSDM v5 Reference Model](../../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md) — definition + record counts
- [Incident Management Process — CSDM v5](../../../blueprints/incident-management/incident-management-process-csdm-v5.md) — incident categorisation by BSO; parent/child escalation model
- [service-consumption](../service-consumption.md) — domain index
- [incident-assignment-bso-tso](../incident-assignment-bso-tso.md) — how BSO drives incident routing
