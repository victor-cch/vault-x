# Design & Planning

**CSDM v5 domain — Design & Planning** *(was: "Design" in CSDM v3/v4)*

The application portfolio and architecture layer. Where Business Capabilities, Business Applications, and Information Objects live. This is **what the business should run on** — independent of how it is delivered or where it runs.

Used primarily by **Enterprise Architecture (EA, formerly APM)**. Records here are NOT direct targets of ITSM processes (Incident, Problem, Change) — they describe the logical design, not the operational reality.

## Design & Planning entities

| Entity | Table | What it represents |
|---|---|---|
| Business Capability | `cmdb_ci_business_capability` | What the organisation *does* (verbs) — hierarchical, max 6 levels |
| Business Application | `cmdb_ci_business_app` | Logical app the business uses (e.g. "SAP S/4", "Salesforce") |
| Information Object | `cmdb_ci_information_object` | Logical category of data (PII, PCI, HIPAA, GDPR Art 30 anchors) |

## Foundational entities that contribute

- **Product Models** — referential object on Business Application via `model_id`
- **Value Streams / Stages** — relate Business Capabilities to value sought
- **Business Process** — what enables the capability

## Key v5 relationships

| From | Relationship | To |
|---|---|---|
| Business Capability | Provided by | Business Application |
| Business Capability | Provided by | Business Service *(crosses into Service Consumption)* |
| Business Application | Uses | Information Object |
| Business Application | Contains | SDLC Component *(crosses into Build & Integration)* |
| Business Application | Contains | Service Instance *(crosses into Service Delivery)* |
| Business Application | uses reference | Business Application *(self-ref for app-of-apps)* |

> **CSDM 5 change**: Business Application's singular `business_process` reference is now considered **legacy**. New work should model the relationship as one-to-many.

## Class notes

- [cmdb_ci_business_app](classes/cmdb_ci_business_app.md) — Business Application (the portfolio anchor)
- [cmdb_ci_information_object](classes/cmdb_ci_information_object.md) — Information Object (data classification, GDPR Art 30)

*Business Capability has not yet appeared in engagement work — add a class note when it does.*

## Why it matters

- **EA risk assessment** — depends on Business Application ↔ Application Service relationships being populated; without them, Technology Portfolio Management can't compute risk.
- **OneTrust ↔ CSDM integration** — Information Object is the landing class for GDPR Article 30 metadata. See OneTrust HLDs.
- **Service mapping (bottom-up)** — Business Application sits in the middle of the chain CI → calculated service → Dynamic CI Group → **BA** → Business Service → BSO.

## Related notes

- [README](README.md)
- [service-delivery](service-delivery.md) — where the runtime instances of BAs live
- [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md)
- [service-mapping-bottom-up](service-mapping-bottom-up.md)
