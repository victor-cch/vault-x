---
status: Approved
intent: Conceptual
---

# `sys_object_source` — the OOTB cross-source CI identifier table

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Conceptual](https://img.shields.io/badge/intent-Conceptual-8B5CF6)

`sys_object_source` is the **OOTB ServiceNow table that maps a CMDB CI to one or more identifiers from external sources**. It's the canonical answer to *"this external system knows the device as X — which CMDB CI does that refer to?"* Used by Discovery, Service Graph Connector (SGC), every integration that ingests CIs from an outside system, and every integration that needs to resolve an external alert/event back to a CMDB record.

## Schema

| Field | Purpose |
|---|---|
| `target_table` | The CMDB table the CI lives in (e.g. `cmdb_ci_ip_firewall`, `cmdb_ci_linux_server`) |
| `target_sys_id` | The CI's sys_id in CMDB |
| `name` | The discovery source name (e.g. `"Cisco DNA"`, `"FortiManager"`, `"Azure"`, `"Dynatrace"`) |
| `id` | The external identifier the source uses for this CI (DNA UUID, Fortinet serial, Azure Resource ID, Dynatrace entity ID) |
| `last_scan` | When the source last confirmed the CI was still there |

One row per `(CI, external-source)` pair. Multiple rows per CI when the CI is known by multiple sources.

## What it enables

| Use case | How |
|---|---|
| **Inbound event → CMDB CI resolution** | An external alert names a device by its source-specific ID. Lookup `sys_object_source WHERE name = "<source>" AND id = "<external_id>"` → `target_sys_id` is the SN CI. |
| **Multi-source CI enrichment** | A FortiGate ingested via Cisco DNA (network discovery) AND FortiManager (firewall management) ends up with two `sys_object_source` rows pointing at the same CMDB CI. Both sources are recorded; neither overrides the other. |
| **Cross-instance identification** | Two ServiceNow instances each pulling from the same upstream sources can correlate the same physical device via the matching `(name, id)` pair — independent of their own sys_ids. |
| **Discovery-source audit trail** | "Which external systems have confirmed this CI in the last 30 days?" — `sys_object_source WHERE target_sys_id = <ci_id>` answers it. The `last_scan` field reveals stale ingestions. |
| **Source-tool migration** | Replacing one discovery tool with another (e.g., Cisco DNA → some new network discovery product) — old rows can stay for historical reference; new rows with a new `name` value accumulate. No schema changes. |

## Common misconception

> *"`sys_object_source` is for ServiceNow Discovery (the on-prem agent-based scanner)."*

**False.** It's the universal cross-source identifier table for **any** external system that pushes CIs into CMDB. Discovery, SGC, ITOM Event Management, OneTrust, Dynatrace, Cisco DNA, FortiManager, custom integrations — they all (should) populate `sys_object_source`. SGC writes rows automatically as part of its inbound ingestion.

The corollary misconception:

> *"To track an external system's ID for a CI, we need a custom field like `u_<source>_id` on the CI table."*

**Almost always wrong.** That's schema bloat: one custom field per source, per CI class. Add a fifth integration and you're adding fields in the wrong direction. The OOTB `sys_object_source` row pattern handles N sources without any schema customisation.

Acceptable to add a custom field only when: (a) the source ID is queried so often that a join to `sys_object_source` is a performance bottleneck *and* (b) the platform team has confirmed `sys_object_source` won't be enriched by Now Platform native features in upcoming releases. Both conditions rarely true.

## Practical implications

### 1. The `name` field is a load-bearing string

The `name` value is the source-system label, and it's case-sensitive. Common values like `"Cisco DNA"`, `"Azure"`, `"Dynatrace"`. If a script writes `"cisco-dna"` while another reads `"Cisco DNA"`, the join fails silently.

**Operational rule**: maintain a registered list of canonical `name` values (e.g., as a system property or a small admin table) and require scripts to read from that list, not hard-code the string.

### 2. Lookups must filter on `name` AND `id`, never just `id`

A real-world anti-pattern (seen in some custom integrations):

```javascript
var sysobjs = new GlideRecord("sys_object_source");
sysobjs.addQuery("id", externalId);   // ← only filter on id
sysobjs.query();
if (sysobjs.next()) { … }
```

This is wrong because an external ID like `"FG-NGHQFG02"` could theoretically appear in rows from different sources with different semantics. Filter must always specify which source we're talking about:

```javascript
sysobjs.addQuery("name", "FortiManager");
sysobjs.addQuery("id", externalId);
```

### 3. SGC populates this automatically

When you configure a Service Graph Connector to ingest from a source, the connector's IRE (Identification & Reconciliation Engine) writes `sys_object_source` rows as part of every successful CI match. The connector's identification rules say *"the unique key from this source is `<field>`"* — and that value lands in `sys_object_source.id`.

If you're seeing `sys_object_source` rows missing for an integration that should be populating them, check the SGC's identifier configuration and the connector's run history — usually the rules aren't matching.

### 4. Stale rows are real

When a CI is decommissioned or a source stops reporting it, `last_scan` ages but the row doesn't auto-delete. Over time you accumulate rows pointing at decommissioned CIs. A reconciliation job that flags rows with `last_scan` older than a defined threshold is good hygiene — same job can highlight CIs that should have been retired but haven't been.

### 5. ACL and scope visibility apply

`sys_object_source` rows can be created in scoped applications. A row in scope X might not be visible to a script running in scope Y depending on ACLs. When a script "can't find" a row that you know is there, scope is the first thing to check.

## Use in integrations (e-bonds, cross-source identification)

The cleanest design pattern for any external integration that creates or updates CMDB CIs:

1. **The external system uses its own stable identifier** (DNA UUID, Fortinet serial, Azure Resource ID, etc.) — never CCH's `sys_id`.
2. **Inbound ingestion writes `sys_object_source` rows** with `name = "<source>"`, `id = "<external_id>"`, `target_sys_id` = the resolved CMDB CI.
3. **Inbound events/alerts/incidents reference the external identifier** in the payload — not the SN sys_id.
4. **Inbound event-handling logic looks up `sys_object_source(name, id)`** to resolve the CMDB CI and write to `cmdb_ci` on the incident (or wherever).

This pattern survives:
- A second SN instance correlating the same devices (both look up by `(name, id)`)
- Source tool replacement (new tool can be configured to emit identifiers from a transition-mapping table; old rows retained)
- Re-imports / rebuilds of either CMDB (sys_ids change, external IDs don't)

## When in doubt

If a script is about to **add a custom `u_<source>_id` field on a CI class** to track an external system's identifier, stop and write a `sys_object_source` row instead.

If a script is about to **hardcode an external system's `name` value** as a string literal, stop and put it in a system property or admin table.

If a `sys_object_source` query is **filtering on `id` alone**, treat it as a defect — the script may behave correctly today but is one new integration away from picking up the wrong row.

If a CI is **discovered from multiple sources** but only one source's identifier is captured, check that the multi-source ingestion is writing one `sys_object_source` row per source — many custom integrations write only one row total and lose the multi-source signal.
