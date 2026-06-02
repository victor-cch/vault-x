# ServiceNow Tables Reference

**Last Updated**: 2026-02-05

A quick reference guide to essential ServiceNow tables organized by functional area.

---

## Table Naming Conventions

ServiceNow uses prefixes to indicate table origin, scope, and ownership.

### Standard Prefixes

| Prefix | Scope | Origin | Example |
|--------|-------|--------|---------|
| **`sys_`** | Core platform | OOTB | `sys_user`, `sys_import_set` |
| **`cmdb_`** | CMDB | OOTB (CMDB plugin) | `cmdb_ci_linux_server` |
| **`em_`** | Event Management | OOTB (ITOM) | `em_event`, `em_alert` |
| **`sn_`** | Newer ServiceNow products | OOTB | `sn_hr_core_case`, `sn_cmp_*` |
| **`sc_`** | Service Catalog | OOTB | `sc_request`, `sc_cat_item` |
| **`kb_`** | Knowledge Base | OOTB | `kb_knowledge` |
| **`ast_`** | Asset | OOTB | `ast_contract` |
| **`alm_`** | Asset Lifecycle Management | OOTB | `alm_hardware` |
| **`core_`** | Core data | OOTB | `core_company` |
| **`cmn_`** | Common data | OOTB | `cmn_location`, `cmn_department` |
| **`wf_`** | Workflow | OOTB | `wf_workflow`, `wf_activity` |
| **`pm_`** | Project Management | OOTB | `pm_project`, `pm_project_task` |

### Custom Table Prefixes

| Prefix | Scope | Origin | Example |
|--------|-------|--------|---------|
| **`u_`** | Global custom | Customer-created | `u_dynatrace_hosts` |
| **`x_<vendor>_<app>_`** | Scoped application | Store apps / custom scoped apps | `x_dynat_ruxit_em_events` |

### Import Set Staging Tables

| Pattern | Description | Example |
|---------|-------------|---------|
| `u_imp_*` | Global scope import staging | `u_imp_dynatrace_hosts` |
| `u_<data_source_name>` | Auto-generated from data source | `u_dynatrace_host_import` |
| `x_<scope>_imp_*` | Scoped app import staging | `x_acme_myapp_imp_orders` |

### Key Distinctions

| Question | Answer |
|----------|--------|
| Is it OOTB? | No `u_` or `x_` prefix |
| Is it customer custom (global)? | Starts with `u_` |
| Is it from a Store app or scoped app? | Starts with `x_<vendor>_<app>_` |
| Which module owns it? | Check the prefix (`em_` = Event Management, `sc_` = Service Catalog, etc.) |

> **Example**: Dynatrace's official ServiceNow app uses `x_dynat_ruxit_*` tables (scoped), while a customer-built Dynatrace integration might use `u_dynatrace_*` tables (global custom).

---

## System Tables

Core platform tables for configuration and security.

| Table | Purpose | Key Fields | Navigation |
|-------|---------|------------|------------|
| `sys_properties` | System property storage | name, value, type, description | System Properties → All Properties |
| `sys_user` | User accounts | user_name, email, active, department | User Administration → Users |
| `sys_user_group` | User groups | name, manager, type, active | User Administration → Groups |
| `sys_domain` | Domain definitions (multi-tenancy) | name, suffix, active | Domain Support → Domains |
| `sys_domain_path` | Domain hierarchy | parent, child | Domain Support → Domain Paths |
| `sys_security_acl` | Access Control Lists | name, operation, active, admin_overrides | System Security → Access Control |

### Example: sys_properties

The `glide.sm.default_mode` property controls Security Manager behavior when no ACLs exist:

```
https://<instance>.service-now.com/sys_properties.do?sysparm_query=name=glide.sm.default_mode
```

| Property | Value | Effect |
|----------|-------|--------|
| `glide.sm.default_mode` | `deny` | Tables without ACLs are locked down (secure default) |
| `glide.sm.default_mode` | `allow` | Tables without ACLs are fully accessible (permissive) |

---

## ITSM Core Tables

IT Service Management process tables.

### Incident Management

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `incident` | Incident records | number, short_description, state, priority, cmdb_ci, assignment_group |
| `incident_task` | Incident child tasks | parent, number, state, assigned_to |

### Problem Management

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `problem` | Problem records | number, short_description, state, root_cause, cmdb_ci |
| `problem_task` | Problem child tasks | parent, number, state, assigned_to |

### Change Management

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `change_request` | Change records | number, short_description, state, type, risk, cmdb_ci |
| `change_task` | Change child tasks | parent, number, state, assigned_to |
| `std_change_producer_version` | Standard change templates | name, current, template |

