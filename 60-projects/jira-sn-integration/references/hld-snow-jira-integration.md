# High Level Design Document — SNOW ITSM ↔ Jira Integration

> **Transcription note**: faithful transcription of the HLD pasted by the author. Word artifacts (text boxes, ActiveX control, empty TOC) removed; tables, headings, and bullet lists normalized to Markdown. Wording and values are unchanged from the source. Diagrams referenced in the source were images and are not reproduced — marked as placeholders.

## Document Control

### Document Status

| Attribute | Detail |
|---|---|
| Document Name | High Level Design Document for SNOW ITSM – JIRA Integration |
| Author | Ahmed Badr |
| Status | In Review |
| Date | June 1, 2026 |

### Change Log

| Version | Date | Author | Details |
|---|---|---|---|
| 0.1 | May 2026 | Ahmed Badr | Initial draft. |
| 1.0 | June 2026 | Ahmed Badr | Added fully implemented bi-directional synchronization, dynamic status transition logic, attachment handling, and implement architecture team feedback. |
| 1.1 | | | |

---

## Glossary

| Term | Definition |
|---|---|
| ITSM | Information Technology Service Management. |
| RITM | Requested Item: a specific record type in ServiceNow representing a user's service catalog request. |
| IntegrationHub | A ServiceNow platform feature used to automate third-party integrations within Flow Designer. |
| Spoke | A scoped application containing pre-built Flow Designer actions to integrate with a specific external system (e.g., the Jira Spoke). |
| Webhook | An automated, real-time HTTP callback triggered by specific events in a system (used in this architecture for Jira-to-ServiceNow updates). |
| Correlation ID | A reference field in ServiceNow used to store the unique Jira Issue Key to maintain a persistent, bi-directional link between the two systems. |

---

## Introduction

This High-Level Design (HLD) document describes the architecture and technical design for the integration between ServiceNow ITSM and Jira, utilizing ServiceNow IntegrationHub and the Jira Spoke. The objective of the integration is to enable seamless, automated collaboration between IT Service Management processes in ServiceNow and development or engineering workflows managed in Jira. The integration focuses on the bi-directional automatic creation, synchronization (including fields, comments, and attachments), and lifecycle management of records across both platforms, connecting ServiceNow Incidents and Service Requests (RITMs) with their corresponding Jira issues. Field mappings, routing logic, and updating rules are centrally defined and maintained to ensure consistency, traceability, and auditability across both platforms. Detailed field-level mappings are maintained externally in the Jira-SNOW Integration Data Dictionary (JIRA DOCUMENTS) which is owned, managed, and updated by the XTEL Jira Team.

---

## Scope

### In scope

- Integration between ServiceNow (Incidents and Service Requests / RITMs) and Jira projects.
- Bi-directional creation of records (ServiceNow to Jira, and Jira to ServiceNow).
- Full bi-directional synchronization of explicitly mapped fields, comments, and attachments.
- Bi-directional reference handling: storing the Jira Issue Key in the ServiceNow `correlation_id` field, and storing the ServiceNow record Number in the Jira custom field External Issue ID (`customfield_10061`).
- Configuration using IntegrationHub Jira Spoke (avoiding custom REST code where possible).
- Centralized routing and mapping logic using Flow Designer.
- Secure communication using HTTPS and authenticated connections.

### Out of scope

- Parent Service Request records (`sc_request` / REQ) and Catalog Tasks (`sc_task`). The integration triggers at the Requested Item (`sc_req_item` / RITM) level.
- Synchronization of all fields. Only explicitly mapped fields are synchronized.
- Synchronization or backfill of any historical or existing open tickets created prior to the integration go-live date. The integration applies only to new records and their subsequent updates.
- Any form of SLA or time-tracking data synchronization. ServiceNow SLAs will natively pause/resume based on standard State changes triggered by Jira, but no SLA metrics or timers are passed between systems.
- Custom Jira plugins beyond standard REST and webhook capabilities.

---

## Current State

Currently, ServiceNow and Jira operate as isolated systems with limited or manual coordination between ITSM and development teams. Incidents or Service Requests that require engineering support are typically transferred manually via email, chat, or ad-hoc Jira issue creation.

**Transaction volume and load:**

- **Expected Monthly Volume**: the integration is expected to process approximately 18,000 to 20,000 Incidents/Requested Items per month.
- **Average Daily Volume**: this volume translates to an estimated average of 600 to 900 tickets processed per day.
- **System Capacity**: the integration utilizes ServiceNow IntegrationHub and asynchronous Jira Webhooks, which are designed to queue and process this volume efficiently without degrading core platform performance or exceeding standard API rate limits.

**Key limitations of the current state:**

- Manual creation of Jira issues leading to inconsistent data.
- Lack of automated status or field synchronization.
- Limited traceability between ServiceNow tickets and Jira issues.
- Increased operational overhead and risk of information loss.

---

## Future State

In the future state, ServiceNow will act as the system of engagement for ITSM processes, while Jira will remain the system of record for development and engineering execution.

### Data Ownership & Conflict Resolution

