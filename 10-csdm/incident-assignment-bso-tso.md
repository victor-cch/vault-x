# Incident Assignment — BSO/TSO Model

How CSDM v5 expects incidents to be **categorised, routed, and escalated** using the BSO/TSO chain. The OOTB v5 best practice is the **Parent/Child incident model**; the alternative is a custom `u_technical_service_offering` field on a single incident.

This MOC is the operational layer of [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md). Read that first for the relationship reference.

## Two approaches — pick deliberately

| Aspect | **Approach 1: Custom field** | **Approach 2: Parent/Child** (CSDM v5 best practice) |
|---|---|---|
| Mechanism | `u_technical_service_offering` custom field carries TSO; `service_offering` carries BSO; both on same incident | New TSO incident created as Parent; BSO incident becomes Child |
| BSO preservation | ✅ Single incident throughout | ✅ Separate incidents, business accountability preserved |
| SLA | ❌ One SLA on one ticket — BSO and TSO share measurement | ✅ Separate SLAs: BSO (customer experience) + TSO (technical resolution) |
| Custom code | Script Include for escalation logic | None — OOTB Business Rule cascades state |
| Scales to multi-user TSO failure | ❌ Hard — one TSO failure, 50 users, 50 incidents share one field | ✅ One TSO Parent, 50 BSO Children, Parent acts as Major Incident hub |
| Verification needed | None — well-trodden | Verify OOTB "Awaiting Parent" hold reason, cascade Business Rule |
| **CCH state today** | **Currently in use** | **Target direction** |

> The CSDM v5 incident management process document recommends Approach 2 but flags four OOTB-capability verifications needed before committing.

## The five CSDM fields on the incident form

| Field | Table Field | Role | Population |
|---|---|---|---|
| **Service Offering** | `service_offering` | Primary anchor — BSO or TSO | Agent selects (or AI predicts) |
| **Service** | `business_service` | BS or TMS parent | Auto-populated from SO parent (read-only) |
| **Configuration Item** | `cmdb_ci` | The specific CI affected | Agent selects (optional for SaaS) |
| **Assignment Group** | `assignment_group` | Who works the incident | Auto from CI support group, fallback to SO support group |
| **Parent Incident** *(Approach 2 only)* | `parent_incident` | Link to TSO Parent | Set when BSO Child is created |

## Three incident creation paths

### Path 1: Service Offering first (user/agent)

```
User describes issue
  → Service Offering (BSO) selected
    → Service auto-populated (read-only)
      → Assignment Group from BSO support_group
        → CI optionally populated
```

CMDB traversal: **BSO → `Depends on :: Used by` → Service Instance** (populates `cmdb_ci`)

### Path 2: Configuration Item first (IT staff)

```
Agent selects CI
  → System checks Dynamic CI Group membership
    → If match: TSO derived from DCG relationship
      → New incident created against TSO
        → Assignment Group from TSO support_group
    → BSO derived separately: CI → SI (via svc_ci_assoc) → BSO (via cmdb_rel_ci)
      → BSO Child created and linked if TSO incident exists
```

CMDB traversal:
- TSO derivation: **Dynamic CI Group → TSO (via `Contains :: Contained by`, TSO is parent)**
- BSO derivation: **CI → `svc_ci_assoc` → Service Instance → `Depends on :: Used by` → BSO**

### Path 3: System-generated (monitoring)

```
Monitoring system detects issue
  → CI resolved from alert payload
    → TSO derived from CMDB relationships (same as Path 2)
      → Incident created against TSO
        → Priority from business_criticality + event severity
          → Assignment Group from TSO support_group
    → BSO derived and linked as Child if business impact confirmed
```

## Escalation — Parent/Child model

When a BSO incident (customer-reported issue) requires technical investigation by a different service team:

```
BSO Incident (Child — symptom)              TSO Incident (Parent — root cause)
├── service_offering = BSO                  ├── service_offering = TSO
├── assignment_group = BSO support          ├── assignment_group = TSO support
├── state = On Hold (Awaiting Parent)       ├── state = In Progress
├── BSO SLA running (E2E customer)          ├── TSO SLA running (technical resolution)
└── parent_incident = TSO incident          └── resolves → cascades to Child
```

1. **TSO incident created** — recorded against the TSO, assigned to TSO support_group. Becomes the **Parent**.
2. **BSO Child linked** — original BSO incident's `parent_incident` set to TSO. State: **On Hold — Awaiting Parent**.
3. **TSO team resolves Parent** — fix on the TSO incident.
4. **Resolution cascades** — Parent resolved → Child state updated via OOTB Business Rule.

### Multi-level technical escalation (L2 → L3 → L4)

If the TSO incident requires further escalation within the technical domain:

**CMDB traversal**: TSO (L2) → `Depends on :: Used by` → TSO (L3) → `Depends on :: Used by` → TSO (L4)

Two options:
- **Reassign the TSO incident** — change `service_offering` to L3 TSO, update `assignment_group`. Simple, loses L2 SLA measurement.
- **Create another Parent** — L3 TSO incident becomes Parent of the L2 TSO incident. Preserves SLA at each level. Use when vendor OLA tracking per level is required.

### Multi-user TSO failures

```
              TSO Parent Incident
                     │
        ┌────────────┼────────────┐
        │            │            │
   BSO Child 1  BSO Child 2  BSO Child 50
        │            │            │
   User 1's BSO  User 2's BSO  User 50's BSO
```

