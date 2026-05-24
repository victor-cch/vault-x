# `u_sp_ebond_config` — Service Provider E-Bond Config (custom, planned)

**Domain**: *(operational config table — not strictly a CSDM CI class, but referenced from INC/CMDB design)*
**Extends**: `sys_metadata` or similar — TBD when designed
**Status**: Custom-planned

## What it represents

A proposed per-SP configuration table to carry the parameters that differ between e-bonded service providers (NTT, Orange, …) under a multi-SP managed-service model. The shape of this table emerged from the gap-analysis daily logs and is the proposed mechanism to drive the per-SP behaviour the INC HLD currently does not parameterise.

## Likely fields

| Field | Type | Notes |
|---|---|---|
| `sp_name` | reference (Company) | Which SP this config belongs to |
| `strike_interval_hours` | int | e.g. 48h for NTT's 3-strike rule |
| `strike_count` | int | e.g. 3 |
| `ola_target_minutes` | int | Per-SP OLA target |
| `auto_close_days` | int | NTT=3, Orange=5, CCH default=7 — the divergent timer that prompted the gap analysis |
| `source_of_authority_detect` | choice | SP / CCH / Joint |
| `source_of_authority_resolve` | choice | SP / CCH / Joint |
| `source_of_authority_close` | choice | SP / CCH / Joint |

## Notes / decisions

- Originated from the **"source of authority per lifecycle stage"** abstraction proposed in the 2026-05-16 e-bond amendments session.
- Cross-cuts INC HLD (per-SP behaviour) and SLM-as-data work (the OLA stub mentioned in the SLM-sequencing log shares this data model).
- Also discussed alongside the CMDB-sync design — the e-bond depends on CI references that come via the CMDB-sync layer.

## Encountered in

- [Daily log — SP e-bond amendments (2026-05-16)](../../../daily-log/2026-05-16-inc-mgmt-sp-ebond-amendments.md) — where the config-table idea was first opened
- [Daily log — Reporting + SLM sequencing (2026-05-16)](../../../daily-log/2026-05-16-inc-mgmt-reporting-slm-sequencing.md) — shared data model with SLM-as-data
- [Daily log — NTT integration architecture (2026-05-16)](../../../daily-log/2026-05-16-ntt-integration-architecture.md) — interlock with CMDB sync
- [Daily log — SP pause / task back / 3-strike unhappy path (2026-05-12)](../../../daily-log/2026-05-12-inc-mgmt-sp-pause-task-back-unhappy-path.md) — the originating gap
- [Observation — SP e-bond timing gaps in the IM HLD](../../../blueprints/incident-management/observation-sp-ebond-timing-gaps.md) — formal observation doc
