# UserSettings

This directory is the local private settings area for a user of this workbench.

Only this README is intended to be tracked. All other files and subdirectories under
`UserSettings/` are ignored by git.

Use this area for personal, non-public settings such as:

- tone and language preferences;
- no-yes-man / critique behavior preferences;
- private workflow notes;
- machine-specific user context;
- local session or handoff hints that should not enter the public MIT repository.

Suggested local files:

```text
UserSettings/preferences.md       # tone, critique style, stable personal workflow
UserSettings/session.md           # current local handoff notes
UserSettings/machines/<name>.md   # machine-specific notes
```

`preferences.md` is the default always-on private user layer. If it exists, agents
should load it before project-specific rules. Do not gate it behind tone/style
keywords. Its existence is optional, and it cannot weaken platform safety, source
protection, permission boundaries, or other non-negotiable workbench invariants.
Other files in this directory are not always-on rule inputs. Load handoff notes,
machine notes, registries, and pending patches only when the current task needs them.

## Sync tool registry

`sync-tools.json` records which private Vaults this workbench's `Packages/*` adapters
call. It is the single place the user declares "which sync tools do I use, and where
are they."

```text
UserSettings/sync-tools.example.json   # public tracked example (placeholder paths)
UserSettings/sync-tools.json           # real local registry, gitignored (may hold absolute paths)
```

- Create/update it with `Packages/<Tool>/Register.ps1 -ToolRoot <vault path>` (or `Startup.ps1`).
- `toolRoot` may be absolute or relative; relative is resolved from the workbench root.
- Because it can contain machine-local absolute paths, `sync-tools.json` is gitignored and
  must never be committed or synchronized to a state repository. Only the `.example` is tracked.
- Resolution order for each adapter: `sync-tools.json` first, then legacy `Packages/*/*.config.psd1`
  (backward-compatible fallback), then auto-discovery of sibling Vault folders.

The configured WorkbenchStateSync repository is the SSOT for user-managed
workbench state. Files under this directory are materialized working copies.
Use `Packages/WorkbenchStateSync/workbenchstatesync.ps1` to pull them from or
push them to that configured state repository.

Do not put public workbench rules here. Put public rules in `Common/SHARED_RULES.md`
or `Reviews/README.md`.

Do not put project-specific code style or architecture rules here. Put those in
`Projects/<name>/RULES.md`.
