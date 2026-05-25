# OneTrust ↔ CSDM - Background Analysis

**Date**: 2026-03-19 (analysis); refreshed for sub-project on 2026-05-05
**Status**: Background reference - investigation that led to the [HLD](../blueprints/hld-onetrust-csdm-integration-ootb.md)
**Purpose**: Documents two things the team needs context on but that don't belong in the design document:

1. **Why "Data Confidentiality OOTB field" doesn't exist** - debunks a recurring assumption from stakeholder discussions and explains the three different ServiceNow data-classification concepts that get confused
2. **Validation checklist** - concrete checks to run against the OneTrust tenant and ServiceNow CMDB before integration design decisions are finalised

The architecture (two-master model, sync mechanisms, integration parts) lives in the [HLD](../blueprints/hld-onetrust-csdm-integration-ootb.md) - not duplicated here.

---

## Context: OneTrust is the Privacy Product

The "Privacy Product" referenced in stakeholder discussions is **OneTrust** - specifically the **Data Mapping Automation** module (part of OneTrust Privacy Operations). OneTrust is licensed at CCH. The **"OneTrust for ServiceNow" connector** is **not currently installed**, despite the OneTrust license being in place.

OneTrust maintains its own relational privacy inventory:

```
Entity (legal entity / BU)
    └── Processing Activity (business process)
            └── Asset (application / system)
                    └── Data Element (personal data type, e.g. "SSN", "email")
                            ├── Data Subject Type (customers, employees)
                            └── Data Classification (Confidential, Restricted)
                    └── Vendor (third-party processor)
```

This model generates the GDPR Art 30 RoPA by traversing: Entity → Processing Activity → Assets → Data Elements → Vendors → Transfer destinations.

---

## The Wrong Assumption: "Data Confidentiality OOTB Field"

The stakeholder presentation referenced a "Data Confidentiality OOTB field" on `cmdb_ci_business_app` that could be enabled during PI18. **This field does not exist.**

The confusion likely arose from mixing up three different ServiceNow concepts:

### 1. Information Object Table - `cmdb_ci_information_object` (the correct OOTB mechanism)

Available since the **New York** release. Each record represents a **type of data** (e.g. "Social Security Number", "Credit Card Data", "Health Records").

**Key field**: `data_classification` - choice-list with values: Public, Internal, Confidential, Restricted, Highly Sensitive.

**CSDM domain**: Design (CSDM v5, Domain 3 - Design & Planning). This is a **Fly-stage** maturity capability.

The connection to Business Applications is a **CMDB relationship**, not a field:

```
cmdb_ci_business_app  ──"Uses"──→  cmdb_ci_information_object
        (parent)                          (child)
                                    ├── name: "Customer PII"
                                    ├── data_classification: Confidential
                                    └── category: PII
```

Relationship stored in `cmdb_rel_ci` with type "Uses::Used by".

**Query pattern** - "Which Business Applications process personal data?":

Two-step approach. Avoids the `IN`-with-dot-walked-value pitfall on `cmdb_rel_ci` and is cheaper at scale (one filtered scan of the IO table, then a sys_id-list filter on the relationships table — no JOINs forced by dot-walked filters).

