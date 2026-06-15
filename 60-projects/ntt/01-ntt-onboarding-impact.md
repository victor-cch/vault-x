# 01 — NTT Onboarding Impact on CCH ServiceNow + Dynatrace

**Scope**: Executive summary of what NTT taking over network and connectivity services means specifically for CCH's existing ServiceNow, Dynatrace, and CMDB stack. Not a contract summary — focuses on the operational/architectural footprint inside CCH's tooling.
**Audience**: Anyone needing to understand the NTT impact in 3 minutes — IT leadership, CSDM lead, ServiceNow admin, Dynatrace tenant admin, incoming colleagues.
**Source basis**: [daily log 2026-05-04](daily-log/2026-05-04.md) — comprehensive 9-stage record of the analysis. This file is the digest; the daily log is the audit trail.

---

## Headline

NTT operates **through** CCH's existing tools, not **instead of** them. The supplier is layered on top of the current Dynatrace + ServiceNow + CMDB ecosystem, with NTT's own ServiceNow acting as a secondary mirror via e-bond.

This is a **supplemental managed-service overlay**, not an outsourcing-with-replacement model.

---

## Dynatrace — stays in place, NTT becomes a consumer

| Aspect | What changes | What doesn't |
|---|---|---|
| Tool itself | Stays in place (RFP §2.4.1; NTT RACI line confirms NTT consumes from Dynatrace) | Tenant remains CCH's; no migration |
| Operations | NTT users on the tenant; they drive Davis problem rules, alerting profiles, dashboards | CCH retains tenant ownership |
| Integration | NTT's own AIOps tooling may layer on via API per RFP §2.4 | Dynatrace remains the authoritative observability layer |

### Inherited problem — AIOps SLAs unmeetable Day 1

NTT inherits the *current* Dynatrace state — including everything we found in the [SAP investigation](../sap/daily-log/2026-05-04.md):

- **B1**: zero alerting profiles scoped to `PRD_S4HANA` MZ → all SAP problems silent end-to-end
- **B3**: Davis problem rules absent on the rich existing telemetry (RFC failures, HTTP errors, ICM availability, HANA replication, CPI iFlow business events, API-Management metrics)
- **Class 4 tile rot** on multiple SAP dashboard tiles
- **Custom HANA telemetry** via Borislav-pattern (4 metrics — replication state + table growth) not surfaced on dashboards

The RFP demands AIOps SLAs of **MTTD <15 min, MTTR <24 h, ≥95% proactive resolution, ≥60% automation coverage**. These are unmeetable Day 1 without first remediating the gaps.

**Choice point**: either CCH fixes B1 before Service Commencement, or NTT inherits unmeetable SLAs from the moment they take over. Either path needs to be agreed before signature.

---

## ServiceNow — two-layer model with e-bond

| Layer | Whose SN? | Role |
|---|---|---|
| Customer-facing | **CCH's ServiceNow** | Source of truth for CCH's view: user-reported tickets, CMDB, business-impact correlation, SLA reporting to CCH leadership |
| Supplier-internal | **NTT's ServiceNow** | Where NTT engineers actually work — paging, on-call routing, multi-client portfolio, internal SLA tracking, OEM escalation |

**E-bond** (bidirectional INC + CHG) keeps the two layers synchronised. The same ticket exists in both systems; status, comments, attachments propagate across.

### CHG e-bond is the load-bearing piece

CCH retains CAB authority per NTT SOW §C.7. Every change touching CCH infrastructure — even when NTT plans and executes it — must surface in CCH SN for CAB approval **before execution**. This is the non-negotiable control CCH retains.

| Direction | Pattern |
|---|---|
| INC: CCH → NTT | User reports issue in CCH SN; NTT engineer needs it in their queue / paging / on-call routing |
| INC: NTT → CCH | NTT AIOps generates auto-incident; surfaces to CCH for visibility + SLA |
| CHG: NTT → CCH | NTT plans change against CCH infra; appears in CCH SN for CAB review; NTT executes only after approval |
| CHG: CCH → NTT | CCH application team raises change request; e-bonds to NTT for execution |

### Tiered support model

| Level | Owner | Notes |
|---|---|---|
| L1 | **Wipro** (CCH service desk, outsourced) | Triage, ticket intake, KB-driven self-service resolution |
| L2 / L3 | **NTT** | GIOC for triage 24/7; MCN for network L2+; PDC for security L2+; ESIF for major incidents + business-hours processes |
| L4 | **OEMs** (Cisco, Fortinet, Zscaler, Claroty, Akamai) | Product-level fixes, firmware, advanced diagnostics |

