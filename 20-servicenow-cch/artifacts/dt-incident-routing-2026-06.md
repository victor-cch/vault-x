# DT-induced Incident Routing — Current-State Assessment

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981)
![Intent: Analytical](https://img.shields.io/badge/intent-Analytical-8B5CF6)

**Date**: 2 June 2026
**Scope**: Operational behaviour of the Dynatrace → ServiceNow incident routing path at CCH, as observed in production.
**Sources**:
- **Production data**: `incident` table filtered `opened_by = SA_DYNATR_SNOW` AND `sys_created_on` in last 3 months. CSV at [`../data/sn-exports/incident-2026-03-to-05.csv`](../data/sn-exports/incident-2026-03-to-05.csv) — **1,330 records, 27 columns**.
- **Live code**: Transform Map "Problem to Incident Transformation Map" — two onBefore Transform Scripts, 9 Field Maps, the `Populate Dynatrace Affected CIs` business rule, the `DynatraceIncidentINTUtil` script include, and three Global-scope post-transform business rules.
- **Companions**: [`transform-map-analysis.md`](transform-map-analysis.md) (code-side line-by-line analysis) · [`business-rules-on-incident.md`](business-rules-on-incident.md) (per-rule analysis of the populators).

---

## Executive summary

Of 1,330 Dynatrace-induced incidents created over the three months to 2026-05-31:

- **99.2 %** carry a populated `service_offering` (1,320 records)
- **99.8 %** carry a populated `assignment_group` (1,327 records)
- **4.9 %** carry a populated `cmdb_ci` (65 records — when populated, always a server-class CI; never a FortiGate)
- **100 %** are confirmed Dynatrace-induced: `correlation_display = DYNATRACE`, `contact_type = Event`, `opened_by = SA_DYNATR_SNOW`
- **100 %** are tagged `INFRASTRUCTURE` in the short description — <span style="color: red">**zero application-level problems**</span> in the dataset
- **95.0 %** are in state `Closed`; of those, 99.7 % have both `resolved_at` and `closed_at` populated — but the closure is human-driven, not driven by the integration (which remains fire-and-forget by design; see §8)

The single dominant problem class is **FortiGate firewall alerts at 74 % of total volume (985 incidents)**. Of those 985:

- **9.3 %** (92) take the FortiGate hardcoded shortcut → the majority routed to `Fortigate / Firewall Administration / G SNOW EXT OTE PRONET` (the actual firewall team).
- **89.7 %** (884) are routed to `Domestic Network / Network Access`; most land on country-level on-site support (`G SNOW <country> ON-SITE SUPPORT`), with ~10 % on related country-level groups (service desks, infrastructure services).
- Both groups take the same code path. The difference is which `sc_cat_item` sys_id their title's regex points at in the `x_dynat_ruxit.dynatrce.fg.category.mapping` JSON property. The DOWN/Critical-Link patterns point at a cat_item categorised "Domestic Network", which triggers an on-site-support trailing conditional in Script 1 and routes to the country desk. The HA/sync/memory patterns point at a cat_item categorised "Fortigate", which routes to the firewall team. The fix is a one-line JSON edit (§10).

The routing pipeline reliably attaches a service offering and an assignment group to nearly every DT incident. But for the dominant alert class, the wrong team owns the incident 9 times out of 10. Counter-intuitively, the misrouted incidents do not bounce more than the correctly-routed ones — they are resolved (or rubber-stamp closed) by the receiving country desks at roughly the same rate.

`service_offering`, `business_service`, and `assignment_group` are populated by three Global-scope post-transform business rules — see [`business-rules-on-incident.md`](business-rules-on-incident.md). `cmdb_ci` is populated manually by operators during triage; no script writes it.

---

## 1. Dataset

| Property | Value |
|---|---|
| Source filter | `opened_by = SA_DYNATR_SNOW` AND `sys_created_on >= last 3 months` |
| Time window | Created in last 3 months (window ending 2026-06-01) |
| Total records | **1,330** |
| Columns | 27, including `number`, `sys_created_on`, `state`, `resolved_at`, `closed_at`, `reassignment_count`, `opened_by`, `correlation_id`, `correlation_display`, `contact_type`, `short_description`, `impact`, `urgency`, `priority`, `cmdb_ci`, `cmdb_ci.sys_class_name`, `service_offering`, `subcategory`, `u_subcategory`, `category`, `assignment_group`, `u_item`, `u_category_full_path`, `location`, `u_worked_by_third_party_vendor`, `u_cchresponsible`, `u_level` |

---

## 2. Funnel — population-level numbers

```
TOTAL DT incidents (last 3 months):    1,330
  with CI (cmdb_ci):                      65    ( 4.9 %)
  with Service Offering:               1,320    (99.2 %)
  with Assignment Group:               1,327    (99.8 %)
  CI populated AND SO populated:          65    ( 4.9 %)
  SO populated but no CI:              1,255    (94.4 %)
  CI populated but no SO:                  0
  of those WITH a CI, % with SO:        100 %
```

Three observations:

1. **`service_offering` and `assignment_group` are near-universally populated.** Routing-by-offering works in the sense that *something* always lands.
2. **`cmdb_ci` <span style="color: red">is overwhelmingly empty</span>.** The incident record almost never carries an explicit primary Configuration Item reference. This is the **primary CI** field, not the Affected CIs M2M list (which is populated by the `Populate Dynatrace Affected CIs` business rule — see §6.5).
3. **When `cmdb_ci` is populated, it is always a server.** All 65 populated CIs are `Linux Server` (39), generic `Server` (15), or `Windows Server` (11). Zero FortiGate, network device, or non-server CIs — even though FortiGates account for 74 % of incident volume.

Routing reaches *a* support group via *an* offering, but does so without the incident carrying a primary CI for 95 % of records — and the primary CI link is absent for entire classes of devices (firewalls, network gear) regardless of whether they exist in the CMDB.

---

## 3. Problem-type cross-tab

Alerts categorised by parsing `short_description`:

```
Problem type                count   %tot   w/CI    CI%   w/SO    SO%
--------------------------------------------------------------------
FortiGate / firewall          985   74.1%     0    0%    978   99.3%
MES server                    161   12.1%     0    0%    161  100.0%
Other                         150   11.3%    51   34.0%  147   98.0%
Pacemaker (OTE)                15    1.1%    14   93.3%   15  100.0%
SAP/CPI                        10    0.8%     0    0%     10  100.0%
Azure                           9    0.7%     0    0%      9  100.0%
--------------------------------------------------------------------
TOTAL                       1,330  100.0%    65    4.9%  1,320  99.2%
```

- **FortiGate** dominates absolute volume. Every one of these 985 incidents is recorded *without* a primary `cmdb_ci`.
- **Pacemaker** has near-universal CI coverage (93 %, 14 of 15) — these alerts always name a specific cluster node (e.g., `vmuslmscs001`) and operators routinely bind it.
- **"Other" server-class problems** (disk, memory, uptime on named VMs) hold the second-highest CI coverage. Of the 150 in this bucket, 51 (34 %) bind a CI.
- **MES, SAP/CPI, Azure** all sit at 0 % CI binding despite the underlying hosts being present in the CMDB.

---

## 4. The FortiGate routing split — the main operational finding

Of 985 FortiGate alerts:

| Branch | n | `u_subcategory` | `service_offering` | Top `assignment_group` |
|---|---:|---|---|---|
| Routed to firewall team | 92 | `Fortigate` | `Firewall Administration` | `G SNOW EXT OTE PRONET` |
| Routed to country desk | 884 | `Domestic Network` | `Network Access` | `G SNOW NG` (38 %), `EG` (13 %), `RS` (10 %), `CH`, `BA`, `UA`, `GR`, … |

Both branches take the same code path through the transform map's FortiGate shortcut. The discriminator is which `sc_cat_item` sys_id the title's regex matches in `x_dynat_ruxit.dynatrce.fg.category.mapping`:

| sys_id | `sc_cat_item.name` | `sc_cat_item.category` | Routing outcome |
|---|---|---|---|
| `271909eb…` (the HA/sync/memory regex target) | **General** | **Fortigate** | Firewall team via `u_escalation_groups` table lookup |
| `fe158879…` (the DOWN / Critical-Link target) | **WAN - General** | **Domestic Network** (`c61d566d…`) | Country on-site support via Rule 3's `u_on_site_support` branch |

The "Domestic Network" subcategory sys_id is hard-coded into the trailing conditional at the end of Script 1:

```javascript
if (target.u_subcategory == 'c61d566d019842003d4d4e13478059d3' &&
    target.priority >= 1 && target.priority <= 4) {
    target.u_on_site_support = true;
}
```

When `u_subcategory` matches, `u_on_site_support` is set to `true`. The post-transform business rule `INC - Fill Assignment group on save` (Populator 3 in §6.6) then routes by location:

```javascript
if (current.u_on_site_support) {
    current.assignment_group = getOnSiteGroupByLocation(lc);
}
```

So the 884 misroutes are routing to country desks because the cat_item they land on has `category = Domestic Network`, which fires the on-site-support trailing conditional, which makes Rule 3 pick the country desk. Fully deterministic — see §10 for the misconfiguration and the fix.

**Reassignment behaviour — counter-intuitive:**

```
Reassignment_count distribution:
  Routed to firewall team (n=92):   0:2  1:57  2:2  3:15  4:9  5:5  7:1  10:1     mean = 2.00
  Routed to country desk  (n=884):  0:40 1:778 2:42 3:11  4:5  5:4  9:1  12:1     mean = 1.08
```

Country-desk-routed incidents have **lower** mean reassignment than firewall-team-routed ones (1.08 vs 2.00). Only 11 of the 884 misrouted incidents bounce more than 2 times. The country desks are either (a) able to resolve `is DOWN` alerts directly via local rituals (power-cycle, vendor ticket), (b) closing them out without escalating, or (c) accepting them as part of routine workload. The misroutes are not generating the bounce-storm an architect might expect.

---

## 5. Service Offering distribution

```
  886  Network Access                              (66.7 %)   ← FortiGate country-desk target
  155  MES                                          (11.7 %)
   99  Firewall Administration                      ( 7.5 %)  ← FortiGate firewall-team target
   73  Middleware Integrations                      ( 5.5 %)
   45  Cloud Resources Linux - Operations Support   ( 3.4 %)
   26  Cloud Windows Systems - Technical Expertise  ( 2.0 %)
   21  SAP S/4HANA - Operations Support             ( 1.6 %)
   10  (empty)                                      ( 0.8 %)
    6  SRA4OT                                       ( 0.5 %)
    5  Incident, Problem & Change Management        ( 0.4 %)
```

The values fall into two structural shapes:

- **Offerings with no role suffix** — "Network Access", "MES", "Firewall Administration", "Middleware Integrations", "SRA4OT" — the dominant shape.
- **Offerings with a CCH role suffix** — "- Operations Support" and "- Technical Expertise" — used on Cloud/SAP-stack categories. These align with the L2/L3 role-suffix family from the CCH escalation model.

Both shapes appear in the same `service_offering` field with no apparent code-level discrimination.

### 5.1 BSO vs TSO classification

The `service_offering` table holds **both** Business Service Offerings (BSO, `service_classification = "Business Service"`) and Technology Management Service Offerings (TSO, `service_classification = "Technology Management Service"`). Mapping each value in our dataset to its classification:

| Service offering | n | Classification | Source of classification |
|---|---:|---|---|
| `Network Access` | 888 | **BSO** | Verified via list view (parent: Network Infrastructure (HW+SW), classification: Business Service) |
| `MES` | 155 | BSO | Inferred from naming convention (no role suffix) |
| `Firewall Administration` | 99 | BSO | Inferred from naming convention |
| `Middleware Integrations` | 73 | BSO | Inferred from naming convention |
| `Cloud Resources Linux - Operations Support` | 45 | **TSO** | "- Operations Support" suffix |
| `Cloud Windows Systems - Technical Expertise` | 26 | **TSO** | "- Technical Expertise" suffix |
| `SAP S/4HANA - Operations Support` | 21 | **TSO** | "- Operations Support" suffix |
| `SRA4OT` | 6 | **⚠ Ambiguous** — not verified | Acronym; no naming-convention signal; lookup deferred |
| `Incident, Problem & Change Management` | 5 | BSO | Inferred from naming convention |
| `Field Sales Management` | 1 | BSO | Inferred from naming convention |
| `NEXT Order Management` | 1 | **BSO** | Verified via list view (parent: Integrated Order Management (IOM)) |
| *(empty)* | 10 | n/a | Final-fallback records (§6.3.3) |

Aggregate split for the dataset:

```
BSO         1,222    (91.9 %)
TSO            92    ( 6.9 %)
Ambiguous       6    ( 0.5 %)    ← SRA4OT, unverified
Empty SO       10    ( 0.8 %)
```

FortiGate-specific: of 985 FortiGate alerts, **975 (99.0 %) route via a BSO**, 3 (0.3 %) via a TSO, 7 with empty SO.

### 5.2 What the BSO-dominant split means in CSDM v5 terms

In CSDM v5, **BSOs are consumer/business-facing offerings** — the "what users see and consume" view. **TSOs are technical/operational offerings** — the "what IT delivers and supports" view. A FortiGate device being down is fundamentally a *technical/operations* event, so the canonical CSDM v5 destination is a TSO (e.g., `Network Access - Operations Support`, which exists in the catalog — visible in the earlier `service_offering` list paste, classification: Technology Management Service).

What actually happens in the data: 99.0 % of FortiGate alerts route via the BSO `Network Access`, not via `Network Access - Operations Support`. The integration is putting **technical alerts onto business-facing offerings**.

The pattern is consistent across the dataset. Only the suffix-bearing offerings (`Cloud Resources Linux - Operations Support`, `Cloud Windows Systems - Technical Expertise`, `SAP S/4HANA - Operations Support`) reach TSOs — together accounting for ~7 % of incidents. Those happen to be the OTE-managed cloud cases where the CCH escalation model's L2/L3 role suffix has explicitly been applied; everywhere else the routing lands on the consumer offering.

The CSDM v5-compliant routing would put incidents on:
- BSOs only when the incident **affects user-facing service delivery** (e.g., a user can't access a service)
- TSOs when the incident is **about IT operational health** (device down, capacity warning, configuration drift)

The current state has these reversed for ~92 % of the dataset. Aligning with v5 means routing technical alerts through TSO offerings (which exist in the catalog already) and reserving BSOs for service-impact incidents. This is a configuration change — the JSON in `x_dynat_ruxit.dynatrce.fg.category.mapping` and similar properties needs to repoint at TSO-classified `sc_cat_item` records — not a CMDB change.

---

## 6. How the routing actually works — verified against live code

See [`transform-map-analysis.md`](transform-map-analysis.md) for the line-by-line code reference.

### 6.1 Transform Map structure

The transform map "Problem to Incident Transformation Map" (`x_dynat_ruxit_problems` → `incident`) consists of:

- **9 Field Maps** (8 script-based, 1 direct), of which the `cmdb_ci` field-map script is **fully commented out — returns `""` unconditionally**.
- **2 onBefore Transform Scripts**:
  - **Script 1** — OTE rule matching + Non-OTE branching (FortiGate / ANF-Atos shortcuts, CSDM walk via `dtCSDMApplicationName` tag, final fallback)
  - **Script 2** — pure FortiGate location stamper (sets `target.location`)
- **No onAfter scripts.**

**Across the entire transform map, the only fields directly written to are**:

| Field | Set by | Source |
|---|---|---|
| `contact_type` | Field map (script) | Static `"event"` |
| `correlation_id` | Field map (direct) | `source.problem_id` |
| `correlation_display` | Field map (script) | Static `"DYNATRACE"` |
| `cmdb_ci` | Field map (script) | **`""`** (dead code) |
| `state` | Field map (script) | OPEN→1, else conditional on `autoresolveproblems` property |
| `short_description` | Field map (direct) | `source.problem_title` |
| `caller_id` | Field map (script) | Static `"SA_DYNATR_SNOW"` |
| `work_notes` | Field map (script) | `details` (with "RESOLVED" → "UPDATE" rewrite on CLOSE) |
| `description` | Field map (script) | `details` on OPEN |
| `impact` | Script 1 | rule-derived or `util.determinePriority`-derived |
| `urgency` | Script 1 | rule-derived or `util.determinePriority`-derived |
| `u_subcategory` | Script 1 | rule-derived or `sc_cat_item.category`-derived |
| `u_item` | Script 1 | rule-derived or `sc_cat_item` sys_id from CSDM walk |
| `u_on_site_support` | Script 1 (conditional) | true if `u_subcategory == 'c61d566d…'` and priority ∈ [1..4] |
| `location` | Script 2 | FortiGate location parser or hardcoded fallback sys_id |

**Notably absent**: `service_offering`, `assignment_group`, and any meaningful value for `cmdb_ci`. Neither the field maps nor the transform scripts write to these. They are populated by post-transform business rules (§6.6). The OOTB `u_technical_service_offering` field is **not modelled on CCH's incident table** (verified against `sys_dictionary` — no such column exists); TSO context lives only in `service_offering.service_classification` (§5.1).

### 6.2 OTE branch (Script 1, when `problem_title` ends with `"OTE"`)

- Loads `x_dynat_ruxit.dynatrace.ote.config` — JSON document of rules + fallback.
- Parses three Azure tags from `source.tags`: `[Azure]SLA`, `[Azure]Infra-Support`, `[Azure]Environment`.
- Walks rules in order; first one whose regex/title match AND tag conditions all match wins.
- On match, sets `target.impact`, `target.urgency`, `target.u_subcategory`, `target.u_item` — these four fields only.
- On no match, sets `u_subcategory` and `u_item` from `fallback` config; leaves `impact`/`urgency` to ServiceNow form defaults.

In the dataset, 76 incidents (5.7 %) have titles ending in `OTE` or are Pacemaker-cluster alerts; 71 of those 76 (93 %) land on `u_subcategory = OTE Cloud Management`.

### 6.3 Non-OTE branch (Script 1, all other alerts)

Three sub-paths in order:

#### 6.3.1 FortiGate / ANF-Atos shortcut

If `DynatraceIncidentINTUtil.determineFortigateCategory(title)` or `determineAnfAtosCategory(title)` returns a non-`'0'` value (a matching `sc_cat_item` sys_id from the category-mapping system property), the script:

- Loads that `sc_cat_item` by sys_id.
- Sets `target.u_subcategory = category`, `target.u_item = <sys_id>`, plus `impact`/`urgency` from `util.determinePriority(title)`.
- **Does not perform any CMDB lookup.** No CI is resolved.

For all 985 FortiGate alerts in the dataset, the function matches a regex and returns the corresponding sys_id. Sub-path B fires for all of them. The destination depends on which sys_id is returned — see §4 and §10.

#### 6.3.2 CSDM walk via `dtCSDMApplicationName` tag

If FortiGate / ANF-Atos shortcuts both return `'0'`, the script:

1. Parses `source.tags` for a `dtCSDMApplicationName:<value>` entry.
2. Queries `cmdb_ci_service_auto WHERE name = <application>` — a **string-name match** against the Application Service / Service Instance class.
3. Walks `cmdb_rel_ci` looking for a parent whose `sys_class_name = service_offering`.
4. Queries `sc_cat_item_subscribe_mtom WHERE service_offering = <so>` AND `sc_cat_item.active = true` AND `sc_cat_item.u_cchreferenceto = Incident`.
5. Applies max-impact/urgency caps from the matched `sc_cat_item`.
6. Sets `target.u_subcategory` (from `sc_cat_item.category`) and `target.u_item` (the `sc_cat_item` sys_id).

This is the only CMDB-traversing path in the transform map. Name-based — the Application Service name from the Dynatrace tag must exactly match the `cmdb_ci_service_auto.name` in CMDB. **Does not write to `cmdb_ci` on the incident.**

#### 6.3.3 Final fallback

If nothing matches:

```javascript
target.u_subcategory = '106f22a101d842003d4d4e1347805997';   // "ServiceNow" catalog category
target.u_item        = '34a001a8fbe87a50bf3ffee64eefdc44';   // sc_cat_item "Incident, Change and Problem Management"
```

…and `util.determinePriority(title)` for impact/urgency. Five records in the dataset hit this path — all titled "Multiple infrastructure problems OTE".

### 6.4 Script 2 — FortiGate location stamper

Reads the problem title, calls `DynatraceIncidentINTUtil.determineFortigateLocation(title)` (extracts a 2-letter country code from FortiGate device names), looks up `cmn_location` by name, sets `target.location`. Falls back to hardcoded sys_id `6a3a0d5237ee35009654261953990ebb` (resolves to **"BSS"**) if no FortiGate pattern matches. Fires the BSS fallback on 33 % of records (443 of 1,330). Does not write to `cmdb_ci` or `service_offering`.

### 6.5 The `Populate Dynatrace Affected CIs` business rule

A business rule on the `incident` table, scoped to the Dynatrace Incident integration app:

1. Determines the corresponding problem state from incident state (1 → OPEN, 6/7 → CLOSE).
2. Looks up the matching `x_dynat_ruxit_problems` source record by `problem_id` + `problem_state`.
3. Reads the comma-separated `impacted_cis` field from the source row.
4. For each Dynatrace entity ID in that list, queries `sys_object_source WHERE id = <entity_id>` — filtering on `id` only, with no `name`/`discovery_source` filter and no `target_table` exclusion.
5. If a `sys_object_source` row is found, inserts a row into the `task_ci` table (the Affected CIs M2M related list).

This rule writes to the Affected CIs related list (`task_ci`), **not** to the primary `cmdb_ci` field on the incident.

### 6.6 The post-transform populators

The three fields the transform map does **not** write — `service_offering`, `business_service`, and `assignment_group` — are populated by **three Global-scope business rules** on the `incident` table. The fourth field, `cmdb_ci`, is populated **manually by operators** during triage. Full per-rule analysis lives in [`business-rules-on-incident.md`](business-rules-on-incident.md).

#### Populator 1 — `Populate Service Offering` (Global, since 2024-07-30)

Runs on every incident Insert and Update. No filter conditions, no script-level guard.

```javascript
var grMapping = new GlideRecord('sc_cat_item_subscribe_mtom');
grMapping.addQuery('sc_cat_item', current.u_item);
grMapping.query();
while (grMapping.next()) {
    current.service_offering = grMapping.service_offering;
    current.business_service = grMapping.service_offering.parent;
}
```

- Reads `current.u_item` (set by Script 1 of the transform map).
- Queries `sc_cat_item_subscribe_mtom`. `while` iteration is effectively last-match-wins.
- Writes `current.service_offering` and `current.business_service` (the latter via dot-walk to the SO's parent — the CSDM Business Service).
- Does not write `assignment_group` or `cmdb_ci`.

#### Populator 2 — `CCH-Map Inc Category to offering` (Global, since 2025-03-10)

A guarded refinement layer over Populator 1. Acts only when `current.service_offering` is empty AND `current.u_item` is set. Same query, first-match-wins. Effectively dead code in practice: Populator 1 has no guard and overwrites whatever Populator 2 sets.

#### Populator 3 — `INC - Fill Assignment group on save` (Global, since 2015-05-14)

Generic CCH escalation routing — predates the Dynatrace integration entirely. Applies to every incident on the platform.

```javascript
function onBefore(current, previous) {
    var lc = current.location;
    var country = new locationInfo().getCountryByLocation(lc);

    if (current.u_on_site_support) {
        current.assignment_group = getOnSiteGroupByLocation(lc);
    } else {
        current.assignment_group = getGroupByEscalation(current.u_item, current.u_level, country);
        // ATOS + Russia/Belarus side-effect on u_comment_from_customer
    }

    if (current.assignment_group.nil()) {
        current.assignment_group = new getAssignmentGroupByLevel().getGroupByRole('l2_admin_access');
    }

    if (current.u_cchresponsible.nil()) {
        // derives u_cchresponsible from assignment_group.u_cchlevel
    }
}
```

- Independent of CSDM. Does not read `service_offering` or `service_offering.support_group`.
- Uses CCH-custom routing table **`u_escalation_groups`**, keyed on `(u_itemid × u_escalation_level × u_request_typeid × u_core_country)` → `u_groupid`.
- Two branches: on-site path (`location → u_onsite_group`) or escalation-table path. Both fall back to a default L2 admin group.
- Side effect: derives `current.u_cchresponsible` from the chosen assignment group's `u_cchlevel`.
- Side effect: writes `current.u_comment_from_customer = "Assigned to ATOS by CCBMS"` when the chosen group's name contains `"ATOS"` AND the caller/opener is from Russia/Russian Federation/Belarus.
- The L2-admin default fallback explains the 99.8 % `assignment_group` population rate.

#### Populator 4 — `cmdb_ci` is set manually by operators, not by any rule

Verified by audit trail (INC1811586):

| Time | Actor | Action |
|---|---|---|
| 06:24:25 | `SA_DYNATR_SNOW` | inserts the incident. `Configuration item` is not in the change list — `cmdb_ci` is empty. |
| 06:25:35 | `Ioannis Delis` (human operator) | picks up the ticket. Among other changes, sets `Configuration item: vmuslmscs001`. |

A scan of the 155 active business rules on the incident table for any script touching `cmdb_ci` returns no live writes. The transform map's `cmdb_ci` field map is commented out (returns `""`) by design — so the integration doesn't pre-empt operator judgement. The `task_ci` write (§6.5) gives the operator a starting set; the operator promotes (or doesn't) into `cmdb_ci`.

This explains the data signature in §3:

- **4.9 % population rate** — the fraction of incidents that get careful operator triage. The other 95.0 % are rubber-stamped without anyone setting the primary CI.
- **Server-class only** — server outages (Pacemaker, MES disk, SAP HANA, server uptime) get operator attention because they map to specific named VMs. FortiGate alerts and infrastructure noise go to the country desks or external teams that ack/close them without binding the primary CI.

#### Summary table

| Field | Populator | Mechanism | Population rate |
|---|---|---|---|
| `service_offering` | Populator 1 (`Populate Service Offering`) | `u_item → sc_cat_item_subscribe_mtom`, last-match-wins | 99.2 % |
| `business_service` | Populator 1 (same) | dot-walks `service_offering.parent` | predicted ~99 % |
| `assignment_group` | Populator 3 (`INC - Fill Assignment group on save`) | `u_escalation_groups` table lookup with L2-admin default | 99.8 % |
| `cmdb_ci` | Manual operator entry | Operator sets when triaging the ticket | 4.9 % (server-class only) |
| `u_cchresponsible` | Populator 3 (side effect) | derived from `assignment_group.u_cchlevel` | 99.8 % (dominant value: `Caller` = 91 %) |
| `u_comment_from_customer` | Populator 3 (side effect, ATOS + RU/BY only) | static string | low |

### 6.7 Incident-table field anatomy

CCH's incident table has **84 dictionary entries** (`sys_dictionary` records keyed on `name = incident`). The majority are `u_*` custom fields added over the years. During this analysis several **labelling collisions** surfaced — fields with different column names but identical display labels, which cause picker-ambiguity bugs in reports, filters, and forms.

#### Label collisions

| Display label | Column name | Type / Reference | Notes |
|---|---|---|---|
| **"Category"** | `category` (OOTB) | String, choice | OOTB; default value `inquiry` — that's why every incident shows "Inquiry / Help" |
| **"Category"** | `u_subcategory` (custom, by `rebeca.sanchez`) | Reference → `Category` table | The actual subcategory routing value (`Domestic Network`, `Fortigate`, `OTE Cloud Management`, …) — labelled "Category" |
| "Subcategory" | `subcategory` (OOTB) | String, choice | 100 % empty in the DT dataset (already dropped from exports) |
| **"Service"** | `business_service` (inherited from `task`) | Reference → `cmdb_ci_service` | The OOTB Business Service field — written by Populator 1 |
| **"Service"** | `u_item` (custom, by `rebeca.sanchez`) | Reference → `Catalog Item` (`sc_cat_item`) | The catalog-item field that drives the routing chain — labelled "Service" |
| "Catalog" | `u_category` (custom, by `rebeca.sanchez`) | Reference → `Catalog` table | Not a category at all — points at a Service Catalog instance |
| "Level" | `u_level` (custom, by `daniel.penchev`) | String, choice → `u_escalation_groups` | The escalation level (`Level 1`, `Level 2`, …) read by Rule 3 |
| "Client" | `caller_id` (OOTB) | Reference → User | Standard incident caller, labelled "Client" — the auto-populate uses `incidentGetCaller()` JS |

#### Operational consequence of the collisions

- **Reports / column picker**: typing "Service" surfaces two distinct fields (`business_service` and `u_item`). Picking the wrong one is silent — the export looks complete but the column carries the wrong values. This bit us when building the extended CSV (the BSO/TSO discriminator failed to land because the picker matched `u_item`'s "Service" label).
- **Filters**: same ambiguity. "Service is not empty" filtered on `business_service` (per the breadcrumb), but could equally have hit `u_item` if the picker resolved differently.
- **Form layout**: two "Service" fields and two "Category" fields appear on the incident form, indistinguishable to the operator without hovering or right-clicking to inspect the field name.
- **Documentation / training**: any prose referring to "Service offering on the incident" needs to disambiguate which of three possible references is meant: `service_offering` (the OOTB linked SO), `business_service` (label "Service"), or `u_item` (label "Service"). All three exist; all three are populated through different mechanisms; all three carry different semantics.

#### Where the v5-relevant service fields actually sit

CSDM v5 doesn't require new columns on the incident table — the OOTB fields are sufficient. The three service-related fields that v5 expects are all present:

| Field | Type | Role in v5 |
|---|---|---|
| `cmdb_ci` | Reference → `cmdb_ci` | The anchor — the CI that's broken / affected. Other service fields can be derived from it via the CMDB walk. |
| `service_offering` | Reference → `service_offering` | Holds **either** a BSO **or** a TSO. The linked record's `service_classification` field (`Business Service` or `Technology Management Service`) distinguishes which. No second column is needed at the platform level. |
| `business_service` | Reference → `cmdb_ci_service` | The parent Service of the offering. Auto-derived from `service_offering.parent` by Populator 1 — single source of truth is the SO. |

CCH's Incident Management HLD **(TBD)** takes a deliberate variant on the OOTB approach: it proposes a custom **`u_technical_service_offering`** field on the incident, so that `service_offering` can hold the BSO **permanently** (immutable across the incident lifecycle for SLA / reporting), while escalation to L2/L3/L4 is tracked by populating `u_technical_service_offering` with the relevant TSO. That field does not exist on the current CCH instance — it is HLD-proposed, not implemented. Two v5-aligned options exist:

| Approach | `service_offering` | `u_technical_service_offering` | Trade-off |
|---|---|---|---|
| Strict OOTB v5 | Holds BSO or TSO; mutates on escalation | Doesn't exist | Loses BSO history on escalation |
| CCH HLD v5 | Holds BSO permanently | Holds escalated TSO | Adds a custom field, but preserves BSO immutability |

Both are CSDM-compliant. The choice is an SLA / reporting trade-off, not a v5 conformance gate. The canonical CSDM v5 service-relationship reference **(TBD)** documents the full chain (BSO → Service Instance ← TSO ← Technology Management Service) and current CCH relationship counts.

#### Custom-field provenance

The 84 dictionary entries keyed on `name = incident` are fields **defined on the incident table itself** — not fields inherited from `task` (those are keyed on `name = task` and are not counted here). The 84 split into two groups:

- **59 CCH-custom** (`u_*` prefix), added by various authors over the years (`rebeca.sanchez`, `daniel.penchev`, `marta.hernandez`, `todor.ginchev`, `ASQ00367`, `ASQ00467`, `BG900581`, `EX001339`, and others). Several date to 2015 — the same era as the 11-year-old `INC - Fill Assignment group on save` business rule.
- **25 OOTB** incident-specific fields defined by ServiceNow on the incident table itself — `caller_id`, `category`, `subcategory`, `incident_state`, `severity`, `problem_id`, `parent_incident`, `child_incidents`, `reopened_by`, `reopened_time`, `reopen_count`, `resolved_by`, `resolved_at`, `cause`, `caused_by`, `close_code`, `notify`, `origin_id`, `origin_table`, `rfc`, `business_impact`, `business_stc`, `calendar_stc`, `sys_id`, plus the collection entry.

The task-inherited fields used everywhere in the routing analysis (`business_service`, `service_offering`, `cmdb_ci`, `state`, `priority`, `impact`, `urgency`, `assignment_group`, `short_description`, `correlation_id`, `correlation_display`, `work_notes`, `number`, `opened_by`, `opened_at`, `closed_by`, `closed_at`, etc.) live on `task`'s dictionary and are inherited at runtime — they don't count toward the 84. To see them in `sys_dictionary`, filter by `Table = task` instead of `Table = incident`.

The schema's accumulated layer — OOTB plus a decade of CCH-specific extensions — is itself the source of much of the routing complexity documented in §6.

```
   60  0 — CRISIS       ( 4.5 %)
  773  1 — URGENT       (58.2 %)
  326  2 — HIGH         (24.5 %)
  169  3 — MEDIUM       (12.7 %)
```

62.7 % of DT-generated incidents are P0 or P1. Sources of impact/urgency: OTE rule table (Script 1), `DynatraceIncidentINTUtil.determinePriority(title)` (which has Fortigate-specific, ATOS-specific, and generic severity×impact mappings), and the inline max-cap on the CSDM-walk path. The cumulative effect is that two-thirds are flagged at urgency 1 or 2.

When *any* P0/P1 incident is essentially a routine occurrence, urgency stops carrying signal. Operators have to triage by content (title parsing) rather than by priority.

---

## 8. Closure behaviour — the integration is fire-and-forget; humans close the incidents

Two compatible statements need to be held separately:

1. **The integration cannot close incidents.** Verified in the live transform-map code:
   - `state` field map sets `state = 1` (New) on insert and ignores every subsequent event — close signals from DT have no effect on incident state.
   - `work_notes` field map rewrites `"RESOLVED Problem P-..."` → `"UPDATE Problem P-..."` on inbound close events — the close signal is intentionally erased.
   - No business rule, flow, or scheduled job exists that re-checks DT problem state and closes the corresponding incident.

   Architectural label: *fire-and-forget*. DT pushes the open event, SN creates the incident, the integration is finished. DT problem closure on the source side is not propagated.

2. **Incidents do reach `Closed` — but via human ITSM workflow on the receiving teams.** Data:

```
State distribution:
  Closed:           1,264  (95.0 %)
  Pending Closure:     53  ( 4.0 %)
  Open:                12  ( 0.9 %)

Of the 1,264 in Closed:
  Both resolved_at and closed_at populated:  1,260  (99.7 %)
```

The 95 % closure rate reflects what the receiving assignment groups do with these incidents — not what the integration does. Closure-rate by problem type:

```
  FortiGate  (n=985):  Closed 95.2 %   Pending 3.7 %   Open 1.1 %
  MES        (n=162):  Closed 96.9 %   Pending 3.1 %   Open 0.0 %
  Pacemaker  (n= 15):  Closed 73.3 %   Pending 26.7 %  Open 0.0 %
  SAP/CPI    (n= 11):  Closed 63.6 %   Pending 36.4 %  Open 0.0 %
  Other      (n=148):  Closed 96.6 %   Pending 2.7 %   Open 0.7 %
```

Pacemaker and SAP/CPI categories close slower but are low-volume; FortiGate, MES, and miscellaneous server traffic close cleanly through human workflow.

**Operational consequence**: when a DT problem auto-resolves on the source side (cluster recovers, FortiGate comes back up), the SN incident does <span style="color: red">**not**</span> auto-close. It sits open until the assignment-group owner notices it and closes it manually. For high-volume noise classes (FortiGate `is DOWN`/`Critical Link Down` patterns that frequently recover within minutes), the team carrying the misroute is also carrying the manual-close burden for problems that already resolved themselves.

---

## 9. Operational implications

### 9.1 Routing succeeds; correctness is a separate question

For 95 % of DT-generated incidents the primary `cmdb_ci` field is empty, yet 99.8 % of incidents land on an assignment group. The pipe is not broken — *something* always lands. What lands may be wrong (see §4 and §10), but routing reliably puts a ticket somewhere.

### 9.2 The FortiGate routing is the dominant operational defect

89.7 % of FortiGate alerts — the most operationally critical class of alert in the dataset, including all `is DOWN` and `Critical Link Down` cases — are routed to country desktop support teams rather than the network team. The cause is one wrong sys_id in `x_dynat_ruxit.dynatrce.fg.category.mapping`: the DOWN/Critical-Link regexes point at the `sc_cat_item` named **"WAN - General"** (category Domestic Network → triggers on-site-support routing) instead of **"General"** (category Fortigate → firewall team). One JSON edit fixes the entire 89.7 % misroute (§10).

### 9.3 Affected CIs M2M is the place CIs do live

`Populate Dynatrace Affected CIs` writes Dynatrace-resolved CIs into the `task_ci` M2M — not into `cmdb_ci`. For any reporting or analysis that needs the CIs associated with a DT incident, the right place to look is the Affected CIs related list, not the primary CI field. (The CSV exports did not include the M2M data.)

### 9.4 The Service Offering field carries mixed semantics

The field holds both BSO-style offerings ("Network Access", "MES", …) and CCH role-suffixed offerings ("Cloud Resources Linux - Operations Support", …). Anyone reporting on routing patterns needs to know this — a simple `GROUP BY service_offering` does not separate the two shapes.

### 9.5 CI absence makes downstream analysis on the primary field difficult

With `cmdb_ci` empty on 95 % of records, downstream analytics that would normally join incidents to an Application Service via `cmdb_ci`, a Business Application via the CI, or a device CI for trend analysis per host cannot do so via the primary CI link for those 95 %. Affected-CIs (the M2M) may carry the equivalent association; that requires a separate query.

### 9.6 Zero application-level signal

100 % of records in this dataset are tagged `INFRASTRUCTURE` in their short description. There are no application-level DT problems landing as incidents in this 3-month window. The integration is currently a FortiGate-and-infrastructure alerting pipe, not an application-monitoring pipe. The 500-application target set by Dynatrace leadership remains unmet.

### 9.7 Misroute correction would shift load substantially

The §10 fix shifts ~875 incidents per 3 months (~5 per workday) from country-level desktop support teams to `G SNOW EXT OTE PRONET` (the firewall team). The country desks would see ~25 % fewer incidents overall; the firewall team would see ~9–10× current volume.

> **Watchlist**: monitor `G SNOW EXT OTE PRONET` ticket volume and resolution rate after the §10 fix is applied. The ~10× shift may be absorbed cleanly given the team's current 81 % within-24h resolution profile, but it is the kind of change that benefits from quiet observation rather than pre-flight capacity sign-off.

---

## 10. The configuration defect and the fix

### Trace of a misrouted FortiGate `is DOWN P1` incident

1. `DynatraceIncidentINTUtil.determineFortigateCategory(title)` matches the title against the JSON regex `.*AVAILABILITY...FortiGate...is DOWN P1` and returns `fe158879431002003d4de93ca24afc6e`.
2. Script 1's Sub-path B looks up that sys_id in `sc_cat_item`. The record exists and is active:

   | Field | Value |
   |---|---|
   | `name` | **WAN - General** |
   | `active` | **true** |
   | `category` | **Domestic Network** (sys_id `c61d566d019842003d4d4e13478059d3`) |

3. Script 1 writes `target.u_item = 'fe158879…'` (displays as "WAN - General") and `target.u_subcategory = 'c61d566d…'` (Domestic Network).

4. Script 1's trailing conditional fires:
   ```javascript
   if (target.u_subcategory == 'c61d566d019842003d4d4e13478059d3' &&
       target.priority >= 1 && target.priority <= 4) {
       target.u_on_site_support = true;
   }
   ```
   `u_subcategory` matches exactly; priority is P0/P1/P2 (1–3). Sets `u_on_site_support = true`.

5. Populator 3 (`INC - Fill Assignment group on save`) reads `u_on_site_support`:
   ```javascript
   if (current.u_on_site_support) {
       current.assignment_group = getOnSiteGroupByLocation(lc);
   }
   ```
   The on-site path returns the country desktop-support group nearest to the FortiGate's location.

6. Final routing: `u_subcategory = Domestic Network`, `service_offering = Network Access`, `assignment_group = G SNOW <country> ON-SITE SUPPORT`.

### Compare to the correctly-routed FortiGate group

For an `HA Status is Unknown` / `Status Failed sync` / `Unknown Cluster Sync` title, step 1 returns `271909eb…` instead. That record:

| Field | Value |
|---|---|
| `name` | **General** |
| `active` | **true** |
| `category` | **Fortigate** |

`u_subcategory` is set to the Fortigate-category sys_id (not `c61d566d…`), so the trailing conditional doesn't fire, `u_on_site_support` stays false, and Rule 3 takes its `u_escalation_groups` table-lookup path. That lookup keys on `u_item × u_level × country × 'Incident'` and finds `G SNOW EXT OTE PRONET` — the firewall team.

### The defect

The `x_dynat_ruxit.dynatrce.fg.category.mapping` property points three regexes (`is DOWN P0`, `is DOWN P1`, `Critical Link Interface`) at `fe158879…` ("WAN - General" → Domestic Network) when they should point at `271909eb…` ("General" → Fortigate). Most likely a name-collision picker error during the property edit — both target records have display names containing "General":

- `fe158879…` is **"WAN - General"**
- `271909eb…` is **"General"**

Only visible by reading the cat_item's `category` field, which is what determines the routing.

### The fix

Update `x_dynat_ruxit.dynatrce.fg.category.mapping`, repointing the three affected regexes:

```diff
- { "regex": ".*AVAILABILITY\\s+problem\\s+on\\s+INFRASTRUCTURE:\\s*FortiGate\\s+\\S+\\s+is\\s+DOWN\\s*P0",
-   "category": "fe158879431002003d4de93ca24afc6e" }
+ { "regex": ".*AVAILABILITY\\s+problem\\s+on\\s+INFRASTRUCTURE:\\s*FortiGate\\s+\\S+\\s+is\\s+DOWN\\s*P0",
+   "category": "271909ebc33c86506517503bb001312e" }

- { "regex": ".*AVAILABILITY\\s+problem\\s+on\\s+INFRASTRUCTURE:\\s*FortiGate\\s+\\S+\\s+is\\s+DOWN\\s*P1",
-   "category": "fe158879431002003d4de93ca24afc6e" }
+ { "regex": ".*AVAILABILITY\\s+problem\\s+on\\s+INFRASTRUCTURE:\\s*FortiGate\\s+\\S+\\s+is\\s+DOWN\\s*P1",
+   "category": "271909ebc33c86506517503bb001312e" }

- { "regex": ".*ERROR\\s+problem\\s+on\\s+INFRASTRUCTURE:\\s*FortiGate\\s+Critical\\s+Link\\s+Interface",
-   "category": "fe158879431002003d4de93ca24afc6e" }
+ { "regex": ".*ERROR\\s+problem\\s+on\\s+INFRASTRUCTURE:\\s*FortiGate\\s+Critical\\s+Link\\s+Interface",
+   "category": "271909ebc33c86506517503bb001312e" }
```

That change shifts ~875 FortiGate outage incidents per 3 months (≈5 per workday) from country desktop support to `G SNOW EXT OTE PRONET` — the firewall team. No code change, no CMDB change, no schema change. Just a property-value edit, deployable via a single Update Set, reversible in seconds.

### Other genuine defects (independent of the FortiGate misroute)

1. **The final-fallback `u_subcategory` resolves to the "ServiceNow" catalog category** — semantically wrong. When a DT incident matches none of the routing branches, it lands in the catalog category used for internal CCH ServiceNow tickets (FlowNow, ChatNow, CMDB, HAM, etc.). Five records hit this path in the extended export — all titled "Multiple infrastructure problems OTE". Not the largest defect but worth correcting.

2. **`location` is fallback-set to `BSS` for 33 % of records.** Script 2 sets `target.location` only when the title matches its FortiGate-device regex. For everything else (443 of 1,330 records) it hardcodes `target.location = '6a3a0d52…'`, which resolves to **"BSS"** in `cmn_location`. Doesn't affect routing — Rule 3 derives country separately — but makes location-based analytics misleading.

### No path in the transform map sets a primary CI on the incident

The 65 incidents in the dataset that have `cmdb_ci` populated got it by manual operator entry during triage — see §6.6 Populator 4.

---

## 11. Outstanding

| # | Item | Status |
|--:|---|---|
| 1 | ~~Identify what sets `current.u_level` at insert.~~ | **Resolved.** Set by the before-insert Business Rule **`INC - Populate CCH Available Levels`** (Global scope, table `incident`). The BR computes `u_cchavailablelevels` from the row count of `u_escalation_groups` for the (`u_item` × `country`) pair, then unconditionally stamps `current.u_level = "Level1"` (no space) as the default escalation level. Author comment on the line: *"DPE, Set def level to Level1"* (`daniel.penchev`). Behaves as a fourth populator alongside the three documented in §6.6 — runs before Rule 3 (`INC - Fill Assignment group on save`), so Rule 3's lookup against `u_escalation_groups` keyed on `u_level = "Level1"` always has a value to work with. |
