# Service Consumption

**CSDM v5 domain — Service Consumption** *(was: "Sell / Consume" in CSDM v3/v4)*

The **business-facing** layer. What the customer or business user actually sees and subscribes to. Business Services and their offerings (BSOs) live here. Used primarily by **Service Portfolio Management (SPM)** and **Customer Service Management (CSM)**.

This domain is "operational" — Business Service Offerings ARE selectable on Incident/Problem/Change. CSM references BSOs via the Install Base Item (IBI) for customer-facing service tracking.

## Service Consumption entities

| Entity | Table | Service Classification | Purpose |
|---|---|---|---|
| Business Service | `cmdb_ci_service_business` | Business Service | The customer-facing service (e.g. "Order Management") |
| Business Service Offering (BSO) | `service_offering` | Business Service | Stratified Business Service — tiers, SLAs, variants |
| Request Catalog | `sc_catalog` | — (not a CMDB CI) | Consumer's view of available offerings |
| Catalog Item | `sc_cat_item` | — | Requestable item within the catalog |

> **Legacy `cmdb_ci_service`**: many instances still hold pre-v5 business service records here. CCH had 1,789 legacy records vs 444 v5 records in April 2026 — migration is not automatic and not done. Plan separately.

## Foundational entities that contribute

- **Product Models** — Service Model, Service Offering Model
- **Value Streams / Stages** — relate services to the value sought; metrics here are feedback to Ideation & Strategy
- **Common Data** — for support_group assignments

## Key v5 relationships

| From | Relationship | To | Notes |
|---|---|---|---|
| Business Service | Reference (`Published as`) | BSO | BS publishes one or more BSOs |
| BSO | **Depends on :: Used by** | Service Instance | The consumer ↔ delivery bridge — BSO is the **parent** |
| Business Service | Reference (`Is part of`) | Service Portfolio | Crosses into [manage-portfolios](manage-portfolios.md) |
| Business Capability | Provided by | Business Service | From [design-planning](design-planning.md) |

## BSO is the incident anchor

In OOTB and CSDM-aligned incident management:
- Every incident has **one** `service_offering` — populated with a **BSO** at registration time (or **TSO** if escalated to a Parent incident).
- `business_criticality` on the BSO drives the urgency dimension of priority. See [business-impact-analysis](business-impact-analysis.md).
- `support_group` on the BSO drives initial assignment.
- The BSO never changes on a Child incident — business accountability is preserved.

## Class notes

- [cmdb_ci_service_business](classes/cmdb_ci_service_business.md) — Business Service (v5 form)
- [service_offering](classes/service_offering.md) — BSO/TSO container table (shared with [service-delivery](service-delivery.md))

## Why it matters

- **Incident registration**: The BSO is selected first; everything else (assignment group, urgency, dependent CIs) derives from it.
- **SLA**: BSO SLA measures customer experience; TSO SLA measures technical resolution. They run on separate incidents (Parent/Child model).
- **Service Catalog**: Beginning New York release, service offerings may be requested through the Request Catalog. BSO becomes the link from "what the user requests" to "what the model maps to".

## Related notes

- [README](README.md)
- [service-delivery](service-delivery.md) — the TSO side and the Service Instance bridge
- [incident-assignment-bso-tso](incident-assignment-bso-tso.md)
- [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md)
