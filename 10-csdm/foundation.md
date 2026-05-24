# Foundation

**CSDM v5 domain — Foundation**

The base layer. Common referential data that every other domain depends on: who the company is, where it operates, who its people and groups are, what products and contracts the organisation manages, what life cycle and value stream taxonomy applies. None of the higher domains resolve cleanly without Foundation being trustworthy.

> **Foundation tables are NOT CIs.** They are referential data on tables outside the CMDB (`core_company`, `cmn_location`, `sys_user`, etc.) or on the boundary (`cmdb_ci_business_process`).

## Foundation entities

### Common Data (organisational structure, locations, people)

| Entity | Table | Used by |
|---|---|---|
| Company | `core_company` | Internal entity, customers, manufacturers, vendors (flags differentiate) |
| Business Unit | `business_unit` | Sub-org under a Company |
| Department | `cmn_department` | Sub-org under a Business Unit |
| Location | `cmn_location` | Hierarchy: Region → Country → State/Province → City → Site → Building → Floor → Room |
| Building | `cmn_building` | Distinct from Location; for facility-typed CIs |
| Group | `sys_user_group` | Support / Change / Managed By assignments |
| User | `sys_user` | OOTB identity |

### Operational referential data

| Entity | Table | Purpose |
|---|---|---|
| Business Process | `cmdb_ci_business_process` | Manually maintained CI; criticality, CIA impact, review cadence; only Foundation entity that IS a CMDB CI |
| Contract | `ast_contract` | Binding agreements; NOT a CI; consumes Contract Model from Product Models |
| Product Model | `cmdb_model` | 10 base types (Application, System Component, Service, Software, Content, Contract, Facility, Hardware, Consumable, Enterprise Good Model) |
| Product Feature | `sn_dpr_model_product_feature` | What a product *does*; core of Digital Product Release |
| SBOM | `sn_sbom_doc` | Software Bill of Materials; via `sn_sbom_core` store app |
| Value Stream | `cmn_value_stream` | New in v5; 16 OOB categories |
| Value Stream Stage | `cmn_value_stream_stage` | Within a Value Stream |
| Life Cycle Stage / Status | (attributes on CIs) | Replaces 8 legacy status fields; PI 2.0 from Xanadu |
| Knowledge | `kb_knowledge` | AI agents consume; OOTB |
| Teams (related-list mechanism) | `cmdb_ci`-attached | Multi-group assignment without proliferating CI attributes |
| CMDB Group | `cmdb_group` | Grouping primitive used by Dynamic CI Groups |

## Class notes

*(none yet — Foundation entities are not first-class CIs in most engagement work, so dedicated class notes appear only when a specific decision attaches. Add via [_template-class.md](_template-class.md) when needed.)*

## Why it matters in incident assignment

- Support group on a CI ultimately resolves to a `sys_user_group` row — Foundation.
- Location-aware incident routing (e.g. data privacy incidents to regional TSOs) depends on `cmn_location` hierarchy.
- Business Process is the only Foundation CI that can carry criticality + CIA impact attributes; relevant for BIA chains that propagate via Process.

## Related notes

- [README](README.md)
- [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md)
