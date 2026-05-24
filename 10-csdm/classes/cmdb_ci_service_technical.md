# `cmdb_ci_service_technical` — Technology Management Service (TMS)

**Domain**: Service Delivery
**Extends**: `cmdb_ci_service`
**Status**: OOTB
**Previous label (CSDM v4 and earlier)**: Technical Service

## What it represents

The **IT capability** — the provider's view of "what we deliver" before it is consumed by the business. Pairs with [cmdb_ci_service_business](cmdb_ci_service_business.md) (BS) on the consumption side and is **mediated by [cmdb_ci_service_auto](cmdb_ci_service_auto.md) (Service Instance)**.

A TMS is single-level, not hierarchical. It is an operational CI (`cmdb_ci_service_technical`) used in IPC (Incident, Problem, Change). It typically has **one or more Technology Management Service Offerings (TSOs)** that stratify it by environment, geography, SLA tier, support group, etc.

> **CSDM 5 rename**: previously labeled "Technical Service" in CSDM 4 and earlier. The label changed in Yokohama family release. The **table name `cmdb_ci_service_technical` did not change**. CCH documentation predating Yokohama uses both names interchangeably.

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB |
| `service_classification` | choice | "Technical Service" (legacy) or "Technology Management Service" depending on release |
| `operational_status` / `life_cycle_stage` / `life_cycle_stage_status` | choice | Filters eligibility for ITSM |
| `support_group` | reference | Default for derived TSO support groups |
| `service_portfolio` | reference | From Rome release; TMS can reference Service Portfolio nodes |

## Key relationships

| From | Relationship | To | Notes |
|---|---|---|---|
| **TMS** | Reference (`Published as`) | **TSO** (`service_offering`) | One TMS publishes one or more TSOs |
| **TSO** | **Contains :: Contained by** | Service Instance | **TSO is the parent** — confirmed by CCH `cmdb_rel_ci` evidence |
| TSO | Contains :: Contained by | Dynamic CI Group | For CI-first incident path |
| TSO (L2) | Depends on :: Used by | TSO (L3) | **CCH-specific pattern, not CSDM 5 canon.** Canonical model is flat sibling TSOs under one TMS. See [csdm-v5-relationship-chain](../csdm-v5-relationship-chain.md#non-canonical-cch-patterns) |
| TSO (L3) | Depends on :: Used by | TSO (L4) | Same — CCH escalation chain, not canonical |
| TMS | Reference (`Is part of`) | Service Portfolio | Cross-domain |

> **Relationship direction is non-obvious here.** TSO is the **parent** in `Contains :: Contained by` with Service Instance. The original CCH HLD had this reversed and produced zero query results in prod. CCHIncidentUtils name matching is the workaround.

## TMS Offering auto-sync

Three foundational attributes auto-synchronise from a TSO **down** to underlying CIs:
- **Change Group**
- **Managed By Group**
- **Support Group**

Define once at the TSO; cascades to all CIs the TSO contains via its Dynamic CI Group or `Contains :: Contained by` relationships. **This is why TSOs are central to the Walk maturity stage.**

> ServiceNow recommends: each CI associated through a Dynamic CI Group be related to **only one** TMS / TSO. Multiple TSOs with conflicting SLA/OLA/Support Groups overwrite data on the related CIs.

## CCH evidence (April 2026)

- **361** TMS records.
- TSO records (Service Offerings with `service_classification = Technical Service`): **735** of the 2,029 total `service_offering` rows.
- 395 `TSO → SI (Contains :: Contained by)` relationships.
- 647 `TSO → TSO (Depends on :: Used by)` relationships — covers L2 → L3 → L4 chain (mixed with OT BS→SO and orphans). **Note: this TSO→TSO pattern is CCH-specific and not in CSDM 5 canon** — see [csdm-v5-relationship-chain](../csdm-v5-relationship-chain.md#non-canonical-cch-patterns).
- 7 `TSO → Dynamic CI Group` relationships (very low — CI-first path largely untapped).

## Notes / decisions

- TSO is the **parent** in the INC HLD parent/child escalation model — incidents escalate from BSO (child) → TSO (parent). See [incident-assignment-bso-tso](../incident-assignment-bso-tso.md).
- Operational eligibility: only TSOs with `life_cycle_stage = Operational` and `life_cycle_stage_status = In Use` are valid for incident assignment.
- TMS classification: in CCH today, classified as one of three sub-types — Operations Support (L2), Technical Expertise (L3), DevOps Enablement (L4) — used to disambiguate when multiple TSOs match the Service Instance.

## Encountered in

- [CSDM v5 Reference Model](../../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md) — definition + record counts + relationship findings
- [Incident Management Process — CSDM v5](../../../blueprints/incident-management/incident-management-process-csdm-v5.md) — TSO as escalation parent; multi-level technical escalation
- [service-delivery](../service-delivery.md) — domain index
- [incident-assignment-bso-tso](../incident-assignment-bso-tso.md) — TSO in the parent/child model
