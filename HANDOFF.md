# HANDOFF - Current Workspace Bootstrap

Updated: 2026-08-09

This public repository is the MultiAgentCrossReview framework. Keep public process, templates, scripts, and package tooling here. User-managed state is synchronized separately.

## Repository Roles

| Repository / area | Role |
|---|---|
| `MultiAgentCrossReview` | Public framework/workbench: common rules, project templates, review process docs, `_TEMPLATE`, scripts, sync-tool connectors |
| `MultiAgentWorkbenchStateSync` | Public example: workbench-state sync tool template |
| `MultiAgentWorkbenchStateVault` | Private real instance: the state tool **+ real data** (`UserSettings/**/*.md`, `Projects/<name>/RULES.md`, real `Reviews/<review-id>/**`) |
| `AgentSessionSync` | Public example: session sync + agent launcher tool template |
| `AgentSessionVault` | Private real instance: the session tool **+ real Codex/Claude JSONL** |

The `...Sync` repos are public examples/templates. The `...Vault` repos are the private, self-contained instances (tool + real data) you actually clone and use. Keep vaults private for real work.

## Fresh Machine Bootstrap

1. Clone this public workbench repository.
2. Clone or create the user-managed state repository.
3. Register your MultiAgentWorkbenchStateVault (the self-contained real instance; the public MultiAgentWorkbenchStateSync is only the example template): `.\Packages\WorkbenchStateSync\Register.ps1 -ToolRoot <vault path>`. This writes the ignored local registry `UserSettings/sync-tools.json`. The adapter passes `-VaultRoot <that vault>` to the Vault launcher, so no separate Vault config is needed.
4. Optional: register your AgentSessionVault the same way: `.\Packages\AgentSessionSync\Register.ps1 -ToolRoot <vault path>`. (Legacy `Packages/*/*.config.psd1` still works as a backward-compatible fallback.)
5. Create ignored `Projects/projects.json` from `Projects/projects.example.json` and set machine-local source project paths.
6. Pull configured state/session packages into the workbench:

```powershell
.\Start.ps1
```

Create local taskbar shortcuts when needed:

```powershell
.\Launchers\Create-Shortcuts.ps1
```

Root `Start.ps1` runs every external sync adapter under `Packages/` (folder = membership). Adapters with no configured external tool are reported as `SKIP`, not as fatal setup errors.

7. Rebuild the local source mirror only when needed:

```powershell
.\Packages\ProjectSync\Sync.ps1
```

## Finish Work

Push configured state/session packages:

```powershell
.\Finish.ps1
```

Root `Finish.ps1` continues across packages, prints a `Package | Action | Result | Reason` summary table, and returns non-zero if any package fails.

