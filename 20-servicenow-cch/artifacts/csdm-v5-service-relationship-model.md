# CSDM v5 — Service Relationship Model

**Scope**: Reference for CSDM v5 relationship chain as it applies to CCH's Incident Management and SGO integration design.
**Last updated**: 4 April 2026
**Sources**:
- CSDM 5.pdf — Figure 16. CSDM 5 Configuration Item relationships (page 49)
- CSDM Data Model Examples (ServiceNow, May 2025, Asset 0003134) — "CSDM 5 Tables and Relationships" page, maturity diagrams (Crawl/Walk/Run/Fly)
**Related**: Incident Management HLD **(TBD)** | OOTB Proposal **(TBD)** | CCHIncidentUtils Analysis **(TBD)**

---

> While CSDM v5 introduces new concepts like Service Instances and Technology Management Services, the underlying data structure for offerings remains largely unchanged:
>
> - **Business Service Offerings (BSO)**: Identified by `service_classification = Business Service`. These represent the "Consumer" view — what the business user actually sees and subscribes to.
> - **Technical / Technology Management Service Offerings (TSO)**: Identified by `service_classification = Technology Management Service`. These represent the "Provider" view — the IT building blocks like "Windows Hosting" or "Network Support".

---

## Part 1 — CSDM v5 Relationship Chain

### Service Consumption

- **Business Service** (`cmdb_ci_service_business`) — represents the business-facing capability
  - *offers →* **Business Service Offering (BSO)** (`service_offering`)
  - Represents how the service is consumed (tiers, SLAs, variants)

### Service Delivery

- BSO *depends on :: used by →* **Service Instance** (`cmdb_ci_service_auto`) — represents the operational / runtime instance of the service
  - NB: "Business Service Offering is *realised by / delivered through* a Service Instance" is more appropriate conceptually.
- Service Instance *depends on :: used by →* **Technical CIs** (servers, databases, load balancers, middleware, containers, etc.)

### Design and Planning (parallel relationship)

- **Business Application** (`cmdb_ci_business_app`) *uses :: used by →* **Service Instance** (`cmdb_ci_service_auto`)

### Service Delivery (provider side)

- **Technology Management Service** (`cmdb_ci_service_technical`) — represents the IT capability
  - *offers →* **Technical Service Offering (TSO)** (`service_offering`)
  - Service Instance *depends on :: used by →* Technology Management Service and may be aligned to one or more TSOs

---

### Relationship Summary

| From | Relationship | To |
|---|---|---|
| Business Service | offers | Business Service Offering (BSO) |
| BSO | depends on :: used by | Service Instance |
| Business Application | uses :: used by | Service Instance |
| Service Instance | uses :: used by | Technology Management Service |
| Technology Management Service | offers | Technical Service Offering (TSO) |
| Service Instance | depends on :: used by | Technical / Infrastructure CIs |

> **Relationship type guidance:** Use `depends on :: used by` only when loss of the Service Instance **guarantees** Technology Management Service failure. Otherwise prefer `uses :: used by` (see differentiations below).

---

### Official ServiceNow CSDM v5 Relationship Table

*Source: CSDM Data Model Examples (May 2025, Asset 0003134) — "CSDM 5 Tables and Relationships" page*

| From | Relationship | To |
|---|---|---|
| Business Capability | Provided by | Business Application |
| Business Capability | Provided by | Business Service |
| Business Application | Uses | Information Object |
| Business Application | uses reference | Business Application |
| Business Application | Contains | SDLC Component |
| Business Application | Contains | Service Instance |
| *SDLC Component | Consumes | Service Instance |
| Service Instance | Depends on/sends Data to | Service Instance |
| Service Instance | Depends on | Service Instance |
| Application | Runs on | Infrastructure CIs |
| Technical Mgmt Service | uses reference attribute | Tech Mgmt Service Offering |
| Tech Mgmt Service Offering | **Contains** | **Service Instance** |
| Tech Mgmt Service Offering | **Contains** | **Dynamic CI Group** |
| Dynamic CI Group | Uses related list | Infrastructure CIs |
| *Service Portfolio | uses reference attribute | Business Service |
| Business Service | uses reference attribute | Business Service Offering |
| Business Service Offering | **Depends on** | **Service Instance** |

> **Key confirmation**: TSO (Tech Mgmt Service Offering) is the **parent** in the `Contains` relationship with Service Instance. BSO (Business Service Offering) is the **parent** in the `Depends on` relationship with Service Instance. This is consistent across all maturity level examples (Crawl, Walk, Run, Fly) in the deck.

### CCH Maturity Assessment

Based on the maturity diagrams in the CSDM Data Model Examples deck:

