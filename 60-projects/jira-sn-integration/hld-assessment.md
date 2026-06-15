# Assessment — SNOW ITSM ↔ Jira Integration HLD

![Status: Draft](https://img.shields.io/badge/status-Draft-F59E0B)
![Intent: Analytical](https://img.shields.io/badge/intent-Analytical-8B5CF6)

| Field | Value |
|---|---|
| Subject | HLD — SNOW ITSM ↔ Jira Integration (v1.0, "In Review", author Ahmed Badr) |
| Reviewer | — |
| Date | 4 June 2026 |
| Verdict | Sound direction; **not yet go-live ready** — several correctness, data-model, and governance gaps to close |

> Transcribed HLD: `hld-snow-jira-integration.md` (same folder). This assessment does not modify it.

---

## Top line

A competent, config-first design that gets the fundamentals right: IntegrationHub + Jira Spoke over custom REST, a correlation-ID link, an explicit conflict-ownership model, and an acknowledged sync-loop safeguard. **But this is, structurally, a bidirectional e-bond between CCH ServiceNow and a partner's (XTEL) Jira** — and it carries the classic bidirectional-sync hazards. The HLD *names* the hard problems (loop prevention, conflict resolution) but does not yet *design* them, and there are concrete data-model gaps that will abort real transactions on day one. Treat the items in §3 as blockers, §4 as must-fix-before-prod, §5 as cross-document reconciliation.

---

## 1. What's solid

- **Config over customization** — IntegrationHub Jira Spoke rather than hand-rolled REST. Right default.
- **Correlation model** — Jira Issue Key in `correlation_id`, SNOW Number in Jira `customfield_10061` (External Issue ID). Two-way linkage + create-vs-update routing keyed on `correlation_id` gives idempotent *creation*. Good.
- **Explicit conflict-ownership intent** — Jira owns execution fields, SNOW owns ITSM fields, latest-timestamp for shared free-text. Most integrations skip this entirely; having a stated model is a real strength.
- **Clear scope fence** — no historical backfill, no SLA/timer sync, RITM-level (not REQ/`sc_task`), only mapped fields. Tight, sensible boundaries.
- **Sized** — 18–20k/month, 600–900/day, 40–60 txn/hr; async webhooks. The author thought about load.
- **Credential hygiene** — token in the Credentials module, encrypted at rest, alias-bound, rotation owned by XTEL with no code change. Correct pattern.

---

## 2. The framing that reframes everything

This is an **e-bond**, not a one-way feed. Both systems create, both update, both close — across an organizational boundary (CCH ↔ XTEL). That means it lives or dies on three mechanisms the HLD currently asserts rather than specifies: **loop prevention, conflict resolution, and ordering**. The race-condition analysis from the IM HLD review (`daily-log/2026-06-04-im-hld-csdm-v5-ebond-review.md`) applies almost verbatim here — this HLD is the concrete instance of that abstract risk set.

---

## 3. Blockers — these will abort real transactions

- **Mandatory Jira fields have no ServiceNow source.** The field-values table marks **Division, Components, Environment, Hypercare** as `Mandatory = Yes` with `SNOW Field Name = N/A`. The Functional Requirements then say outbound flows *abort* if these are missing. **Therefore every SNOW→Jira create aborts** unless these are sourced from somewhere. Resolve: add SNOW fields / catalog variables / defaults, or declare that SNOW→Jira creation is not actually supported for these work types. This is the single biggest gap.
- **Sync-loop safeguard is a black box.** "Logic implemented to prevent infinite loops" — but no mechanism is described. This is *the* correctness control for bidirectional sync. Specify it: how does an inbound Jira update get distinguished from a human SNOW edit so it isn't echoed back? Standard pattern = an "updated-by-integration-user" / last-sync-source marker that suppresses the outbound trigger. Without a written design this is unverifiable.
- **Jira workflow transitions are guarded — the dynamic map assumes they're always available.** A Jira issue only accepts a transition valid from its *current* status. The Dynamic Status Mapping is keyed on SNOW old→new state, not on Jira's current status, so e.g. firing "Solve Issue" when the Jira issue isn't in a transitionable state will 400/fail. Need: compute the transition from Jira's actual current status, and handle invalid-transition errors. The map also has missing pairs (e.g., On Hold(3)→Closed(7), WIP(2)→Open(1)).
- **Closure/resolution will fail SNOW mandatory validation.** Jira Resolved/Closed → SNOW Resolved(6)/Closed(7), but OOTB SNOW requires `resolution_code` / close notes on resolve. Jira likely won't supply them. Map a resolution field or set a default, or the inbound close aborts.

---

## 4. Must-fix before prod — correctness, security, operability

### Race conditions & data integrity
- **Duplicate creation race.** SNOW creates a Jira issue → Jira's "issue created" webhook fires back to SNOW before SNOW has written `correlation_id`. The create-vs-update guard can miss, creating a second SNOW record. Mitigate: write `correlation_id` synchronously on the create response, and have the inbound flow also match on `External Issue ID` (`customfield_10061`).
- **"Latest timestamp wins" is unsafe across two clocks.** SNOW `sys_updated_on` vs Jira `updated` are different clocks; skew + no tolerance window means a stale write can win and silently overwrite a human edit to Summary/Description. Prefer a designated authority even for free-text, or last-writer-with-origin-tracking and a skew tolerance.
- **Priority is bidirectional but SNOW priority is derived.** SNOW `priority` is computed from Impact × Urgency (OOTB). Letting Jira overwrite `priority` directly desyncs it from Impact/Urgency. This **directly conflicts with the CCH IM HLD** ("Priority cannot be changed directly — adjust Impact/Urgency"). Also the value tables are inconsistent: Jira priority `10004` (blank name) is unmapped, and "Any other Value → Normal" silently flattens. Reconcile the mapping and decide whether Jira may set priority at all.
- **Reopen thrash.** Resolved/Closed → Open transitions exist on both sides; with bidirectional sync a reopen can ping-pong. Ties back to the loop safeguard — needs the same origin-suppression.

### Comments & attachments
- **Comment leakage / visibility.** Bidirectional comment sync across an org boundary: SNOW `work_notes` (internal) vs `comments` (customer-facing), and Jira internal vs public comments. Unmanaged, internal notes leak to the partner. Specify which comment type maps where and how internal/private is handled.
- **Attachment controls.** Size/type limits, malware scanning, and loop-on-attachment (a synced attachment re-triggering sync) are unaddressed. Large files over webhook/REST need a strategy.

### Security
- **Inbound webhook trust is unspecified.** SNOW→Jira auth (token) is covered; Jira→SNOW is not. A Flow Designer webhook trigger URL must be authenticated / verified (shared secret, signature, IP allow-list) or it's an unauthenticated write path into Incident/RITM. Specify inbound verification.

### Operability
- **Error handling is a checkbox.** At 600–900/day with guarded transitions and mandatory validation, failures are routine. There's no retry/backoff, dead-letter, alerting, or reconciliation design. Even 1% failure ≈ 180–200 stuck tickets/month. Define the failure path and who watches it.
- **Update idempotency under retry.** Field updates are safe to re-apply; **transitions are not** (re-firing "Close Issue" fails). Retry logic must distinguish the two.
- **Planning & Risk Management = NA.** No rollback, no test strategy beyond "validate via REST", no KPIs/cutover detail. For a go-live integration this section can't stay empty.

### Volume & sizing — the transaction count is light by ~an order of magnitude

- **They counted tickets, not transactions.** The stated "40–60 bi-directional transactions/hour" ≈ the ticket-arrival rate (40–60/hr × 24h ≈ 600–900/day). But a *bidirectional* sync emits several transactions per ticket lifetime — create + the Jira echo-back + each state transition (each way) + comments + attachments + the suppressed loop round-trips. Realistically **8–20× per ticket**, so true transaction volume is **~5–10× the budgeted figure**.
- **No peak headroom.** ITSM arrival isn't uniform — Monday mornings, monitoring storms, major incidents run 3–5× average. "Designed for 40–60/hr" has zero burst margin.
- **It undercuts the HLD's own claim.** The document asserts this volume runs "without exceeding standard API rate limits" — unsupported at the true rate, against Jira Cloud 429 throttling, with **no backoff/retry designed** (§4 Operability).
- **IntegrationHub is transaction-metered.** At the real per-ticket transaction count, monthly IH consumption could run into the **hundreds of thousands of transactions** — a licensing/quota exposure the HLD never mentions.
- **Internal inconsistency**: 20,000/month ÷ 30 calendar days = ~667/day, but ÷ ~21 business days = ~950/day — the "600–900/day" figure mixes calendar- and business-day denominators.
- **Fix**: re-derive transaction volume from a per-ticket lifecycle model; size IH entitlement and Jira rate-limit headroom against *peak*, not average; add backoff/retry/dead-letter accordingly.

---

## 5. Reading the volume — a Sherlock note

The numbers don't only fail to reconcile; they describe what's actually flowing through the pipe.

- **600–900 tickets/day for one platform is not development output.** No engineering team genuinely produces ~900 work items/day. So this isn't "work being created" — it's a **support firehose**. The overwhelming majority must be operational: incidents, data fixes, failed jobs, report discrepancies, access and how-to.
- **The Components list is the tell.** *Jobs & Batches, Data Integration, Performance, Reporting* — the vocabulary of **batch / ETL / data-pipeline operations**. A trade-promotion platform (PromoPlan, TPM, PUD) running promotions across CCH's ~29 markets throws off enormous recurring data/batch *exception* volume.
- **"Guidance and Training" maps to the Incident table** (work type 10009 → `incident`). So how-to / training questions are logged — and counted — as **incidents**. That's (a) a slice of the volume that isn't breakage at all, and (b) incident-metric pollution that contradicts the CSDM-aligned IM model.
- **The deduction**: this is neither heroic throughput nor (only) staggering scale. It's the signature of **operational toil + data/batch exceptions + adoption friction** — much of which should be *engineered away* (self-service data fixes, batch auto-remediation) or *deflected* (KB/training), not individually ticketed. The volume is a **symptom of under-automation and an adoption gap**, not a measure of value produced. Even "a DevOps team sending problems to the Moon" wouldn't sustain this — because most of these aren't engineering problems.
- **The corollary for *this* integration**: if a large share of the 18–20k is low-novelty, repetitive, or training-as-incident, then e-bonding **all** of it (at the 5–10× transaction multiplier) amplifies noise. A quality design **filters what crosses the bond** — only engineering-actionable tickets sync — rather than mirroring the whole firehose both ways. Garbage propagated bidirectionally at scale is garbage twice.
- **Before sign-off**, treat the volume as a prompt to profile ticket *composition* (genuine defects vs data/batch toil vs training) — both to size correctly and to decide what actually deserves to be synced.

---

## 6. Cross-document reconciliation (with the CCH IM HLD)

This integration must sit *under* the IM process, not beside it. Conflicts to resolve with `blueprints/incident-management/hld-sn-incident-management.md`:

- **Priority authority** — IM HLD forbids direct priority edits (derive from Impact/Urgency); this HLD makes priority bidirectional. Pick one.
- **States** — IM HLD reverts to OOTB states (New / In Progress / On Hold / Resolved / Closed Complete/Incomplete). This HLD's Static Status table uses "Open / Work in Progress / Info Waiting / Pending Closure" labels — partly legacy/SR-flavored. Align the state vocabulary and `hold_reason` handling (Awaiting Customer ↔ Awaiting Vendor).
- **Incident-table pollution** — the Work Type Mapping routes "Guidance and Training" (10009) to the **Incident** table. Training/how-to items logged as incidents inflate incident volume and MTTR and break the CSDM-aligned IM model. Route these to Request / a how-to channel, not Incident.
- **Assignment routing** — IM HLD routes via CSDM (Service Offering → support group). This HLD doesn't say how `assignment_group` is set on a **Jira-created** SNOW incident. Define it, or Jira-origin incidents bypass the CSDM routing the IM HLD is building.
- **Governance: the vendor drives CCH's SLA.** Out-of-scope says SNOW SLAs "pause/resume based on State changes triggered by Jira." Combined with "Jira wins on State," **XTEL effectively controls CCH's customer-facing SLA clock**. That may be intended, but it's a governance decision to make explicitly, not a side effect of a scope exclusion.
- **e-bond annex alignment** — the IM HLD's eventual e-bond annex should set the house rules (correlation key, loop prevention, conflict precedence, ordering) that *this* integration is one instance of. Build them once; apply here.

---

## 7. Open questions for the author / XTEL

1. Where do the four mandatory Jira fields (Division, Components, Environment, Hypercare) come from on a SNOW-originated create?
2. What is the concrete sync-loop suppression mechanism?
3. How are Jira transitions computed against the issue's *current* status, and how are invalid-transition and missing-mapping cases handled?
4. What authenticates the inbound Jira→SNOW webhook?
5. Which comment types map across, and how is internal/private content kept from leaking across the org boundary?
6. Resolution-code source on Jira→SNOW closure?
7. Retry / dead-letter / reconciliation design and ownership?
8. Is vendor-driven SLA pause/resume an accepted governance position?
9. What is the actual ticket *composition* (genuine defects vs data/batch toil vs training), and should low-value/training tickets be excluded from the bond?

---

## 8. Recommendation

**Endorse the architecture; do not sign off for go-live yet.** The Spoke-based, correlation-keyed, conflict-aware approach is the right shape. Gate approval on: (a) closing the four §3 blockers, (b) a written loop-prevention + error-handling + inbound-auth design, (c) reconciliation with the IM HLD on priority, states, assignment, and the SLA-governance point, and (d) re-sizing transaction volume from a per-ticket model **plus** a sync-eligibility filter so only engineering-actionable tickets cross the bond (not the training/data-toil firehose — §5). Most of this is specification work on top of a sound skeleton, not redesign.
