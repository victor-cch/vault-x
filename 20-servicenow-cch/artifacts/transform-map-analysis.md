# Transform Map — Code Analysis

![Status: Approved](https://img.shields.io/badge/status-Approved-10B981)
![Intent: Analytical](https://img.shields.io/badge/intent-Analytical-8B5CF6)

**Source**: Transform Map "Problem to Incident Transformation Map" — `x_dynat_ruxit_problems` → `incident`, Dynatrace Incident integration scope.
**Date**: 1 June 2026 — full verification against live code.
**Related**: [Incident Integration Blueprint](hld-sn-dt-incident-integration.md) | [CSDM v5 Service Relationship Model](csdm-v5-service-relationship-model.md) | [DT-induced Incident Routing — Current-State Assessment](dt-incident-routing-2026-06.md) (data-side companion) | CCHIncidentUtils Code Reference *(at [`../../../blueprints/incident-management/cchincidentutils-code-reference.md`](../../../blueprints/incident-management/cchincidentutils-code-reference.md))*

---

## Overview

The Transform Map is the entry point for all Dynatrace → ServiceNow incident creation. It consists of:

- **9 Field Maps** — 8 script-based, 1 direct map.
- **2 onBefore Transform Scripts** — Script 1 (rule matching + Non-OTE branching) and Script 2 (FortiGate location stamper).
- **No onAfter scripts**.

The combined transform writes to: `contact_type`, `correlation_id`, `correlation_display`, `state`, `short_description`, `caller_id`, `work_notes`, `description`, `impact`, `urgency`, `u_subcategory`, `u_item`, `u_on_site_support`, `location`. It **does not write to `cmdb_ci`** (the field map exists but its script body is fully commented out and returns `""`) and **does not write to `service_offering`** (no field map for it; neither script touches it).

The populations of `cmdb_ci` (~5 % of incidents) and `service_offering` (99 % of incidents) observed in the production data are produced **outside the transform map** — see `dt-incident-routing-2026-06.md` §6.6 for the populator mechanism (CCHIncidentUtils + a post-insert business rule). The one business rule identified in this analysis (`Populate Dynatrace Affected CIs`, §6) writes to the `task_ci` M2M (Affected CIs related list), not to the primary `cmdb_ci` field.

---

## Field Maps Summary

| # | Source | Target Field | Coalesce | Logic |
|--:|---|---|---|---|
| 1 | Script | `contact_type` | no | Static `"event"` |
| 2 | `problem_id` | `correlation_id` | **yes** | Direct map — this is the dedup key |
| 3 | Script | `correlation_display` | no | Static `"DYNATRACE"` |
| 4 | Script | `cmdb_ci` | no | **Dead — returns `""`**. Every substantive line in the script is commented out (verified 2026-06-01). The commented-out version would have done `sys_object_source.addQuery("id", ci_item)` with no other filters. |
| 5 | Script | `state` | no | OPEN → New(1); else → Resolved(6) if `autoresolveproblems=true`, otherwise New(1) |
| 6 | `problem_title` | `short_description` | no | Direct map |
| 7 | Script | `caller_id` | no | Static `"SA_DYNATR_SNOW"` |
| 8 | Script | `work_notes` | no | Returns `details`; on CLOSE, rewrites `"RESOLVED Problem"` → `"UPDATE Problem"` |
| 9 | Script | `description` | no | `details` on OPEN; preserves existing `target.description` on CLOSE/UPDATE |

**Notable absences from this list**:

- No field map for `service_offering`
- No field map for `u_technical_service_offering`
- No field map for `assignment_group`
- No field map for `u_subcategory` / `u_item` (these are set by Script 1 instead)

### Field-map cmdb_ci script body (verified 2026-06-01)

```javascript
answer = (function transformEntry(source) {
    
    //var ci_item = source.config_item;
    //var sysobjs = new GlideRecord("sys_object_source"); 
    //sysobjs.addQuery("id",ci_item);
    //sysobjs.query();
    //if(sysobjs.next()) {
    //    return sysobjs.getValue('target_sys_id');
    //} else 
    //{
        return "";
//    }
    
})(source);
```

Every operational line is commented out. Returns `""` unconditionally.

### Other observations

- **`state` is controlled by system property** `x_dynat_ruxit.autoresolveproblems` — if `false`, CLOSE events set state back to New(1), keeping incidents permanently open.
- **`work_notes` actively hides resolution** — regex rewrites "RESOLVED" to "UPDATE" in the work notes text, masking the problem lifecycle from ServiceNow users.
- **Coalesce on `correlation_id`** — `problem_id` ensures repeated webhooks update the same incident.

---

## Transform Script — onBefore (Script 1) — Main Logic

This is the primary script. Handles OTE and Non-OTE branches; sets `impact`, `urgency`, `u_subcategory`, `u_item`, and conditionally `u_on_site_support`. Does not write to `cmdb_ci`, `service_offering`, or `u_technical_service_offering`.

### OTE Path

**Entry condition**: `source.problem_title.slice(-3) === "OTE"` — checks if the title **ends with** "OTE" (last three characters).

#### Tag Parsing

Parses three Azure tags from `source.tags` (comma-separated):

| Tag Key | Variable |
|---|---|
| `[Azure]SLA` | `tag1` |
| `[Azure]Infra-Support` | `tag2` |
| `[Azure]Environment` | `tag3` |

#### Rule Matching

Loads `x_dynat_ruxit.dynatrace.ote.config` as JSON. The structure expected by the code is:

```json
{
  "rules": [
    {
      "regex_patterns": ["pattern1", "pattern2"],
      "titles": ["fallback-keyword1"],
      "sla": "<tag1 match or empty>",
      "support": "<tag2 match or empty>",
      "env": "<tag3 match or empty>",
      "impact": "<1|2|3>",
      "urgency": "<1|2|3>",
      "subcategory": "<u_subcategory sys_id>",
      "item": "<u_item / sc_cat_item sys_id>"
    }
  ],
  "fallback": {
    "subcategory": "<default u_subcategory sys_id>",
    "item": "<default u_item sys_id>"
  }
}
```

**Matching logic** (verified 2026-06-01):

1. For each rule, check `regex_patterns` first (case-insensitive `RegExp` test against `problem_title`).
2. If no `regex_patterns`, fall back to the `titles` array (substring `indexOf` match).
3. Additionally match `sla`, `support`, `env` against parsed Azure tags — **empty string = wildcard** (matches anything).
4. First rule where ALL conditions match wins.
5. On match, **sets `target.impact`, `target.urgency`, `target.u_subcategory`, `target.u_item`** — these four fields only.
6. On no match, the `fallback` block sets `target.u_subcategory` and `target.u_item` only; `impact` and `urgency` are not touched (they remain whatever the system defaults).

> **Prior-version correction**: The 17 March 2026 analysis claimed step 5 sets `target.service_offering` and `target.u_technical_service_offering`, and that a "cross-fallback" propagates BSO ↔ TSO. **Neither is in the live code as of 2026-06-01.** The OTE branch sets `u_subcategory` and `u_item`, not service-offering fields. If the JSON config carries `service_offering` / `tso` keys (the export below contains them), those keys are unused by the current code.

#### OTE Config — Live Rules (exported 2026-03-18, fields still as exported)

The config below is from the **March 2026 export** of `x_dynat_ruxit.dynatrace.ote.config`. The table includes a column for the **service_offering / tso sys_id** that the rule pointed at *at that time*. The current code (2026-06-01) does not read those keys — it reads `rule.subcategory` and `rule.item` instead. Either the config has been updated to include `subcategory` and `item` keys (in addition to or instead of `service_offering`/`tso`), or the code has been changed since the export. **A fresh export of the config is outstanding** to reconcile.

**16 rules + 1 fallback**. Three distinct service-offering sys_ids referenced in the export:

| Sys_id | Used as in export | Likely name (needs verification) |
|---|---|---|
| `850dba3cebe7d218d5cfff0775d0cd9a` | `service_offering` (BSO) | ANF / Linux offering |
| `f80dba3cebe7d218d5cfff0775d0cd94` | `tso` | Windows TSO |
| `900dba3cebe7d218d5cfff0775d0cd41` | `tso` | Backup Appliance TSO |
| `a605421e93d28a50c062bb7a6aba10c1` | `fallback.service_offering` | Default fallback offering |

**Rules by category** (as exported 2026-03-18):

| # | SLA | Support | Env | Match | Impact | Urgency | Offering (as exported) |
|--:|---|---|---|---|---|---|---|
| 1 | Critical | OTE | * | "Azure NetApp File" | 1 (High) | 2 (Med) | BSO `850d...` |
| 2 | Normal | OTE | * | "Azure NetApp File" | 2 (Med) | 2 (Med) | BSO `850d...` |
| 3 | Critical | OTE | * | "Windows Unexpected Shutdown" | 1 (High) | 2 (Med) | TSO `f80d...` |
| 4 | Normal | OTE | * | "Windows Unexpected Shutdown" | 2 (Med) | 2 (Med) | TSO `f80d...` |
| 5 | Non-Production | OTE | * | "Windows Unexpected Shutdown" | 2 (Med) | 3 (Low) | TSO `f80d...` |
| 6 | * | * | * | "Pacemaker" | 1 (High) | 2 (Med) | BSO `850d...` |
| 7 | Normal | OTE | * | "Backup Appliance VMs" | 2 (Med) | 2 (Med) | TSO `900d...` |
| 8 | * | OTE | Prod | "CPU-request saturation on node", "Memory-request saturation on node" | 1 (High) | 2 (Med) | **empty** |
| 9 | * | OTE | Prod | "Out-of-memory kills", "Node not ready", "K8s PVC low disk", "Backoff event", "PV Used" | 2 (Med) | 2 (Med) | **empty** |
| 10 | * | OTE | Prod | "CPU usage close to limits", "Memory usage close to limits", "container restarted" | 2 (Med) | 3 (Low) | **empty** |
| 11 | * | OTE | Dev | "CPU-request saturation on node" | 1 (High) | 2 (Med) | **empty** |
| 12 | * | OTE | Dev | "Out-of-memory kills", "Node not ready", "K8s PVC low disk", "Backoff event" | 2 (Med) | 2 (Med) | **empty** |
| 13 | * | OTE | Dev | "Memory-request saturation on node", "PV Used", "CPU/Memory close to limits", "container restarted" | 2 (Med) | 3 (Low) | **empty** |
| 14 | Normal | OTE | * | regex `Windows.*Disk Utilization` | 2 (Med) | 2 (Med) | TSO `f80d...` |
| 15 | Critical | OTE | * | regex `Windows.*Disk Utilization` | 1 (High) | 2 (Med) | TSO `f80d...` |
| 16 | Critical | OTE | * | regex `Linux.*Disk Utilization` | 1 (High) | 2 (Med) | BSO `850d...` |

**Observations about the data above**:

1. **Pacemaker (rule 6) is a wildcard** — matches any SLA and support tag. It's the only rule that doesn't require `support = "OTE"`.
2. **SLA drives impact differentiation** — Critical → 1 (High), Normal → 2 (Med), Non-Production → 2 + Urgency 3 (Low).
3. **Production vs Development** — same alert types get different priority tiers (Prod is higher).
4. **JSON syntax error in rule 8** — missing comma after `"urgency": "2"`. Either ServiceNow's JSON parser is lenient or this rule silently fails.

---

### Non-OTE Path

**Entry condition**: anything not ending with `"OTE"`.

```javascript
var tagsJson = source.tags;
var titleX = source.problem_title;
var application = "";

// Extract dtCSDMApplicationName from tags
if (tagsJson && tagsJson.trim() !== "") {
    var tagsArr = tagsJson.split(',');
    for (var i = 0; i < tagsArr.length; i++) {
        if (tagsArr[i].includes("dtCSDMApplicationName")) {
            application = tagsArr[i].substring(tagsArr[i].indexOf(':') + 1).trim();
            break;
        }
    }
}

var util = new DynatraceIncidentINTUtil();
var calculated = util.determinePriority(titleX);
var check = util.determineFortigateCategory(titleX);
var checkAnfAtos = util.determineAnfAtosCategory(titleX);
var impact = calculated.impact;
var urgency = calculated.urgency;
```

So three things are gathered before branching:
- `application` — the value of the `dtCSDMApplicationName` Dynatrace tag, if present
- `calculated.impact` and `calculated.urgency` — from `util.determinePriority(titleX)` (see DynatraceIncidentINTUtil section)
- `check`, `checkAnfAtos` — category-mapping sys_ids from `util.determineFortigateCategory(titleX)` and `util.determineAnfAtosCategory(titleX)` (`'0'` if no pattern match)

Three sub-paths in order:

#### Sub-path A — CSDM walk via `dtCSDMApplicationName`

**Entry condition**: `check == '0'` AND `checkAnfAtos == '0'` (neither FortiGate nor ANF-Atos pattern matched).

```javascript
var ciService = new GlideRecord('cmdb_ci_service_auto');
ciService.addQuery('name', application);
ciService.query();

while (ciService.next() && !foundMatch) {
    var ciRel = new GlideRecord('cmdb_rel_ci');
    ciRel.addQuery('child.name', ciService.name);
    ciRel.addEncodedQuery("parent.sys_class_name=service_offering");
    ciRel.query();
    
    while (ciRel.next() && !foundMatch) {
        var getSO = new GlideRecord("sc_cat_item_subscribe_mtom");
        getSO.addQuery("service_offering", ciRel.parent);
        getSO.addEncodedQuery("sc_cat_item.active=true");
        getSO.addEncodedQuery("sc_cat_item.u_cchreferenceto=Incident");
        getSO.query();
        
        while (getSO.next()) {
            if (getSO.sc_cat_item.u_incmaximpact < impact && 
                getSO.sc_cat_item.u_incmaxurgency < urgency) {
                target.impact = impact;
                target.urgency = urgency;
                target.u_subcategory = getSO.sc_cat_item.category;
                target.u_item = getSO.sc_cat_item;
                foundMatch = true;
                break;
            }
        }
    }
}
```

Traversal sequence:

```
dtCSDMApplicationName tag value
  → cmdb_ci_service_auto.name match
     → cmdb_rel_ci (child = service_auto, parent.sys_class_name = service_offering)
        → sc_cat_item_subscribe_mtom (service_offering ↔ sc_cat_item)
           → sc_cat_item (active=true, u_cchreferenceto=Incident)
              → impact/urgency cap check, then sets u_subcategory + u_item
```

**Key properties**:

- The walk anchors on a **name-string match** in `cmdb_ci_service_auto`, not on a Dynatrace entity ID. The Dynatrace tag must carry an Application Service / Service Instance name that *exactly matches* a CMDB record's `name` field.
- **The walk does not write `target.cmdb_ci`**. It uses the matched `cmdb_ci_service_auto` only as an anchor; the CI sys_id is never assigned to the incident.
- The impact/urgency cap check (`u_incmaximpact < impact && u_incmaxurgency < urgency`) means the rule only assigns if its cap is below the `determinePriority` result. Otherwise the values from `calculated` are left as locals (not assigned to target). This is unusual — the typical pattern would be `Math.max` capping; here the rule only fires when the cap is *strictly less than* the calculated.

> **Prior-version correction**: The 17 March 2026 analysis described the Non-OTE path as performing a `sys_object_source` query filtered on `name = "SGO-Dynatrace"`, followed by `CCHIncidentUtils.getAppServiceFromCI()` / `getBSOFromAppService()` / `getDynamicCIGroup()` / `getTSOfromDynamicCI()` calls. **None of that is in the live code as of 2026-06-01**. The actual mechanism is the `dtCSDMApplicationName` tag walk shown above. The CCHIncidentUtils functions may exist (see [`../../../blueprints/incident-management/cchincidentutils-code-reference.md`](../../../blueprints/incident-management/cchincidentutils-code-reference.md)) but are not called from this transform script.

#### Sub-path B — FortiGate / ANF-Atos shortcut

**Entry condition**: `check != '0'` OR `checkAnfAtos != '0'`.

```javascript
var categoryCheck = (check != '0') ? check : checkAnfAtos;

var getCatItem = new GlideRecord("sc_cat_item");
getCatItem.addQuery("sys_id", categoryCheck.toString());
getCatItem.query();

while (getCatItem.next()) {
    target.impact = impact;
    target.urgency = urgency;
    target.u_subcategory = getCatItem.category;
    target.u_item = categoryCheck.toString();
    foundMatch = true;
}
```

If the FortiGate or ANF-Atos category mapping property matched a pattern in the title, this path:

- Loads the matched `sc_cat_item` directly by sys_id (no CMDB lookup at all).
- Sets `target.u_subcategory` (from `sc_cat_item.category`), `target.u_item` (the sys_id), and impact/urgency from `calculated`.

**This is the path that handles all FortiGate alerts** — the 1,631 FortiGate incidents in the dataset come through here. **No CMDB lookup is performed**. The category mapping property (`x_dynat_ruxit.dynatrce.fg.category.mapping`) defines the title-pattern → `sc_cat_item` sys_id mapping; the transform just looks up and applies.

#### Sub-path C — Final fallback

**Entry condition**: nothing matched (`foundMatch === false`).

```javascript
if (!foundMatch) {
    target.impact = impact;
    target.urgency = urgency;
    target.u_subcategory = '106f22a101d842003d4d4e1347805997';
    target.u_item        = '34a001a8fbe87a50bf3ffee64eefdc44';
}
```

Hardcoded sys_ids for `u_subcategory` and `u_item`. Worth resolving the display names of these two sys_ids directly in the instance — they identify where every unrouted DT incident lands.

#### Trailing conditional

```javascript
if (target.u_subcategory == 'c61d566d019842003d4d4e13478059d3' &&
    target.priority >= 1 && target.priority <= 4) {
    target.u_on_site_support = true;
}
```

Flags `u_on_site_support` for one specific `u_subcategory` and priority range. The sys_id `'c61d566d…'` is worth resolving to a display name to understand which subcategory triggers this.

---

## Transform Script — onBefore (Script 2) — FortiGate Location Stamper

A separate, smaller onBefore script. Sets only `target.location`. Does **not** touch `cmdb_ci`, `service_offering`, `u_subcategory`, `u_item`, `impact`, or `urgency`.

```javascript
(function runTransformScript(source, map, log, target) {
    var title = source.problem_title.toString();
    var util  = new x_dynat_ruxit.DynatraceIncidentINTUtil();
    var idx   = util.determineFortigateLocation(title);
    
    if (idx != "") {
        locationCode = idx.substring(0, 2);
        var loc = new GlideRecord("cmn_location");
        loc.addQuery("name", locationCode);
        loc.query();
        while (loc.next()) {
            target.location = loc.sys_id;
        }
    } else {
        target.location = "6a3a0d5237ee35009654261953990ebb";
    }
})(source, map, log, target);
```

Logic:

- Calls `DynatraceIncidentINTUtil.determineFortigateLocation(title)` to extract a FortiGate device name from the title.
- Takes the first 2 characters as a country code, looks up `cmn_location` by name, sets `target.location`.
- Hardcoded fallback `6a3a0d5237ee35009654261953990ebb` if no FortiGate pattern is detected.

**Issues**:

- Default location is a **hardcoded sys_id** — if that record is deleted or moved, all non-FortiGate incidents get a broken location reference.
- Uses `while (loc.next())` instead of `if (loc.next())` — if multiple locations match the 2-char code, the **last one wins** (likely unintentional).

---

## Business Rule — `Populate Dynatrace Affected CIs`

Table: `incident`. Scope: Dynatrace Incident integration application. Verified live 2026-06-01.

```javascript
(function executeRule(current, previous /*null when async*/) {
    var problemstate;
    var val_incident_state = current.state;
    
    if (val_incident_state == 1) {
        problemstate = 'OPEN';
    } else if (val_incident_state == 6 || val_incident_state == 7) {
        problemstate = 'CLOSE';
    }
    
    var gr_dynat_problems = new GlideRecord('x_dynat_ruxit_problems');
    gr_dynat_problems.addQuery('problem_id', current.correlation_id);
    gr_dynat_problems.addQuery('problem_state', problemstate);
    gr_dynat_problems.query();
    
    if (gr_dynat_problems.next()) {
        var ci_impacted = gr_dynat_problems.impacted_cis;
        var ci_seperated = ci_impacted.split(",");
        
        for (var npos = 0; npos < ci_seperated.length; npos++) {
            var arr_ci = ci_seperated[npos];
            
            var sysobjs = new GlideRecord("sys_object_source");
            sysobjs.addQuery("id", arr_ci);
            sysobjs.query();
            
            if (sysobjs.next()) {
                var gr_ci_sys_id = sysobjs.getValue('target_sys_id');
                
                var gr_task_ci = new GlideRecord('task_ci');
                gr_task_ci.addQuery('task', current.sys_id);
                gr_task_ci.addQuery('ci_item', gr_ci_sys_id);
                gr_task_ci.query();
                
                if (gr_task_ci.next()) {
                    // already exists, do nothing
                } else {
                    gr_task_ci.initialize();
                    gr_task_ci.task    = current.sys_id;
                    gr_task_ci.ci_item = gr_ci_sys_id;
                    gr_task_ci.insert();
                }
            }
        }
    }
})(current, previous);
```

Logic:

1. Maps incident `state` to the problem state convention (`1 → OPEN`, `6/7 → CLOSE`).
2. Looks up the matching source row in `x_dynat_ruxit_problems` by `problem_id == current.correlation_id` + `problem_state`.
3. Reads `impacted_cis` (a comma-separated string of Dynatrace entity IDs) and splits it.
4. For each entity ID, queries `sys_object_source WHERE id = <entity_id>` — **`id` only**, no `name` filter, no `target_table` filter.
5. If found, gets the resolved CI sys_id (`target_sys_id`) and inserts a row into `task_ci` (Affected CIs M2M) linking incident → CI, de-duped.

**Key properties**:

- **Writes to `task_ci`, not to `current.cmdb_ci`**. So this rule does not explain the 64 incidents in the dataset that have `cmdb_ci` populated.
- **No `name = "SGO-Dynatrace"` filter** — accepts any `sys_object_source` row that matches the entity ID, regardless of which integration registered it.
- **No `target_table` exclusions** — would happily resolve to a `cmdb_key_value` or `cmdb_ci_ip_address` row if one happened to match.

> **Prior-version correction**: The 17 March 2026 analysis attributed the `sys_object_source` query (with a fictional `name = "SGO-Dynatrace"` filter) to the transform script. The actual location is this business rule, and the actual filter is `id` only. The filters described in the prior analysis are not in the live code.

---

## DynatraceIncidentINTUtil — Script Include (Status as of 2026-06-01)

Plugin-scoped utility class `x_dynat_ruxit.DynatraceIncidentINTUtil`. Four functions known. **As of 2026-06-01, the transform map's Script 1 actively calls three of these** (`determinePriority`, `determineFortigateCategory`, `determineAnfAtosCategory`) and Script 2 calls the fourth (`determineFortigateLocation`). All four functions are *live* — the prior analysis's "3 of 4 are dead code" claim was based on a March 2026 search of business rules only; the transform-script calls are the live use.

> **Prior-version correction**: The 17 March 2026 analysis concluded that `determinePriority()`, `determineFortigateCategory()`, and `determineAnfAtosCategory()` were dead code because no business rule referenced them. The transform-script reading on 2026-06-01 shows all three are called from Script 1's Non-OTE branch. The functions are **live**.

The corresponding system properties (`x_dynat_ruxit.dynatrce.fg.category.mapping`, `x_dynat_ruxit.dynatrce.anf.atos.category.mapping`) are therefore also **live config**, not dead.

The function bodies as documented in the 17 March 2026 analysis (reproduced below) have not been re-verified against the live script-include source on 2026-06-01. **Re-verification of those bodies is outstanding** before deeper claims about their internals are trusted.

### `determinePriority(title)` (per March 2026 reading)

Uses a switch/case with regex matching against the normalized (uppercased, whitespace-collapsed) problem title. Rules are evaluated top-to-bottom; first match wins.

**Fortigate exceptions** (checked first):

| Pattern | Impact | Urgency |
|---|---|---|
| AVAILABILITY + FORTIGATE + P0 | 1 (High) | 1 (High) |
| AVAILABILITY + FORTIGATE + P1 | 1 (High) | 2 (Med) |
| AVAILABILITY + AZURE FORTIGATE + P0 | 1 (High) | 1 (High) |
| RESOURCE_CONTENTION + FORTIGATE + MEMORY USAGE | 2 (Med) | 2 (Med) |
| RESOURCE_CONTENTION + FORTIGATE (any) | 2 (Med) | 2 (Med) |
| ERROR + FORTIGATE HA STATUS | 1 (High) | 2 (Med) |
| ERROR + FORTIGATE STATUS FAILED SYNC | 1 (High) | 2 (Med) |
| ERROR + FORTIGATE UNKNOWN CLUSTER SYNC | 1 (High) | 2 (Med) |
| ERROR + FORTIGATE CRITICAL LINK INTERFACE | 1 (High) | 2 (Med) |

**ATOS exceptions**:

| Pattern | Impact | Urgency |
|---|---|---|
| INFRASTRUCTURE PROBLEM + ATOS + PRIORITY P0 | 1 (High) | 1 (High) |
| INFRASTRUCTURE PROBLEM + ATOS + PRIORITY P1 | 2 (Med) | 1 (High) |
| INFRASTRUCTURE PROBLEM + ATOS + PRIORITY P2 | 2 (Med) | 2 (Med) |

**Generic rules**:

| Severity | Impact Type | Impact | Urgency |
|---|---|---|---|
| AVAILABILITY | INFRASTRUCTURE | 1 | 2 |
| AVAILABILITY | SERVICE / APPLICATION | 3 | 2 |
| ERROR | INFRASTRUCTURE | 3 | 2 |
| ERROR | SERVICE / APPLICATION | 2 | 2 |
| PERFORMANCE | INFRASTRUCTURE | 4 | 3 |
| PERFORMANCE | SERVICE / APPLICATION | 3 | 2 |
| RESOURCE_CONTENTION | INFRASTRUCTURE | 3 | 2 |
| RESOURCE_CONTENTION | SERVICE / APPLICATION | 4 | 3 |

**Default**: `{ impact: "0", urgency: "0" }` — both undefined if nothing matches.

### `determineFortigateCategory(eventTitle)` (per March 2026 reading)

Consumes `x_dynat_ruxit.dynatrce.fg.category.mapping` system property. Normalizes title (uppercase, collapse whitespace), iterates mapping rules, tests each regex (case-insensitive), returns the matching `category` sys_id. Returns `'0'` if no match.

### `determineAnfAtosCategory(eventTitle)` (per March 2026 reading)

Consumes `x_dynat_ruxit.dynatrce.anf.atos.category.mapping` system property. Same shape as Fortigate. Returns `'0'` if no match.

### `determineFortigateLocation(title)` (per March 2026 reading)

Extracts FortiGate device name from problem title using two regex patterns:

1. **Primary** (availability): `P-\d+\s*-\s*AVAILABILITY problem on INFRASTRUCTURE:\s*FortiGate\s+([A-Za-z0-9]+)\s+is\s+DOWN\s+P\d`
2. **Secondary** (error): `ERROR problem on INFRASTRUCTURE:\s*FortiGate\s+Critical Link Interface Status is Down on\s+([A-Za-z0-9]+)`

Returns the captured device name (e.g. `"BGFG01"`), or empty string. Caller (Script 2) takes the first 2 characters as the location code.

---

## Category Mapping Properties (exported 2026-03-18 — still live as of 2026-06-01)

### `x_dynat_ruxit.dynatrce.fg.category.mapping`

Note the typo in the property name (`dynatrce`, missing 'a').

Applies to **FortiGate** alerts. Used by `determineFortigateCategory`, which is called by Script 1's Non-OTE branch. **10 rules mapping to 2 distinct categories**:

| # | Alert Type | Category sys_id |
|--:|---|---|
| 1 | FortiGate `<name>` is DOWN (P0) | `fe158879...` |
| 2 | FortiGate `<name>` is DOWN (P1) | `fe158879...` |
| 3 | Azure FortiGate `<name>` is DOWN (P0) | `271909eb...` |
| 4 | FortiGate Memory Usage > 82/88/95% | `271909eb...` |
| 5 | FortiGate CPU Usage > 70% | `271909eb...` |
| 6 | FortiGate HA Status is Down | `271909eb...` |
| 7 | FortiGate HA Status is Unknown | `271909eb...` |
| 8 | FortiGate Status Failed sync Cluster | `271909eb...` |
| 9 | FortiGate Unknown Cluster Sync Status | `271909eb...` |
| 10 | FortiGate Critical Link Interface | `fe158879...` |

The two categories appear to split **physical FortiGate DOWN + link issues** (`fe158879...`) from **Azure / resource / HA / cluster issues** (`271909eb...`). Each is an `sc_cat_item` sys_id consumed by Script 1's FortiGate-shortcut path.

### `x_dynat_ruxit.dynatrce.anf.atos.category.mapping`

Note the typo in the property name (`dynatrce`, missing 'a').

Applies to **ATOS infrastructure** alerts. Used by `determineAnfAtosCategory`. **3 rules**, all mapping to the same category and assignment group:

| # | Regex Pattern | Category sys_id | Assignment Group sys_id |
|--:|---|---|---|
| 1 | `.*INFRASTRUCTURE\s+PROBLEM.*PRIORITY\s+P0.*ATOS` | `8098ad3a2b4db6902450ff61de91bfe0` | `8d39119437b7f1009654261953990ec9` |
| 2 | `.*INFRASTRUCTURE\s+PROBLEM.*PRIORITY\s+P1.*ATOS` | (same) | (same) |
| 3 | `.*INFRASTRUCTURE\s+PROBLEM.*PRIORITY\s+P2.*ATOS` | (same) | (same) |

All three rules collapse to the same category and assignment group regardless of priority. The `assignment_group` field exists in the JSON but **the function `determineAnfAtosCategory` only returns `category`** per the March 2026 reading — re-verify against live code if the assignment-group value matters.

---

## System Properties — Complete List

| Property | Used In | Purpose |
|---|---|---|
| `x_dynat_ruxit.dynatrace.ote.config` | Script 1 OTE branch | JSON routing rules for OTE alerts |
| `x_dynat_ruxit.autoresolveproblems` | Field Map #5 (`state`) | Controls whether CLOSE events resolve incidents |
| `x_dynat_ruxit.dynatrce.fg.category.mapping` | `DynatraceIncidentINTUtil.determineFortigateCategory()` (called by Script 1) | FortiGate title → category sys_id mapping |
| `x_dynat_ruxit.dynatrce.anf.atos.category.mapping` | `DynatraceIncidentINTUtil.determineAnfAtosCategory()` (called by Script 1) | ATOS title → category sys_id mapping (assignment_group field unused) |
| `x_dynat_ruxit.logging.verbosity` | Plugin logging | Logging level |

> **Prior-version correction**: The 17 March 2026 analysis flagged the `*.category.mapping` properties as "dead config" because the helper functions appeared unreferenced. They are not dead — Script 1's Non-OTE branch invokes them on every Non-OTE alert.

Properties **not present in the live transform map** (despite being in the March 2026 analysis):

- `cch.business.offering.relation.to.application.service` — was claimed to be used by `CCHIncidentUtils`. The transform map does not call `CCHIncidentUtils`, so this is unused at least from this code path.
- `cch.it.offering.relation.to.application.service` — same.
- `cch.business_criticality.to.urgency.mapping` — same. The "inline urgency mapping from business_criticality" claim in the prior analysis (with the Med-vs-High discrepancy table) is not present in the live transform code — `urgency` comes from `util.determinePriority(title)`, not from a criticality mapping.

---

## Key Findings (refreshed 2026-06-01)

| # | Finding | Status |
|--:|---|---|
| 1 | **The transform map writes to neither `cmdb_ci` nor `service_offering`.** Field map for `cmdb_ci` is dead (returns ""), no field map for `service_offering`, neither transform script touches either field. | **Verified 2026-06-01** |
| 2 | **The `sys_object_source` query lives in the `Populate Dynatrace Affected CIs` business rule** — not in the transform map. It uses `id` only (no `name`, no `target_table` filters) and writes to `task_ci` (Affected CIs M2M), not to `current.cmdb_ci`. | **Verified 2026-06-01** |
| 3 | **The OTE branch sets `impact`, `urgency`, `u_subcategory`, `u_item`** — not `service_offering` or `u_technical_service_offering`. The prior analysis's "cross-fallback BSO/TSO" description was inaccurate. | **Verified 2026-06-01** |
| 4 | **The Non-OTE CSDM walk anchors on `cmdb_ci_service_auto.name = dtCSDMApplicationName tag value`**, then walks `cmdb_rel_ci` → `service_offering` → `sc_cat_item_subscribe_mtom` → `sc_cat_item`. Sets `u_subcategory` and `u_item` only. | **Verified 2026-06-01** |
| 5 | **FortiGate alerts are routed by title pattern → category sys_id**, not by CMDB lookup. They take the Sub-path B shortcut in Script 1; CMDB is not consulted. | **Verified 2026-06-01** |
| 6 | **Both `DynatraceIncidentINTUtil.determineFortigateCategory` and `determineAnfAtosCategory` are live**, called by Script 1's Non-OTE branch. The associated `*.category.mapping` properties are live config. | **Verified 2026-06-01** (the function bodies themselves not re-verified) |
| 7 | **Final fallback in Non-OTE branch is a hardcoded `u_subcategory` + `u_item` pair**: `'106f22a101d842003d4d4e1347805997'` / `'34a001a8fbe87a50bf3ffee64eefdc44'`. Display names not yet resolved. | **Verified 2026-06-01** |
| 8 | **Work notes actively mask resolution** — regex rewrites "RESOLVED Problem" → "UPDATE Problem" on CLOSE events. | Per March 2026 reading; field-map content not re-verified today but no reason to doubt. |
| 9 | **Auto-resolve is property-controlled** — `x_dynat_ruxit.autoresolveproblems` must be `true` for CLOSE events to resolve. | Per March 2026 reading. |
| 10 | **No onAfter script** — all transform logic runs in onBefore. Anything that derives further (like `service_offering` from `u_item`) must be downstream of the transform — a business rule on the incident table. | **Verified 2026-06-01** |
| 11 | **Default location is a hardcoded sys_id** (`6a3a0d5237ee35009654261953990ebb`) — fragile reference. | Per March 2026 reading; Script 2 still uses it. |

---

## Open Items (still outstanding after 2026-06-01)

1. **Find the business rule(s) on `incident` that write to `current.cmdb_ci`** — explains the 64 populated values in the 2026-05-28 dataset.
2. **Find the business rule(s) on `incident` that write to `current.service_offering`** — explains the 99.2 % populated values; likely derives `service_offering` from `u_item` via reverse lookup on `sc_cat_item_subscribe_mtom`.
3. **Fresh export of `x_dynat_ruxit.dynatrace.ote.config`** — reconcile whether the JSON now contains `subcategory` / `item` keys (matching the code) instead of / in addition to `service_offering` / `tso` (per the March 2026 export).
4. **Re-verify `DynatraceIncidentINTUtil` function bodies** against the live script include, especially `determinePriority` (the Fortigate/ATOS/generic rules tables).
5. **Resolve the hardcoded fallback sys_ids** to display names:
   - `u_subcategory = '106f22a101d842003d4d4e1347805997'`
   - `u_item = '34a001a8fbe87a50bf3ffee64eefdc44'`
   - `u_subcategory == 'c61d566d019842003d4d4e13478059d3'` (trigger for `u_on_site_support`)
   - Default `location = '6a3a0d5237ee35009654261953990ebb'`
6. **Verify whether `CCHIncidentUtils` functions** (`getAppServiceFromCI`, `getBSOFromAppService`, `getDynamicCIGroup`, `getTSOfromDynamicCI`) are still defined in the script include. If yes, they are not called by *this* transform code; they may still be referenced from a business rule or another script include.

---

*Original: 17 March 2026. Substantive rewrite: 1 June 2026 (live-code verification). Prior version content preserved where re-verified or where it pre-dates today's investigation — corrections inline.*
