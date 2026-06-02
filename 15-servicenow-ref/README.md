# 15-servicenow-ref — ServiceNow Platform Reference

**Purpose**: foundational ServiceNow platform concepts that everything else in this vault — CSDM, CCH-specific reality, Dynatrace integrations, project work — depends on. Concepts every reader needs to share before deeper discussions hold.

This pillar sits parallel to `10-csdm/`. CSDM is the *modelling framework*; this is the *runtime platform mechanics*. The two are independent but both canonical.

## When to look here

- Any time a term appears unmodified in code, queries, URLs, or platform UI — and someone asks "what does that actually mean?".
- Before joining a discussion about integrations, business rules, ACLs, scoped applications, or data references — the concepts here are the prerequisites.

## What lives here

Each note is short, definitive, and *normative* (chiselled in stone — not investigation, not opinion). One concept per note. Reference target for the rest of the vault to link to.

### Current notes

- [[sys_id]] — the universal primary key for every record on the platform
- [[sys_object_source]] — the OOTB cross-source CI identifier table (Discovery, SGC, e-bonds)
- [[glide-record]] — the server-side record API *(Draft — to be expanded)*
- [[tables/README|tables — MOC]] — index of ServiceNow tables encountered in real work; the per-table notes under `tables/` get created on demand as each table surfaces

### Candidate notes (added as the need surfaces)

- `business-rules.md` — execution order, when/onBefore/onAfter, before/after/async
- `acl-evaluation.md` — read/write/create access rules and how they interact with queries
- `scoped-applications.md` — Global vs scoped, cross-scope access, the `x_<vendor>_<app>` prefix convention
- `reference-fields.md` — dot-walking, display value vs sys_id, the dot operator in encoded queries
- `update-sets.md` — change-promotion mechanics, capture and apply
- `system-properties.md` — `sys_properties` table, namespacing, scope visibility
- `transform-maps.md` — staging table → target table conversion, field maps, transform scripts

The pattern: add a note here the first time a "wait, what does that actually mean?" moment costs more than 30 seconds to answer somewhere else.

---

*Pillar created 2026-06-01 to capture platform fundamentals that the existing pillars assumed were already known.*
