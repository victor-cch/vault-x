---
status: Draft
intent: Conceptual
---

# `GlideRecord` — server-side record API

![Status: Draft](https://img.shields.io/badge/status-Draft-F59E0B) ![Intent: Conceptual](https://img.shields.io/badge/intent-Conceptual-8B5CF6)

The primary server-side API for reading, querying, and writing records in ServiceNow. Used in business rules, script includes, scheduled jobs, transform scripts, and Flow Designer script actions.

## To be written

- Construction (`new GlideRecord('table')`) and table scoping
- Query building: `addQuery`, `addEncodedQuery`, `addOrCondition`, comparison operators
- Iteration: `query()` then `next()`; the difference vs `get()` (single-record lookup by sys_id)
- Field access: direct dot access (returns display value in string contexts) vs `getValue('field')` (sys_id / raw value) vs `getDisplayValue('field')`
- Dot-walking reference fields: how `record.ref_field.sub_field` resolves
- Writes: `setValue`, `update()`, `insert()`, `deleteRecord()`
- Read access vs ACL evaluation: when queries silently drop records the caller can't read
- Common pitfalls: not calling `.query()`, comparing against `null` vs `nil()`, conditional writes inside `while` vs `if`

Anchor cross-reference: every `GlideRecord` operation ultimately keys on [[sys_id]] — see that note for the underlying record-identification model.