To define the implications of this architectural decision, data ownership is delineated as follows. In the event of a field conflict or simultaneous bi-directional update:

- **Jira "Wins" (Execution)**: Jira acts as the source of truth for all engineering and execution-related fields. In a conflict, Jira's data will overwrite ServiceNow for fields like Status/State, Components, Environment, and resolution details. Jira dictates the progress of the work.
- **ServiceNow "Wins" (ITSM)**: ServiceNow acts as the source of truth for ITSM related attributes. In a conflict, ServiceNow will overwrite Jira for fields like Caller/Requested For, initial Urgency, and customer-facing service requests.
- **Latest Timestamp Wins**: for shared, bi-directionally updated free-text fields (such as the Summary), the system with the most recent transaction timestamp will take precedence.

### Key improvements

- Bi-directional, automatic creation of linked records between ServiceNow (Task) and Jira.
- Consistent, mapping-driven synchronization of key fields, user comments, and file attachments.
- Link via the Jira Issue Key stored on ServiceNow records.
- Active bi-directional integration utilizing Jira webhooks and ServiceNow Flow Designer to automatically synchronize record lifecycle events between both platforms.
- Implementation of a sync-loop safeguard to prevent infinite synchronization loops between the two systems.

---

## Solution Design

The solution is implemented using ServiceNow IntegrationHub with the Jira Spoke. Flow Designer orchestrates the integration logic, evaluates routing conditions, and executes create or update actions against Jira.

**Key design principles:**

- **Configuration over customization**: utilizing out-of-the-box IntegrationHub Spoke actions rather than custom scripted REST messages wherever possible.
- **Mapping-driven logic externalized from flows**: the business logic for field and status mappings is defined externally (owned by the XTEL team in the Data Dictionary JIRA DOCUMENTS). Technically, this is implemented in ServiceNow using Flow Designer and variables (e.g., dynamic Status Transition ID calculation scripts), ensuring the core process flow does not rely on hardcoded static values.
- **Idempotent updates**: utilizing the stored Jira Issue Key (`correlation_id`) to ensure duplicate records are not created upon subsequent updates.
- **Clear separation between trigger, routing, and execution logic**: the architecture modularizes the integration into distinct operational layers:
  - **Trigger**: initiated by native ServiceNow Record Actions (e.g., Task created/updated) or inbound Jira Webhooks.
  - **Routing**: evaluated via Flow Designer condition branches (e.g., checking the `correlation_id` to determine Create vs. Update).
  - **Execution**: processed via dedicated IntegrationHub Jira Spoke actions (for outbound payloads) and ServiceNow task update actions (for inbound payloads).
- **Sync-loop safeguard**: logic implemented to prevent infinite automated update loops between ServiceNow and Jira.

<!-- Diagram: Architectural Overview — not included in pasted source -->
<!-- Diagram: Sequence Diagram — not included in pasted source -->

### Work Type Mapping

| Jira Work Type | Value | ServiceNow Table | Value |
|---|---|---|---|
| Service Request | 1766 | RITM | `sc_req_item` |
| Incident | 10007 | Incident | `incident` |
| Guidance and Training | 10009 | Incident | `incident` |

### Static Status Mapping Values

| Jira Status | ServiceNow State (INC) | ServiceNow State (SR) | ServiceNow Value |
|---|---|---|---|
| Open | Open | Open | 1 |
| Support At Work | Work in Progress | Work in Progress | 2 |
| Awaiting Customer Action | On Hold | Info Waiting | 3 |
| Resolved | Resolved | Pending Closure | 6 |
| Closed | Closed | Closed | 7 |

### Dynamic Status Mapping

| ServiceNow old State | ServiceNow new State | Jira Transition |
|---|---|---|
| Open (1) | Work in Progress (2) | Initial Response |
| Open (1) | On Hold (3) | Assign to customer |
| Open (1) | Resolved (6) | Solve Issue (fast close) |
| Open (1) | Closed (7) | Close Issue |
| Work in Progress (2) | On Hold (3) | Assign to customer |
| Work in Progress (2) | Resolved (6) | Solve Issue |
| Work in Progress (2) | Closed (7) | Close Issue |
| On Hold (3) | Work in Progress (2) | Respond to XTEL |
| On Hold (3) | Resolved (6) | Solve Issue |
| Resolved (6) | Closed (7) | Close Issue |
| Resolved (6) | Open (1) | Re-open Issue |
| Closed (7) | Open (1) | Re-open by admin |

### Jira Field Values

