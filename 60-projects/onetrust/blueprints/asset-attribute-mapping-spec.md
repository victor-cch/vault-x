# OneTrust Asset Attribute Mapping Spec

**Date**: 2026-05-14 *(revised from 2026-05-05 to align with OOTB HLD)*
**Status**: For OneTrust team review
**Audience**: OneTrust integration team (CCH-side and OneTrust vendor side), CSDM team
**Purpose**: Confirms the 19 application attributes that ServiceNow CSDM will provide to OneTrust via the Asset Discovery Wizard sync (Part 1 of [HLD](hld-onetrust-csdm-integration-ootb.md)). This document is the single artefact for the OneTrust team to validate field definitions, expected values, and edge-case handling before integration configuration.

**Design alignment**: All ServiceNow-side fields are **OOTB** — no custom (`u_*`) columns are required on `cmdb_ci_business_app`, `cmdb_application_product_model`, or any other CSDM class. Classification pushback (Part 3) lands in `cmdb_ci_information_object` via OOTB `Uses ↔ Used by` relationships — see HLD §5.5 and §7.3.

**Related**:
- [HLD - OneTrust ↔ CSDM Integration (OOTB)](hld-onetrust-csdm-integration-ootb.md) - full design context, two-master model, Parts 2 and 3
- [Background Analysis](../references/background-analysis.md) - why OneTrust is the platform of authority for privacy data

---

## 1. Scope

This spec covers **Part 1 (Asset Sync)** of the integration only - application metadata flowing from ServiceNow CSDM into OneTrust. Part 2 (Incident Management) and Part 3 (Classification Pushback from OneTrust) are designed in the HLD and not covered here.

**Phase 1 scope**: Centrally-managed applications only (per `Administration` filter - see §4).
**Phase 2 scope** (later): Local (BU-managed) applications added when BU rollout completes.

---

## 2. Attribute mapping table

| # | OneTrust Attribute | CSDM Source Field | Source Table | Type | Required | Sample Value | Notes |
|---:|---|---|---|---|:---:|---|---|
| 1 | **Name** | `name` | `cmdb_ci_business_app` | String | ✅ | `SAP S/4HANA ECC EU` | Primary identifier |
| 2 | **Administration** | derived from OOTB attribute (`company` / `business_unit` / `support_group` — see §4) | `cmdb_ci_business_app` | Derived enum | ✅ | `Central` | Values: Central / Local. Derived on the SN side from an OOTB attribute; OneTrust receives the Central / Local label. Phase 1 filter — only Central in scope. Source attribute choice is HLD Open Decision #12. |
| 3 | **Business Criticality** | `business_criticality` | `cmdb_ci_business_app` | Enum | 🟡 | `1 - most critical` | CSDM standard 1-4 scale |
| 4 | **Product** | `product` | `cmdb_application_product_model` (via `model_id`) | Reference | 🟡 | `SAP ERP` | Definition with OneTrust pending - see §3 |
| 5 | **Platform** | `platform` | `cmdb_ci_business_app` | String / Enum | 🟡 | TBD | Definition with OneTrust pending - see §3 |
| 6 | **Platform Architect** | OOTB user-reference field on Product Model (candidates: `managed_by`, `assigned_to`) — see §10 | `cmdb_application_product_model` | sys_user reference | 🟡 | `john.smith@cchellenic.com` | OOTB Product Model has limited people fields; final mapping TBD per §10 |
| 7 | **Product Manager** | OOTB user-reference field on Product Model (candidate: `owned_by`) — see §10 | `cmdb_application_product_model` | sys_user reference | 🟡 | `jane.doe@cchellenic.com` | OOTB Product Model has limited people fields; final mapping TBD per §10 |
| 8 | **Application Type** | `application_type` | `cmdb_ci_business_app` | Enum | 🟡 | `Business` | OOTB enum |
| 9 | **Install Type** | `install_type` | `cmdb_ci_business_app` | Enum | 🟡 | `SaaS` | OOTB enum: IaaS / PaaS / SaaS / On-Prem / Hybrid |
| 10 | **Platform Host** | `platform_host` | `cmdb_ci_business_app` | String | 🟡 | `Azure West Europe` | Hosting context |
| 11 | **Life Cycle Stage** | `life_cycle_stage` | `cmdb_ci_business_app` | Enum | ✅ | `Operate` | CSDM v5 - Plan / Build / Operate / Retire / Decommission. Critical for decommission detection |
| 12 | **Life Cycle Stage Status** | `life_cycle_stage_status` | `cmdb_ci_business_app` | Enum | 🟡 | `Active` | CSDM v5 sub-status |
| 13 | **Business Owner** | `business_owner` | `cmdb_ci_business_app` | sys_user reference | 🟡 | `john.smith@cchellenic.com` | OOTB |
| 14 | **Description** | `short_description` | `cmdb_ci_business_app` | String | 🟡 | `Group ERP system for finance and supply chain` | Single field. Long description out of scope |
| 15 | **IT Application Owner** | `it_application_owner` | `cmdb_ci_business_app` | sys_user reference | 🟡 | `it.owner@cchellenic.com` | OOTB |
| 16 | **Install Status** | `install_status` | `cmdb_ci_business_app` | Enum | 🟡 | `Installed` | OOTB enum: Installed / In Stock / Pending Install / Retired / etc. |
| 17 | **Operational Status** | `operational_status` | `cmdb_ci_business_app` | Enum | 🟡 | `Operational` | OOTB enum: Operational / Non-Operational / Repair in Progress / etc. |
| 18 | **Updated** | `sys_updated_on` | `cmdb_ci_business_app` | Datetime | ✅ | `2026-05-05 14:32:18` | System field - auto-populated, no manual mapping |
| 19 | **Vendor** | `vendor` | `cmdb_ci_business_app` (core_company ref) | Reference | 🟡 | `SAP SE` | **Currently blank in CSDM** - population approach is an open decision |

