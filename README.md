# MultiAgentCrossReview

Public framework for cross-checking Claude and Codex review results.

This repository is not a public archive of real review work. It keeps the process, templates, tools, and sanitized examples. Real review records and user-specific settings belong in a user-configured state repository.

## Repository Roles

| Repository | Visibility | Role |
|---|---:|---|
| `MultiAgentCrossReview` | Public | Review process, templates, orchestration scripts, package copies, and sanitized examples. |
| `MultiAgentWorkbenchStateSync` | Public | Standalone sync tool for user-managed workbench state. |
| User state repository | User-chosen | Real `UserSettings/`, `Projects/<name>/RULES.md`, and `Reviews/<review-id>/` records. Usually private. |
| `AgentSessionSync` | Public | Separate transport for raw Codex/Claude session data. |

## Public / Private Boundary

Public content in this repository:

- `Common/**`
- `Reviews/README.md`
- `Reviews/_TEMPLATE/**`
- `Reviews/run-review.ps1`
- `Packages/WorkbenchStateSync/**`
- `Examples/**`

User-managed state that must not be committed here:

- actual `Reviews/<review-id>/` instances
- user callbacks and user-derived review context
- real `Claud/REVIEW.md`, `Codex/REVIEW.md`, and `DECISION.md` records
- real review artifacts and candidate patches
- local `UserSettings/**/*.md`
- local `Projects/<name>/RULES.md`
- raw session JSONL, tokens, credentials, machine paths, and logs

## Concrete Example

`Examples/WorkbenchState/` is the tracked, sanitized example. It shows the shape of the state that WorkbenchStateSync moves:

```text
Examples/WorkbenchState/
  UserSettings/preferences.example.md
  Projects/MultiAgentCrossReview/RULES.md
  Reviews/2026-07-04_WorkbenchStateBoundary/
    README.md
    Claud/REVIEW.md
    Codex/REVIEW.md
    DECISION.md
```

In a real state repository, the same shape would live at:

```text
UserSettings/preferences.md
Projects/MultiAgentCrossReview/RULES.md
Reviews/2026-07-04_WorkbenchStateBoundary/README.md
Reviews/2026-07-04_WorkbenchStateBoundary/Claud/REVIEW.md
Reviews/2026-07-04_WorkbenchStateBoundary/Codex/REVIEW.md
Reviews/2026-07-04_WorkbenchStateBoundary/DECISION.md
```

Do not create real review instances under public `Reviews/<review-id>/`. They are ignored by `.gitignore` and should be synced through the state repository.

## Daily Flow

Pull user-managed state into the workbench:

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
```

Create a new real review in the state-backed worktree:

```powershell
Copy-Item .\Reviews\_TEMPLATE .\Reviews\2026-07-04_MyTopic -Recurse
```

Check or advance the review:

```powershell
.\Reviews\run-review.ps1 -Topic 2026-07-04_MyTopic -Status
.\Reviews\run-review.ps1 -Topic 2026-07-04_MyTopic -Steps 1
```

Push user-managed state back to the configured state repository:

```powershell
.\Packages\WorkbenchStateSync\Finish.ps1 -CommitMessage 'workbench state: update review'
```

## WorkbenchStateSync

`Packages/WorkbenchStateSync/` is the in-repository copy of the sync tool. It synchronizes:

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
Reviews/<review-id>/**
```

It excludes public framework files and local working copies:

```text
UserSettings/README.md
Reviews/README.md
Reviews/_TEMPLATE/**
Reviews/run-review.ps1
Projects/<name>/baseline/**
Projects/<name>/edit/**
*.jsonl, *.db, *.sqlite, *.key, *.pem, *.env, *.user, *.log
```

Configure the local target:

```powershell
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
```

Then edit `workbenchstatesync.config.psd1`:

```powershell
@{
    VaultRoot = 'D:\State\MultiAgentWorkbenchState'
    WorktreeRoot = ''
}
```

`workbenchstatesync.config.psd1` and `WorkbenchStateSync.local.psd1` are local-only and ignored by git.

## Review Model

Each review topic uses one mutable file per role:

```text
Reviews/<review-id>/
  README.md
  Claud/REVIEW.md
  Codex/REVIEW.md
  DECISION.md
```

Current truth is the working tree file. History is git history in the state repository.

The initial Claude and Codex judgments should be independent. After both exist, each agent cross-checks the other result and records disagreements, missing evidence, and boundary issues. User callbacks are inputs to evaluate, not automatic truth.

## Project Mirrors

`Projects/<name>/baseline/` is a read-only mirror used for review. Agent edit copies live under:

```text
Projects/<name>/edit/Claud/
Projects/<name>/edit/Codex/
```

These folders are local working material and are not synced by WorkbenchStateSync.

## Rules

Rule loading order:

1. `AGENTS.md`
2. `Common/ROUTING.md`
3. `Common/SHARED_RULES.md`
4. `Reviews/README.md`
5. `Projects/<active>/RULES.md`
6. local `UserSettings/` files if present

Before drafting project-specific commit or DevLog text, read `Projects/<active>/RULES.md` first.

## License

MIT.