- One TSO Parent — the root cause, assigned to TSO team
- 50 BSO Children — each user's incident, linked
- TSO resolution cascades to all 50 simultaneously
- Each BSO Child retains its own SLA

**This is how CSDM v5 naturally supports Major Incident management** — the TSO Parent is the hub.

## Identifying the TSO from a BSO Incident

Given the Service Instance on the BSO incident (`cmdb_ci`):

```
SELECT * FROM cmdb_rel_ci
WHERE child_ci = <Service Instance sys_id>
  AND type = 'Contains :: Contained by'
  AND parent_ci.service_classification = 'Technical Service'
  AND parent_ci.classification_subtype = 'Operations Support'  -- L2
  AND parent_ci.life_cycle_stage = 'Operational'
  AND parent_ci.life_cycle_stage_status = 'In Use'
```

- Single match → auto-populate the new TSO incident
- Multiple matches → present to agent for selection

**No name matching. No hardcoded filters. Pure relationship traversal.**

The CCH HLD §7.2.4 had this query reversed (parent = Service Instance, child = TSO) and returned zero results in prod. CCHIncidentUtils name-matching is the workaround for the inverted relationship.

## SLA model under Parent/Child

### BSO Incident (Child) SLAs

| Timer | Starts | Measures |
|---|---|---|
| **E2E SLA** | Incident created | Total customer experience — creation to closure |
| **Business SLA** | On Hold — Awaiting Caller | Time waiting for customer input |

### TSO Incident (Parent) SLAs

| Timer | Starts | Measures |
|---|---|---|
| **Resolution SLA** | Incident created | Technical resolution time |
| **Vendor OLA** | Vendor/contract present on TSO | Vendor-specific resolution commitment |

- BSO SLA = customer-facing measurement
- TSO SLA = technical resolution measurement
- Independent on separate incidents
- Inherit vendor/contract from the Offering on each incident
- Priority drives SLA duration tiers
- Pause/resume based on state transitions

## OOTB lifecycle states

| State | Description |
|---|---|
| New | Created, pending triage |
| In Progress | Active investigation/resolution |
| On Hold | Paused — *Awaiting Caller / Awaiting Change / Awaiting Vendor / Awaiting Parent* |
| Resolved | Fix applied, pending confirmation |
| Closed Complete | Confirmed resolved |
| Closed Incomplete | Closed without full resolution |

- No custom states
- Parent/Child state synchronisation: Parent → Children via Business Rule

## CMDB prerequisites — what must exist

This process **cannot function** without:

| Prerequisite | Table | Minimum coverage |
|---|---|---|
| Business Services defined | `cmdb_ci_service_business` | All operational business services |
| BSOs linked to Service Instances | `cmdb_rel_ci` (Depends on :: Used by) | All operational BSOs |
| TSOs linked to Service Instances | `cmdb_rel_ci` (Contains :: Contained by) | All operational TSOs |
| TSO escalation chains | `cmdb_rel_ci` (Depends on :: Used by, TSO→TSO) | All L2→L3→L4 chains |
| Dynamic CI Groups wired to TSOs | `cmdb_rel_ci` (Contains :: Contained by) | Major infrastructure areas |
| Support groups on all Offerings | `service_offering.support_group` | 100% of operational BSOs and TSOs |
| Business criticality on BSOs | `service_offering.business_criticality` | All operational BSOs |
| CI-to-Service Instance associations | `svc_ci_assoc` | Principal CI classes |

## Common gotchas

- **`cmdb_rel_ci` direction reversed** — query returns zero results; CCHIncidentUtils name-matching is the workaround
- **Multiple TSOs matching an SI** — name matching produces ambiguous results; needs governance (one CI per DCG per TSO)
- **Life cycle stage not Operational** — Offering doesn't appear in selection list
- **No support_group on BSO** — assignment falls back to Service Desk default
- **Business_criticality unset** — urgency derivation produces wrong priority
- **Single SLA on a v4-style incident** — Approach 1 can't separate customer-facing vs technical SLA

## CCH state today (April 2026)

- **Using Approach 1**: `u_technical_service_offering` custom field with CCHIncidentUtils Script Include
- **Target**: Approach 2 (Parent/Child) for new design — verifications still outstanding
- **Chain coverage**: BSO ↔ SI 870 records; TSO ↔ SI 395 records; TSO ↔ TSO 647 records (mixed quality); TSO ↔ DCG only 7 records (CI-first path largely untapped)

## Related notes

- [README](README.md)
- [csdm-v5-relationship-chain](csdm-v5-relationship-chain.md) — the relationship reference
- [classes/service_offering.md](classes/service_offering.md) — BSO/TSO container
- [classes/cmdb_ci_service_business.md](classes/cmdb_ci_service_business.md) — Business Service
- [classes/cmdb_ci_service_technical.md](classes/cmdb_ci_service_technical.md) — TMS
- [classes/cmdb_ci_service_auto.md](classes/cmdb_ci_service_auto.md) — Service Instance (the bridge)
- [business-impact-analysis](business-impact-analysis.md) — how Priority is derived
- [Incident Management Process — CSDM v5](../../projects/dt-sn-integration/incident-integration/csdm-v5-service-relationship-model.md) — the engagement-side source for this MOC
- [CCH Incident Management HLD](../../blueprints/incident-management/hld-sn-incident-management.md) — current HLD design (Approach 1)
- [CCH Incident Management Process — CSDM v5](../../blueprints/incident-management/incident-management-process-csdm-v5.md) — target process (Approach 2)