**Required column legend**: ✅ = always populated; 🟡 = expected populated but may be empty in some records (see §6 for empty handling)

---

## 3. Field definitions to confirm with OneTrust

Two fields in the OneTrust spec are ambiguous and must be defined before integration configuration. CSDM may or may not have a direct equivalent depending on the answer.

### Platform

**OneTrust spec says**: `Platform`

**Possible meanings** (CSDM equivalents in brackets):
- **Hosting platform** (e.g. AWS / Azure / OCI / on-premise) - may map to a `cloud_provider` field or be derivable from the platform host relationship
- **Application platform** (e.g. SAP S/4 HANA / Salesforce / ServiceNow itself) - may map to product/model
- **Technology stack** (e.g. Java / .NET / Python / SAP ABAP) - may need a custom enum

**Need from OneTrust team**: definition + expected value list.

### Product

**OneTrust spec says**: `Product`

**Possible meanings**:
- **Marketing product** (the commercial product name)
- **Software product** (the model record in CSDM Product Model table)
- **LeanIX-style "Product"** (a logical bundle of related applications, used in portfolio management)

**Need from OneTrust team**: definition + relationship to "Application" (one Product = many Apps? or one-to-one?).

---

## 4. Administration field - phased rollout filter

`Administration` is **not just a label** — it is the integration-scope filter that determines which applications are in scope per phase. **OneTrust receives a derived enum value (Central / Local)**; on the ServiceNow side, the value is derived from an OOTB attribute on `cmdb_ci_business_app` — no custom field is created.

| Phase | Filter | Population |
|---|---|---|
| **Phase 1** | `Administration = Central` | Centrally-managed applications only (Group / DTPS-managed) |
| **Phase 2** (later) | `Administration IN (Central, Local)` | Add Local (BU-managed) applications when BU rollout completes |

### Derivation candidates (OOTB attributes)

Per HLD Open Decision #12. Final choice is part of the design-decision lock before Phase 1 implementation.

| Candidate OOTB attribute | Derivation rule | Pros | Cons |
|---|---|---|---|
| `company` (reference → `core_company`) | App's `company` = top-level CCH Holdings → Central; specific subsidiary → Local | Cleanly OOTB; CSDM-aligned; commonly populated | Requires a definitive list of "central-managed" company sys_ids |
| `business_unit` (reference → `business_unit`) | App's `business_unit` IN central-managed BU list → Central; else Local | OOTB; explicit BU semantics | Depends on `business_unit` table being populated and curated |
| `support_group` (reference → `sys_user_group`) | App's `support_group` IN central-support-groups list → Central; else Local | OOTB; reflects operational ownership | Indirect proxy for governance authority |

### Implementation prerequisites