| JIRA Field Name | SNOW Field Name | Field Code | Value Name | Value Code | Mandatory |
|---|---|---|---|---|---|
| summary | short_description | summary | | Free Text | Yes |
| priority | priority | priority | | 10004 | Yes |
| priority | priority | priority | Critical | 10005 | Yes |
| priority | priority | priority | High | 2 | Yes |
| priority | priority | priority | Normal | 10001 | Yes |
| priority | priority | priority | Low | 4 | Yes |
| description | description | description | | Free Text | Yes |
| Division | N/A | 10135 | DIV1 | 12631 | Yes |
| Division | N/A | 10135 | DIV2 | 12632 | Yes |
| Components | N/A | components | Analytics | 12049 | Yes |
| Components | N/A | components | Data integration | 12050 | Yes |
| Components | N/A | components | Framework | 12051 | Yes |
| Components | N/A | components | Infrastructure | 12053 | Yes |
| Components | N/A | components | Jira | 12054 | Yes |
| Components | N/A | components | Jobs & Batches | 12055 | Yes |
| Components | N/A | components | Performance | 12057 | Yes |
| Components | N/A | components | PromoPlan | 12058 | Yes |
| Components | N/A | components | PUD | 12059 | Yes |
| Components | N/A | components | Reporting | 12060 | Yes |
| Components | N/A | components | TPM | 12062 | Yes |
| Environment | N/A | 10077 | DEV | 10115 | Yes |
| Environment | N/A | 10077 | DTM | 10116 | Yes |
| Environment | N/A | 10077 | TST | 10117 | Yes |
| Environment | N/A | 10077 | UAT | 10118 | Yes |
| Environment | N/A | 10077 | HFX | 10119 | Yes |
| Environment | N/A | 10077 | PROD | 10120 | Yes |
| Environment | N/A | 10077 | Other | 10121 | Yes |
| Hypercare | N/A | 10325 | YES | 11109 | Yes |

### Jira–ServiceNow Field Mapping

| ServiceNow Field | Jira Field | Description |
|---|---|---|
| Short Description | Summary | Bi-directional |
| Description | Description | Bi-directional |
| Correlation ID | Issue ID/Key | Uni-directional (Jira to SNOW) |
| Priority | Priority | Bi-directional |

### Priority Mapping

| ServiceNow Value | Jira Value |
|---|---|
| 1 | Critical |
| 2 | High |
| 3 | Normal |
| 4 | Low |
| Any other Value | Normal |

### Service Account & Authentication

- **Service Account & Authentication Method**: the integration authenticates using a dedicated service account: `cchservicenow@xtelcloud.com`. Authentication from ServiceNow to Jira is achieved using a secure API token provided directly by the XTEL Jira team.
- **Vault Location**: the token is securely stored within the native ServiceNow Credentials module. It is bound to the Jira Spoke via a Connection & Credential Alias. Tokens are encrypted at rest and are never hardcoded within Flow Designer logic, scripts, or business rules.
- **Rotation Policy**: token lifecycle and generation are managed by the XTEL team. In the event of a required rotation or expiration, the XTEL team will issue a new token, which the ServiceNow ITSM Platform Team will update directly within the existing ServiceNow Credential record, requiring no code or flow changes.

---

## Requirements

### Functional Requirements

- Automatically create ServiceNow tasks from Jira issues, and vice versa.
- Update existing Jira issues when mapped fields or states change in ServiceNow.
- Update ServiceNow records when mapped fields or states are modified in Jira.
- Synchronize comments and file attachments bi-directionally between both systems.
- Store the Jira Issue Key (`correlation_id`) in ServiceNow for persistent linkage.
- Implement mandatory field data validation to ensure all required information is populated and correctly formatted before creating or updating records in either system.
- **Conflict Resolution**: Jira owns execution fields (e.g., State); ServiceNow owns ITSM fields. The latest timestamp wins for shared text updates.
- **Mandatory Field Validation**: outbound flows validate required fields (Priority, Division, Components, Environment, Hypercare) before sending. Missing data aborts.

### Non-Functional Requirements

- Secure, authenticated communication over HTTPS.
- Error handling and logging.
- Scalability to support multiple divisions, teams, and projects.
- System safeguards to prevent infinite automated synchronization loops between platforms.
- Compliance with ServiceNow IntegrationHub and Jira API best practices.
- **Volume & Throughput**: designed for 18k–20k tickets/month (approx. 40–60 bi-directional transactions/hour).

---

## Implementation

### ServiceNow Implementation Steps

1. Install and activate IntegrationHub and the Jira Spoke.
2. Configure Jira Connection and Credential Alias.
3. Define OAuth or API token-based authentication.
4. Build Flow Designer flows for task triggers.
5. Implement routing logic, field mappings, and configuration of transition ID mapping logic.
6. Build Flow Designer flows triggered by Jira webhooks to automatically process inbound updates (fields, comments, state transitions, and attachments) to ServiceNow tasks.
7. Configure error handling and logging.

- **Authentication Mechanism**: the integration strictly utilizes API token-based authentication, leveraging the secure token provided by the XTEL team (OAuth is not used).
- **Webhook Target Endpoint**: Jira webhooks are directed to the native ServiceNow Flow Designer Webhook trigger URL.

### Jira Implementation Steps

1. Configure Jira projects and issue types.
2. Grant API access to the ServiceNow integration user.
3. Validate field mappings via REST API.
4. Configure Jira webhooks to securely send issue events (creation, updates, comments, state transitions, and attachments) to ServiceNow endpoints.

---

## Planning and Risk Management

*NA (not populated in source document).*

---

## Appendix

### Plugins

- IntegrationHub
- Jira Spoke

### Diagrams

*(Referenced in source as images — not reproduced in this transcription.)*