- **Crawl**: Business Application + Service Instance only — CCH has this
- **Walk**: Add Tech Mgmt Service + Tech Mgmt Service Offering — CCH has this (361 TMS, 735 TSOs)
- **Run**: Add Service Consumption (BSO → Service Instance, Business Service) — CCH has this (757 BSO→SI links, 1,294 BSOs)
- **Fly**: Add Business Capability, Service Portfolio, strategic relationships — CCH does not have this yet

CCH is at approximately **Run maturity** for CSDM v5.

---

### Key CSDM v5 Concepts

- Service Offerings do **NOT** link directly to Application Services / Service Instances without going through the defined relationship chain
- Lifecycle and ownership differ by domain (Service Consumption vs Design and Planning vs Service Delivery)
- The term "Application Service" (CSDM v4) is replaced by **Service Instance** in CSDM v5 — the table remains `cmdb_ci_service_auto`
- **Service Instances are the bridge** between business and technical layers. Service Instances (`cmdb_ci_service_auto`) are the only objects allowed to connect BOTH upward to the business domain AND downward to the technical domain. This matches the official CSDM v5 layering:
  - **Service Consumption**: Business Services and Offerings
  - **Design and Planning**: Business Applications
  - **Service Delivery**: Service Instances, Technology Management Services, TSOs, and Technical CIs

### Relationship type differentiations

**Prefer `uses :: used by` when:**
- Modelling capability consumption
- Linking applications to services
- Showing shared services or platforms
- Uncertain or partial failure scenarios

**Use `depends on :: used by` when:**
- Availability is binary
- SLA / outage / incident impact must propagate
- Removing the provider guarantees failure

---

## Part 2 — Incident Management HLD: Proposed Relationship Model

*Source: hld-sn-incident-management.md **(TBD)** sections 7.2.1–7.2.8*

The HLD proposes a CSDM-based escalation model with four levels. This section documents **what the HLD describes**, mapped to the same relationship structure as Part 1.

### Service-Centric Categorization (HLD 7.2.1)

- Each incident is categorized using a **Business Service Offering (BSO)**
- BSO represents the customer-facing service impacted by the incident
- BSO remains constant throughout the incident lifecycle — stored in `service_offering`
- Replaces legacy category-based and catalog-driven logic

### Incident Registration — BSO Path (HLD 7.2.2)

- User or system populates `service_offering` (BSO) on the incident
- System derives the **Application Service** (Service Instance) via `cmdb_rel_ci`:
  - Parent = BSO (`service_offering`)
  - Type = `Depends on :: Used by`
  - Child class = `cmdb_ci_service_auto` or `cmdb_ci_service_by_tags`
- Resolved Application Service is populated in `cmdb_ci`
- `assignment_group` is set from the BSO's `support_group`

### Escalation Model Structure (HLD 7.2.3)

| Level | Role | Service Offering | Field | Assignment |
|---|---|---|---|---|
| **L1** | Business Service | BSO | `service_offering` | BSO `support_group` |
| **L2** | Operations Support | TSO (Ops Support) | `u_technical_service_offering` | TSO `support_group` |
| **L3** | Technical Expertise | TSO (Tech Expertise) | `u_technical_service_offering` | TSO `support_group` |
| **L4** | DevOps Enablement | TSO (DevOps) | `u_technical_service_offering` | TSO `support_group` |

- BSO stays in `service_offering` at all times
- Escalation is tracked via `u_technical_service_offering` (custom field)
- Only offerings with `life_cycle_stage = Operational` and `life_cycle_stage_status = In Use` are eligible

### L1 → L2 Escalation: BSO to Operations Support (HLD 7.2.4)

The HLD describes this lookup via `cmdb_rel_ci`:

- Parent = Application Service (from `cmdb_ci`)
- Type = `Contains :: Contained by`
- Child = TSO classified as Operations Support

If single match → auto-populate `u_technical_service_offering` and update `assignment_group`.
If multiple matches → name-matching logic applied. If still ambiguous → Service Desk user prompted to select.

### L2 → L3 → L4 Escalation: Between Technical Levels (HLD 7.2.5)

- Uses `Depends on :: Used by` between TSOs in `cmdb_rel_ci`
- **L2 → L3**: requires escalation justification via modal dialog (stored in `u_reason_for_escalation`)
- **L3 → L4**: same relationship type, no justification required
- L2 is confirmed by verifying `Contains :: Contained by` relationship with Application Service in `cmdb_ci`

### De-Escalation (HLD 7.2.6)

- From L3 or L4 → user prompted to select target TSO
- Can return to Operations Support (L2) or directly to BSO level (L1)
- Uses the same `Depends on :: Used by` relationships in reverse
- BSO never changes during de-escalation

### CI-First Path (HLD 7.2.7)

When an agent selects a CI directly:

