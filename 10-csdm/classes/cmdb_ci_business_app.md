# `cmdb_ci_business_app` — Business Application

**Domain**: Design & Planning
**Extends**: `cmdb_ci`
**Status**: OOTB (since Kingston release)

## What it represents

The **Design & Planning domain's anchor** for application portfolio modelling. Represents a **logical application** the business owns (e.g. "SAP S/4 Finance", "Salesforce Sales Cloud") — independent of how it is delivered or where it runs. One Business Application per logical app, regardless of how many environments or geographies it spans.

Sits **parallel** to the service-delivery chain (BSO → Service Instance → TSO) and connects in via the `Uses :: Used by` relationship to Service Instance.

> **NOT an operational CI** — Business Applications should NOT be used in Incident, Problem, or Change. The runtime equivalent is the Service Instance.

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB |
| `correlation_id` | string | Stable external identifier; useful for tag-driven bridging |
| `architecture_type` | choice | Includes "platform app" and "platform host" (New York release) |
| `business_criticality` | choice | Drives BIA propagation upward |
| `model_id` | reference | Product Model — for design/planning detail |

## Key relationships

| From | Relationship | To | Notes |
|---|---|---|---|
| **Business Application** | **Uses :: Used by** | Service Instance | The design-to-operations linkage (CSDM 5 change — was `Consumes / Consumed by` in v4) |
| Business Application | Contains | SDLC Component | Build & Integration linkage |
| Business Application | Uses | Information Object | Data classification scope |
| Business Application | uses reference | Business Application | Self-ref for app-of-apps |
| Business Capability | Provided by | Business Application | Capability → App |
| Business Application | Ref: Business Process | Business Process | **Legacy** in CSDM 5 — prefer one-to-many modelling |

> **CSDM 5 relationship change**: Business Application ↔ Service Instance relationship changed from `Consumes / Consumed by` (CSDM 4) to **`Uses / Used by`** (CSDM 5). Confirm against the current spec version when implementing.

## Cardinality vs Service Instance

| Attribute | Business Application | Service Instance |
|---|---|---|
| Level | Logical / portfolio | Operational / runtime |
| Cardinality | **ONE per app** (logical) | **MANY per app** (one per environment) |
| Used for | Cost, risk, lifecycle tracking | Incidents, monitoring |
| Example | SAP S/4 Finance | SAP-S4-PROD-EU, SAP-S4-DEV-EU |
| Domain | Design & Planning | Service Delivery |

## CCH evidence

- *(record count pending verification)*
- BA catalogue cleanliness is the **prerequisite** for any CI-upward bridging programme (see [service-mapping-bottom-up](../service-mapping-bottom-up.md)). If `cmdb_ci_business_app` is not well-formed, expect a 6-12 month catalogue cleanup as a separate programme.

## Notes / decisions

- The recommended pattern for CI-upward mapping uses a **Dynamic CI Group per Business Application** to absorb the granularity/churn/ownership mismatch between calculated services (tens of thousands) and BAs (hundreds).
- Hierarchy: not directly supported on BA; hierarchy lives on Business Capability instead.
- Owner: typically Application Owner, accountable for cost/risk/usage rationalisation through Enterprise Architecture (EA, formerly APM).

## Encountered in

- [CSDM v5 Reference Model](../../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md) — design-side parallel relationship in the v5 chain
- [Calculated Service → BSO Bridge](../../../projects/dt-sn-integration/references/calculated-service-to-bso-bridge.md) — BA as the middle layer in the bottom-up bridge
- [design-planning](../design-planning.md) — domain index
- [service-mapping-bottom-up](../service-mapping-bottom-up.md) — BA in the CI-to-BSO chain
