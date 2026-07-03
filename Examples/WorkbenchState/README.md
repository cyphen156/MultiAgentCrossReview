# Workbench State Example

This directory is a sanitized public example of the state that WorkbenchStateSync moves.

It is intentionally placed under `Examples/`, not `Reviews/`, because real review instances must not be tracked by the public framework repository.

## What This Demonstrates

The example models a real workflow decision:

- public `MultiAgentCrossReview` keeps framework files only;
- real `Reviews/<review-id>/` records move through a user-managed state repository;
- `WorkbenchStateSync` is the button-like transport for that state;
- raw session JSONL remains separate from review state.

## Public Example Path

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

## Equivalent Real State Path

```text
UserSettings/preferences.md
Projects/MultiAgentCrossReview/RULES.md
Reviews/2026-07-04_WorkbenchStateBoundary/README.md
Reviews/2026-07-04_WorkbenchStateBoundary/Claud/REVIEW.md
Reviews/2026-07-04_WorkbenchStateBoundary/Codex/REVIEW.md
Reviews/2026-07-04_WorkbenchStateBoundary/DECISION.md
```

The real version belongs in the configured state repository/worktree and is synced with:

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
.\Packages\WorkbenchStateSync\Finish.ps1 -CommitMessage 'workbench state: update boundary review'
```
