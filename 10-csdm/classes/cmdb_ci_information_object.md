# `cmdb_ci_information_object` — Information Object

**Domain**: Design & Planning
**Extends**: `cmdb_ci`
**Status**: OOTB (since New York release)

## What it represents

Represents a **category of information / data** handled by the business. In CSDM v5, Information Object is the anchor where **data sensitivity, confidentiality, and compliance metadata** attach to the model. The class that the **OneTrust ↔ CSDM integration** uses to surface GDPR Art 30 data into ServiceNow.

The Information Object captures *what kind of data* is used by an application; the actual storage of that data lives elsewhere (DB Catalog and child CIs).

## Information Object vs related concepts

| Concept | What it captures | Where it lives |
|---|---|---|
| **Information Object** | What data **IS** (logical) | `cmdb_ci_information_object` |
| DB Catalog | Where data **LIVES** (physical) | Schema-typed CIs |
| Business Capability | What the business **DOES** | `cmdb_ci_business_capability` |

## Key fields

| Field | Type | Notes |
|---|---|---|
| `sys_id` | GUID | OOTB |
| `name` | string | OOTB |
| `data_sensitivity` | string/choice | PII, PCI, HIPAA, etc. |
| `confidentiality` | choice | Confidentiality classification |

## Key relationships

| From | Relationship | To | Notes |
|---|---|---|---|
| Business Application | Uses | Information Object | The compliance scoping link |
| Information Object | (TBD on OneTrust side) | OneTrust Data Element / Asset | Integration-driven |

## Compliance use case

- Tag Business Applications with Information Objects to answer: **"Which apps process Patient Data / PII / GDPR-scope data?"**
- Supports PII, PCI, HIPAA, GDPR Art 30 audits — the types of data scoping reviews drive periodically.
- For PII: enables periodic review of how the data is stored, exposed, and transported.

## Notes / decisions

- Central to the **OneTrust ↔ CSDM bidirectional sync** (data classification, Information Objects).
- Per CSDM 5 white paper: Information Object table **may be required sooner** in your data model than the Fly maturity stage suggests, if compliance drives the work. Stage placement is a recommendation, not a constraint.
- Anchor for the OneTrust HLD pattern: BA → Information Object → OneTrust assessment surface.

## Encountered in

- [OneTrust ↔ CSDM Integration OOTB HLD](../../../projects/onetrust/blueprints/hld-onetrust-csdm-integration-ootb.md) — OOTB integration pattern (Information Objects + `Uses ↔ Used by` relationships)
- [OneTrust ↔ CSDM Integration Simplified HLD](../../../projects/onetrust/blueprints/hld-onetrust-csdm-integration-simplified.md) — direct-classification variant on `cmdb_ci_business_app.data_classification`
- [design-planning](../design-planning.md) — domain index
