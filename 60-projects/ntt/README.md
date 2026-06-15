# NTT ↔ CCH ServiceNow Integration

**Status**: Draft — for team review. NTT DATA managed-service contract for CCH network and connectivity services (Cisco, Fortinet, Zscaler, Akamai, Claroty xDome / NAC4OT, Azure footprint).

**Shape**: NTT operates **through** CCH's existing tooling, not instead of it — a supplemental managed-service overlay. Two ServiceNow instances (**CCH SNOW** customer-facing master; **NTT GSNOW** supplier execution layer) bridged by NTT's **iHub** middleware. The design is **selective by process**:

| Practice | Mechanism |
|---|---|
| **Incident** | iHub e-bond — automated, bidirectional, 24×7 |
| **Request** | iHub e-bond — automated, bidirectional |
| **Configuration** | Manual CMDB sync (interim) → automated CI Batch job (long term) |
| **Problem** | Swivel-chair (ESIF) into CCH SNOW |
| **Change** | Swivel-chair (ESIF) into CCH SNOW — CAB approves before execution |

---

## What's here

The working design set for the integration, split across two HLDs by audience and lifecycle: the **ITSM e-bond** (INC + REQ) and **Configuration Management** (CMDB synchronisation). They are companions — the e-bond depends on the **CI + Managed Service mandatory** invariant defined in the CMDB HLD.

---

## Read in this order

| # | Document | Purpose |
|---|---|---|
| 1 | [blueprints/hld-ntt-servicenow-ebond.md](blueprints/hld-ntt-servicenow-ebond.md) | **Authoritative design** — INC + REQ e-bond over iHub: governance regimes (proactive NTT-raised vs reactive CCH-raised), service-operations model, integration mechanism per process, sync flows, requirements, state mapping / 3-Strike-Rule, conflict resolution & loop prevention, transition plan, risk register, data mapping appendix |
| 2 | [blueprints/hld-ntt-servicenow-cmdb-sync.md](blueprints/hld-ntt-servicenow-cmdb-sync.md) | **Companion design** — CMDB ownership & synchronisation: each party owns its CMDB; manual alignment (interim) → automated CI Batch job (long term); NTT GSNOW structure (Platform → Service Group → Managed Service → CLA); the CI + Managed Service mandatory invariant |

---

## Catalogue

### Blueprints — authoritative designs

| File | What it covers |
|---|---|
| [blueprints/hld-ntt-servicenow-ebond.md](blueprints/hld-ntt-servicenow-ebond.md) | Two-master model (CCH SNOW customer-facing + CAB authority; GSNOW execution); INC + REQ bidirectional e-bond via iHub; monitoring split by layer (LogicMonitor = network/infra, Dynatrace = application); ESIF swivel-chair for PRB + CHG; tiered support (Wipro L1 / GIOC / MCN·PDC·POD6 / OEMs); assignment-group-driven trigger model; correlation/loop-control via `correlation_id` + source-instance tag |
| [blueprints/hld-ntt-servicenow-cmdb-sync.md](blueprints/hld-ntt-servicenow-cmdb-sync.md) | CMDB per-instance ownership; manual sync process + reconciliation; long-term automated CI Batch job; NTT CMDB structure and Managed-Service tagging via LogicMonitor autodiscovery; CI + Managed Service mandatory (catch-all CI exception for CI-less CCH reactive incidents) |

---

## Open decisions to resolve

Tracked in the e-bond HLD §8.6; CMDB-specific ones also in the CMDB HLD §10.

| # | Decision | Status |
|--:|---|---|
| 1 | E-bond transport | **RESOLVED** — NTT iHub middleware (MAP + Digital Fabric) |
| 2 | CMDB manual-sync process — cadence, ownership-per-class, reconciliation | OPEN |
| 3 | Attachment propagation — binary vs link-back | PROPOSED — link-back with size threshold |
| 4 | Trigger / assignment-group mapping model (NTT's 5 GSNOW groups ↔ CCH groups) | OPEN — confirm with both SN owners |
| 5 | State map vs real per-instance state values | PROPOSED — §8.4 |
| 6 | Swivel-chair traceability — cross-reference + reconciliation report (PRB/CHG) | PROPOSED |
| 7 | Out-of-hours handling for business-hours processes | OPEN |
| 8 | Major-incident (P1) bridging across instances | OPEN — time-critical |
| 9 | Cross-instance CI reference for business impact (NTT CI ↔ CCH application) | OPEN |

---

## Reference pillars

Links out to the shared reference pillars rather than duplicating them:

- [[correlation_id]] — the cross-instance identifier the INC/REQ e-bond keys on
- [[sys_object_source]] — the cross-source CI identifier relevant to the CMDB alignment
- [[15-servicenow-ref/README|15-servicenow-ref]] — ServiceNow platform mechanics

---

## Layout

```
ntt/
├── README.md                                  ← this file
└── blueprints/                                ← authoritative designs (companion pair)
    ├── hld-ntt-servicenow-ebond.md            ← ITSM e-bond: INC + REQ
    └── hld-ntt-servicenow-cmdb-sync.md        ← Configuration Management: CMDB sync
```
