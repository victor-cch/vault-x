# 60-projects

Engagement-bounded work: integration projects, transformations, and other time-boxed initiatives.
Each project has its own folder and should reference shared standards in [[10-csdm]], [[20-servicenow-cch]], [[30-dynatrace-ref]], and [[40-dynatrace-cch]] instead of duplicating baseline guidance.

## Current structure

### jira-sn-integration/
- Purpose: ServiceNow ITSM to Jira integration design and assessment artifacts.
- Current contents:
	- `README.md`
	- `hld-snow-jira-integration.md`
	- `hld-snow-jira-integration-REWORKED-for-review.md`
	- `hld-assessment.md`

### ntt/
- Purpose: NTT engagement materials and e-bond design work.
- Current contents:
	- `README.md`
	- `01-ntt-onboarding-impact.md`
	- `daily-log/`
	- `hld/`

### onetrust/
- Purpose: OneTrust integration blueprinting and reference pack.
- Current contents:
	- `README.md`
	- `blueprints/`
	- `references/`
	- `diagrams/`

## Conventions for new project folders

- Create a dedicated folder under `60-projects/` named after the engagement.
- Include a local `README.md` with scope, owners, and artifact index.
- Keep project-specific HLDs, assessments, and logs inside that project folder.
- Link to shared models and governance from reference pillars instead of copying them.
