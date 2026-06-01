# Vault X (vault-x)

ITSM / observability consulting workbench — an Obsidian vault uniting CSDM v5 reference, CCH current-state reality, Dynatrace integration patterns, and Dynatrace deployed-reality snapshots.

## Required software

- [Obsidian](https://obsidian.md) — desktop app (Mac, Windows, Linux, Azure DevBox)
- Git — for sync across machines

## First-time setup

1. Install Obsidian.
2. Clone this repo locally.
3. Obsidian → **Open folder as vault** → select the cloned directory.
4. Settings → **Community plugins** → **Turn on community plugins** (Obsidian's "restricted mode" must be disabled).
5. Install the plugins listed under [Required plugins](#required-plugins).
6. Restart Obsidian.

After first open, Obsidian creates a `.obsidian/` directory. The `.gitignore` excludes per-machine workspace state (window layout, cache) so those don't churn the repo; shared config (plugin list, hotkeys, appearance) is tracked.

## Required plugins

| Plugin | Purpose |
|---|---|
| **Dataview** | YAML frontmatter queries — turns the vault into a queryable graph |
| **Excalidraw** | Inline diagrams (architecture sketches, mapping visualisations) |
| **Templater** | Consistent note structure across hundreds of files |

Mermaid is built into Obsidian — no install required.

The official [Obsidian Web Clipper](https://obsidian.md/clipper) browser extension is also recommended for capturing ServiceNow Docs and Dynatrace Docs pages directly into `00-inbox/`.

## Excel files

Obsidian doesn't natively render `.xlsx`. Two practical approaches:

- **Active editing**: keep the `.xlsx` in-repo, right-click in Obsidian → **Open externally** to launch in Excel / LibreOffice.
- **Stable data**: convert to a Markdown table once content settles, then query alongside other notes via Dataview.

## Folder structure

```
00-inbox/              ← Capture point: PDFs, screenshots, half-formed thoughts
10-csdm/               ← The canon: CSDM v5 framework, classes, glossary
15-servicenow-ref/     ← ServiceNow platform fundamentals (sys_id, GlideRecord, …)
20-servicenow-cch/     ← CCH current-state reality (the deployed SN instance)
30-dynatrace-ref/      ← Dynatrace integration patterns and DQL reference
40-dynatrace-cch/      ← CCH-specific deployed Dynatrace state
50-mappings/           ← The web: how the pillars connect
60-projects/           ← Engagement-bounded work (integrations, transformations)
70-processes/          ← ITSM process designs (Incident, Problem, Change, CM, …)
90-meta/               ← Templates, conventions, plugin notes
```

The 10–40 pillars are *reference layers* (what is / what should be). 50 is the cross-pillar web. 60 and 70 are *activity layers* — episodic engagement work and continuous process discipline respectively — which use the reference pillars as inputs and link out to them.

Each pillar has its own README describing what lives there.

## Sync across machines

Standard Git workflow — clone on each machine, `git pull` before working, `git commit` + `git push` regularly. The `.gitignore` keeps per-machine Obsidian state out of the repo.

## Provenance

Originally seeded from the prior `platform-z` repo, developed by Victor Andreev — retired with honours after becoming the bedrock of vault-x.

---

*Ideation by Feodor Venetsianov. Fruition by Claude and Victor Andreev.*
