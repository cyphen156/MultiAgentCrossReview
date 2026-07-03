Review-ID: 2026-07-04_WorkbenchStateBoundary
Author: Codex
Baseline: public-framework-boundary
Session-Id:
Status: Evidence-checked

# Review

## Judgment

Use a three-part split:

1. `MultiAgentCrossReview` for public process and tooling.
2. `MultiAgentWorkbenchStateSync` for the reusable sync tool.
3. A user-chosen state repository for real mutable records.

## Evidence

- `WorkbenchStateSync` includes `UserSettings/**/*.md`, `Projects/<name>/RULES.md`, and `Reviews/<review-id>/**`.
- It excludes public framework files, project mirrors, raw sessions, and secret-shaped files.
- A sanitized `Examples/WorkbenchState/` tree gives readers a concrete layout without normalizing public real-review commits.

## Risk

The sync tool repository name must match its broadened role. Keeping the old `PrivateRulesSync` name makes the model look like a rules-only vault again.
