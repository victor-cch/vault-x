---
status: Approved
intent: Normative
---

# `sys_id` — the universal record identifier

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Normative](https://img.shields.io/badge/intent-Normative-EF4444)

**`sys_id` is the primary key of every record in every table in ServiceNow** — not just CMDB. Every user, every incident, every business rule, every system property, every catalog item, every table definition itself has one.

## Properties

| Property | Detail |
|---|---|
| **Format** | 32-character hexadecimal string (e.g. `34a001a8fbe87a50bf3ffee64eefdc44`). No dashes, no separators. |
| **Uniqueness** | Globally unique across the entire instance. No two records share a sys_id, regardless of table. |
| **Generation** | Auto-assigned by the platform on `INSERT`. Cannot be specified by the caller (with rare admin exceptions). |
| **Mutability** | Immutable for the record's lifetime. Renaming, retyping, moving — none of it changes the sys_id. |
| **Foreign key role** | Reference fields store the target record's sys_id. When an incident's `cmdb_ci` points at a server, the field's stored value IS the server's sys_id. |
| **URL-addressable** | Every record can be opened directly: `<table_name>.do?sys_id=<sys_id>`. A "record not found" response from this URL means the sys_id does not correspond to any row in that table. |

## Common misconception

> *"sys_id is the ID of every object in CMDB."*

**False.** It's the ID of every record in every table on the platform. CMDB is a *subset* of tables (those prefixed `cmdb_ci_*`, `cmdb_rel_ci`, etc.) — but `sys_id` exists on `incident`, `sys_user`, `sys_user_group`, `sc_cat_item`, `sys_properties`, `sys_script`, `sys_db_object`, every single table. The CMDB association is coincidental: CIs are records, and records have sys_ids.

## Practical implications

### 1. Hardcoded sys_ids in scripts are a load-bearing reference

When a transform script or business rule contains a literal like:

```javascript
target.u_subcategory = '106f22a101d842003d4d4e1347805997';
```

…it is naming a specific row in some specific table. If that row is deleted or never existed, the script silently sets an invalid reference. **The platform will not warn you**: reference fields don't validate their targets at write time.

To check whether a hardcoded sys_id resolves: navigate to `<expected_table>.do?sys_id=<sys_id>` in the browser. If "record not found", the reference is dead.

### 2. URLs reveal the table

URLs of the form `xxx.do?sys_id=...` expose two things at once:
- `xxx` = the table the platform thinks the record lives in
- `sys_id` = the row

When inheriting an instance and chasing what an obscure ID means, the first move is: try `<table>.do?sys_id=<id>` against the most likely table. If you don't know the table, the dictionary entry for the reference field that uses the sys_id tells you (see `sys_dictionary.do` for any field's `reference` attribute).

### 3. Display value ≠ sys_id

The form UI renders reference fields as their **display value** (a human-readable string like `"Linux Server: vmuslmscs001"`). The underlying stored value is the sys_id. When pasting field contents between systems, scripts, or CSVs — be explicit which you mean: dot-walks like `current.cmdb_ci` yield the display value in string contexts, `current.cmdb_ci.sys_id` (or `current.cmdb_ci.toString()`) yields the sys_id.

### 4. Encoded queries against sys_id

ServiceNow's encoded query syntax treats sys_id specially in some operators:

| Operator | Example | Behaviour |
|---|---|---|
| `=` | `sys_id=34a001a8...` | Direct lookup by primary key |
| `IN` | `sys_idIN<id1>,<id2>,<id3>` | Lookup multiple |
| `INSTANCEOF` | (only on `sys_id` of inheritance-aware tables) | Includes subclass records |

The fastest possible query on any table is `addQuery('sys_id', '<id>')` — it bypasses index scans and goes straight to the primary-key lookup.

### 5. Cross-instance migration breaks unless you carry sys_ids

If you copy a record from one instance (dev) to another (prod) using Update Sets, the Update Set carries the sys_id, so the prod record is the same record as the dev record (same primary key). If you instead export-and-reimport via CSV without preserving sys_id, prod gets a **new** record with a new sys_id — and every reference to the old sys_id in prod stays broken.

This is why Update Sets exist, and why hand-built imports of business rules / catalog items / scripts are a known source of "dead reference" issues.

## Use in integrations (e-bonds, write-back, deep links)

External systems integrating with ServiceNow — service providers, e-bond peers, ticketing platforms, observability tools — should carry **both the record's `number` and its `sys_id`** in every cross-system payload. Number is for humans; sys_id is for machines and contracts. The two play different roles and neither one alone is sufficient.

| Concern | Why both are needed |
|---|---|
| **Disambiguation across instances** | Each ServiceNow instance has its own `number` counter. Customer `INC1811586` and a provider's `INC1811586` (in their own SN instance) are completely different records. Sys_id pins which instance and which row. |
| **Immutability against renumbering** | `number` can be reformatted by an admin (e.g. CCH migrated 7-digit numbers to 8-digit format historically). Sys_id survives. Long-running integrations that key off number break under renumbering; sys_id-keyed references do not. |
| **Deep-link construction** | To open the exact record from the provider's UI, the deep-link is `incident.do?sys_id=...`. With only the number, the provider must do a `GET /api/now/table/incident?sysparm_query=number=...` first, then open the result — slower, more fragile. With sys_id, it's a direct URL. |
| **Idempotency on write-back** | When the provider sends "here is an update for record X", referencing by sys_id guarantees the update lands on the intended record. Number-only references have edge cases (renumbering windows, restored-from-backup records, accidental duplicates). Sys_id has none. |
| **Audit cross-reference** | Sys_id appears in every ServiceNow internal audit trail (`sys_audit`, ECC queue, system logs). Providers including sys_id in their own logs means a 1-to-1 join between the two logs is possible without a translation table. |
| **Defensive validation** | The provider can verify the message is consistent: receive a payload claiming `INC1811586 / sys_id abc123…` → look up sys_id in ServiceNow → confirm the resulting record's `number` matches. Mismatch indicates corruption, replay, or spoofing — surface as an error rather than write to the wrong record. |

**Rule of thumb**: if an e-bond / integration spec asks for only one of the two identifiers, that's a design smell. Asking for only `number` loses machine reliability and audit defensibility. Asking for only `sys_id` loses human verifiability (no one can quote it on a phone call). The textbook pattern is both.

In regulated or contractual contexts (most e-bonds are one or the other), being able to prove *"this is THE record, not just A record with that name"* can be legally relevant. Sys_id is the only identifier the platform guarantees for that purpose — the `number` is best-effort.

## Related concepts

- [[glide-record]] — the server-side API for reading and writing records via their sys_id (TBD)
- [[reference-fields]] — how reference fields store and resolve sys_ids (TBD)
- [[update-sets]] — sys_id preservation across instances (TBD)

## When in doubt

If a sys_id appears in a script, a log, an audit trail, a hardcoded fallback, or a system property and its meaning isn't immediately obvious:

1. Look at the field's dictionary entry to find the target table.
2. Open `<target_table>.do?sys_id=<the_id>` in the browser.
3. If the record exists → its `Name` (or equivalent display field) tells you what the reference means.
4. If "record not found" → the reference is dead; the script that uses it has a silent failure point.
