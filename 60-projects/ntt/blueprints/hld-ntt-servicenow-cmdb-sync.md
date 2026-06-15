# NTT ↔ CCH ServiceNow Integration — HLD (Configuration Management · CMDB Synchronisation)

---

## 1. Document Control

**Date**: 2026-06-13<br>
**Status**: Draft — for team review<br>
**Author**: Victor Andreev

## 2. Sign-offs

| Name | Role |
|---|---|
| | Configuration Manager / CSDM Architect (CCH) |
| | Service Owner — ServiceNow (CCH) |
| | Service Owner — GSNOW (NTT) |
| | Service Delivery Manager — NTT |

## 3. Introduction

This blueprint defines the **Configuration Management** integration between **CCH's ServiceNow (CCH SNOW)** and **NTT DATA's ServiceNow (GSNOW)** for the NTT managed-service contract. It is the companion to the **ITSM e-bond HLD** (`hld-ntt-servicenow-ebond.md`), which covers Incident and Request synchronisation and depends on the **CI + Managed Service** invariant defined here.

Each party **owns and manages its own CMDB**; neither writes directly into the other's. Cross-instance alignment is **manual** in the interim, moving to an automated **CI Batch job** long term. **CI + Managed Service are mandatory** on every ticket in either platform, which keeps the two CMDBs reconcilable.

## 4. Scope

### 4.1 In scope

