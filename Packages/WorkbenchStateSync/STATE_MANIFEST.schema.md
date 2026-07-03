# WorkbenchStateSync Manifest Schema

The current implementation uses a fixed built-in manifest so the workbench can bootstrap without extra configuration.

Default included state:

```text
UserSettings/**/*.md
Projects/*/RULES.md
Reviews/*/**
```

Default excluded framework/local-heavy paths:

```text
UserSettings/README.md
Reviews/README.md
Reviews/_TEMPLATE/**
Reviews/run-review.ps1
Projects/*/baseline/**
Projects/*/edit/**
```

Future explicit manifest entries should use this shape:

```powershell
@{
    Name = 'reviews'
    WorktreePath = 'Reviews'
    VaultPath = 'Reviews'
    Include = @('*')
    Recurse = $true
}
```

Rules:

- Paths are relative to the MultiAgentCrossReview worktree and the configured state repository root.
- Entries must not include project mirrors, edit copies, build artifacts, raw session JSONL, tokens, databases, environment files, or machine credentials.
- Public framework files stay in the public MultiAgentCrossReview repository.
