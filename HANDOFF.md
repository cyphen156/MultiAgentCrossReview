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
4. Create ignored `Projects/projects.json` from `Projects/projects.example.json` and set machine-local source project paths.
5. Pull state into the workbench:

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
```

6. Rebuild the local source mirror if needed:

```powershell
.\sync.ps1
```

## Finish Work

Push user-managed state back to the configured state repository:

```powershell
.\Packages\WorkbenchStateSync\Finish.ps1
```

Use `-SkipGitPull` or `-SkipGitPush` when the state repository has no remote or you want local-only synchronization.

## Boundaries

- Public framework files stay in this repository: `Common/`, `Reviews/README.md`, `Reviews/_TEMPLATE/**`, `Reviews/run-review.ps1`, package code, examples.
- User-managed state is synchronized by WorkbenchStateSync: `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, real `Reviews/<review-id>/**`.
- Excluded from WorkbenchStateSync: `Projects/<name>/baseline/**`, `Projects/<name>/edit/**`, build outputs, logs, raw session JSONL, credentials, tokens, local machine config.
- Raw Codex/Claude session transport remains an AgentSessionSync concern.

## Current Known Follow-Up

Existing public history still tracks old real review instance files. New review instances are ignored, but existing tracked files must be untracked in a separate cleanup step after preserving them in the configured state repository.
