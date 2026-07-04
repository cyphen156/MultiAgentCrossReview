# HANDOFF - Current Workspace Bootstrap

Updated: 2026-07-04

This public repository is the MultiAgentCrossReview framework. Keep public process, templates, scripts, and package tooling here. User-managed state is synchronized separately.

## Repository Roles

| Repository / area | Role |
|---|---|
| `MultiAgentCrossReview` | Public framework: common rules, project templates, review process docs, `_TEMPLATE`, scripts, sync packages |
| configured state repository | User-managed workbench state: `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, real `Reviews/<review-id>/**` |
| `AgentSessionSync` | Separate raw session JSONL transport |

The configured state repository may be private or public. Choose visibility according to the data stored there; private is recommended for real work.

## Fresh Machine Bootstrap

1. Clone this public workbench repository.
2. Clone or create the user-managed state repository.
3. Create ignored `Packages/WorkbenchStateSync/workbenchstatesync.config.psd1` from the example and set `VaultRoot` to the state repository path.
4. Optional: create ignored `Packages/AgentSessionSync/agentsessionsync.config.psd1` from the example and set `ToolRoot` to the local AgentSessionSync clone.
5. Create ignored `Projects/projects.json` from `Projects/projects.example.json` and set machine-local source project paths.
6. Pull configured state/session packages into the workbench:

```powershell
.\Start.ps1
```

Root `Start.ps1` reads `Packages/sync-tools.json` and runs only tools with `enabled: true`. Missing local configs are reported as `SKIP`, not as fatal setup errors.

7. Rebuild the local source mirror only when needed:

```powershell
.\Packages\ProjectSync\Start.ps1
```

## Finish Work

Push configured state/session packages:

```powershell
.\Finish.ps1
```

Root `Finish.ps1` continues across packages, prints a `Package | Action | Result | Reason` summary table, and returns non-zero if any package fails.

Use `-SkipGitPull` or `-SkipGitPush` when the state repository has no remote or you want local-only synchronization.

ProjectSync is listed in `Packages/sync-tools.json` but defaults to `enabled: false`. Run it manually only when the project mirror needs refresh.

## Boundaries

- Public framework files stay in this repository: `Common/`, `Reviews/README.md`, `Reviews/_TEMPLATE/**`, `Reviews/run-review.ps1`, package code, examples.
- User-managed state is synchronized by WorkbenchStateSync: `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, real `Reviews/<review-id>/**`.
- Excluded from WorkbenchStateSync: `Projects/<name>/baseline/**`, `Projects/<name>/edit/**`, build outputs, logs, raw session JSONL, credentials, tokens, local machine config.
- Raw Codex/Claude session transport remains an AgentSessionSync concern. The standalone AgentSessionSync repo is canonical; this workbench keeps only a thin package adapter.

## Current Known Follow-Up

Old public history is intentionally left public. Current `HEAD` tracks only framework review files under `Reviews/`; future real review instances are ignored and should move through the configured state repository.
