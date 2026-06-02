---
status: Approved
intent: Conceptual
---

# `GlideRecord` — the server-side record API

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Conceptual](https://img.shields.io/badge/intent-Conceptual-8B5CF6)

`GlideRecord` is the primary server-side API in ServiceNow for **reading, writing, and iterating records** in any table. It's the workhorse object referenced in business rules, script includes, scheduled jobs, transform scripts, UI actions, ACL conditions, and Flow Designer script actions. Every server-side automation that touches CMDB, incidents, change requests, tasks, users, groups, or any other table goes through GlideRecord.

## The mental model

A `GlideRecord` instance represents a **query against a single table** plus, after `.query()` runs, a cursor over the result set. The same instance becomes the "current row" as you iterate. Field access on the instance reads (or writes) values on whatever row the cursor is pointed at.

```javascript
var gr = new GlideRecord('incident');     // 1. construct against a table
gr.addQuery('priority', '1');             // 2. build the query
gr.addQuery('state', '!=', '6');
gr.query();                               // 3. execute
while (gr.next()) {                       // 4. iterate
    gs.info('P1 open: ' + gr.number);     //    instance is now the current row
}
```

Four steps, in that order. Forgetting `.query()` is the most common GlideRecord bug in CCH-style customisations — the iteration loop never runs because the query never executed; the script silently does nothing.

## Construction and the table argument

```javascript
new GlideRecord('incident')          // OOTB incident table
new GlideRecord('cmdb_ci')           // any CI (polymorphic — see below)
new GlideRecord('cmdb_ci_server')    // only server-class records
new GlideRecord('x_custom_table')    // scoped-app or custom table
```

Two notes:

- **Polymorphic tables (`task`, `cmdb_ci`)**: a query against `cmdb_ci` returns records from all subclasses. A query against `cmdb_ci_server` only returns records of class `cmdb_ci_server` or its descendants. Most scripts want the more specific class — generic-table queries are slower (every subclass is scanned) and often return more than expected.
- **Scope**: if your script runs in scope X and the table is in scope Y, cross-scope read/write access is controlled by the application's "Accessible from" setting AND by scope-level ACLs. Cross-scope GR queries that fail silently are nearly always a scope ACL issue, not a query issue.

## Querying

| Method | Purpose | Example |
|---|---|---|
| `addQuery(field, value)` | Equals condition | `gr.addQuery('priority', '1')` |
| `addQuery(field, op, value)` | Comparison with operator | `gr.addQuery('sys_created_on', '>', javascript:gs.daysAgo(30))` |
| `addQuery(field, 'IN', list)` | Multi-value match | `gr.addQuery('state', 'IN', '1,2,3')` |
| `addNullQuery(field)` / `addNotNullQuery(field)` | Empty / non-empty | `gr.addNullQuery('cmdb_ci')` |
| `addEncodedQuery(string)` | Parse a `^`-separated query string | `gr.addEncodedQuery('state!=6^priority=1')` |
| `addOrCondition(field, value)` | OR within the previous addQuery's expression | (limited use; addEncodedQuery is usually cleaner) |
| `setLimit(n)` | Stop after n rows | `gr.setLimit(100)` |
| `orderBy(field)` / `orderByDesc(field)` | Sort | `gr.orderByDesc('sys_created_on')` |
| `query()` | Execute the query | mandatory before iteration |
| `getRowCount()` | Total rows matched (server round-trip) | informational; use sparingly — it's a DB count |

Encoded queries (`'state!=6^priority=1^opened_by=javascript:gs.getUserID()'`) are exactly what the platform stores in saved filters and what URL query parameters use. They're often easier to copy-paste from a list-view URL than to translate into chained `addQuery` calls. Both forms compose: `gr.addQuery('table', X)` AND `gr.addEncodedQuery(Y)` is `(X) AND (Y)`.

## Iteration

```javascript
gr.query();
while (gr.next()) {
    // loop body — gr is now the current row
}
```

`next()` advances the cursor and returns `true` while there's a row to read; `false` when the result set is exhausted. The first call to `next()` moves to the first row (cursor starts before the first row).

### Iterate-once is a different intent

A common anti-pattern observed in CCH business rules: `while (gr.next())` used when the script only needs the **first** match, not all matches. The loop body runs once per row and the script writes the same field repeatedly, with **last-match-wins** semantics — usually accidental. If you want the first match:

```javascript
if (gr.next()) {
    // single-row handling
}
```

`if` is explicit. `while` is a code smell when the body sets a field once.

(Example we've audited at CCH: the `Populate Service Offering` business rule uses `while` to iterate `sc_cat_item_subscribe_mtom` and overwrites the same `current.service_offering` on every iteration — last-match-wins. Almost certainly intended as `if`.)

### `getRowCount()` vs `.next()` checks

`getRowCount()` returns the total matched rows but **runs an extra database round-trip** (a SQL `COUNT` query). If you only care "did anything match?", use `.next()` directly:

```javascript
gr.query();
if (gr.next()) {  // true if any match
    // ...
}
```

Reserve `getRowCount()` for cases where the count itself is the answer (e.g., logging "12 records updated"), not as a precondition check.

## Single-record lookup: `.get()`

For a known sys_id, `.get(sys_id)` is the idiomatic shortcut:

```javascript
var gr = new GlideRecord('incident');
if (gr.get('abc123def456...')) {
    gs.info('Found: ' + gr.number);
}
```

Equivalent to `addQuery('sys_id', sys_id)` + `query()` + `next()` in one call. Returns `true` if found.

`.get()` also accepts a `(field, value)` overload for matching on a single non-sys_id field — but only when the match is expected to be unique. If multiple rows match, you get the first one without warning, which is usually a bug.

## Field access — three flavours

This is where most subtle bugs live. ServiceNow gives three ways to read a field's value:

| Form | Returns | When to use |
|---|---|---|
| `gr.field_name` (direct dot access) | **String coercion** of the underlying GlideElement object | Generic logging or string concatenation. **Treat as display-value in most contexts.** |
| `gr.getValue('field_name')` | The raw stored value (e.g., the sys_id of a reference field, the integer of a choice field) | Comparisons, foreign-key lookups, writing the value to another field via `setValue()` |
| `gr.getDisplayValue('field_name')` | The human-readable rendered value | UI output, notifications, log messages |

For a reference field on incident pointing at a server CI:

```javascript
gr.cmdb_ci                    // displays the server's name (e.g., "vmuslmscs001")
gr.getValue('cmdb_ci')        // returns the sys_id (e.g., "abc123def456...")
gr.getDisplayValue('cmdb_ci') // displays the server's name
```

The trap: `gr.cmdb_ci == 'abc123def456...'` evaluates *false* (left side is the display value), even though that sys_id IS the underlying stored value. Comparisons against sys_ids must use `getValue()` or explicit `.toString()`.

## Dot-walking reference fields

```javascript
gr.cmdb_ci.sys_class_name        // class of the referenced CI
gr.cmdb_ci.owned_by.email        // email of the CI's owner (two dot-walk steps)
gr.assignment_group.support_group.name   // dot-walk through multiple references
```

Each `.` traverses one reference. Three properties to remember:

1. **One database query per dot per row.** A loop that dot-walks 3 levels deep on 1,000 rows triggers ~3,000 implicit queries. For performance-critical loops, fetch the related records explicitly with their own GlideRecord queries.
2. **`null` propagates silently.** If `gr.cmdb_ci` is empty, `gr.cmdb_ci.owned_by` returns an empty value, not an error. The script doesn't crash — it just silently gets nothing. Defensive code checks each intermediate field for `nil()` before dot-walking.
3. **In encoded queries**, the same dot-walking syntax works in the **field name**, not in the value: `addEncodedQuery('cmdb_ci.sys_class_name=cmdb_ci_linux_server')`. Filters dot-walking through references in the WHERE clause.

## Writing — insert, update, delete

```javascript
// Insert
var gr = new GlideRecord('incident');
gr.initialize();
gr.short_description = 'New incident from script';
gr.priority = '2';
gr.cmdb_ci = '<some sys_id>';
var sysId = gr.insert();    // returns the new record's sys_id

// Update
gr.setValue('priority', '1');
gr.update();

// Delete
gr.deleteRecord();
```

Three rules:

- **`.initialize()` is required before `.insert()`** if you didn't load a row first. Without it, `.insert()` may carry over default values or fail.
- **Set fields via direct assignment (`gr.field = value`) or `setValue(field, value)`.** They behave equivalently for most cases; `setValue` is preferred when the field name is dynamic (`gr.setValue(dynamicFieldName, value)`).
- **`.update()` updates the currently-positioned row**, not arbitrary rows. To update many rows, iterate and call `.update()` in the loop.

### Bulk delete — `.deleteMultiple()`

```javascript
gr.query();
gr.deleteMultiple();   // deletes ALL matched rows
```

A scary one. No confirmation, no per-row hook, no audit trail expansion beyond the platform's standard delete logging. Used responsibly for cleanup jobs; should never appear in a business rule that runs on user-action without strong gates.

## ACL evaluation and silent record dropping

GlideRecord queries are **subject to ACLs by default** (for non-system users). If the caller doesn't have read access to a row, it doesn't appear in the result set — without warning. This is the biggest source of "the script returns nothing but I can see the record on the form" mysteries.

Three things to know:

1. **System-account scripts** (running as the integration user) often bypass ACLs implicitly via elevated roles like `admin`, `snc_internal`. The role matters: a script running as `SA_DYNATR_SNOW` sees what `SA_DYNATR_SNOW` is allowed to see — which may be less than the developer expects.
2. **`gr.setWorkflow(false)` disables business rules during write** — useful for bulk updates that shouldn't trigger downstream automation. Doesn't affect ACLs.
3. **Cross-scope queries**: a GR query in scope X against a table in scope Y is constrained by the application's "Accessible from" setting. A record may be physically present and ACL-readable but invisible to the cross-scope caller.

## Common pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Forgetting `.query()` | Loop body never executes; no error | Add `gr.query()` before `while/.next()` |
| `while` when you want `if` | Last-match-wins semantics; field overwritten silently | Use `if (gr.next())` for single-match logic |
| `addQuery('sys_id', value)` instead of `.get(value)` | More verbose; same effect | Prefer `.get(value)` when looking up by sys_id |
| Comparing sys_id strings against `gr.refField` directly | Comparison evaluates false even when the sys_ids match | Use `gr.getValue('refField') == sysIdString` |
| Dot-walking through a `nil()` reference | Silent empty result | Guard with `if (!gr.refField.nil()) {…}` |
| `.deleteMultiple()` without `setLimit()` | Wipes an entire table if the query matches everything | Always pair with explicit `addQuery` filters; never use on whole-table |
| Querying a polymorphic table (`task`, `cmdb_ci`) when the specific class is known | Slower; returns more than expected | Use the most specific class possible |
| Cross-scope GR returns nothing | Scope-level ACL is hiding the records | Check the target application's "Accessible from" setting |

## Performance considerations

1. **Filter before iterating.** `addQuery` calls run as `WHERE` clauses in the underlying SQL. Filtering 50 rows in the database is orders of magnitude faster than fetching 50,000 and skipping in JavaScript.
2. **`setLimit()` for read-bounded loops.** If a script only needs the first 10 results, `setLimit(10)` prevents pulling 10,000 over the wire.
3. **`getValue()` is faster than `getDisplayValue()`** for reference and choice fields because it doesn't dereference. Use it in tight loops where the raw sys_id or stored value is enough.
4. **Avoid `getRowCount()` as a precondition check** — it's a separate DB round-trip. Use `.next()` directly.
5. **Dot-walking is implicit joins.** A 3-level dot-walk on 10,000 rows is 30,000 DB hits, not 10,000. Fetch the related records up front for tight loops.
6. **`new GlideAggregate(table)`** is the right tool when you need counts, sums, or group-bys at scale — GR is row-by-row, GlideAggregate is set-based.

## When in doubt

If a GlideRecord script "isn't returning anything", check in this order:

1. Did `.query()` run? (most common — missing entirely)
2. Are the `addQuery` values the right type? (string `'1'` vs integer `1` for state/priority — usually the platform normalises, but not always)
3. Is the caller's role allowed to read the records? (ACL filter dropping them)
4. Is the query against the right table? (querying `cmdb_ci` when expecting subclass behaviour; or querying scoped table from wrong scope)
5. Has the record actually been inserted? (in `before` business rules, the record isn't persisted yet — querying for it returns nothing)

If a GlideRecord write isn't applying, check in this order:

1. Was `.initialize()` called before `.insert()`?
2. Did you call `.update()` or `.insert()`? Setting fields without calling the persist method does nothing.
3. Are the values the right type / format? (Choice fields require the choice value, not the label.)
4. Is the field writable by the caller? (ACL write-rule may block the write silently — check the system log for ACL violations.)
5. Is `gr.setWorkflow(false)` accidentally set, skipping side-effects you expected from business rules?

GlideRecord keys on [[sys_id]] for every record-identification operation — see that note for the underlying primary-key model.
