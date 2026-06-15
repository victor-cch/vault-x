---
status: Approved
intent: Conceptual
---

# `correlation_id` — the cross-instance record identifier

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981) ![Intent: Conceptual](https://img.shields.io/badge/intent-Conceptual-8B5CF6)

`correlation_id` is an **OOTB string field present on virtually every task-based table** in ServiceNow (`incident`, `sc_request`, `sc_req_item`, `change_request`, `problem`, …). Its job is to hold a **foreign identifier**: the key by which *this* record is known in *another* system. The platform does not interpret it — it is deliberately generic. Its entire purpose is integration: it lets an external system (or a second ServiceNow instance) say *"the record I'm sending you corresponds to **this** one you already have."* It is the join key across a system boundary.

## Properties

| Property | Detail |
|---|---|
| **Type** | Plain string (max 255 chars). No reference, no validation, no uniqueness constraint enforced by the platform. |
| **Scope** | Exists OOTB on `task` and its children (INC/REQ/RITM/CHG/PRB). Inherited, not per-table-custom. |
| **Semantics** | Holds the *foreign* system's handle for this record — not this instance's own identity (that's [[sys_id]] / `number`). |
| **Who writes it** | Whatever creates the pairing: integration middleware (mints once), a native product (ServiceBridge), or a human (swivel-chair). |
| **Direction** | One value per record, pointing "outward". In a bidirectional pair, *each* record's `correlation_id` points at its twin. |

## What it is not

`correlation_id` is the **matching** key. It is frequently confused with two neighbours that do different jobs:

| Field | Question it answers | Job |
|---|---|---|
| `correlation_id` | *"Which record over there is the same as this one?"* | **Matching** — find-or-create, idempotency, reconciliation |
| `sys_id` | *"Which record is this, here?"* | **Local identity** — primary key within one instance |
| source-instance tag (e.g. `x_ebond_source`) | *"Who wrote this update — do I echo it back?"* | **Loop control** — suppress ping-pong |

Matching the pair (`correlation_id`) and stopping the echo (source tag) are separate concerns. An integration needs both; one does not substitute for the other.

## Common misconception

> *"`correlation_id` and `sys_id` are interchangeable ways to identify a record across systems."*

**False.** They point in opposite directions. `sys_id` is *this* instance's own primary key — meaningless to the peer, who has their own `sys_id` for their copy. `correlation_id` is where *this* instance stores the *peer's* handle. In a healthy e-bonded pair the two records cross-reference: CCH's record carries GSNOW's identifier in `correlation_id`, and GSNOW's record carries CCH's. Neither side's `sys_id` ever travels as the other side's identity — it travels *into* the other side's `correlation_id`.

The corollary misconception:

> *"To link a ticket to a partner's ticket, we need a custom field like `u_<partner>_ref`."*

**Usually wrong.** `correlation_id` is OOTB and exists for exactly this. A custom field is only justified when a single record must be correlated to **more than one** foreign system simultaneously (rare on transactional records) — at which point the right pattern is a small related table, not a field per partner.

## The three jobs it does in any e-bond

1. **Find-or-create (no duplicates).** Every inbound update is tagged with the correlation key. The receiver asks *"do I already hold a record with this key?"* — yes → apply the update; no → create. Without it, every inbound message risks spawning a fresh duplicate.
2. **Idempotency.** A replayed message (store-and-forward after an outage) lands on the same record rather than creating a second one. Re-sending is safe by construction.
3. **Reconciliation & audit.** A drift job walks the pairs *by correlation key* to catch divergence (closed one side, open the other — e.g. an auto-close-timing asymmetry across the seam). Because both instances log the same key, a single ticket's history joins across both platforms' `sys_audit`.

## Use in integrations — the concept is universal, the field is the SN-side instrument

The **pattern** — a stable foreign-system handle for matching, idempotency, and reconciliation — is integration-universal. `correlation_id` is the ServiceNow-side field that implements it. *How* it gets populated varies by integration shape:

| Integration shape | Population | Notes |
|---|---|---|
| **SN ↔ SN via middleware** (e.g. NTT iHub e-bond) | **Machine-minted once** by the middleware onto both records at pair creation | The middleware owns the key; both `incident`/`sc_request` records carry it. The textbook case. |
| **SN ↔ SN, native product** (e.g. Orange ServiceBridge) | **Product-managed** — ServiceBridge uses `correlation_id` as its native cross-instance pairing key | Same mechanism as middleware, but the platform product brokers it rather than custom integration code. |
| **SN ↔ non-SN** (e.g. Jira) | **Asymmetric**: SN stores the foreign key (e.g. Jira `PROJ-123`) in `correlation_id`; the peer stores SN's `number`/`sys_id` in *its* own field | The handle is universal; only the SN side calls it `correlation_id`. The peer has an equivalent field under another name. |
| **Swivel-chair** (manual re-key, no middleware) | **Human-keyed** — an operator types the foreign number into the field on each side | Same concept, weakest enforcement: omission is the live risk, guarded by a reconciliation report that flags records with no foreign match. |

**Pair with `number` and `sys_id`, not instead of them.** A robust cross-system payload carries the peer's `number` (for humans), its `sys_id` (for machine reliability and audit — see [[sys_id]]), *and* uses `correlation_id` to store that handle locally. Asking for only one identifier is a design smell.

## Relationship to `sys_object_source`

Both are cross-boundary identifiers, but for different record kinds — keep them distinct:

| | Identifies | Across | Table/field |
|---|---|---|---|
| [[sys_object_source]] | a **CMDB CI** | external *sources* (Discovery, SGC, Dynatrace, Cisco DNA) | dedicated table, one row per `(CI, source)` |
| `correlation_id` | a **transactional record** (INC/REQ/CHG/PRB) | other *instances* / ticketing systems | a field on the task record |

CIs are correlated by `sys_object_source`; tickets are correlated by `correlation_id`. An integration that e-bonds *tickets* and aligns *CIs* uses both — `correlation_id` to pair the incident, `sys_object_source` (or the manual CMDB process) to resolve its CI.

## Practical implications

### 1. No uniqueness constraint — enforce it in logic
The platform does not stop two records sharing a `correlation_id`. Find-or-create logic must query on it and handle the "more than one match" case as an error (corruption/replay), not silently pick the first.

### 2. Mint once, never re-mint
The correlation key is established at pair creation and is immutable for the pair's life. Re-minting on a later update orphans the original pairing and produces duplicates downstream.

### 3. It is not loop control
Suppressing echo updates is the source-instance tag's job, not `correlation_id`'s. Conflating them produces either infinite ping-pong (no tag) or dropped legitimate updates (matching mistaken for loop control).

### 4. Manual population is the weak link
In swivel-chair and any human-keyed correlation, a skipped or mistyped value silently breaks the join. The standard guard is a periodic reconciliation report flagging records with no resolvable foreign match.

## When in doubt

- If an integration spec asks how to link a ticket to its partner copy and someone proposes a **custom `u_<partner>_ref` field**, stop — `correlation_id` is OOTB and is the answer unless the record genuinely needs *multiple* simultaneous foreign references.
- If two records share a `correlation_id` unexpectedly, treat it as a defect (replay, double-create, or restore-from-backup) — not as data to pick the first row from.
- If updates are ping-ponging, the fault is loop control (the source tag), **not** `correlation_id`.
- If a manually-keyed correlation is missing on one side, the swivel-chair step was skipped — the reconciliation report is the control that should have caught it.

## Related concepts

- [[sys_id]] — this instance's own primary key; the machine identifier that should *travel into* the peer's `correlation_id`, paired with `number`
- [[sys_object_source]] — the equivalent cross-boundary key for CMDB CIs (per external source), not transactional records