NTT acts on behalf of CCH for OEM ticket creation and live troubleshooting.

---

## CMDB — fourth pipe + co-management

CCH CMDB now has **four source pipes** instead of three:

1. Manual
2. Cisco DNA
3. Dynatrace
4. **NTT (writes directly per NTT SOW §2.6.4)**

An **authoritative-source-per-class matrix** is required to prevent conflicting CIs across pipes. This is design work that hasn't been done yet.

### Co-management constraint (NTT SOW §C.9)

From Service Commencement, **CCH gives up read-write access to in-scope devices**. CCH retains read-only access to monitoring and reporting.

This is a real operational shift. Current CCH teams making config changes need to transition to ticket-driven workflow with NTT executing via the e-bonded CHG process. Break-glass procedure exists for emergencies but carries SLA suspension and chargeable cleanup — discouragement is structural.

---

## What's structurally new

| New element | Origin |
|---|---|
| Two-layer ITSM with cross-instance e-bond | Standard MSP pattern, contractually formalised |
| 4-source CMDB topology + authoritative-source matrix requirement | NTT joining as 4th writer |
| 24/7 incident response + business-hours-only Change / Problem / Request | NTT SOW §C.3 service hour split |
| CCH read-only on devices + break-glass exception path | NTT SOW §C.9 + Attachment H |
| Soft SLA regime (commercially reasonable efforts + service credits at ≥3 failures / 12 mo) | Attachment I structure |
| Client-PAM-Named-Accounts model (CCH retains identity kill-switch over NTT access) | Attachment H.2 |

---

## What needs to happen before this works end-to-end

1. **B1 remediation in Dynatrace** — single alerting profile on `PRD_S4HANA`; otherwise AIOps SLAs are unmeetable. Cheapest single fix; ~30 min.
2. **E-bond design** — field mappings, sync triggers, conflict resolution, attachment behaviour. Non-trivial design work.
3. **Authoritative-source matrix for CMDB** — per CI class, which of the 4 pipes wins.
4. **Cross-boundary CSDM modelling** — file 04's BSO/TSO Parent-Child pattern across two SN instances when an NTT-side infra incident affects a CCH-side application.
5. **Operational process redesign** — current direct-config workflows transition to ticket-driven via e-bond.
6. **Pre-signature contractual items** — final SLA values (Attachment I tables), charges (M.3 TBC), term/termination (Attachment L missing), ISO 27001:2022 alignment.

---

## Net effect on the SAP work captured today

**Unchanged.** Files [SAP 02](../sap/02-dt-monitoring-sap.md) and [SAP 04](../sap/04-csdm-v5-incident-automation.md) describe application-tier scope CCH retains. NTT inherits the analysis, not replaces it. The B1 / B3 / B4 blockers identified in the SAP investigation are now joint workstreams (CCH design + NTT execution post-transition) rather than CCH-only problems.

The SAP daily log and the user-guide files become part of the Transition-In knowledge transfer regardless of who closes the gaps.

---

## At a glance

| Question | Answer |
|---|---|
| Does Dynatrace go away? | No — it stays. NTT consumes and contributes. |
| Does CCH ServiceNow go away? | No — it remains the customer-facing source of truth. |
| Is there a second ServiceNow? | Yes — NTT's, used for their global ops. E-bond syncs the two. |
| Who approves changes against CCH infrastructure? | CCH's CAB. Always. Even if NTT plans and executes. |
| Who has read-write on managed devices? | NTT, exclusively, after Service Commencement. CCH break-glass for emergencies. |
| Who writes to CCH CMDB? | NTT for in-scope devices, plus the existing manual + Cisco DNA + Dynatrace pipes. |
| Are SLAs hard contractual obligations? | No — "commercially reasonable efforts" + voluntary service credits after 3 failures in 12 months. |
| Does this disrupt the SAP incident-routing work? | No. SAP sits in CCH's retained application-tier scope. The work transfers to NTT operationally; the analysis stays valid. |

---

*Created: 4 May 2026 — distilled from the [2026-05-04 daily log](daily-log/2026-05-04.md) at the close of the first NTT-discussion session.*
