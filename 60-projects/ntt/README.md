# NTT Sub-Project

**Parent**: [project-cchbc](../../README.md)
**Status**: Scaffold — work just starting (May 2026)
**Scope**: NTT DATA managed-service contract for CCH network and connectivity services — operational integration with CCH's existing Dynatrace, ServiceNow, and CMDB ecosystem

---

## Why this exists

CCH has signed (or is finalising) a major managed-service contract with **NTT DATA** to operate and support its network and connectivity infrastructure — Cisco, Fortinet, Zscaler, Akamai Guardicore, Claroty xDome (NAC4OT), and the entire Azure network footprint. This is a multi-year, multi-thousand-device, multi-tower scope that fundamentally reshapes how CCH operates network/security infrastructure and how operational signals flow into CCH's incident-management chain.

The relationship has two surfaces that must be designed together:

- **Operational**: NTT becomes the hands-on-keyboard owner of the in-scope estate (devices, configurations, monitoring response). CCH gives up read-write access and retains read-only visibility plus governance authority (CAB, security policy, SLA enforcement).
- **Integrational**: NTT runs its own ServiceNow + tooling stack for global operations. The two ServiceNow platforms must be e-bonded for INC and CHG synchronisation. CCH's Dynatrace remains and is consumed/integrated with by NTT per contract.

This is a different shape of complexity than the SAP sub-project — there it's discovery + config + tagging gaps inside CCH's own estate; here it's a cross-organisational integration design where decisions made in one ServiceNow propagate (or fail to propagate) into another.

The boundary: anything **NTT-contract-specific** lives here. Anything cross-cutting that happens to mention NTT as an example stays at the project root.

---

## Scope and open questions

To be filled in as the work progresses. Initial seed list:

- **Two-SOW reconciliation** — CCH's Network Management & Connectivity Services RFP (v1.1, Sept 2025) and NTT DATA's responding Statement of Work (v2.0, 28 April 2026) — do they cohere or do gaps need closing before signature? Notable items still TBC in NTT SOW: charges (M.3), Term and Termination (Attachment L), specific SLA values (Attachment I tables), Operating Model detail (Attachment J).
- **SLA enforceability tension** — Attachment I opens with "no liability, no remedy" then I.8 defines a service credit model. Reconciliation: service credits are voluntary mechanism only after 3 failures in 12 months; not contractual breach remedies. Soft SLA regime; CCH should review with legal.
- **Internal date inconsistency** — Attachment M says partial transition commences 1 April / completes 12 July; Stage 6 says Guardicore onboards 1 Nov 2026 with parallel run Jan 2027. Year of M.1 dates needs clarification.
- **Pre-signature items** — contract not yet executed (Attachment N signature blocks blank). Charges TBC, Term/Termination missing, ISO 27001:2013 (older standard, current is :2022).
- **E-bond design** — INC and CHG bidirectional sync between CCH SN and NTT SN; field mappings, status synchronisation, attachment propagation, conflict resolution. CHG is the load-bearing case (CCH retains CAB authority).
- **Co-management model** — per NTT SOW Section C.9, CCH gives up read-write access to in-scope devices at Service Commencement. Break-the-glass procedure, exception handling, and audit trail design.
- **Dynatrace integration mode** — RFP Section 2.4.1 explicitly preserves CCH's Dynatrace and asks NTT to either use it or integrate with it. Which mode? Direct user accounts on CCH tenant, or API-based integration from NTT's tooling?
- **Tiered support model** — L1 = Wipro (CCH service desk), L2/L3 = NTT (GIOC / MCN / PDC), L4 = OEMs (Cisco, Fortinet, Zscaler, Claroty, Akamai). NTT acts on behalf of CCH for OEM ticketing.
- **Service hour split** — Incident management is 24x7 (NTT GIOC for L1 triage, MCN/PDC for L2+); Problem/Request/Change/Reporting are business-hours only (ESIF). Operational design needs to reflect this asymmetry.
- **Transition planning** — Guardicore: 1 Nov 2026 onboarding, knowledge transfer mid-Nov to 31 Dec, parallel run Jan 2027 with no SLA. Other towers tbd.
- **CMDB authoritative-source matrix** — current CCH topology is manual + Cisco DNA + Dynatrace; NTT becomes a fourth contributor (per RFP Section 2.6.4 they update CCH CMDB directly). Authoritative-source-per-class matrix needs design.
- **Cross-boundary CSDM** — when an NTT-managed infra CI fails, the FYI/incident must correlate with CCH-side application incidents (e.g. SAP) for business-impact context. Relationship import design.
- **NAC4OT (Claroty xDome SA)** — 53 active on-prem access points; managed by NTT under a specific RACI (separate from xDome non-Remote-Access scope which is also NTT-operated).
- **Out-of-scope clarification** — NTT explicitly excludes SOC-level security operations, physical interventions, end-user connectivity, RMA physical receipt. CCH retains these.

---

## Layout

```
projects/ntt/
├── README.md                              ← this file
├── 01-ntt-onboarding-impact.md            ← executive summary: NTT's footprint inside CCH SN/Dynatrace/CMDB
└── daily-log/                             ← session-by-session notes
    └── 2026-05-04.md                      ← initial NTT discussion + 2 SOWs analysed (9 stages, comprehensive)
```

When subfolders are warranted, mirror the project conventions: `assessments/`, `hld/`, `use-cases/`, `scripts/`, `notes/`, `refs/`.

Further numbered files (`02-ebond-design.md`, `03-cmdb-authoritative-source-matrix.md`, etc.) will emerge as the analysis deepens.

---

## Key parties and acronyms

| Term | Meaning |
|---|---|
| **CCB Management Services GmbH** | The contracting Client entity on the NTT SOW (the corporate vehicle behind CCH for this contract) |
| **NTT DATA Inc.** | Top-line contractor name |
| **NTT Switzerland SA** | The NTT DATA legal entity actually delivering services per the SOW |
| **GIOC** | NTT Global Incident Operations Center — L1 triage, 24/7 |
| **MCN** | NTT Managed Cloud Network team — L2+ for network (LAN/WAN/FWL/Zscaler), 24/7 |
| **PDC** | NTT Professional Delivery Center — L2+ for security (Guardicore, Claroty), 24/7 on-call |
| **ESIF** | NTT Emergency Service Incident Framework — Major Incident Mgmt 24/7 on-call; Problem/Request/Change/Reporting business hours only |
| **NAC4OT** | CCH internal naming for the OT NAC capability; technically deployed on **Claroty xDome Secure Access (xDome SA / xSA)** |
| **xDome** | Broader Claroty CPS platform (Asset Discovery, Exposure Mgmt, Network Protection, Threat Detection) — separate scope from xSA |
| **CFC** | CCH Cyber Fusion Center — internal SOC; receives logs from network systems |
| **Wipro** | CCH outsourced service desk (L1) |

---

## Cross-links to existing CCH artifacts that touch NTT

| Artifact | NTT relevance |
|---|---|
| [01 — NTT Onboarding Impact](01-ntt-onboarding-impact.md) | Executive summary — NTT's footprint inside CCH ServiceNow + Dynatrace + CMDB |
| [Daily log 2026-05-04](daily-log/2026-05-04.md) | Initial NTT discussion + verbatim capture of both SOWs (CCH RFP + NTT response) across 9 stages |

(More will accumulate as the work progresses.)

---

*Created: 4 May 2026*
