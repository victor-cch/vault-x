# OneTrust ↔ CSDM Integration

**Status**: Design and specification work for the OneTrust ↔ CSDM integration. Picked design: OOTB-only, Option A (Information Objects + `Uses ↔ Used by` relationships).

**Scope**:
- Integration between ServiceNow CSDM and OneTrust (Privacy Product) for GDPR Article 30 compliance
- Two masters: CSDM owns applications; OneTrust owns privacy metadata
- Three integration parts: Part 1 asset sync (OneTrust pulls from CSDM), Part 2 incident management (bidirectional with work-notes pushback), Part 3 classification pushback (OneTrust → SN via Information Objects + `Uses ↔ Used by` relationships — OOTB pattern, no custom fields)

---

## What's here

This is the working set for the OneTrust ↔ CSDM integration: target-state design (`blueprints/`), background investigation and validation checklist (`references/`), and Mermaid + ASCII extracts for PDF rendering (`diagrams/`).

The OneTrust ServiceNow Store app was withdrawn. The integration is configured via OOTB mechanisms on the ServiceNow side — no custom fields, no schema modifications:

- **Part 1 (Asset Sync)**: OneTrust's OOTB Asset Discovery Wizard pulls from SN REST API. SN-side work = service account with read access to `cmdb_ci_business_app` + population of OOTB fields (`correlation_id`, `vendor`, etc.) where currently sparse.
- **Part 2 (Incident Management)**: Business Rule on the SN `incident` table + OneTrust workflow. Bidirectional with work-notes pushback. OOTB tables only.
- **Part 3 (Classification Pushback)**: OneTrust workflow → SN REST Table API → creates / updates `cmdb_ci_information_object` records and `cmdb_rel_ci` "Uses ↔ Used by" relationships between Business Applications and Information Objects. OOTB CSDM v5 pattern.

---

## Read in this order

For someone new to the topic, read these in order. After this 3-document path, the catalogue below provides depth.

| # | Document | Purpose |
|---|---|---|
| 1 | [blueprints/hld-onetrust-csdm-integration-ootb.md](blueprints/hld-onetrust-csdm-integration-ootb.md) | **Authoritative design** — two-master architecture, sync flow, data model, CSPP alignment, GDPR Art 30 mapping, implementation steps for all 3 parts, open decisions. **OOTB-only**: no custom fields. Option A for classification (Information Objects + `Uses` relationships). |
| 2 | [blueprints/asset-attribute-mapping-spec.md](blueprints/asset-attribute-mapping-spec.md) | **Field-level spec for OneTrust team review** — 19 application attributes, types, expected values, empty-handling, identifier strategy, open questions to resolve with OneTrust. Aligned to OOTB HLD (no `u_*` source fields). |
| 3 | [references/background-analysis.md](references/background-analysis.md) | Background investigation — why OneTrust over SN's native modules, why Information Objects (Option A) is the right CSDM-canonical pattern, validation checklist (V-1 through V-13) |

---

## Catalogue

### Blueprints — authoritative design + field-level spec

| File | What it covers |
|---|---|
| [blueprints/hld-onetrust-csdm-integration-ootb.md](blueprints/hld-onetrust-csdm-integration-ootb.md) | Target-state integration design — two-master model (CSDM authoritative for applications, OneTrust authoritative for privacy metadata), three integration parts, CSPP-aligned classification, GDPR Art 30 mapping, OOTB-only design principle, Information Object pattern for classification pushback, 16 open decisions |
| [blueprints/asset-attribute-mapping-spec.md](blueprints/asset-attribute-mapping-spec.md) | Field-level specification for the 19 attributes flowing CSDM → OneTrust in Part 1. Types, sample values, empty-handling rules, enum format expectations, OOTB identifier strategy (`correlation_id`), refresh cadence, 12 open questions, OOTB-only field mapping |

### References — context, investigation, validation

| File | What it covers |
|---|---|
| [references/background-analysis.md](references/background-analysis.md) | Three things the team needs context on but that don't belong in the design: (1) why "Data Confidentiality OOTB field" doesn't exist as commonly imagined (debunks recurring assumption; explains the three different ServiceNow data-classification concepts); (2) why Information Objects (Option A) is the recommended approach and how the OneTrust integration drives CCH's CMDB to Fly-stage maturity organically; (3) validation checklist V-1 through V-13 to run against the OneTrust tenant + ServiceNow CMDB before integration design decisions are finalised |

### Diagrams — pure Mermaid sources for SVG rendering

| Folder | Source HLD | Diagrams (`.mmd`) |
|---|---|---|
| [diagrams/blueprints/](diagrams/blueprints/) | `blueprints/hld-onetrust-csdm-integration-ootb.md` | `ootb-architecture.mmd` (flowchart, §5.2) + `ootb-sync-flow.mmd` (sequence, §5.4) |
| [diagrams/blueprints/](diagrams/blueprints/) | `blueprints/hld-onetrust-csdm-integration-simplified.md` | `simplified-architecture.mmd` (flowchart, §7.2) + `simplified-sync-flow.mmd` (sequence, §7.4) |

