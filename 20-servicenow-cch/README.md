# 20-servicenow-cch

ServiceNow as deployed at CCH — current-state reality. Org structure, CI inventory, service catalogue, known data quality gaps, dated observations on the customer instance. Reflects what *is*, not what *should be* — for the generic ServiceNow platform view see [[15-servicenow-ref]], for the framework canon see [[10-csdm]], and for cross-pillar wiring see [[50-mappings]]. Pairs with [[40-dynatrace-cch]] on the observability side.

## `artifacts/` — engagement-time deliverables

Finalised CCH analysis documents duplicated from the active project repos. Each is a frozen snapshot; the live working copy lives in `platform-z/projects/<project>/`. Snapshot date is in the header of each file.

| Artefact | Scope | Vault-x backdrop |
|---|---|---|
| `dt-incident-routing-2026-06.md` | Current-state assessment of DT-induced incident routing — funnel, FortiGate misroute, BSO/TSO split, the four populator BRs, configuration defect with fix | Process backdrop: [[70-processes/incident/incident-management-process]]. CSDM model backdrop: [[10-csdm/incident-assignment-bso-tso]], [[10-csdm/csdm-v5-relationship-chain]]. Platform mechanics: [[15-servicenow-ref/glide-record]], [[15-servicenow-ref/sys_id]]. |
| `business-rules-on-incident.md` | Per-rule code-level analysis of the three populator business rules on `incident` (Populate Service Offering, CCH-Map Inc Category, INC - Fill Assignment group on save) plus the integration-scope `Populate Dynatrace Affected CIs` | Platform mechanics: [[15-servicenow-ref/glide-record]]. Process role: [[70-processes/incident/incident-management-process]] §1 *"Incident is a consumer of CSDM data"*. |
| `transform-map-analysis.md` | Code-level analysis of the `Problem to Incident Transformation Map` (9 field maps + 2 onBefore scripts) — what the transform map writes vs. what's populated downstream | Backdrop is the same as the routing artefact — both are companion pieces to the same investigation. The transform map analysis explains the *integration entry point*; the routing analysis explains the *downstream populator chain* that fills the gaps. |
| `csdm-v5-service-relationship-model.md` | CSDM v5 relationship chain reference **as captured at engagement time (4 April 2026)** — includes (a) the canonical chain from SN sources, (b) the HLD proposed Incident Management model, (c) CCH instance verification with live relationship counts (870 BSO→SI, 395 TSO→SI, 647 TSO→TSO) | Substantively overlaps with vault-x canonical content: the canonical generic chain is in [[10-csdm/csdm-v5-relationship-chain]] and the BSO/TSO incident framing is in [[10-csdm/incident-assignment-bso-tso]]. Keep this artefact as the **frozen engagement-time evidence** with CCH counts; treat the [[10-csdm]] notes as the canonical reference. |

### How the four artefacts relate

```
                    ┌─────────────────────────────────────────────┐
                    │  csdm-v5-service-relationship-model         │
                    │  (the BACKDROP — what v5 says, what CCH has)│
                    └────────────────────┬────────────────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              ▼                          ▼                          ▼
   ┌──────────────────┐      ┌────────────────────┐      ┌──────────────────┐
   │ transform-map-   │      │  dt-incident-      │      │ business-rules-  │
   │ analysis         │      │  routing-2026-06   │      │ on-incident      │
   │                  │      │                    │      │                  │
   │ what the         │ ◄──► │ what the data      │ ◄──► │ per-rule code    │
   │ integration      │      │ shows + the four   │      │ for the three    │
   │ writes           │      │ populator chain    │      │ populator BRs    │
   └──────────────────┘      └────────────────────┘      └──────────────────┘
```

The routing assessment is the central narrative; the transform-map and business-rules artefacts are its code-level evidence companions; the v5 relationship model is the reference backdrop.
