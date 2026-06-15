# ServiceNow ITSM ↔ Jira Integration

**Status**: In Review — bidirectional integration between **CCH ServiceNow** (Incidents / RITMs) and the **XTEL Jira** instance via IntegrationHub + Jira Spoke.

**Shape**: structurally a **bidirectional e-bond across an organisational boundary** (CCH ↔ XTEL), so the same race-condition discipline as the broader e-bond work applies — loop prevention, conflict resolution, ordering. SNOW→Jira is a REST call via the Spoke (SNOW holds the API token); Jira→SNOW is a webhook push to a Flow Designer trigger.

> **Confirmed volume**: **~20 tickets/day, 100 at peak** (supersedes the vendor HLD's original "600–900/day / 18–20K/month" figure). At this scale, sizing/rate-limit/IntegrationHub-quota concerns are not material; the live findings are correctness, security, and governance — not load.

---

## What's here

The original vendor HLD (the thing being assessed), an independent assessment, and a reworked draft carrying the assessment's fixes — kept as a separate review artifact so the vendor original stays untouched.

---

## Read in this order

| # | Document | Purpose |
|---|---|---|
| 1 | [references/hld-snow-jira-integration.md](references/hld-snow-jira-integration.md) | The vendor HLD (v1.0, author Ahmed Badr) — what is being built: field/status/priority mappings, conflict-ownership model, auth, implementation steps |
| 2 | [references/hld-assessment.md](references/hld-assessment.md) | Independent assessment — blockers, must-fix-before-prod, cross-document reconciliation with the CCH IM HLD, open questions, recommendation |
| 3 | [blueprints/hld-snow-jira-integration-REWORKED-for-review.md](blueprints/hld-snow-jira-integration-REWORKED-for-review.md) | Reworked draft — the assessment's fixes folded into the HLD as proposed clauses; core Spoke architecture unchanged |

---

## Catalogue

### Blueprints — proposed reworked design

| File | What it covers |
|---|---|
| [blueprints/hld-snow-jira-integration-REWORKED-for-review.md](blueprints/hld-snow-jira-integration-REWORKED-for-review.md) | Original text + proposed additions: loop-safeguard specified (integration-origin marker), duplicate-create guard, inbound webhook authentication, mandatory-field sourcing as a Jira responsibility, SLA privilege coupled to liability, priority authority (ServiceNow-owned), transition computation against Jira current status, comment-visibility mapping. Markup distinguishes net-new clauses from rewordings of the original |

### References — vendor source + assessment

| File | What it covers |
|---|---|
| [references/hld-snow-jira-integration.md](references/hld-snow-jira-integration.md) | Faithful Markdown transcription of the vendor HLD being assessed |
| [references/hld-assessment.md](references/hld-assessment.md) | The four §3 blockers, §4 correctness/security/operability must-fixes, §5 IM-HLD reconciliation, §6 open questions, §7 recommendation ("endorse the architecture; do not sign off for go-live yet") |

---

## Key open items before go-live

From the assessment — none are volume-driven; all hold at ~20/day:

- **Four §3 blockers** — mandatory Jira fields with no SNOW source (aborts every SNOW→Jira create); black-box loop safeguard; guarded Jira transitions vs the static map; closure failing SNOW resolution validation.
- **Inbound webhook authentication** — the Jira→SNOW leg is an unauthenticated write path into Incident/RITM unless verified (shared secret / signature + IP allow-list). Now the most prominent finding with volume de-risked.
- **Correctness** — duplicate-create race, two-clock "latest timestamp wins", priority-derived-vs-bidirectional, reopen thrash, comment leakage across the org boundary.
- **IM-HLD reconciliation** — priority authority, state vocabulary, incident-table pollution (training-as-incident), assignment routing, and the **vendor-driven SLA clock** governance decision.

---

## Reference pillars

- [[correlation_id]] — the cross-instance key the integration uses (Jira Issue Key in SNOW `correlation_id`; SNOW Number in Jira `customfield_10061`)
- [[15-servicenow-ref/README|15-servicenow-ref]] — ServiceNow platform mechanics

---

## Self-containment

References to material outside this folder (e.g. the CCH IM HLD) are given as descriptive path text, not links, so the folder stays packageable for sharing.

---

## Layout

```
jira-sn-integration/
├── README.md                                              ← this file
├── blueprints/                                            ← proposed reworked design
│   └── hld-snow-jira-integration-REWORKED-for-review.md
└── references/                                            ← vendor source + assessment
    ├── hld-snow-jira-integration.md                       ← vendor HLD (being assessed)
    └── hld-assessment.md                                  ← independent assessment
```