**Why extracted copies exist**: source HLDs keep diagrams inline (for in-document reading); the extracted `.mmd` files exist purely so they can be rendered to SVG/PNG via the Mermaid CLI (`mmdc`) before document export (most Markdown → PDF tools don't render Mermaid).

### Diagram management — housekeeping rules

To keep source/extracted in sync without drift:

1. **One direction of authority**: the source-doc copy is canonical. The extracted `.mmd` is derived. Never edit the extracted file independently.
2. **Update protocol**: when a diagram changes, edit the source HLD first, then propagate the change to the matching `.mmd`. Same in reverse for deletions — if a diagram is removed from a source HLD, delete the matching `.mmd`.
3. **Extraction threshold**: substantial diagrams (architecture overviews, multi-node flows, sequences with 5+ steps) get extracted. Small inline trees stay inline.
4. **Naming convention**: extracted file names are `<hld-variant>-<diagram-purpose>.mmd` where `<hld-variant>` matches the HLD filename's suffix (`ootb` or `simplified`) and `<diagram-purpose>` is a short noun (`architecture`, `sync-flow`, etc.). One `.mmd` per diagram per HLD.
5. **SVG conversion**: render each `.mmd` with `mmdc -i <name>.mmd -o <name>.svg`. Rendered SVGs **are** committed alongside the `.mmd` sources — they are the deliverable artefacts for Word embedding (per the mermaid → SVG → Word workflow). Re-render and commit whenever the source `.mmd` changes.
6. **New extractions**: when a new substantial diagram is added to a source HLD, also add the extracted `.mmd`. The commit should touch both files together.

---

## Open decisions to resolve

These need stakeholder agreement before integration build starts. Full context in the [HLD](blueprints/hld-onetrust-csdm-integration-ootb.md#10-open-design-decisions).

| # | Decision | Status |
|---:|---|---|
| 1 | OneTrust Asset Discovery Wizard available in the tenant? | OPEN — first priority validation |
| 2 | Sync alternative — filtered (Alt 1) vs full (Alt 2) | PROPOSED Alt 2 (no circular dependency) |
| 3 | Where classification lands in SN — Information Objects vs custom field | **RESOLVED** — Option A: `cmdb_ci_information_object` + OOTB `Uses ↔ Used by` relationships |
| 4 | Unique identifier for round-trip | OPEN — recommend OOTB `correlation_id`; confirm during Asset Discovery Wizard config |
| 5 | Which incidents trigger Part 2 (privacy filter criteria) | OPEN |
| 6 | Decommission handling — auto-archive or flag for review | OPEN |
| 7 | Vendor field population (currently sparse in CSDM) | OPEN |
| 8 | Business Process alignment (depends on Signavio data model) | BLOCKED |
| 9 | Physical Cabinets / Websites in CSDM scope? | OPEN — CSDM scope decision |
| 10 | Existing OneTrust records with no CSDM match | OPEN — migration approach |
| 11 | Definition of "Platform" and "Product" in OneTrust spec | OPEN — see [mapping spec](blueprints/asset-attribute-mapping-spec.md) |
| 12 | Phase-1 filter mechanism (Central vs Local apps) using OOTB attribute — `company`, `support_group`, or `business_unit`? | OPEN — must use OOTB, no custom field |
| 13 | OneTrust API capability — can OT workflows directly create CMDB relationships and `cmdb_ci_information_object` records via SN REST API, or is SN-side middleware needed? | OPEN |
| 14 | Identifier strategy for `cmdb_ci_information_object` — coalesce key when OneTrust creates / updates IOs via REST? | OPEN — IRE rule design needed |
| 15 | OneTrust Data Element → CMDB Information Object granularity — one IO per data type ("Email Address") or per category ("PII")? | OPEN — needs Privacy team alignment |
| 16 | Reporting query performance — confirm the two-step pattern (filter IOs by classification → filter `cmdb_rel_ci` by parent class) is performant at production scale | OPEN — likely fine, but worth a query-plan check |

---

## External dependencies acknowledged but not detailed here

This sub-project is self-contained for sharing. Two adjacent areas of work exist that this design depends on or interacts with — mentioned for context only, no links or specific locations provided:

- **CSDM v5 model** — the application/service taxonomy this integration plugs into (Product Model → Business Application → Service Offerings). Owned by the CSDM workstream; assumed in scope and stable.
- **The Dynatrace ↔ ServiceNow incident integration** — provides the CSDM routing chain context that Part 2 (incident management) consumes when a privacy-related INC is raised. Separate scope; this sub-project assumes that integration is in place but does not depend on its specifics.

---

## Layout

```
onetrust/
├── README.md                                          ← this file
├── blueprints/                                        ← authoritative designs + field-level spec
│   ├── hld-onetrust-csdm-integration-ootb.md         ← OOTB HLD (Option A — IO + Uses relationships)
│   ├── hld-onetrust-csdm-integration-simplified.md   ← Simplified HLD (Direct Classification, no incident)
│   └── asset-attribute-mapping-spec.md                ← 19-field spec, OOTB-aligned
├── references/                                        ← context, investigation, validation
│   └── background-analysis.md
└── diagrams/                                          ← extracted Mermaid sources for SVG rendering
    └── blueprints/
        ├── ootb-architecture.mmd                      ← flowchart, OOTB HLD §5.2
        ├── ootb-sync-flow.mmd                         ← sequence, OOTB HLD §5.4
        ├── simplified-architecture.mmd                ← flowchart, simplified HLD §7.2
        └── simplified-sync-flow.mmd                   ← sequence, simplified HLD §7.4
```
