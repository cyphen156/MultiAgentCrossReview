# Workbench State Example

This directory is a sanitized public example of the state that WorkbenchStateSync moves.

Real state belongs in a user-configured repository or worktree. The public MultiAgentCrossReview repository keeps only framework files, templates, tooling, and examples like this one.

## Example Layout

```text
Examples/WorkbenchState/
  UserSettings/preferences.example.md
  Projects/ExampleProject/RULES.md
  Reviews/2026-07-04_ExampleReview/
    README.md
    Claud/REVIEW.md
    Codex/REVIEW.md
    DECISION.md
```

Equivalent real paths in a state repository:

```text
UserSettings/preferences.md
Projects/ExampleProject/RULES.md
Reviews/2026-07-04_ExampleReview/README.md
Reviews/2026-07-04_ExampleReview/Claud/REVIEW.md
Reviews/2026-07-04_ExampleReview/Codex/REVIEW.md
Reviews/2026-07-04_ExampleReview/DECISION.md
```
