# WorkbenchStateSync

WorkbenchStateSync is the package-level sync helper for user-managed MultiAgentCrossReview state.

The public MultiAgentCrossReview repository keeps process, templates, docs, and tools. Mutable user state is removed from the public repository and synchronized with a user-configured repository or worktree.

The target repository may be private or public. Choose its visibility according to the data you put there.

This package copy is canonical for the workbench implementation. The standalone public `MultiAgentWorkbenchStateSync` repository is published from this package, not developed as a separate competing source.

## Sync Scope

Included:

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
Reviews/<review-id>/**
```

Excluded:

```text
UserSettings/README.md
Reviews/README.md
Reviews/_TEMPLATE/**
Reviews/run-review.ps1
Projects/<name>/baseline/**
Projects/<name>/edit/**
*.jsonl, *.db, *.sqlite, *.key, *.pem, *.env, *.user, *.log
```

Raw conversation/session JSONL remains a separate AgentSessionSync concern.

## Configuration

Copy the example config to the ignored local config path:

```powershell
Copy-Item .\Packages\WorkbenchStateSync\workbenchstatesync.config.example.psd1 .\Packages\WorkbenchStateSync\workbenchstatesync.config.psd1
```

Then set `VaultRoot` to the local clone/path of the repository that should store the synchronized state.

```powershell
@{
    VaultRoot = 'D:\State\MultiAgentWorkbenchState'
    WorktreeRoot = ''
}
```

`WorkbenchStateSync.local.psd1` at the repository root is also supported and is ignored by git.

## Usage

Pull state from the configured repository into the current workbench:

```powershell
.\Packages\WorkbenchStateSync\Start.ps1
```

Push state from the current workbench into the configured repository, then commit and push that repository:

```powershell
.\Packages\WorkbenchStateSync\Finish.ps1
```

The repository root `Start.ps1` / `Finish.ps1` run this package only because it is listed with `enabled: true` in `Packages/sync-tools.json`. Project mirror refresh is separate and belongs to `Packages/ProjectSync/Start.ps1`.

Lower-level copy operations are available directly:

```powershell
.\Packages\WorkbenchStateSync\workbenchstatesync.ps1 -Direction Pull
.\Packages\WorkbenchStateSync\workbenchstatesync.ps1 -Direction Push
```

Useful options:

```powershell
.\Packages\WorkbenchStateSync\Start.ps1 -DryRun
.\Packages\WorkbenchStateSync\Finish.ps1 -DryRun
.\Packages\WorkbenchStateSync\Finish.ps1 -CommitMessage 'workbench state: update desktop'
.\Packages\WorkbenchStateSync\Start.ps1 -Force
.\Packages\WorkbenchStateSync\Finish.ps1 -NoOverwrite
.\Packages\WorkbenchStateSync\Finish.ps1 -SkipGitPush
```

## Conflict Behavior

WorkbenchStateSync does not silently overwrite divergent destination files.

When source and destination both have a file at the same relative path with different content:

1. The destination file is copied to a timestamped `.bak-*` backup.
2. The copy is skipped unless `-Force` is supplied.
3. With `-Force`, the source file overwrites the destination after backup.

Token-like content is scanned on push. Values are not printed.