### Task (Base Table)

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `task` | Base task table (parent of incident, problem, change) | number, state, assignment_group, assigned_to, priority |
| `task_sla` | SLA tracking for tasks | task, sla, stage, has_breached |

> **Note**: `incident`, `problem`, `change_request` all extend `task`. Queries on `task` return all task types.

---

## CSDM Foundation Domain

Organizational structure tables from Common Service Data Model.

### Core Organization

| Table | Purpose | Key Fields | CSDM Role |
|-------|---------|------------|-----------|
| `core_company` | Companies/organizations | name, stock_symbol, contact | Service Owner context |
| `business_unit` | Business units | name, parent, bu_head | Financial reporting |
| `cmn_department` | Departments | name, dept_head, parent | User organization |
| `cmn_cost_center` | Cost centers | name, code, manager, valid_to | Financial allocation |
| `cmn_location` | Physical locations | name, street, city, country, type | Data centers, offices |

### Service Portfolio

| Table | Purpose | Key Fields | CSDM Role |
|-------|---------|------------|-----------|
| `service_offering` | Service offerings with SLAs | name, parent, commitments, price | What customers consume |
| `sla` | SLA definitions | name, target, schedule, workflow | Service level targets |

### Example: Location Hierarchy

```
core_company (ACME Corp)
  └── cmn_location (US-East Data Center)
        └── cmdb_ci_rack (Rack A-01)
              └── cmdb_ci_server (server01.acme.com)
```

---

## CSDM Support Domain (CMDB)

Configuration Management Database tables.

### Base CI Table

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `cmdb_ci` | Base Configuration Item | name, sys_class_name, operational_status, support_group, correlation_id |

### Hardware CIs

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `cmdb_ci_server` | Server (generic) | name, os, ip_address, fqdn, ram, cpu_count |
| `cmdb_ci_linux_server` | Linux Server | + linux-specific fields |
| `cmdb_ci_win_server` | Windows Server | + windows-specific fields |
| `cmdb_ci_unix_server` | Unix Server | + unix-specific fields |
| `cmdb_ci_vm_instance` | Virtual Machine | + vm_instance_id, virtual |
| `cmdb_ci_ec2_instance` | AWS EC2 Instance | + object_id (i-xxxxx) |
| `cmdb_ci_network` | Network device | + ports, bandwidth |
| `cmdb_ci_storage` | Storage device | + capacity, used_space |

### Application CIs

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `cmdb_ci_appl` | Application | name, version, running_on, used_for |
| `cmdb_ci_db_instance` | Database (generic) | + port, type |
| `cmdb_ci_db_oracle_instance` | Oracle Database | + oracle-specific fields |
| `cmdb_ci_db_mssql_instance` | SQL Server Database | + mssql-specific fields |
| `cmdb_ci_db_postgresql_instance` | PostgreSQL Database | + pg-specific fields |
| `cmdb_ci_db_mysql_instance` | MySQL Database | + mysql-specific fields |

### Service CIs (CSDM 5)

| Table | Purpose | CSDM Concept |
|-------|---------|--------------|
| `cmdb_ci_service_business` | Business Service | Customer-facing services |
| `cmdb_ci_service_technical` | Technology Management Service | Shared infrastructure services |
| `cmdb_ci_business_app` | Business Application | Business capability grouping |
| `cmdb_ci_service_auto` | Application Service | Auto-discovered dependencies |

### CI Relationships

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `cmdb_rel_ci` | CI relationships | parent, child, type |
| `cmdb_rel_type` | Relationship types | name, parent_descriptor, child_descriptor |
| `cmdb_rel_type_suggest` | Suggested relationships for UI filtering | base_table, relationship, dependent_table |

> **Suggested Relationships**: Filter relationship picker UI when users create manual relationships. Guides users to valid source→target pairs (e.g., Apache Web Server → Runs on → Linux Server). Configuration: Configuration > Relationships > Suggested Relationships.

### Common Relationship Types

| Relationship | Parent Descriptor | Child Descriptor | Example |
|--------------|-------------------|------------------|---------|
| `Runs on::Runs` | Runs | Runs on | App → Server |
| `Depends on::Used by` | Depends on | Used by | Service → App |
| `Hosted on::Hosts` | Hosted on | Hosts | VM → Hypervisor |
| `Contains::Contained by` | Contains | Contained by | Cluster → Nodes |

---

## Event Management Tables

ITOM Health event processing tables.

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `em_event` | Raw events from monitoring | source, node, severity, message_key, type, resource |
| `em_alert` | Processed alerts (CI-bound) | message_key, ci, severity, state, incident |
| `em_event_rule` | Event processing rules | name, active, order, source, transform_script |
| `em_alert_management_rule` | Alert → Incident rules | name, active, conditions, actions |
| `em_connector_instance` | Connector configurations | name, connector, active, configuration |