- Confirm the source OOTB attribute (HLD Open Decision #12)
- Validate that the chosen attribute is populated consistently across the in-scope application population — bulk-populate gaps as part of pre-integration data prep
- Define and version-control the "central-managed" reference list (sys_ids of qualifying companies / BUs / support groups) — held in a small lookup table or sys_choice
- Implement the derivation as a Business Rule or scripted field on `cmdb_ci_business_app`, OR derive at sync time inside the OneTrust outbound payload — both are OOTB approaches
- Default behaviour for ambiguous records: TBD (default to Central pending review, or flag for manual triage)

---

## 5. Enum value formats

ServiceNow stores enum values as their **display label** by default (e.g. `"Operational"`), but the API can return either the **label** or the **internal value** (`"1"`) depending on configuration.

**OneTrust team must confirm** for each enum field:
- Expected format - label or internal value?
- Case sensitivity?
- Exact spelling (e.g. `Non-Operational` vs `Non Operational` vs `Not Operational`)
- How to handle additional values added later in CSDM (will OneTrust auto-accept or require schema update)

**Recommended approach**: SN sends labels (human-readable, stable across SN upgrades); OneTrust maintains its own internal mapping table.

---

## 6. Empty / null field handling

For each 🟡 field above, OneTrust must specify expected behaviour when CSDM source is empty:

| Option | When to use | Risk |
|---|---|---|
| **Send null** | OneTrust accepts null and treats as "unknown" | Simplest. Recommended default |
| **Send placeholder** (e.g. "Unknown", "Not Set") | OneTrust requires non-null but accepts a sentinel value | Risk of placeholder being treated as real value |
| **Skip the field** | OneTrust accepts partial records | Simplest for SN, but may break downstream OneTrust workflows |
| **Reject the record** | OneTrust requires complete records | Causes sync failures - not recommended for Phase 1 |

**Recommended default**: send null for missing values. OneTrust treats null as "not yet specified" and surfaces those for privacy team review where relevant.

**Special cases**:
- **Vendor** (currently blank in CSDM for most records) - OneTrust will receive null en masse on first sync. Privacy team should expect this and not raise as data quality issue
- **Platform Architect / Product Manager** (OOTB fields on Product Model, see §10) — may be unpopulated for many records today. Plan a back-fill workstream alongside Phase 1 sync activation

---

## 7. Unique identifier strategy

Required for round-trip identity. Per HLD §5.6, Part 3 classification pushback uses this identifier to address the right CSDM Business Application when OneTrust creates / updates the linked `cmdb_ci_information_object` records and `Uses ↔ Used by` relationships.

**OOTB options only** — no custom field is introduced.

| Option | OOTB? | Pros | Cons |
|---|:---:|---|---|
| **`sys_id`** | ✅ | Already exists, stable for the life of the record, zero implementation cost | Opaque GUID; brittle if a CI is ever recreated rather than updated |
| **`correlation_id`** | ✅ | OOTB string field on every `cmdb_ci_*` table — **designed exactly for cross-system identifiers**. Human-readable. Survives CI recreation if populated consistently. | Currently unpopulated for most records; requires a one-off population workstream |
| **Application name** | ✅ | Human-readable | Not guaranteed unique; volatile (apps get renamed) |

**Recommended**: use **`correlation_id`** as the canonical round-trip key. It's the OOTB pattern for exactly this purpose — a stable cross-system reference designed for integrations. Populate `correlation_id` on all in-scope Business Applications before Phase 1 sync activation, in a format agreed with OneTrust (e.g., `APP-EU-ERP-001`).

`sys_id` remains the fallback if OneTrust's Asset Discovery Wizard auto-maps on it and the population effort for `correlation_id` is judged too high for Phase 1.

**Need from OneTrust team**: confirm whether the Asset Discovery Wizard reads `correlation_id` from the SN REST response or only `sys_id`, and which one OneTrust persists as its lookup key.

---

## 8. Refresh cadence

| Cadence | Mechanism | Use case |
|---|---|---|
| **Daily scheduled sync** | Asset Discovery Wizard scheduled run | Steady-state - new apps + field updates |
| **Real-time webhook (optional)** | Business Rule on `cmdb_ci_business_app` insert/update → OneTrust REST API | If privacy team needs immediate visibility on new apps |

**Recommended**: daily scheduled sync for Phase 1. Real-time webhook can be added later if cadence proves insufficient.

**Need from OneTrust team**: confirm acceptable freshness SLA for OneTrust workflows (especially DPIA and breach notification triggers).

---

## 9. Open questions for OneTrust team

| # | Question | Why it matters |
|---:|---|---|
| 1 | Define "Platform" and "Product" precisely (see §3) | CSDM cannot map until definition is clear |
| 2 | Confirm enum value format (label vs internal value, case sensitivity, exact spelling) | Mapping mismatches between enum representations are a classic silent-failure pattern |
| 3 | Confirm empty-field handling per attribute (null vs placeholder vs skip) | Drives validation rules on the SN side |
| 4 | Confirm unique identifier strategy (sys_id, name, external ID?) | Required for Part 3 classification pushback round-trip |
| 5 | Confirm sync cadence SLA (daily acceptable, or need faster?) | Drives mechanism choice (scheduled vs webhook) |
| 6 | Asset Discovery Wizard available in CCH OneTrust tenant? | If not, fallback is custom REST API integration (higher effort) |
| 7 | Asset Discovery Wizard field-mapping config - point-and-click or scripted? | Affects who can configure and how change-control works |
| 8 | Does OneTrust auto-create / update relationships between Assets when sync brings in related references (e.g. business_owner = sys_user)? | Determines whether SN must pre-create user records in OneTrust or whether OneTrust resolves on the fly |
| 9 | What does OneTrust do with the "Updated" timestamp - drives sync delta detection, or stored as metadata? | Affects how SN structures incremental syncs |
| 10 | Confirm sample payload OneTrust expects (example record with all 19 fields populated) | Removes ambiguity on JSON structure, nesting, field names |
| 11 | Confirm OOTB user-reference field on `cmdb_application_product_model` to carry **Platform Architect** | Avoids a custom field; CSDM team to validate the chosen field name is acceptable to the OneTrust data model |
| 12 | Confirm OOTB user-reference field on `cmdb_application_product_model` to carry **Product Manager** | Same as above |

---

## 10. CSDM-side dependencies (OOTB — no custom fields)

Per the OOTB design principle of the [HLD](hld-onetrust-csdm-integration-ootb.md), **no `u_*` custom fields are created** on `cmdb_ci_business_app`, `cmdb_application_product_model`, or any other CSDM class. The dependencies below are about **populating existing OOTB fields and confirming the source-attribute choice for derived values**.

| Item | Type | Where it lands | Owner | Status |
|---|---|---|---|---|
| **Administration source attribute** | Decision + reference list | OOTB attribute on `cmdb_ci_business_app` (`company` / `business_unit` / `support_group`) — derivation rule per §4 | CSDM team + Privacy / DTPS governance | HLD Open Decision #12 |
| **Platform Architect mapping target** | Decision | OOTB user-reference field on `cmdb_application_product_model` (candidates: `managed_by`, `assigned_to`) | CSDM team | New open question — see §9 |
| **Product Manager mapping target** | Decision | OOTB user-reference field on `cmdb_application_product_model` (candidate: `owned_by`) | CSDM team | New open question — see §9 |
| **`correlation_id` population** | Data work | OOTB field on `cmdb_ci_business_app` | CSDM team | Recommended per §7 — populate for in-scope apps before Phase 1 sync |
| **`vendor` population** | Data work | OOTB `vendor` reference on `cmdb_ci_business_app` | CSDM team + procurement | Currently sparse — see HLD Open Decision #7 |

### What is **not** in this list (and why)

- **`u_data_classification` custom field** — removed. Classification pushback (Part 3) lands in OOTB `cmdb_ci_information_object` records linked via `Uses ↔ Used by` relationships in `cmdb_rel_ci`. No custom field on `cmdb_ci_business_app` for classification. Full design in HLD §5.5, §5.6, §7.3.
- **`u_administration` custom enum** — removed. Replaced by derivation from an OOTB attribute (see above).
- **`u_external_app_id` custom string** — removed. Replaced by OOTB `correlation_id` field (see §7).
- **`u_platform_architect` / `u_product_manager` custom user references** — removed. Replaced by OOTB user-reference fields on `cmdb_application_product_model`; final field choice is the open question above.

---

## Appendix: Sample CSDM record

For OneTrust team reference - what a single record looks like once mapped:

```json
{
  "name": "SAP S/4HANA ECC EU",
  "administration": "Central",
  "business_criticality": "1 - most critical",
  "product": "SAP ERP",
  "platform": "[TBD - definition pending]",
  "platform_architect": "john.smith@cchellenic.com",
  "product_manager": "jane.doe@cchellenic.com",
  "application_type": "Business",
  "install_type": "On-Prem",
  "platform_host": "Frankfurt DC1",
  "life_cycle_stage": "Operate",
  "life_cycle_stage_status": "Active",
  "business_owner": "business.owner@cchellenic.com",
  "short_description": "Group ERP system for finance and supply chain",
  "it_application_owner": "it.owner@cchellenic.com",
  "install_status": "Installed",
  "operational_status": "Operational",
  "sys_updated_on": "2026-05-05 14:32:18",
  "vendor": "SAP SE",
  "correlation_id": "APP-EU-ERP-001"
}
```

*Note*: `correlation_id` is the **OOTB** field on `cmdb_ci_business_app` used as the cross-system round-trip identifier (see §7). No custom `external_app_id` field exists.