Generated `Launchers\Shortcuts\` `.lnk` files are tracked in git; regenerate them after clone with `Launchers\Create-Shortcuts.ps1` to fix machine-specific paths.

Use `-SkipGitPull` or `-SkipGitPush` when the state repository has no remote or you want local-only synchronization.

`Packages/ProjectSync/` exposes a `Sync` command (not `Start`/`Finish`), so the folder-scanning root one-click never runs it. Run `.\Packages\ProjectSync\Sync.ps1` manually only when the project mirror needs refresh.

## Boundaries

- Public framework files stay in this repository: `Common/`, `Reviews/README.md`, `Reviews/_TEMPLATE/**`, `Reviews/run-review.ps1`, package code, examples.
- User-managed state is synchronized by WorkbenchStateSync: `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, real `Reviews/<review-id>/**`.
- Excluded from WorkbenchStateSync: `Projects/<name>/baseline/**`, `Projects/<name>/edit/**`, build outputs, logs, raw session JSONL, credentials, tokens, local machine config.
- Raw Codex/Claude session transport is a session-sync concern. The public AgentSessionSync repo is only the example template; the real instance you point `ToolRoot` at is the self-contained AgentSessionVault (tool + real session JSONL). This workbench keeps only a thin package adapter.

## Current Known Follow-Up

Old public history is intentionally left public. Current `HEAD` tracks only framework review files under `Reviews/`; future real review instances are ignored and should move through the configured state repository.

### Session retention: both legs are done

Updated: 2026-08-09. Both the Claude and Codex legs of AgentSessionVault now share one retention contract, and the public AgentSessionSync template carries the same code and docs.

**The contract**

The transport unit is the agent app index, not a project. `ProjectRoot` anchors Start/Finish only and never limits scope. Retention has two tiers:

- `Claude/projects/<key>/`, `ClaudeApp/claude-code-sessions/`, and `Codex/sessions/<cwd-key>/YYYY/MM/DD/` are the active working set and the only thing Pull restores.
- `Claude/archive/<key>/`, `ClaudeApp/archive/`, and `Codex/archive/<cwd-key>/YYYY/MM/DD/` are permanent storage and are never restored automatically.
- Push **moves** into the archive tier and never deletes from the vault, guarded by `ActiveWindowDays` (30).
- `Launchers\Restore-ArchivedSession.ps1` brings an archived session back, from either agent's archive. An archive without a restore path is a grave.
- The app's `deleted_<id>` markers are transported and treated as tombstones in both directions. They retire the list entry only; the transcript is preserved.

Rationale: the apps enforce their own retention window, but this repository kept everything and Pull fed it straight back, so the index could never shrink. Preserving everything is correct; re-seeding the working set with it is not.

**Where the two agents deliberately differ**

Claude Code prunes on its own schedule, so a transcript missing from the local app index means *aged* — that plus a git-based recency check (renames excluded) is the archive signal. Codex prunes nothing, so local absence means *the user deleted it* and must never be read as aging. The Codex signals are instead:

- explicit — the rollout is present in `~/.codex/archived_sessions`; this always outranks age;
- aging — the **top-level** `timestamp` of the rollout's last record is older than `ActiveWindowDays`.

File mtime (`git checkout` rewrites it), the rollout filename's start date (a long-running thread would be misjudged), and the current host's cwd are not valid age criteria. A nested `payload.timestamp` is not the record timestamp either — the reader parses each record and reads only the top-level property.

**Storage layout: path = A, tag = B**

Codex vault copies are split by a deterministic key derived from the rollout's first `session_meta.payload.cwd`; Pull strips that axis back off, so the local app tree is untouched. Semantic project membership is many-to-many and lives in `Codex/session_projects.jsonl` (`Set-CodexSessionProjects.ps1`), so re-classifying never moves a large rollout. Push runs unattended and cannot judge subject — that is why the physical path uses the mechanical key and not the topic.

**Standing constraints**

- Never delete from the vault. Move to an archive tier.
- Never use `robocopy /PURGE` against the vault — it would delete the other host's sessions this host has never pulled.
- Any age criterion must be computable identically on both hosts.
- Agent memory files (`~/.claude/projects/<key>/memory/*.md`, `~/.codex/memories`) are machine-local and are not transported by this tool.
- Entries whose transcript is present in neither tier are neither deleted nor auto-archived — the other host may hold the only copy. Push warns and leaves them in the active index.
- Rollouts near GitHub's 100MiB per-file limit are transported as `.jsonl.gz`; the secret scan runs on the local source **before** the copy into the worktree.

Reference implementation: `Launchers\AgentSessionSync.Common.ps1`, `Launchers\Push-Sessions.ps1` steps 3a-3g, and the assertions in `Launchers\tests\Test-AgentSessionSync.ps1`.

**Still open (not this contract's scope)**

Codex sidebar reduction is a separate matter: Push cleans the vault and the local working set but never touches `state_5.sqlite`, so the app's own list is repaired only through `Repair-CodexThreadVisibility.ps1`, which stops at `version-mismatch` when the PATH CLI is older than the restored rollout format. Git LFS has not been decided.
