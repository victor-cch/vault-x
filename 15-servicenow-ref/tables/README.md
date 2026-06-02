---
status: Approved
intent: Reference
---

# ServiceNow Tables — Map of Content

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Reference](https://img.shields.io/badge/intent-Reference-3B82F6)

Index of ServiceNow tables encountered in real work. Each table gets its own note here as it surfaces — purpose, key fields, common queries, what it relates to. Unresolved wikilinks below are the **growth queue** — tables on our radar that don't have a note yet.

This MOC sits in [[15-servicenow-ref]] alongside [[sys_id]], [[glide-record]], [[sys_object_source]].

---

## Table naming conventions

How to recognise origin and ownership from the table name alone.

### Standard prefixes (OOTB)

| Prefix | Scope | Example |
|---|---|---|
| `sys_` | Core platform | `sys_user`, `sys_dictionary`, `sys_script` |
| `cmdb_` | CMDB | `cmdb_ci`, `cmdb_ci_linux_server` |
| `em_` | Event Management (ITOM) | `em_event`, `em_alert` |
| `sn_` | Newer ServiceNow products | `sn_hr_core_case` |
| `sc_` | Service Catalog | `sc_request`, `sc_cat_item` |
| `kb_` | Knowledge Base | `kb_knowledge` |
| `ast_` | Asset | `ast_contract` |
| `alm_` | Asset Lifecycle Management | `alm_hardware` |
| `core_` | Core data | `core_company` |
| `cmn_` | Common data | `cmn_location`, `cmn_department` |
| `wf_` | Workflow | `wf_workflow` |
| `pm_` | Project Management | `pm_project` |

### Custom prefixes

| Prefix | Scope | Example |
|---|---|---|
| `u_` | Global custom (customer-created) | `u_dynatrace_hosts`, `u_escalation_groups` |
| `x_<vendor>_<app>_` | Scoped application | `x_dynat_ruxit_em_events` |

### Import-set staging tables

| Pattern | Description | Example |
|---|---|---|
| `u_imp_*` | Global-scope import staging | `u_imp_dynatrace_hosts` |
| `u_<data_source_name>` | Auto-generated from a data source | `u_dynatrace_host_import` |
| `x_<scope>_imp_*` | Scoped-app import staging | `x_acme_myapp_imp_orders` |

### Quick test — which kind of table is this?

| Question | Answer |
|---|---|
| Is it OOTB? | No `u_` or `x_` prefix |
| Is it customer-custom (global)? | Starts with `u_` |
| Is it from a Store app or scoped app? | Starts with `x_<vendor>_<app>_` |
| Which module owns it? | The prefix tells you (`em_` = Event Management, `sc_` = Service Catalog, etc.) |

---

## Platform / System

Core platform tables.

- [[sys_user]] — user accounts
- [[sys_user_group]] — user groups
- [[sys_properties]] — system property storage
- [[sys_domain]] — domain definitions (multi-tenancy)
- [[sys_domain_path]] — domain hierarchy
- [[sys_security_acl]] — Access Control Lists
- [[sys_dictionary]] — field definitions for every table
- [[sys_script]] — server-side Business Rules
- [[sys_script_client]] — Client Scripts
- [[sys_script_include]] — reusable server-side script libraries
- [[sys_ui_policy]] — UI Policies
- [[sys_ui_action]] — UI Actions (form buttons, related-list actions)
- [[sys_choice]] — choice list values per (table, element)
- [[sys_audit]] — field-level change audit log

---

## Task — the base ITSM table

Everything that someone "works on" extends `task`.

- [[task]] — base task table (parent of incident, problem, change_request, sc_request, sc_task, …)
- [[task_sla]] — SLA tracking for tasks
- [[task_ci]] — many-to-many between tasks and CIs (Affected CIs related list)

> Queries on `task` return all task subtypes. Fields like `assignment_group`, `assigned_to`, `priority`, `state`, `cmdb_ci`, `business_service`, `service_offering`, `correlation_id`, `work_notes` are defined here and inherited by every subtype.

---

## ITSM processes

### Incident Management

- [[incident]] — incident records
- [[incident_task]] — incident child tasks

### Problem Management

- [[problem]] — problem records
- [[problem_task]] — problem child tasks

### Change Management

- [[change_request]] — change records
- [[change_task]] — change child tasks
- [[std_change_producer_version]] — standard change templates

---

## CSDM Foundation Domain

Organisational structure and physical reality.

- [[core_company]] — companies / organisations
- [[business_unit]] — business units
- [[cmn_department]] — departments
- [[cmn_cost_center]] — cost centres
- [[cmn_location]] — physical locations (data centres, offices)

---

## CSDM Service Portfolio

Service portfolio layer.

- [[service_offering]] — Service Offerings (BSO and TSO; distinguished by `service_classification`)
- [[cmdb_ci_service_business]] — Business Service (CSDM 5)
- [[cmdb_ci_service_technical]] — Technology Management Service (CSDM 5)
- [[cmdb_ci_service]] — legacy / generic service class
- [[sla]] — SLA definitions

---

## CMDB — base + relationships

- [[cmdb_ci]] — base Configuration Item table
- [[cmdb_rel_ci]] — CI-to-CI relationships
- [[cmdb_rel_type]] — relationship type definitions
- [[cmdb_rel_type_suggest]] — suggested relationships for UI filtering
- [[svc_ci_assoc]] — Service-to-CI association (Service Instance binding)

### Common relationship types

| Relationship | Parent → Child | Example |
|---|---|---|
| `Runs on :: Runs` | child runs on parent | App → Server |
| `Depends on :: Used by` | child depends on parent | Service → App |
| `Hosted on :: Hosts` | child hosted on parent | VM → Hypervisor |
| `Contains :: Contained by` | parent contains child | Cluster → Nodes |

---

## CMDB — hardware CIs

- [[cmdb_ci_server]] — server (generic)
- [[cmdb_ci_linux_server]] — Linux Server
- [[cmdb_ci_win_server]] — Windows Server
- [[cmdb_ci_unix_server]] — Unix Server
- [[cmdb_ci_vm_instance]] — Virtual Machine
- [[cmdb_ci_ec2_instance]] — AWS EC2 Instance
- [[cmdb_ci_network]] — Network device
- [[cmdb_ci_storage]] — Storage device

---

## CMDB — application CIs

- [[cmdb_ci_appl]] — Application
- [[cmdb_ci_db_instance]] — Database (generic)
- [[cmdb_ci_db_oracle_instance]] — Oracle Database
- [[cmdb_ci_db_mssql_instance]] — SQL Server Database
- [[cmdb_ci_db_postgresql_instance]] — PostgreSQL Database
- [[cmdb_ci_db_mysql_instance]] — MySQL Database

---

## CMDB — service-delivery CIs (CSDM 5)

- [[cmdb_ci_service_auto]] — Service Instance / Application Service (auto-discovered)
- [[cmdb_ci_query_based_service]] — Dynamic CI Group
- [[cmdb_ci_business_app]] — Business Application

---

## Event Management (ITOM Health)

- [[em_event]] — raw events from monitoring sources
- [[em_alert]] — processed alerts (CI-bound)
- [[em_event_rule]] — event processing rules
- [[em_alert_management_rule]] — alert → incident rules
- [[em_connector_instance]] — connector configurations
- [[em_match_rule]] — event-to-alert matching rules
- [[em_impact_calculation_rule]] — impact calculation rules
- [[em_alert_correlation_rule]] — alert correlation / grouping

### CI resolution

- [[sys_object_source]] — external ID → CI mapping (fast, indexed lookup)
- [[cmdb_datasource_last_update]] — tracks which datasource last updated each CI

---

## Integration Hub — import & transform

- [[sys_data_source]] — external data source configuration
- [[sys_import_set]] — staged import data
- [[sys_transform_map]] — field-mapping configuration
- [[sys_transform_entry]] — individual field mappings
- [[scheduled_data_import]] — scheduled import jobs

### Flow Designer

- [[sys_hub_flow]] — Flow definitions
- [[sys_hub_action_instance]] — Flow action steps

---

## Service Catalog

- [[sc_catalog]] — service catalogs
- [[sc_category]] — catalog categories
- [[sc_cat_item]] — catalog items
- [[sc_request]] — service requests
- [[sc_req_item]] — requested items (RITM)
- [[sc_task]] — catalog tasks
- [[sc_cat_item_subscribe_mtom]] — many-to-many between catalog items and service offerings

---

## Guided Setup / Playbooks

- [[gsw_content]] — playbook / wizard definitions
- [[gsw_content_task]] — individual playbook tasks
- [[gsw_status]] — progress tracking

---

## Table-hierarchy reference

```
task (base)
├── incident
│   └── incident_task
├── problem
│   └── problem_task
├── change_request
│   └── change_task
├── sc_request
│   └── sc_req_item
│       └── sc_task
└── (other task subtypes)

cmdb_ci (base)
├── cmdb_ci_server
│   ├── cmdb_ci_linux_server
│   ├── cmdb_ci_win_server
│   └── cmdb_ci_unix_server
├── cmdb_ci_vm_instance
│   └── cmdb_ci_ec2_instance
├── cmdb_ci_appl
│   └── cmdb_ci_db_instance
│       ├── cmdb_ci_db_oracle_instance
│       ├── cmdb_ci_db_mssql_instance
│       └── …
├── cmdb_ci_service           (legacy / generic)
│   ├── cmdb_ci_service_business
│   └── cmdb_ci_service_technical
├── cmdb_ci_service_auto      (Service Instance — Application Service)
└── cmdb_ci_business_app
```

---

## Quick navigation patterns

URL templates that work on any modern ServiceNow instance.

```
# By sys_id
https://<instance>.service-now.com/<table>.do?sys_id=<32-char-id>

# By query
https://<instance>.service-now.com/<table>.do?sysparm_query=<field>=<value>

# List view
https://<instance>.service-now.com/<table>_list.do
```

Examples:

```
# Find a system property by name
sys_properties.do?sysparm_query=name=glide.sm.default_mode

# Find a CI by correlation_id (external monitoring ID)
cmdb_ci.do?sysparm_query=correlation_id=HOST-58AE749F489A2DEB

# Find all incidents for a CI
incident_list.do?sysparm_query=cmdb_ci=<ci_sys_id>

# Find dictionary entries defined on the incident table
sys_dictionary_list.do?sysparm_query=name=incident

# Find before-insert business rules on incident
sys_script_list.do?sysparm_query=collection=incident^active=true^when=before^action_insert=true
```

---

## How to grow this index

When a new table surfaces in real work:

1. Add a `[[wikilink]]` to it in the appropriate section above (create a new section if no fit).
2. Create `15-servicenow-ref/tables/<table_name>.md` with a short conceptual description, key fields, related tables, and the URL pattern to list it.
3. If the table is conceptually related to an existing concept note ([[sys_id]], [[glide-record]], [[sys_object_source]]), link both ways.

Notes already populated with substantive content are listed above as direct wikilinks; unresolved wikilinks above are the **growth queue** — visible in Obsidian as orange / dotted links until each gets its own note.
