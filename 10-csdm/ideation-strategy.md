# Ideation & Strategy

**CSDM v5 domain — Ideation & Strategy** *(new in v5)*

The strategic-investment layer. Captures the **ideas, planning items, goals, and targets** that drive what gets built. Tables here are mostly outside the CMDB and live in Strategic Portfolio Management (SPM) namespaces (`sn_align_core_*`, `sn_gf_*`).

This domain is the **front of the lifecycle** — an idea is captured here, enriched in Design & Planning, developed in Build & Integration, released through Service Delivery, consumed through Service Consumption.

## Ideation & Strategy entities

| Entity | Table | Purpose |
|---|---|---|
| Product Idea | `sn_align_core_product_idea` | An idea that can be curated/promoted into demand, project, epic, or story |
| Planning Item | `sn_align_core_planning_item` | Any work that can be aligned to goals, planned, executed (demands, projects, epics) |
| Strategic Plan | `sn_gf_plan` | Mission, Vision, Value statement |
| Strategic Priority | `sn_gf_strategy` | Key focus areas driving long-term goals; cross-functional |
| Goal | `sn_gf_goal` | Broad outcomes; often per-business-unit |
| Target | `sn_gf_goal_target` | Quantifiable measure for a Goal |

## Foundational entities that contribute

- **Product Models** — ideas and planning items relate to new or existing products
- **Value Streams / Stages** — relate organisational goals and strategic planning to the value sought
- **Business Process** — supports understanding of activities required for goals/targets

## What this domain is NOT

Despite the "strategy" framing, this domain does **not** contain:
- Business Capability — that's [design-planning](design-planning.md)
- Business Service — that's [service-consumption](service-consumption.md)
- Service Portfolio — that's [manage-portfolios](manage-portfolios.md)

The split is deliberate: SPM tables handle abstract investment intent; CMDB tables handle the realised model.

## Class notes

*(none yet — engagement work has not landed here. SPM-led implementations would populate this domain first.)*

## Related notes

- [README](README.md)
- [design-planning](design-planning.md) — the downstream domain when an idea is approved
