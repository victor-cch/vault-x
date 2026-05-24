# Build & Integration

**CSDM v5 domain — Build & Integration** *(was: "Build" in CSDM v3/v4)*

Visibility into the **build effort** of digital products — DevOps pipelines, source repositories, software components, AI digital assets. Records here are NOT direct targets of ITSM processes; they reference development details that downstream Service Delivery consumes.

CSDM 5 places greater emphasis on **integration** here, recognising that most digital products rely on internal or third-party services to deliver business capabilities.

## Build & Integration entities

| Entity | Table | Purpose |
|---|---|---|
| DevOps Change Data Model | (`sn_devops_change_*`) | DevOps Change Velocity data model; from ServiceNow Store |
| SDLC Component | `cmdb_ci_sdlc_component` | A unique development effort of code; parts of a Business Application broken into individual components |
| AI System Digital Asset | `alm_ai_system_digital_asset` | Deployable AI software/binaries |
| AI Model Digital Asset | `alm_ai_model_digital_asset` | LLM/ML/SLM models |
| AI Dataset Digital Asset | `alm_ai_dataset_digital_asset` | Training/validation datasets |
| AI Prompt Digital Asset | `alm_ai_prompt_digital_asset` | Prompts as a tracked asset |

## SDLC Component types

| Type | Examples | Deployed as |
|---|---|---|
| Application | Microservices, APIs | Application Service (Service Instance) |
| Infrastructure | DB configs, security configs | Infrastructure CI snapshot |

## Foundational entities that contribute

- **System Component Model, Product Feature, AI System Product Model, AI Content Product Model** — referential objects for what's being built

## Key v5 relationships

| From | Relationship | To |
|---|---|---|
| Business Application | Contains | SDLC Component |
| SDLC Component | Consumes | Service Instance |

## Class notes

*(none yet — DevOps-driven engagement work has not landed here.)*

## Related notes

- [README](README.md)
- [design-planning](design-planning.md) — where the Business Applications that contain SDLC Components live
- [service-delivery](service-delivery.md) — where SDLC Components deploy *to*