### CI Resolution Table

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `sys_object_source` | External ID → CI mapping (fast lookup) | id, name, target_sys_id, target_table |
| `cmdb_datasource_last_update` | Tracks which datasource last updated each CI | ci, datasource, last_update_time |

This table provides **indexed lookup** for Event Management CI resolution:

| id | name | target_sys_id | target_table |
|----|------|---------------|--------------|
| `HOST-58AE749F489A2DEB` | Dynatrace | `7f8f9702...` | `cmdb_ci_win_server` |
| `/subscriptions/.../vm1` | Azure | `3c4d5e26...` | `cmdb_ci_vm_instance` |
| `i-0abc123def456` | AWS | `1a2b3c48...` | `cmdb_ci_ec2_instance` |

> **Performance**: `sys_object_source` lookup ~50ms vs CMDB scan which degrades at scale (60M+ CIs).

### Alert Correlation Tables

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `em_match_rule` | Event-to-alert matching rules | name, active, order, source, filter |
| `em_impact_calculation_rule` | Impact calculation rules | name, active, severity_calculation |
| `em_alert_correlation_rule` | Alert correlation/grouping | name, active, type, window |

### Key Event Management Properties

| Property | Purpose | Default |
|----------|---------|---------|
| `evt_mgmt.use_cmdb_identifiers` | Use CMDB CI identifiers for resolution | true |
| `evt_mgmt.ci_resolution_timeout` | CI resolution timeout (ms) | 30000 |
| `evt_mgmt.max_events_per_run` | Max events processed per job | 1000 |

---

## Integration Hub Tables

Data import and transformation tables.

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `sys_data_source` | External data source configuration | name, type, url, credential |
| `sys_import_set` | Staged import data | state, table_name, mode, run_time |
| `sys_transform_map` | Field mapping configuration | name, source_table, target_table, active |
| `sys_transform_entry` | Individual field mappings | map, source_field, target_field, transform_script |
| `scheduled_data_import` | Scheduled import jobs | name, data_source, run_as, schedule |

### Flow Designer

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `sys_hub_flow` | Flow definitions | name, active, trigger, inputs |
| `sys_hub_action_instance` | Flow action steps | flow, action, order, inputs |

---

## Service Catalog Tables

Request fulfillment and catalog management.

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `sc_catalog` | Service catalogs | name, title, active |
| `sc_category` | Catalog categories | name, parent, active |
| `sc_cat_item` | Catalog items | name, category, active, price, delivery_time |
| `sc_request` | Service requests | number, requested_for, stage, approval |
| `sc_req_item` | Requested items (RITM) | request, cat_item, stage, price |
| `sc_task` | Catalog tasks | parent, stage, assigned_to |

---

## Guided Setup / Playbooks

Configuration and adoption tracking tables.

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `gsw_content` | Playbook/wizard definitions | name, type, parent, order |
| `gsw_content_task` | Individual playbook tasks | content, task_name, url, description |
| `gsw_status` | Progress tracking | content, user, status, completed_on |

---

## Quick Navigation Patterns

### Direct Record Access

```
# By sys_id
https://<instance>.service-now.com/<table>.do?sys_id=<32-char-id>

# By query
https://<instance>.service-now.com/<table>.do?sysparm_query=<field>=<value>

# List view
https://<instance>.service-now.com/<table>_list.do
```

### Examples

```
# Find property by name
sys_properties.do?sysparm_query=name=glide.sm.default_mode

# Find CI by correlation_id
cmdb_ci.do?sysparm_query=correlation_id=HOST-58AE749F489A2DEB

# Find incidents for a CI
incident_list.do?sysparm_query=cmdb_ci=<ci_sys_id>

# Find events by node
em_event_list.do?sysparm_query=node=server01.acme.com
```

---

## Table Hierarchy Reference

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
└── (other task types)

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
│       └── ...
├── cmdb_ci_service
│   ├── cmdb_ci_service_business
│   └── cmdb_ci_service_technical
└── cmdb_ci_business_app
```

---

## Related Documentation

- Event Management Reference **(TBD)** — Event lifecycle and CI resolution
- CSDM Unified Reference **(TBD)** — Service and CI class hierarchy
- Dynatrace ServiceNow Integration **(TBD)** — Integration overview
- Dynatrace-ServiceNow Integration Patterns **(TBD)** — Implementation patterns
- ITOM Suite Overview **(TBD)** — ITOM module landscape

---

*This document provides a quick reference to commonly used ServiceNow tables for ITOM and ITSM implementations.*
