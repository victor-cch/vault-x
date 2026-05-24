# CSDM v5 — Personal Knowledge Graph

**Purpose**: a working map of CSDM v5 as it appears in real engagements — record counts, label changes, relationship traps, incident routing decisions — wired together as an Obsidian-friendly graph so backlinks surface "where did we touch this before?" without manual grep.

Two kinds of pages live here:

- **Maps of Content (MOCs)** — opinionated explainers of *how a piece of v5 actually works in practice* (incident assignment, BIA, bottom-up service mapping). These are written from real engagement evidence; they replace the official whitepaper when the official text is too abstract to act on.
- **Class notes** — one per CI class or table encountered in real work. Records what the class is *for*, the relationships that matter, real CCH evidence (record counts, gotchas), and where the class came up in projects/daily-logs/blueprints.

## CSDM v5 in one minute

The model has **seven domains** — Foundation underpins five lifecycle-stage domains, plus Manage Portfolios spans across them. Most engagement work touches three: **Design & Planning** (the application portfolio), **Service Delivery** (where the bridge between business and technical CIs lives), and **Service Consumption** (the business-facing offerings).

The **Service Instance** (`cmdb_ci_service_auto`, formerly "Application Service" in CSDM v4) is the load-bearing class — the only one allowed to span both sides of the model. Above it sits the **Business Service Offering (BSO)** for the consumer view; below it sits the **Technology Management Service** (`cmdb_ci_service_technical`, formerly "Technical Service") and its **TSO** for the provider view. **The chain only works if `cmdb_rel_ci` carries the right relationship types** — see [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md).

> **Label changes vs CSDM v3/v4** — tables didn't move, only the human-facing labels changed:
> - Application Service → **Service Instance** (`cmdb_ci_service_auto`)
> - Technical Service → **Technology Management Service** (`cmdb_ci_service_technical`)
> - Technical Service Offering → **Technology Management Service Offering** (still `service_offering` with `service_classification = Technical Service`)

## Vault structure

```
csdm-v5/
├── README.md                          — this file
├── _template-class.md                 — template for new class notes
│
├── DOMAIN INDEXES (7 v5 domains)
│   ├── foundation.md                  — Common Data, Value Stream, Product Models, Life Cycle
│   ├── ideation-strategy.md           — Product Idea, Planning Item, Goal (new in v5)
│   ├── design-planning.md             — Business Capability, Business Application, Information Object
│   ├── build-integration.md           — SDLC Component, DevOps Change, AI digital assets
│   ├── service-delivery.md            — Service Instance, TMS, TSO, infrastructure CIs (merges old "Manage Technical Services" + "Operate")
│   ├── service-consumption.md         — Business Service, BSO, Request Catalog
│   └── manage-portfolios.md           — Service Portfolio (cross-domain)
│
├── MAPS OF CONTENT (opinionated explainers)
│   ├── csdm-v5-relationship-chain.md  — the relationship reference (BSO ↔ SI ↔ TSO)
│   ├── service-mapping-bottom-up.md   — CI → calculated service → DCG → BA → BS → BSO
│   ├── incident-assignment-bso-tso.md — BSO incident, TSO escalation, parent/child model
│   └── business-impact-analysis.md    — BIA chain (severity → impact + urgency → priority)
│
└── classes/                           — one note per CI class encountered in real work
    ├── README.md                      — naming + linking convention
    ├── cmdb_ci_business_app.md
    ├── cmdb_ci_information_object.md
    ├── cmdb_ci_service_auto.md        — Service Instance (the bridge)
    ├── cmdb_ci_service_business.md    — Business Service
    ├── cmdb_ci_service_calculated.md  — calculated service (Dynatrace/SGO landing)
    ├── cmdb_ci_service_technical.md   — Technology Management Service
    ├── cmdb_ci_query_based_service.md — Dynamic CI Group (the bridging primitive)
    ├── service_offering.md            — BSO & TSO container (one table, two classifications)
    └── u_sp_ebond_config.md           — custom SP e-bond config (planned)
```

## How to use this vault

- **Working on incident routing?** Start at [incident-assignment-bso-tso](incident-assignment-bso-tso.md), then drill into [cmdb_ci_service_business](classes/cmdb_ci_service_business.md) and [cmdb_ci_service_technical](classes/cmdb_ci_service_technical.md).
- **Working on impact?** [business-impact-analysis](business-impact-analysis.md) explains the BIA chain; [service-mapping-bottom-up](service-mapping-bottom-up.md) explains how to walk from a discovered CI back to a BSO.
- **Adding a new class**: copy [_template-class.md](_template-class.md) into [classes/](classes/), rename to the technical table name (e.g. `cmdb_ci_service_offering.md`), fill in. Add a one-line entry under the matching domain index and (if relevant) the matching MOC.
- **Recall**: open a class note → Obsidian's backlinks pane lists every daily log / blueprint / project doc that mentioned it.

## Working principles

1. **CSDM v5 labels everywhere** — when v4 terminology surfaces in old docs, note the v4↔v5 mapping inline; don't silently rewrite the source.
2. **Real evidence over theory** — wherever possible, class notes carry CCH-verified record counts and dated observations, not generic descriptions.
3. **Tables didn't move, labels did** — when in doubt, the *table name* is canonical, not the label.
4. **Encounter-driven for class notes** — new class notes appear when work touches the class. MOC pages can be written ahead of need (they are higher-leverage).
5. **One concept per page** — keep class notes tight; MOCs are where the synthesis lives.

## CCH v5 maturity snapshot (April 2026)

| Layer | Table | CCH count | Maturity stage |
|---|---|---|---|
| Business Services (v5) | `cmdb_ci_service_business` | 444 (~360 operational) | Run |
| Business Services (legacy) | `cmdb_ci_service` | 1,789 | — (migration not complete) |
| Service Offerings (BSO + TSO) | `service_offering` | 2,029 (1,293 business-facing) | Run |
| Service Instances | `cmdb_ci_service_auto` | 10,194 | Crawl/Walk done |
| Technology Management Services | `cmdb_ci_service_technical` | 361 | Walk |
| BSO → SI (`Depends on :: Used by`) | `cmdb_rel_ci` | 870 | Run |
| TSO → SI (`Contains :: Contained by`) | `cmdb_rel_ci` | 395 | Walk |
| TSO → TSO (`Depends on :: Used by`) | `cmdb_rel_ci` | 647 | Walk |
| TSO → Dynamic CI Group | `cmdb_rel_ci` | 7 | Walk-pilot |

CCH is at **Run maturity** (BSO ↔ SI ↔ TSO chain populated). **Fly maturity** (Business Capability, Service Portfolio, strategic relationships) is not yet in place.

Source: [CSDM v5 Reference Model](../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md), April 2026 verification.

---

*The CSDM 5 White Paper (Lemm, Koeten) is the upstream source. This vault is the engagement-side digestion of it.*