```javascript
// Step 1 — find Information Objects with sensitive classification.
// NOTE: 'confidential' / 'restricted' / 'highly_sensitive' are placeholder
// stored values — verify the actual choice values on the instance with:
//   new GlideRecord('cmdb_ci_information_object')
//     .getElement('data_classification').getChoices();
var ioSysIds = [];
var io = new GlideRecord('cmdb_ci_information_object');
io.addQuery('data_classification', 'IN', 'confidential,restricted,highly_sensitive');
io.query();
while (io.next()) {
    ioSysIds.push(io.getUniqueValue());
}

if (ioSysIds.length === 0) {
    gs.print('No sensitive Information Objects found — table is empty in CCH (confirmed).');
    return;
}

// Step 2 — find "Uses" relationships pointing to those Information Objects.
// NOTE: 'Uses::Used by' is the conventional cmdb_rel_type.name format
// (parent_descriptor::child_descriptor). Verify the exact value on the
// instance — punctuation/case must match.
//
// Optional: restrict parent class to Business Application by uncommenting
// the parent.sys_class_name filter below.
var rel = new GlideRecord('cmdb_rel_ci');
rel.addQuery('type.name', 'Uses::Used by');
rel.addQuery('child', 'IN', ioSysIds.join(','));
// rel.addQuery('parent.sys_class_name', 'cmdb_ci_business_app');  // optional
rel.query();

while (rel.next()) {
    gs.print(
        rel.parent.getDisplayValue('name')
        + ' (' + rel.parent.getDisplayValue('sys_class_name') + ')'
        + ' → ' + rel.child.getDisplayValue('name')
        + ' (' + rel.child.getDisplayValue('data_classification') + ')'
    );
}
```

**Caveats this query surfaces** (and why it returns zero rows at CCH today):
- `cmdb_ci_information_object` is Fly-stage maturity in CSDM and is **confirmed empty** in the CCH instance (verified by the integration team). Step 1 returns an empty list and the script exits early. That's the diagnostic signal: the OOTB mechanism exists but isn't usable in current state, which is exactly why OneTrust takes that role.
- The choice values for `data_classification` are not guaranteed to match the labels — verify with the `.getChoices()` snippet above before running for real.
- `cmdb_rel_ci` can be very large; even with the sys_id-list filter, do not embed this script in a real-time UI flow without a `setLimit()` cap.

### 2. Platform-Level Data Classification (NOT what we need)

- **Navigation**: System Security > Data Classification > Data Classes
- **Purpose**: Classifies ServiceNow's own dictionary entries (columns on tables) by sensitivity - e.g. marking `sys_user.email` as PII
- **OOTB hierarchy**: Restricted > Confidential > PII > Internal > Public

**This is NOT for classifying business applications.** It governs ServiceNow's own data model.

### 3. GRC Privacy Management (Licensed Add-On)

- **Navigation**: GRC > Privacy Management
- **Purpose**: Data protection assessments, GDPR compliance, RTBF requests
- **Note**: Licensed add-on, not base platform
- **Decision**: OneTrust is the platform of authority for privacy at CCH (architectural decision, not subject to change in this scope)

---

## Why Information Objects (Option A) IS the recommended approach

When OneTrust pushes classification back to ServiceNow, two options for where it lands:

| Option | Target in ServiceNow | Effort | OOTB? | Notes |
|---|---|---|:---:|---|
| **A (chosen)** | Populate `cmdb_ci_information_object` + `Uses ↔ Used by` relationships in `cmdb_rel_ci` | Medium | ✅ | OOTB tables and OOTB relationship type. Creates IO records and CMDB relationships via REST. Fly-stage maturity; table currently empty at CCH. |
| B (rejected) | Custom field on `cmdb_ci_business_app` (e.g. `u_data_classification`) | Low | ❌ | Single field update per app. Simple API call but creates forever-maintained custom schema. |

**Recommendation: Option A (Information Objects).** Reasoning:

- **No schema commitment.** A custom field on `cmdb_ci_business_app` would persist across every future ServiceNow upgrade, every Store-app installation, every CSDM model migration. An Information Object record is *data*, not *schema*; it lives within OOTB tables.
- **Many-to-many natural.** One app can use multiple data types (PII + Financial + Health); one data type can be used by many apps. A custom field models this awkwardly (delimited list or repeated rows); a CMDB relationship models it natively.
- **Reusable across consumers.** Once classification lives in IOs, any future tool that needs to know "which apps process PII" reads from one OOTB pattern — not from a OneTrust-specific custom field that other tools wouldn't know to query.
- **CSDM-canonical.** Information Objects are the documented CSDM v5 mechanism for data classification (Domain 3 — Design & Planning). Future CMDB-Health and Discovery-Health dashboards already understand the pattern.
- **The empty IO table at CCH is the starting condition, not a blocker.** The OneTrust integration *is* what populates Information Objects — every classification OneTrust pushes back creates / updates an IO record and a relationship. CCH's CMDB matures to Fly-stage for data classification as a side-effect of the integration, not as a separate project.