- **CMDB ownership** — each party owns its own CMDB; the alignment process across the two instances
- **Manual CMDB synchronisation** (interim) — an agreed process aligning the in-scope CIs across CCH SNOW and GSNOW
- **CI Batch job** (long term) — the automated cross-instance sync that replaces the manual process <span style="color:red">**(TBC — cadence, scope, direction; Decision #2)**</span>
- **CI + Managed Service mandatory** invariant on tickets (with the catch-all exception for CI-less CCH reactive incidents)
- **NTT GSNOW CMDB structure** — Platform → Service Group → Managed Service, with Cloud Accounts
- **CCH SNOW CMDB population** — via CCH's existing pipes (manual + Cisco DNA + Dynatrace)
- **Reconciliation** of the in-scope CI set across the two instances

### 4.2 Out of scope

- **The INC/REQ e-bond** and its triggers, state mapping, and loop control — see the e-bond HLD
- **Full CI-class schema / CSDM model** detail — owned by the CCH Configuration Manager / CSDM architect
- **SOM operational inventories** (full Platform/SG/MS/CLA, cloud-account and location inventories) — these live in the **Service Operations Manual**

### 4.3 Scope Boundaries

- **CMDB is owned per-instance** — neither side writes directly into the other's CMDB; alignment is an agreed process.
- **Manual is the interim, batch is the target** — the CI Batch job supersedes the manual process once implemented.
- **CI + Managed Service mandatory** is the contract the e-bond relies on to keep records reconcilable.

## 5. Current State

Greenfield — each party holds its own CMDB independently; no alignment process exists between them. CCH SNOW is populated via CCH's existing pipes (manual + Cisco DNA + Dynatrace); GSNOW is populated via LogicMonitor autodiscovery + Managed-Service tagging.

## 6. Future State

- Each party maintains its own CMDB; an agreed **manual synchronisation** keeps in-scope CIs aligned (interim).
- **CI + Managed Service are mandatory** on every ticket in either platform; CI-less CCH reactive incidents route to a **catch-all CI** as an interim, with CCH ensuring a CI is present going forward.
- **Long term**, an automated **CI Batch job** replaces the manual sync.

## 7. Solution Design

### 7.1 CMDB Ownership & Synchronisation

Each party **owns and manages its own CMDB**; cross-instance synchronisation is **manual**, following a process agreed by CCH and NTT service-management representatives. **CI + Managed Service are mandatory** on every ticket in either platform, which keeps the two CMDBs reconcilable.

**Long term**, the manual sync is replaced by an automated **CI Batch job** between the two instances <span style="color:red">**(TBC — cadence, scope, and direction to be defined; Decision #2)**</span>. Manual synchronisation is the interim until the batch job is implemented.

### 7.2 NTT GSNOW CMDB structure

CIs are organised as **Platform (PL) → Service Group (SG) → Managed Service (MS)**, with **Cloud Accounts (CLA)** assigned to platforms. Population is via **LogicMonitor autodiscovery + Managed-Service tagging**: a CI tagged with the correct Managed Service appears in GSNOW with `Status=Discovered`, in the correct Platform/Service Group, with managed services configured. Cloud accounts are Azure (West EU / North EU). Illustrative platforms:

| Platform (PL) | Contents |
|---|---|
| Sitepod | NTT tooling (LogicMonitor, XTAM, Salt, Ansible) |
| CCHBC Network Enhanced Production | NW Appliances + PaaS (CLA: Azure) |
| CCHBC OT Network | NW Appliances + PaaS (OT) |
| CCHBC Network | NW Appliances + PaaS |
| CCHBC SRA 2021 Production | NW Appliances + PaaS |
| Networking | On-prem NW appliances and consoles |

Detailed Platform/SG/MS/CLA inventory is maintained in the **SOM** — <span style="color:red">**(TBD: full CMDB inventory — see SOM Appendix.)**</span>

### 7.3 CCH SNOW CMDB

Populated via CCH's existing pipes (manual + Cisco DNA + Dynatrace). The manual sync aligns the in-scope CIs across the two instances.

> <span style="color:red">**(TBD — diagram: CMDB structure (Platform → Service Group → Managed Service → CLA) and CI↔Managed-Service tagging. To be supplied next version.)**</span>

## 8. Requirements

| ID | Requirement |
|---|---|
| FR-1 | **CI and Managed Service are mandatory** on any ticket created in either platform. Exception: reactive incidents raised by CCH may lack a CI, in which case NTT routes them to a **catch-all CI** (interim); CCH ensures a CI is present going forward |
| FR-2 | CMDB synchronisation between CCH SNOW and GSNOW follows the agreed **manual** process; neither side writes directly into the other's CMDB |
| FR-3 | The in-scope CI set is reconciled across the two instances at an agreed cadence <span style="color:red">**(TBC — Decision #2)**</span> |
| FR-4 | Long term, the manual sync is replaced by an automated **CI Batch job** <span style="color:red">**(TBC — Decision #2)**</span> |

## 9. Implementation

**Manual synchronisation (interim):**

1. Agree the manual sync process — cadence, per-class ownership, and reconciliation cycle — with CCH and NTT service management (Decision #1).
2. Enforce **CI + Managed Service mandatory** on tickets in both platforms (the invariant the e-bond depends on; FR-1) — enforced on the ticket forms, catch-all CI as the interim exception.
3. NTT: confirm **LogicMonitor autodiscovery + Managed-Service tagging** populates GSNOW (Platform → Service Group → Managed Service) correctly.
4. CCH: maintain the CCH SNOW CMDB via existing pipes (manual + Cisco DNA + Dynatrace); align the in-scope CIs to GSNOW at the agreed cadence.
5. Periodic manual review/alignment of the in-scope CI set across the two instances.

**Automated CI Batch job (long term):**

6. Implement the automated **CI Batch job** between the two instances (Decision #2), retiring the manual process once proven.

## 10. Open Design Decisions

| # | Question | Status |
|--:|---|---|
| 1 | CMDB manual-sync process — cadence, ownership-per-class, reconciliation cycle | OPEN — agree with CCH + NTT service management (e-bond HLD Decision #2) |
| 2 | CI Batch job — cadence, scope, direction | OPEN |
| 3 | Cross-instance CI reference for business impact (NTT CI ↔ CCH application, e.g. SAP) | OPEN |

## 11. References

- NTT DATA Statement of Work v2.0 (28 April 2026) — §2.6.4 (CMDB)
- CCH Network Management & Connectivity Services RFP v1.1 (Sept 2025) — §2.6.4 (CMDB)
- NTT **Service Operations Manual** (Coca-Cola HBC) — source for the CMDB structure and Managed-Service tagging
- Companion: **ITSM e-bond HLD** (`hld-ntt-servicenow-ebond.md`) — Incident + Request e-bond that depends on the CI + Managed Service invariant