1. System checks if CI belongs to a **Dynamic CI Group**
2. If match → derives TSO from `cmdb_rel_ci` (TSO → `Contains :: Contained by` → Dynamic CI Group)
3. `u_technical_service_offering` populated, `assignment_group` set from TSO's `support_group`
4. BSO derived separately: CI → Application Service (via `svc_ci_assoc`) → BSO (via `cmdb_rel_ci`)

### Common TSO Selection (HLD 7.2.8)

- Available only after at least one escalation
- Filtered to: Operations Support classification, related Application Services in Production, part of current BSO's escalation chain, flagged as Common or Primary and Common

---

### HLD Relationship Summary

| From | Relationship | To | HLD Section |
|---|---|---|---|
| BSO | depends on :: used by | Service Instance (Application Service) | 7.2.2 |
| Service Instance | contains :: contained by | TSO (Operations Support) | 7.2.4 |
| TSO (L2) | depends on :: used by | TSO (L3) | 7.2.5 |
| TSO (L3) | depends on :: used by | TSO (L4) | 7.2.5 |
| TSO | contains :: contained by | Dynamic CI Group | 7.2.7 |
| CI | associated with (via `svc_ci_assoc`) | Service Instance | 7.2.7 |

---

## Comparison: CSDM v5 vs HLD

| Aspect | CSDM v5 (Part 1) | HLD (Part 2) | Status |
|---|---|---|---|
| Terminology | Service Instance | Application Service | Cosmetic gap — same table `cmdb_ci_service_auto` |
| BSO → Service Instance | `depends on :: used by` | `Depends on :: Used by` | **Compliant** |
| Service Instance ↔ TSO | TSO (parent) → `contains :: contained by` → Service Instance (child) | Application Service (parent) → `Contains :: Contained by` → TSO (child) | **Reversed** — HLD query returns 0 results in prod |
| TMS layer | Service Instance → TMS → TSO | Absent — direct Service Instance → TSO | **Missing layer** |
| TSO → TSO escalation | Not defined | `Depends on :: Used by` between TSOs (L2→L3→L4) | Custom — acceptable |
| Multi-match resolution | Pure relationship traversal | Name matching (`STARTSWITH`) | **Non-CSDM pattern** |
| Dynamic CI Groups | Not defined | TSO → `Contains :: Contained by` → Dynamic CI Group | Custom — only 7 records in prod |

---

## CCH Instance Verification (2–3 April 2026)

### Record counts

| Layer | Table | Count |
|---|---|---|
| Business Services (v5) | `cmdb_ci_service_business` | 444 (~360 operational) |
| Business Services (legacy) | `cmdb_ci_service` | 1,789 |
| Service Offerings | `service_offering` | 2,029 (1,293 business-facing) |
| Service Instances | `cmdb_ci_service_auto` | 10,194 |
| Technology Management Services | `cmdb_ci_service_technical` | 361 |

### Relationship coverage

| Link | Relationship | Records | Source |
|---|---|---|---|
| Service Offering → Service Instance | `Depends on :: Used by` | **870** | 3 April extract |
| TSO → Service Instance | `Contains :: Contained by` | **395** | 3 April extract |
| TSO → TSO (+ OT BS→SO + orphans) | `Depends on :: Used by` | **647** | 3 April extract |
| TSO → Dynamic CI Group | `Contains :: Contained by` | **7** | 3 April extract |
| Calculated App Service → Process Group | `Contains :: Contained by` | **456** | 3 April extract (Dynatrace discovery) |

### Key finding: Service Instance never parents Service Offering

Queried all 497 `cmdb_rel_ci` records where Service Instance is the parent. Child class breakdown:

| Child Class | Count |
|---|---|
| Server | 243 |
| Service Instance | 155 |
| Windows Server | 81 |
| Linux Server | 7 |
| Tag-Based Application Service | 6 |
| MS SQL Instance | 4 |
| Configuration Item | 1 |
| **Service Offering** | **0 (not present)** |

The HLD's section 7.2.4 query (parent = Application Service, child = TSO) returns **zero results** in the current CMDB. `CCHIncidentUtils` name matching compensates.

### Chain status

```
BSO → (Depends on :: Used by) → Service Instance ← (Contains :: Contained by) ← TSO
 ✅ 870 relationships                                ✅ 395 relationships (actively growing)

TSO (L2) → (Depends on :: Used by) → TSO (L3) → (Depends on :: Used by) → TSO (L4)
 ✅ 647 relationships (mixed — includes OT Business Service → SO and orphans)
```

> **Correction log:** Earlier version (2 April 2026) incorrectly stated the CSDM v5 chain used `Depends on :: Used by` from Service Instance to Technology Management Service. Corrected after reviewing Figure 16 of the CSDM v5 specification.

---

*Created: 2 April 2026 | Corrected: 3 April 2026 | Expanded with Part 2 and comparison: 3 April 2026*