This is captured in the HLD as Open Decision #3 — **resolved to Option A**.

---

## Validation Checklist

Concrete checks to run before integration design decisions are finalised. Owner: integration team in coordination with OneTrust admin and CSDM team.

### Immediate (before any design decisions)

- [ ] **V-1**: Confirm OneTrust license scope - is the "OneTrust for ServiceNow" connector module available in the OneTrust tenant?
- [ ] **V-2**: Check with OneTrust admin - is the ServiceNow Asset Discovery Wizard accessible? Has it ever been configured?
- [x] **V-3**: Query `cmdb_ci_information_object.list` in ServiceNow - does the table have any records? **Answered: no — the table is empty in the CCH instance (confirmed).**
- [x] **V-4**: Query `cmdb_rel_ci` where `child.sys_class_name = cmdb_ci_information_object` - do any "Uses" relationships exist? **Answered by V-3: with no IO records, no "Uses" relationships can target them.**
- [ ] **V-5**: Check if GRC Privacy Management plugin is installed - `sys_plugins.list`
- [ ] **V-6**: Confirm what the OneTrust connector writes back to ServiceNow natively (which tables, which fields)

### If connector is available

- [ ] **V-7**: Configure Asset Discovery Wizard with ServiceNow API credentials (service account, read access to `cmdb_ci_business_app`)
- [ ] **V-8**: Run a test pull - verify CSDM Business Applications appear as OneTrust Assets
- [ ] **V-9**: Test bidirectional sync - classify a test asset in OneTrust, verify classification appears in ServiceNow
- [ ] **V-10**: Verify the 19-field data model from the [mapping spec](../blueprints/asset-attribute-mapping-spec.md) maps correctly through the connector

### If connector is NOT available (fallback)

- [ ] **V-11**: Assess OneTrust REST API capabilities - can Assets be created/updated programmatically?
- [ ] **V-12**: Design custom sync using ServiceNow Business Rule (on `cmdb_ci_business_app` insert/update) → OneTrust REST API
- [ ] **V-13**: Design reverse sync using OneTrust webhook/API → ServiceNow REST API to create / update `cmdb_ci_information_object` records and `cmdb_rel_ci` "Uses ↔ Used by" relationships (Option A — OOTB pattern, no custom field)

---

## References

- [HLD - OneTrust ↔ CSDM Integration (OOTB, Option A)](../blueprints/hld-onetrust-csdm-integration-ootb.md) - the design that this analysis informed
- [Asset Attribute Mapping Spec](../blueprints/asset-attribute-mapping-spec.md) - field-level spec
- ServiceNow KB0831514 - Information Objects with Business Application Relationship
- ServiceNow KB0831515 - Business Applications with Information Object Relationship
- ServiceNow Community - [Data Classification Fields in CMDB](https://www.servicenow.com/community/cmdb-forum/data-classification-fields-in-cmdb/m-p/2715799)
- ServiceNow Docs (Utah) - [Data Classification](https://docs.servicenow.com/en-US/bundle/utah-platform-security/page/administer/security/concept/data-classification.html) (platform-level, not CMDB)
- [OneTrust ServiceNow Integration](https://www.onetrust.com/integrations/servicenow/)
- [OneTrust Data Mapping Automation](https://www.onetrust.com/products/data-mapping-automation/)
- [OneTrust Developer Portal](https://developer.onetrust.com/)
- GDPR Article 30 - Records of Processing Activities
