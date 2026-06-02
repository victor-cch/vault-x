# Business Rules on the `incident` Table — Code Analysis

![Status: Draft](https://img.shields.io/badge/status-Draft-F59E0B)
![Intent: Analytical](https://img.shields.io/badge/intent-Analytical-8B5CF6)

**Scope**: All active business rules on the `incident` table that participate in the population of `service_offering`, `assignment_group`, `cmdb_ci`, or any other field downstream of the Dynatrace transform map. Sister document to [`transform-map-analysis.md`](transform-map-analysis.md) — the transform map itself does **not** write those three fields; this file documents what does.

**Companion analysis**: [`dt-incident-routing-2026-06.md`](dt-incident-routing-2026-06.md) §6.6 (the populator-mechanism question this file closes).

---

## Inventory

Found via `sys_script.list?sysparm_query=collection=incident^active=true^scriptLIKEsc_cat_item_subscribe_mtom`:

| # | Rule name | Scope | Insert | Update | Delete | Query | Status |
|--:|---|---|:-:|:-:|:-:|:-:|---|
| 1 | `Populate Service Offering` | Global | ✓ | ✓ | ✗ | ✗ | **Verified 2026-06-01** — writes `service_offering` AND `business_service` from `u_item` via `sc_cat_item_subscribe_mtom`; no guard, last-match-wins |
| 2 | `CCH-Map Inc Category to offering` | Global | ✓ | ✓ | ✗ | ✗ | **Verified 2026-06-01** — writes `service_offering` from `u_item` via `sc_cat_item_subscribe_mtom` |

Found separately (broader scan of incident-table BRs, 2026-06-01):

| # | Rule name | Scope | Insert | Update | Status |
|--:|---|---|:-:|:-:|---|
| 3 | `INC - Fill Assignment group on save` | Global | ✓ | ✓ | **Verified 2026-06-01** — populates `assignment_group` (and `u_cchresponsible`) via `u_escalation_groups` lookup; not via `service_offering.support_group`. 11 years old (2015). |

Also relevant (in Dynatrace integration scope, documented separately in [`transform-map-analysis.md`](transform-map-analysis.md) §6):

| Rule name | Scope | Writes to |
|---|---|---|
| `Populate Dynatrace Affected CIs` | `x_dynat_ruxit` | `task_ci` (Affected CIs M2M) — does **not** write `cmdb_ci`, `service_offering`, or `assignment_group` |

---

## Rule 1 — `Populate Service Offering`

### Form metadata (captured 2026-06-01)

| Property | Value |
|---|---|
| Name | `Populate Service Offering` |
| Table | `incident` |
| Application scope | Global |
| Active | true |
| Advanced | true |
| When | Insert + Update (both ticked) |
| Order | Pending |
| **Filter conditions** | **None set** — the form shows "-- choose field --" (default). The rule fires on every incident Insert/Update; any guard must live inside the script body. |
| Role conditions | None visible |

**Update set provenance**: `STRY-SP1-US1-371093-SSO` (sys_id `sys_script_724137b8c3aa42d46dc2da1f0501310e`, created 30/07/2024 08:39:32 by `ASQ00130`). Pre-dates `CCH-Map Inc Category to offering` (March 2025) by ~8 months — likely the original populator; the newer rule appears to be a guarded refinement that fills in blanks rather than overwriting.

### Script body (verified 2026-06-01)

ES12 mode: **off**. Script uses ES5-era syntax only.

```javascript
(function executeRule(current, previous /*null when async*/) {
    var grMapping = new GlideRecord('sc_cat_item_subscribe_mtom');
    grMapping.addQuery('sc_cat_item', current.u_item);
    grMapping.query();

    // If a matching record is found, populate the service_offering field
    while (grMapping.next()) {
        current.service_offering = grMapping.service_offering;
        current.business_service = grMapping.service_offering.parent;
        // Fetch the parent business_service from the service_offering
    }
})(current, previous);
```

### Logic

1. Runs on every incident Insert and Update — **no filter conditions, no guard inside the script**.
2. Queries `sc_cat_item_subscribe_mtom WHERE sc_cat_item = current.u_item`.
3. Iterates the matches with `while (grMapping.next())` — but each iteration overwrites the previous, so it is **effectively last-match-wins** (`while` is being used like an `if`).
4. Per matching row, writes two fields:
   - `current.service_offering = grMapping.service_offering` (the SO from the M2M row)
   - `current.business_service = grMapping.service_offering.parent` (dot-walks to the parent record of the service_offering — in CSDM, the Business Service that owns the offering)

### Properties

- **Writes `business_service` as well as `service_offering`** — a field the 1,328-record export did not include. The `business_service` population rate on DT-induced incidents is therefore likely also ~99 %, but unconfirmed. A column on `business_service` should be added to the next export to verify.
- **No guard, last-match-wins, runs on every Insert/Update**: this means even if `service_offering` was set by an upstream mechanism (the transform map's CSDM-walk path, or Rule 2), this rule will overwrite it.
- **Interaction with Rule 2 (`CCH-Map Inc Category to offering`)**: both rules use the same query. Rule 1 is older (Jul 2024); Rule 2 is newer (Mar 2025) and has an empty-guard. Whatever order they run in, Rule 1 wins on the final value because it has no guard. **Rule 2's guard is effectively dead code** when both fire on the same record. The semantic difference (first-match vs last-match for the M2M result) only matters if a `sc_cat_item` has multiple `sc_cat_item_subscribe_mtom` rows.
- **Does not write `assignment_group`**.
- **Does not write `cmdb_ci`**.

### What this confirms in `dt-incident-routing-2026-06.md`

- The 99.2 % `service_offering` population rate observed in the export is now **fully explained** by this rule (with Rule 2 acting as a no-op refinement layer in most cases).
- The 99 %+ `business_service` population rate is **predicted by the code but not yet measured** — should be confirmed by re-exporting the dataset with `business_service` included.

### What this does NOT explain

- The **99.8 % `assignment_group` population rate** — neither this rule nor Rule 2 writes that field. The populator is therefore elsewhere (likely an OOTB ServiceNow business rule that derives `assignment_group` from `service_offering.support_group`, or a Data Lookup Rule, or an Assignment Rule).
- The **4.9 % `cmdb_ci` population rate** — still not explained by any rule we've found so far. Server-class CIs only; the populator likely involves a separate path entirely.

---

## Rule 2 — `CCH-Map Inc Category to offering`

### Form metadata (captured 2026-06-01)

| Property | Value |
|---|---|
| Name | `CCH-Map Inc Category to offering` |
| Table | `incident` |
| Application scope | Global |
| Active | true |
| Advanced | true |
| Accessible from | This application scope only |
| When | Insert + Update (both ticked) |
| Order | Pending |
| **Filter conditions** | `Service offering` <op> ... AND `Service(u_item)` <op> ... (operators not visible in the paste — likely `changes` or `is empty`) |
| Role conditions | None visible |

**Update set provenance**: `IM-SP1-US1-563413-GSH` (single version, sys_id `sys_script_06144565877b56148451ef0a0cbb3520`, created 10/03/2025 15:03:34 by `ASQ00130`). The rule has not been edited since that update set was applied.

### What the filter conditions tell us

The visible filter has two clauses joined by AND:

1. A condition on **`service_offering`** (likely `is empty` or `changes from`)
2. A condition on **`u_item`** (labelled "Service(u_item)" in the form — `u_item` is presumably a reference to `sc_cat_item`)

So this rule fires when:
- The incident's `service_offering` is in a particular state (empty / changed), AND
- The incident's `u_item` is in a particular state.

That shape is consistent with a "map category to offering" purpose: if `u_item` is set but `service_offering` is not, derive `service_offering` from `u_item` via `sc_cat_item_subscribe_mtom`.

### Script body (verified 2026-06-01)

```javascript
(function executeRule(current, previous /*null when async*/) {

    var mapping = new GlideRecord('sc_cat_item_subscribe_mtom');

    if (current.service_offering == '' && current.u_item != '') {
        mapping.addEncodedQuery('sc_cat_item.sys_id=' + current.u_item);
        mapping.query();

        if (mapping.next()) {
            current.service_offering = mapping.service_offering.sys_id;
        }
    }

})(current, previous);
```

### Logic

1. Runs on incident Insert and Update (per the form configuration).
2. **Guard**: only acts when `current.service_offering` is empty AND `current.u_item` is set. This means it does **not** overwrite an existing service offering — it only fills in a blank.
3. Queries `sc_cat_item_subscribe_mtom WHERE sc_cat_item = current.u_item`.
4. Takes the **first** matching M2M row (`mapping.next()` called once — no iteration).
5. Sets `current.service_offering = mapping.service_offering.sys_id`.

### Properties

- **First-match-wins**: if a `sc_cat_item` is linked to multiple service offerings via `sc_cat_item_subscribe_mtom`, only one is chosen — order depends on the M2M table's default sort (typically `sys_id` ascending or `sys_created_on`).
- **Idempotent within a single record**: once `service_offering` is populated, the guard prevents re-application.
- **Does not write `assignment_group`** — that population is the responsibility of a different rule (likely `Populate Service Offering`, pending).
- **Does not write `cmdb_ci`** — the cmdb_ci populator is still unidentified.
- **Field `u_item` is the trigger source** — this is the `sc_cat_item` reference that the transform map's Script 1 set during routing (in either the FortiGate shortcut, the CSDM walk, or the hardcoded fallback). So every DT-induced incident that reached one of those paths has `u_item` populated and therefore gets `service_offering` populated by this rule.
- **Explains the 99.2 % `service_offering` rate** observed in `dt-incident-routing-2026-06.md`. The 0.8 % gap (10 records) is consistent with edge cases: either `u_item` was unset (no transform-script path matched) or the cat item it referenced had no `sc_cat_item_subscribe_mtom` row.

### Note on the form's Condition field

In addition to the Script body, ServiceNow business rules have a separate **Condition** field (a one-line JavaScript expression that gates whether the script runs at all — distinct from the table-level filter conditions). That field has not been captured yet — if it is non-empty, paste it. If it is empty, the filter conditions on the form (`Service offering` + `Service(u_item)`) are the only runtime gates.

The "Turn on ECMAScript 2021 (ES12) mode" toggle controls whether the script can use modern JavaScript features (`let`, `const`, arrow functions, template literals, etc.). For this rule, the body uses only ES5-era syntax, so the toggle state is not material to behaviour.

---

## Rule 3 — `INC - Fill Assignment group on save`

### Form metadata (captured 2026-06-01)

| Property | Value |
|---|---|
| Name | `INC - Fill Assignment group on save` |
| Table | `incident` |
| Application scope | Global |
| Active | true |
| When | Insert + Update (both ticked) |
| Order | Pending |

Header comment in the script reads `2015-05-14 TGI` — the rule is **11 years old** and predates the Dynatrace integration entirely. It is generic CCH escalation routing that applies to every incident on the platform, with the Dynatrace integration's incidents inheriting it for free.

### Script body (verified 2026-06-01)

```javascript
// 2015-05-14 TGI, Populate assignment group in case the client script failed to do so.

function onBefore(current, previous) {
    var lc = current.location;
    var countryCCH = new locationInfo();
    var country = countryCCH.getCountryByLocation(lc);

    if (current.u_on_site_support) {
        current.assignment_group = getOnSiteGroupByLocation(lc);
    } else {
        current.assignment_group = getGroupByEscalation(current.u_item, current.u_level, country);

        if (current.assignment_group.name.indexOf("ATOS") > -1) {
            if (current.caller_id.user_name.indexOf("RU") > -1
                || current.caller_id.user_name.indexOf("RF") > -1
                || current.caller_id.user_name.indexOf("BY") > -1
                || current.opened_by.user_name.indexOf("RU") > -1
                || current.opened_by.user_name.indexOf("RF") > -1
                || current.opened_by.user_name.indexOf("BY") > -1) {
                current.u_comment_from_customer = "Assigned to ATOS by CCBMS";
            }
        }
    }

    // Default assignment group
    if (current.assignment_group.nil()) {
        var obj_assign_gr = new getAssignmentGroupByLevel();
        current.assignment_group = obj_assign_gr.getGroupByRole('l2_admin_access');
    }

    // Derive u_cchresponsible from assignment_group's u_cchlevel
    if (current.u_cchresponsible.nil()) {
        var gr_group = new GlideRecord("sys_user_group");
        if (gr_group.get(current.assignment_group)) {
            current.u_cchresponsible = gr_group.u_cchlevel.replace(' ', '');
        }
    }
}

function getOnSiteGroupByLocation(lc) {
    var userLocation = new locationInfo();
    return userLocation.getFirstOnSiteToParent(lc);
}

function getGroupByEscalation(u_item, u_level, country) {
    var escalationGroups = new GlideRecord('u_escalation_groups');
    escalationGroups.addQuery('u_itemid', u_item);
    escalationGroups.addQuery('u_escalation_level', u_level);
    escalationGroups.addQuery('u_request_typeid', 'Incident');
    escalationGroups.addQuery('u_core_country', country);
    escalationGroups.query();

    while (escalationGroups.next()) {
        return escalationGroups.u_groupid;
    }
}
```

(Uses the legacy `function onBefore(current, previous)` signature rather than the modern `(function executeRule(){})(current, previous)` IIFE wrapper. Both work; the legacy form confirms this rule's age.)

### Logic

1. Gets the incident's `location` reference, then derives `country` via the `locationInfo` script include (`getCountryByLocation`).
2. **Branch A** — `current.u_on_site_support == true`:
   - Calls `getOnSiteGroupByLocation(lc)` → `locationInfo.getFirstOnSiteToParent(lc)` → walks the location's parent chain and returns the first `u_onsite_group` it finds.
3. **Branch B** — `u_on_site_support` is false/empty:
   - Queries `u_escalation_groups` filtered on `(u_itemid = current.u_item, u_escalation_level = current.u_level, u_request_typeid = 'Incident', u_core_country = country)` → returns the first matching `u_groupid`.
   - **ATOS + Russia/Belarus side-effect**: if the resulting group's name contains `"ATOS"` AND the caller or opener username starts with `RU`/`RF`/`BY`, sets `current.u_comment_from_customer = "Assigned to ATOS by CCBMS"`. Routes a static note onto the incident for Russia/Belarus operators.
4. **Fallback** — if `assignment_group` is still nil: `getAssignmentGroupByLevel().getGroupByRole('l2_admin_access')` → a default L2-admin group.
5. **Side effect** — if `u_cchresponsible` is empty: looks up the assignment_group in `sys_user_group`, reads its `u_cchlevel`, strips whitespace, writes to `current.u_cchresponsible`.

### Properties

- **Generic, not Dynatrace-specific** — runs on every incident Insert/Update; DT-induced incidents inherit it because the upstream transform map sets the fields it consumes.
- **Lookup table is `u_escalation_groups`**, a CCH-custom table keyed on `(u_itemid × u_escalation_level × u_request_typeid × u_core_country)`. This is a **parallel routing model to CSDM** — neither `service_offering` nor `support_group` is consulted on this path.
- **Source fields it depends on** (all set upstream of this rule):
  - `current.u_item` — set by the transform map's Script 1.
  - `current.u_level` — escalation level (L1/L2/L3). **Setter not yet identified.** This is a candidate for an additional outstanding question.
  - `current.u_on_site_support` — set by the transform map's Script 1 trailing conditional, only when `u_subcategory == 'c61d566d…'`.
  - `current.location` — set by the transform map's Script 2 (FortiGate location stamper) or by another mechanism for non-FortiGate incidents.
- **Default-fallback explains the 99.8 % population rate** — even when both lookups miss, the L2-admin default fires, so almost every incident lands somewhere.
- **`u_cchresponsible` is a side-effect output** — derived from `assignment_group.u_cchlevel`. Worth measuring in a future export.
- **`u_comment_from_customer` is also a side-effect output** for the ATOS/Russia case — a CCBMS audit trail.

### What this confirms in `dt-incident-routing-2026-06.md`

- The 99.8 % `assignment_group` population rate is now **fully explained**.
- The earlier hypothesis (that `assignment_group` was derived from `service_offering.support_group`) is **disproved**. The actual mechanism is the `u_escalation_groups` table lookup, which is independent of `service_offering`.
- The FortiGate-misroute symptom (`G SNOW <country> ON-SITE SUPPORT` for misrouted FortiGates) is now traceable: the transform map sets `u_item` to a generic catalog item (Domestic Network / Network Access), the country comes from the FortiGate device name in the title, `u_level` defaults to L1, and `u_escalation_groups` maps `(Network Access × L1 × Incident × <country>)` to the country desktop support team. The "misroute" is the *correct output* of this lookup table given the input parameters — the gap is upstream, in what `u_item` the FortiGate path resolves to.

### What this does NOT explain

- The **4.9 % `cmdb_ci` population rate** is still unexplained.
- The setter for `current.u_level` is not yet identified — likely an OOTB or CCH-custom rule that runs before this one.

---

## Summary of what each rule does

| Field | Populator | Mechanism |
|---|---|---|
| `service_offering` | **Rule 1** (`Populate Service Offering`) | `u_item → sc_cat_item_subscribe_mtom → service_offering`, last-match-wins, runs every insert/update without guard. Rule 2 acts only when SO is empty and is functionally redundant. |
| `business_service` | **Rule 1** (same) | Dot-walks `service_offering.parent` and writes it. |
| `assignment_group` | **Rule 3** (`INC - Fill Assignment group on save`) | Two-branch lookup: on-site path (`location → u_onsite_group`) or escalation path (`u_escalation_groups` table keyed on `u_item × u_level × country × 'Incident'`), with L2-admin default fallback. **Independent of `service_offering`.** |
| `u_cchresponsible` | **Rule 3** (side effect) | Derived from `assignment_group.u_cchlevel` with whitespace stripped. |
| `cmdb_ci` | **Unidentified** | None of the three rules writes it. 4.9 % populated (server-class only) → likely a server-CI-specific path elsewhere. |

## Pending — to close this analysis

1. **Identify the `assignment_group` populator.** Likely candidates:
   - An OOTB ServiceNow business rule that derives `assignment_group` from `service_offering.support_group`. Search: `sys_script.list?sysparm_query=collection=incident^active=true^scriptLIKEassignment_group`.
   - A Data Lookup Rule: `dl_definition.list?sysparm_query=table=incident^active=true`.
   - An Assignment Rule: `sys_assignment_lookup_rule.list?sysparm_query=table=incident^active=true`.
2. **Identify the `cmdb_ci` populator** (server-class only). Likely candidates:
   - Another business rule downstream of `Populate Dynatrace Affected CIs` that conditionally copies the first `task_ci` entry into `cmdb_ci` when the CI's `sys_class_name` matches a server class. Search: `sys_script.list?sysparm_query=collection=incident^active=true^scriptLIKEcmdb_ci^scriptLIKEsys_class_name`.
   - A Data Lookup Rule with `cmdb_ci` as the target field.
3. **Confirm order of execution** between Rule 1, Rule 2, and `Populate Dynatrace Affected CIs` — the `Order` field on each BR determines the sequence. Capture all three Order values.
4. **Add `business_service` to the next CSV export** to confirm the rule's predicted ~99 % population rate empirically.
5. (After 1–4): promote `dt-incident-routing-2026-06.md` §6.6 from hypothesis to verified-fact.

---

*Created: 2026-06-01. Status: Draft — Rules 1 and 2 verified; `assignment_group` and `cmdb_ci` populators still outstanding.*
