# HANDOFF - Current Workspace Bootstrap

Updated: 2026-07-04

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

### Session retention: Codex leg is not done (assigned to Codex)

Updated: 2026-08-04. The Claude leg of AgentSessionVault was reworked; the Codex leg was deliberately left untouched so it can be picked up separately.

**What changed on the Claude leg**

The transport unit is the agent app index, not a project. `ProjectRoot` no longer limits scope. Beyond that, retention now has two tiers:

- `Claude/projects/<key>/` is the active working set and is the only thing Pull restores.
- `Claude/archive/<key>/` is permanent storage and is never restored automatically.
- Push **moves** (never deletes) any transcript the app has already dropped locally into the archive tier, guarded by `ActiveWindowDays` (30) and a git-based recency check that ignores renames.
- `Launchers\Restore-ArchivedSession.ps1` brings an archived session back. An archive without a restore path is a grave.
- The app's `deleted_<id>` markers are transported and treated as tombstones in both directions. They retire the list entry only; the transcript is preserved.

Rationale: the app enforces its own retention window, but this repository kept everything and Pull fed it straight back, so the index could never shrink. Preserving everything is correct; re-seeding the working set with it is not.

**What Codex needs**

The same two problems exist on the Codex leg and none of the above applies to it yet.

1. **Deletions do not propagate.** `Push-Sessions.ps1` copies with `robocopy /E` and never removes, so rollouts deleted from `~/.codex/sessions` stay in the vault and return on the next Pull. On 2026-08-04, 9 rollouts (~302MB) were deleted locally and every one of them is still in `origin/main`. Do **not** solve this with `/PURGE` — it would delete the other host's sessions that this host has never pulled.
2. **The index resurrects entries.** `Sync-CodexIndex.ps1` unions by `id` with newest `updated_at` winning, so removing a line locally is undone by the next merge. This union is correct for its original purpose (both hosts write the same file) and must not simply be dropped.
3. **No deletion signal exists.** Claude leaves `deleted_<id>` markers; Codex does not. A Codex tombstone has to be invented or the archive move has to be driven by something else — the index entry's absence combined with an age window is the obvious candidate, mirroring `Get-TransportRecentPaths`.
4. **Size is the Codex problem, not Claude's.** `Codex/` is 728MB against `Claude/` at 198MB, and `.git` is 770MB. Two rollouts already exceed GitHub's 100MiB per-file limit and are excluded from transport by the guard in `Push-Sessions.ps1` (step 3d), which prints what it skipped on every run. Compressed transport (`.gz`) or Git LFS would remove that ceiling; neither has been decided.

**Constraints to respect**

- Never delete from the vault. Move to an archive tier, as the Claude leg does.
- Whatever criterion is chosen must be computable identically on both hosts. File mtime is not — `git checkout` rewrites it. Use git history or content timestamps.
- Keep the exclusion loud. A silent partial transport is the failure class this repository just finished removing.

Reference implementation to mirror: `Launchers\AgentSessionSync.Common.ps1` (`Get-TransportRecentPaths`, `Move-ToTransportArchive`, `Get-ClaudeDeletionMarkers`), `Launchers\Push-Sessions.ps1` steps 3d/3e/3f, and the assertions in `Launchers\tests\Test-AgentSessionSync.ps1`.
