# RuleSync

RuleSync is the public sync engine for private MultiAgentCrossReview rule files.

It separates three roles:

- `MultiAgentCrossReview`: public workbench and the place agents read rules from.
- `MultiAgentRulesVault`: private rule vault and the SSOT for personal/project-local markdown rules.
- `Packages/RuleSync`: public copy engine that moves markdown rule files between them.

## SSOT

`MultiAgentRulesVault` is the SSOT for private markdown rules.
The MultiAgentCrossReview worktree is the materialized working copy.
Claude/Codex memory is only cache or context and must not be treated as source of truth.

## Default Synced Files

Synced:

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
```

Never synced:

```text
Projects/<name>/baseline/**
Projects/<name>/edit/**
auth/token/db/env/key files
build artifacts
session JSONL
```

If an agent has useful WIP under `Projects/<name>/edit/**`, promote the relevant patch or evidence to
`Reviews/<id>/<agent>/artifacts/` before switching machines. RuleSync intentionally does not carry edit copies.

## Usage

Create a local ignored config:

```powershell
Copy-Item .\Packages\RuleSync\rulesync.config.example.psd1 .\Packages\RuleSync\rulesync.config.psd1
```

Edit `rulesync.config.psd1` and set `VaultRoot` to your private RulesVault clone.
This file is machine-local and must not be committed.

Pull private rules into the worktree:

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Pull
```

Push worktree rule changes back to the private vault:

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Push
```

You may still pass `-VaultRoot` or `-WorktreeRoot` explicitly to override local config.
Use `-DryRun` to preview, and `-Force` to overwrite divergent destinations.

## Public vs Private Files

Tracked in the public MIT repository:

```text
Packages/RuleSync/rulesync.ps1
Packages/RuleSync/rulesync.config.example.psd1
Packages/RuleSync/README.md
```

Ignored local files:

```text
Packages/RuleSync/rulesync.config.psd1
RuleSync.local.psd1
```

Do not commit actual vault paths or private markdown rules.

## Conflict Policy

RuleSync never silently overwrites a different destination file.

When source and destination both exist and differ:

1. A timestamped `.bak` copy of the destination is created next to the destination file.
2. A warning is printed.
3. Without `-Force`, the file is skipped.
4. With `-Force`, the source overwrites the destination after the backup is made.

## Machine Files

Files under `UserSettings/machines/<host>.md` are intended to be host-specific.
Each machine should edit only its own host file.

