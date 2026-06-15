# `service_offering` — Service Offering (BSO / TSO container)

**Domain**: Service Consumption (when `service_classification = Business Service`) AND Service Delivery (when `service_classification = Technical Service`)
**Extends**: `cmdb_ci_service`
**Status**: OOTB (Service Offering OOTB in New York; Business Service Portfolio OOTB in New York)

## What it represents

The **stratified offering** of a parent Service — capability tiers, availability, environment, geography, pricing, support group, technical approval group, packaging options (commitments).

**One table, two classifications:**

| Classification    | Parent Service                                            | Acronym | Role                                        |
| ----------------- | --------------------------------------------------------- | ------- | ------------------------------------------- |
| Business Service  | [cmdb_ci_service_business](cmdb_ci_service_business.md)   | **BSO** | Consumer view — what the business user sees |
| Technical Service | [cmdb_ci_service_technical](cmdb_ci_service_technical.md) | **TSO** | Provider view — IT building blocks          |

This is critical: **BSO and TSO live on the same physical table**. The `service_classification` field is the discriminator. Queries that don't filter by classification return both.

> **CSDM 5 rename**: Technical Service Offering (TSO) was previously labeled "Technical Service Offering" in CSDM 4; in v5 it's "Technology Management Service Offering" (still TSO). Table name is unchanged.

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB |
| `service_classification` | choice | **Business Service** (= BSO) or **Technical Service** (= TSO) |
| `parent` | reference | Business Service or TMS |
| `support_group` | reference | Drives default incident assignment_group |
| `business_criticality` | choice (1-5) | Drives Urgency derivation in BIA chain |
| `vendor` | reference | Drives Vendor OLA tracking on TSO |
| `life_cycle_stage` | choice | Only `Operational` is eligible for ITSM |
| `life_cycle_stage_status` | choice | Only `In Use` is eligible for ITSM |

## Service commitments

Each Service Offering consists of one or more **service commitments** that define availability, criticality, scope, pricing. A typical TMS may offer two tiers:
- **"Prod"** — high availability, 5-minute response, 24/7
- **"NonProd"** — limited availability, 60-minute response, 8-5 weekdays

## Key relationships

### BSO (Business Service classification)

| From | Relationship | To | Notes |
|---|---|---|---|
| Business Service | Reference (`Published as`) | BSO | Parent reference |
| **BSO** | **Depends on :: Used by** | Service Instance | The consumer ↔ delivery bridge — **BSO is the parent** |
| Service Catalog | uses reference | BSO | Beginning New York, BSOs may be requested through Request Catalog |

### TSO (Technical Service classification)

| From | Relationship | To | Notes |
|---|---|---|---|
| TMS | Reference (`Published as`) | TSO | Parent reference |
| **TSO** | **Contains :: Contained by** | Service Instance | **TSO is the parent** — **opposite direction** to BSO→SI |
| TSO | Contains :: Contained by | Dynamic CI Group | For the CI-first incident path |
| TSO (L2) | Depends on :: Used by | TSO (L3) | Multi-level escalation |
| TSO (L3) | Depends on :: Used by | TSO (L4) | Continues escalation chain |

> **The two `service_offering` parent-side relationships use different types.** This is the most common cause of mismatched CSDM queries in practice.

## TSO auto-sync to CIs

Three foundational attributes auto-synchronise from a TSO **down** to underlying CIs:
- **Change Group**
- **Managed By Group**
- **Support Group**

Define once at the TSO; cascades to all CIs the TSO contains via its Dynamic CI Group or `Contains :: Contained by` relationships.

## CCH evidence (April 2026)

- Total `service_offering` records: **2,029**
- **Business-facing (BSO)**: 1,293
- **Technology Management (TSO)**: 735
- BSO → SI relationships: **870**
- TSO → SI relationships: **395**
- TSO → TSO escalation chains: **647** (mixed: technical escalation + OT BS→SO + orphans)

## Notes / decisions

- A single incident has **one** `service_offering` — either BSO or TSO, never both. The parent/child incident model is how CSDM v5 preserves both consumer and provider accountability.
- Eligibility: only Offerings with `life_cycle_stage = Operational` AND `life_cycle_stage_status = In Use` are eligible to appear on incidents.
- Operationally CCH currently uses the custom `u_technical_service_offering` field on the incident to carry the TSO while `service_offering` holds the BSO — this is **Approach 1** in the CSDM v5 incident process (custom field path), not the OOTB parent/child model.

## Encountered in

- [CSDM v5 Reference Model](../../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md) — table definition + record counts
- [Incident Management Process — CSDM v5](../../../blueprints/incident-management/incident-management-process-csdm-v5.md) — BSO/TSO as incident anchors
- [incident-assignment-bso-tso](../incident-assignment-bso-tso.md) — how both classifications drive incident routing
- [service-consumption](../service-consumption.md) — domain index for BSO
- [service-delivery](../service-delivery.md) — domain index for TSO
