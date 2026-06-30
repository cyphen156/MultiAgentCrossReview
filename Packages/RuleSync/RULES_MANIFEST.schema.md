# RuleSync Manifest Schema

The first RuleSync implementation uses a fixed default manifest so the workbench can bootstrap without extra configuration.

Default manifest:

```text
UserSettings/**/*.md
Projects/*/RULES.md
```

Future explicit manifest entries should use this shape:

```powershell
@{
    Name = 'user-settings'
    WorktreePath = 'UserSettings'
    VaultPath = 'UserSettings'
    Include = @('*.md')
    Recurse = $true
}
```

Rules:

- Paths are relative to the MultiAgentCrossReview worktree and the RulesVault root.
- Entries must copy markdown rule/settings files only.
- Entries must not include `Projects/<name>/baseline/**` or `Projects/<name>/edit/**`.
- Secret, token, database, and environment files must remain excluded even if a future manifest tries to include them.

