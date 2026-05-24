# Service Delivery

**CSDM v5 domain — Service Delivery** *(was: "Manage Technical Services" in CSDM v3/v4; absorbs the runtime/Operate view)*

The **provider's view of running services**. This is the domain that ITSM processes target — Incident, Problem, Change. Service Mapping and ServiceNow Discovery write into here. It's where the **bridge between business and technical layers** lives via the Service Instance, and where the Technology Management Service (TMS) and Offering (TSO) sit.

> This domain merges what CSDM v3/v4 called "Manage Technical Services" with the running-infrastructure view. In v5, infrastructure CIs are part of Service Delivery (they support the Service Instance).

## Service Delivery entities

### Services (the consumer-facing layer of this domain)

| Entity | Table | Service Classification | Purpose |
|---|---|---|---|
| Service Instance | `cmdb_ci_service_auto` | — (parent class) | **The bridge.** Operational/runtime instance of a service. Was "Application Service" in v4 |
| Application Service *(Service Instance sibling)* | `cmdb_ci_service_discovered` / `cmdb_ci_service_by_tags` / `cmdb_ci_service_calculated` / `cmdb_ci_query_based_service` | Application Service | Logical instance of an app stack — five population methods |
| Data Service Instance | `cmdb_ci_data_service_instance` | Technical Service | DB, storage, AI/ML pipelines, datasets |
| Connection Service Instance | `cmdb_ci_connection_service_instance` | Technical Service | VLAN, LAN, WLAN |
| Network Service Instance | `cmdb_ci_network_service_instance` | Technical Service | Network services on Network Functions |
| Facility Service Instance | `cmdb_ci_facility_service_instance` | Technical Service | Building HVAC, power, lighting, access |
| Operational Process Service Instance | `cmdb_ci_operational_process_service_instance` | Technical Service | Manufacturing, industrial, utility processes |
| Technology Management Service (TMS) | `cmdb_ci_service_technical` | Technical Service | **Provider view** — IT capability (e.g. "Windows Hosting") |
| Technology Management Service Offering (TSO) | `service_offering` | Technical Service | Stratified TMS — env/geo/SLA tiers |
| Dynamic CI Group | `cmdb_ci_query_based_service` | Technical Service or Application Service | Query-based grouping of CIs; the **bridging primitive** to BAs |

### Service Delivery Network (infrastructure layer)

| Entity | Table | Purpose |
|---|---|---|
| API | `cmdb_ci_api` | API as a managed entity (API Insights data model) |
| Application | `cmdb_ci_appl` | Deployed program/module; technical CI, discoverable; NOT a portfolio inventory |
| AI Function | `cmdb_ci_function_ai` | AI SaaS apps on public cloud |
| AI Application | `cmdb_ci_appl_ai_application` | AI software runnable on diverse platforms |
| Operational Technology (OT) | (`cmdb_ci_ot_*`) | Industrial control systems; via CMDB Class Model App |
| Network Function Application | `cmdb_ci_network_function_application` | Network apps |
| Hosts (servers) | `cmdb_ci_*_server` | OS-typed: Linux, Windows, Unix, generic Computer |
| Network devices | `cmdb_ci_ip_router`, `cmdb_ci_ip_switch`, `cmdb_ci_firewall` | Routing / switching / security |
| Containers | `cmdb_ci_docker_container`, `cmdb_ci_kubernetes_*` | Container runtime |
| Database | `cmdb_ci_db_*` | DB instances |
| Cloud resources | `cmdb_ci_cloud_*`, `cmdb_ci_vm_instance` | Cloud-native CIs |

### Foundational entities that contribute

- **Product Model** — referential on every CI via `model_id`
- **CMDB Group** — reference object on Dynamic CI Groups
- **SBOM** — software bill of materials for vulnerability management
- **Common Data** — locations, groups, users for assignment

## Key v5 relationships

| From                 | Relationship                     | To                 | Notes                                                                              |
| -------------------- | -------------------------------- | ------------------ | ---------------------------------------------------------------------------------- |
| BSO                  | Depends on :: Used by            | Service Instance   | The consumer ↔ delivery bridge — see [service-consumption](service-consumption.md) |
| TSO                  | **Contains :: Contained by**     | Service Instance   | TSO is the **parent**; SI is the **child**                                         |
| TSO                  | Contains :: Contained by         | Dynamic CI Group   | For the CI-first incident path                                                     |
| TSO (L2)             | Depends on :: Used by            | TSO (L3)           | **CCH-specific, not CSDM 5 canon** — see [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md#non-canonical-cch-patterns) |
| TSO (L3)             | Depends on :: Used by            | TSO (L4)           | Same — CCH escalation chain, not canonical                                         |
| TMS                  | Reference (`Published as`)       | TSO                | TMS publishes one or more TSOs                                                     |
| Service Instance     | Depends on :: Used by            | Service Instance   | Inter-service dependencies                                                         |
| Service Instance     | Depends on :: Used by            | Infrastructure CIs | Runs on                                                                            |
| Application          | Runs on                          | Infrastructure CIs | Discovery-created                                                                  |
| Business Application | Uses :: Used by                  | Service Instance   | From Design & Planning                                                             |
| CI                   | associated with (`svc_ci_assoc`) | Service Instance   | Membership; NOT a `cmdb_rel_ci` row                                                |

> **Relationship trap**: TSO → Service Instance is `Contains :: Contained by` (TSO is parent). Some older CCH documentation got this reversed and produced zero query results in prod. Verify direction every time.

## TMS Offering auto-sync

These foundational attributes auto-synchronise from a TSO down to underlying CIs:
- **Change Group**
- **Managed By Group**
- **Support Group**

Define once at the offering; cascades to all CIs the TSO contains.

> ServiceNow recommends: each CI associated through a Dynamic CI Group be related to **only one** TMS / TSO. Multiple TSOs with different SLA/OLA/Support Groups conflict on data synchronisation.

## Class notes

- [cmdb_ci_service_auto](classes/cmdb_ci_service_auto.md) — Service Instance (the bridge)
- [cmdb_ci_service_technical](classes/cmdb_ci_service_technical.md) — Technology Management Service
- [cmdb_ci_service_calculated](classes/cmdb_ci_service_calculated.md) — Calculated Application Service (Dynatrace/SGO landing)
- [cmdb_ci_query_based_service](classes/cmdb_ci_query_based_service.md) — Dynamic CI Group
- [service_offering](classes/service_offering.md) — the BSO/TSO container table
- [u_sp_ebond_config](classes/u_sp_ebond_config.md) — custom SP e-bond config (planned)

## Why it matters

- **Incident routing**: BSO incidents identify the affected Service Instance, which leads to the TSO via `Contains :: Contained by` (TSO → SI). See [incident-assignment-bso-tso](incident-assignment-bso-tso.md).
- **CI-first path**: discovered CI → Dynamic CI Group → TSO. Requires DCG ↔ TSO relationships.
- **BIA**: business_criticality lives on Service Offerings (BSO and TSO). Severity propagation walks the SI ↔ TSO chain. See [business-impact-analysis](business-impact-analysis.md).

## Related notes

- [README](README.md)
- [service-consumption](service-consumption.md) — the BSO side
- [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md)
- [incident-assignment-bso-tso](incident-assignment-bso-tso.md)
- [service-mapping-bottom-up](service-mapping-bottom-up.md)
